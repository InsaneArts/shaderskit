#if canImport(Metal)
import Foundation
import Metal
import simd

// MARK: - Framework extensions used by the agent family

extension ComputeContext {
    /// Packs a kernel uniform struct into bytes for `setBytes`, following a `compute.uniformLayouts`
    /// entry. `setBytes` copies at encode time, so per-frame values (and per-dispatch values such as
    /// one cursor stamp) never race a frame that is still executing.
    func agentPackBytes(_ layout: UniformLayout, _ values: [String: [Float]]) -> [UInt8] {
        let size = max(16, (layout.size + 15) / 16 * 16)
        var bytes = [UInt8](repeating: 0, count: size)
        bytes.withUnsafeMutableBytes { raw in
            guard let p = raw.baseAddress else { return }
            for f in layout.fields {
                guard let v = values[f.path], !v.isEmpty, f.offset + 4 <= size else { continue }
                switch f.type {
                case "i32": p.storeBytes(of: Int32(v[0]), toByteOffset: f.offset, as: Int32.self)
                case "u32": p.storeBytes(of: UInt32(max(0, v[0])), toByteOffset: f.offset, as: UInt32.self)
                default:
                    for (i, x) in v.prefix(max(1, f.size / 4)).enumerated() where f.offset + i * 4 + 4 <= size {
                        p.storeBytes(of: x, toByteOffset: f.offset + i * 4, as: Float.self)
                    }
                }
            }
        }
        return bytes
    }

    /// Reads a field of the node's packed uniform block. For transformed props (colors, positions)
    /// this is the value upstream's `getCpuValue` returns, in the renderer's working color space.
    func agentUniformField(_ path: String) -> [Float]? {
        guard let f = descriptor.uniformLayout.field(path), f.offset + f.size <= uniformSize else { return nil }
        return (0..<max(1, f.size / 4)).map { uniformBytes.load(fromByteOffset: f.offset + $0 * 4, as: Float.self) }
    }

    /// Upstream `makeCpuValueGetter`: the raw numeric prop value, or `fallback` when it is not a number.
    func agentNumber(_ name: String, _ fallback: Float) -> Float {
        props[name]?.numberValue ?? fallback
    }

    /// A color prop as upstream's `getCpuValue` returns it (the transformed vec4).
    func agentColor(_ name: String, fallback: SIMD4<Float>) -> [Float] {
        if let v = agentUniformField("n_x.\(name)"), v.count == 4 { return v }
        return [fallback.x, fallback.y, fallback.z, fallback.w]
    }
}

// MARK: - The harness

/// Port of `createAgentSystem` (gpu/scaffolds/agentSystem.ts): the state buffers, the output
/// texture, the per-frame uniforms, the init latch and the per-frame step list shared by every
/// agent/particle shader.
///
/// Buffers are allocated by introspecting the kernels' storage bindings (one buffer per binding
/// name, sized from its `array<T, N>` type), which mirrors upstream allocating one buffer per
/// layout entry. Every kernel binds by name, so a shader with two layouts (ParticleFlow's fluid +
/// particle groups) runs through the same harness.
final class AgentSystem {
    enum Threads {
        /// The runtime agent count.
        case agents
        /// `maxAgents`, for the one-shot spawn.
        case max
        /// A per-frame 2D grid passed to `frame(grid:)`.
        case grid
        /// A fixed size (a full render target, a voxel grid).
        case fixed(Int, Int)
    }

    struct Pipeline {
        var kernel: Int
        var threads: Threads
    }

    struct Config {
        var maxAgents: Int
        /// Desktop cap (upstream `countCap.desktop`).
        var countCap: Int
        var outputKey = "outTex"
        var outputWidth: Int
        var outputHeight: Int
        var pipelines: [String: Pipeline]
        var program: [String]
        var initStep: String?
    }

    /// One kernel dispatch. `uniforms` overrides the frame's uniform bytes for this dispatch only.
    struct Dispatch {
        var kernel: Int
        var threads: SIMD3<UInt32>
        var uniforms: [String: [UInt8]] = [:]
    }

    let config: Config
    let output: MTLTexture
    private let kernels: [Int: ComputeKernelDescriptor]
    private let layouts: [String: UniformLayout]
    private var buffers: [String: MTLBuffer] = [:]
    private var textures: [String: MTLTexture] = [:]
    private var uniforms: [String: [UInt8]] = [:]
    private var zeroed = false
    private var initialized = false
    private var lastSeed: Float = 0

    init(context ctx: ComputeContext, config: Config) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute block") }
        self.config = config
        var byIndex: [Int: ComputeKernelDescriptor] = [:]
        for k in info.kernels { byIndex[k.index] = k }
        kernels = byIndex
        layouts = info.uniformLayouts
        for (key, p) in config.pipelines where byIndex[p.kernel] == nil {
            throw ShaderEngineError.missingFunction("\(name) kernel \(p.kernel) (\(key))")
        }
        for k in info.kernels {
            for b in k.buffers where b.space == "storage" && buffers[b.name] == nil {
                guard let length = Self.byteLength(b.type) else { throw ShaderEngineError.missingFunction("\(name) buffer \(b.name): \(b.type)") }
                guard let buf = ctx.device.device.makeBuffer(length: length, options: .storageModePrivate) else { throw ShaderEngineError.noMetalDevice }
                buf.label = "\(name) \(b.name)"
                buffers[b.name] = buf
            }
        }
        guard let out = ctx.makeTexture(width: config.outputWidth, height: config.outputHeight, label: "\(name) \(config.outputKey)") else {
            throw ShaderEngineError.noMetalDevice
        }
        output = out
        textures[config.outputKey] = out
    }

    /// Byte length of a storage binding type such as `array<vec4<f32>, 4096>` (std430 strides).
    static func byteLength(_ type: String) -> Int? {
        guard type.hasPrefix("array<"), let comma = type.lastIndex(of: ",") else { return nil }
        let countText = type[type.index(after: comma)...].filter { $0.isNumber }
        guard let count = Int(countText) else { return nil }
        let element = type[type.index(type.startIndex, offsetBy: 6)..<comma]
        let stride: Int
        if element.hasPrefix("vec4") || element.hasPrefix("vec3") { stride = 16 }
        else if element.hasPrefix("vec2") { stride = 8 }
        else { stride = 4 }
        return max(16, count * stride)
    }

    /// Name of the kernel uniform binding whose WGSL struct type is `type` (`SimParams`, `MarchParams`, …).
    func uniformName(ofType type: String) -> String? {
        for i in kernels.keys.sorted() {
            if let b = kernels[i]?.buffers.first(where: { $0.space == "uniform" && $0.type == type }) { return b.name }
        }
        return nil
    }

    /// Packs one uniform struct (by binding name) without storing it — for per-dispatch overrides.
    func pack(_ ctx: ComputeContext, _ name: String, _ values: [String: [Float]]) -> [UInt8] {
        guard let layout = layouts[name] else { return [UInt8](repeating: 0, count: 16) }
        return ctx.agentPackBytes(layout, values)
    }

    /// Writes the frame's value for one uniform struct (upstream `writeParams` / `paramsU.write`).
    func write(_ ctx: ComputeContext, _ name: String, _ values: [String: [Float]]) {
        uniforms[name] = pack(ctx, name, values)
    }

    /// Writes the struct the `SimParams` binding reads.
    func writeParams(_ ctx: ComputeContext, _ values: [String: [Float]]) {
        if let n = uniformName(ofType: "SimParams") { write(ctx, n, values) }
    }

    /// Binds a late-arriving texture (a child RTT, a solver's velocity texture).
    func bindExternal(_ name: String, _ texture: MTLTexture) {
        textures[name] = texture
    }

    /// Upstream `resolveCount`: clamp a raw count prop into `[min, countCap]`.
    func resolveCount(_ raw: Float, min minCount: Int = 16) -> Int {
        Swift.min(Swift.max(AgentMath.jsRound(Double(raw)), minCount), config.countCap)
    }

    func step(_ key: String, count: Int, grid: (Int, Int)? = nil) -> Dispatch? {
        guard let p = config.pipelines[key] else { return nil }
        let t: SIMD3<UInt32>
        switch p.threads {
        case .fixed(let w, let h): t = SIMD3(UInt32(w), UInt32(h), 1)
        case .grid: t = SIMD3(UInt32(grid?.0 ?? 1), UInt32(grid?.1 ?? 1), 1)
        case .max: t = SIMD3(UInt32(config.maxAgents), 1, 1)
        case .agents: t = SIMD3(UInt32(count), 1, 1)
        }
        return Dispatch(kernel: p.kernel, threads: t)
    }

    /// Upstream `sys.frame`: the program, with the one-shot init prepended on the first call and
    /// whenever `reseed` differs from the last seed.
    func frame(count: Int? = nil, grid: (Int, Int)? = nil, reseed: Float? = nil) -> [Dispatch] {
        let n = count ?? config.countCap
        var nodes: [Dispatch] = []
        if let initStep = config.initStep {
            let reseeded = reseed != nil && reseed != lastSeed
            if !initialized || reseeded {
                initialized = true
                if let r = reseed { lastSeed = r }
                if let s = step(initStep, count: n, grid: grid) { nodes.append(s) }
            }
        }
        for key in config.program {
            if let s = step(key, count: n, grid: grid) { nodes.append(s) }
        }
        return nodes
    }

    /// Encodes the steps in order into one serial compute encoder. The first call zero-fills every
    /// state buffer first (WebGPU buffers start zeroed; the resolves rely on zeroed accumulators).
    func encode(_ ctx: ComputeContext, _ steps: [Dispatch]) throws {
        if !zeroed {
            zeroed = true
            if let blit = ctx.commandBuffer.makeBlitCommandEncoder() {
                blit.label = "\(ctx.descriptor.name) zero state"
                for b in buffers.values { blit.fill(buffer: b, range: 0..<b.length, value: 0) }
                blit.endEncoding()
            }
        }
        guard !steps.isEmpty, let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return }
        defer { enc.endEncoding() }
        enc.label = "\(ctx.descriptor.name) agents"
        for s in steps where s.threads.x > 0 && s.threads.y > 0 && s.threads.z > 0 {
            guard let k = kernels[s.kernel] else { continue }
            try ctx.dispatch(enc, k, threads: s.threads) { e in
                for b in k.buffers {
                    if b.space == "uniform" {
                        let bytes = s.uniforms[b.name] ?? uniforms[b.name] ?? [UInt8](repeating: 0, count: max(16, layouts[b.name]?.size ?? 16))
                        bytes.withUnsafeBytes { raw in
                            if let base = raw.baseAddress { e.setBytes(base, length: raw.count, index: b.slot) }
                        }
                    } else if let buf = buffers[b.name] {
                        e.setBuffer(buf, offset: 0, index: b.slot)
                    }
                }
                for t in k.textures {
                    e.setTexture(textures[t.name] ?? ctx.device.placeholderTexture, index: t.slot)
                }
            }
        }
    }
}

// MARK: - Per-frame CPU recipes (std/sim/agentFrame, scaffolds/agentSystem, kit/host/pointer)

/// Upstream `readAgentFrame`: dt clamped to [1ms, 33ms], viewport aspect, pointer (UV, y down).
struct AgentFrame {
    var dt: Float
    var aspect: Float
    var pointerX: Float
    var pointerY: Float

    init(_ ctx: ComputeContext, fallbackAspect: Float = 16.0 / 9.0) {
        dt = min(max(ctx.frame.deltaTime, 0.001), 0.033)
        aspect = ctx.height > 0 ? Float(ctx.width) / Float(ctx.height) : fallbackAspect
        pointerX = ctx.frame.pointer.x
        pointerY = ctx.frame.pointer.y
    }
}

enum AgentMath {
    static let degToRad = Float.pi / 180
    /// The fixed resolution agent sizes are authored against (`SIZE_REF_RES`).
    static let sizeRefRes: Float = 1024
    /// R3 low-discrepancy strides (`R3_ALPHA`).
    static let r3Alpha: SIMD3<Double> = SIMD3(0.8191725133961645, 0.6710436067037893, 0.5497004779019703)

    /// JavaScript `Math.round` (halves round toward +∞).
    static func jsRound(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    static func clamp01(_ x: Float) -> Float { min(max(x, 0), 1) }

    /// `agentFrame.expDecay`: `exp(−rate·dt)`.
    static func expDecay(_ rate: Float, _ dt: Float) -> Float { exp(-rate * dt) }

    /// `agentFrame.fitJitteredGrid`.
    static func fitJitteredGrid(count: Int, domainX: Float, overscan: Float) -> (cols: Int, cellW: Float, cellH: Float) {
        let spanX = Double(domainX + 2 * overscan)
        let spanY = Double(1 + 2 * overscan)
        let cols = max(1, jsRound((Double(count) * (spanX / spanY)).squareRoot()))
        let rows = max(1, Int((Double(count) / Double(cols)).rounded(.up)))
        return (cols, Float(spanX / Double(cols)), Float(spanY / Double(rows)))
    }

    /// `agentFrame.fitIsoGrid`.
    static func fitIsoGrid(count: Int, aspect: Float, min lo: Int, max hi: Int) -> (w: Int, h: Int) {
        var w = jsRound((Double(count) * Double(aspect)).squareRoot())
        w = min(max(w, lo), hi)
        var h = jsRound(Double(count) / Double(w))
        h = min(max(h, lo), hi)
        return (w, h)
    }

    /// `agentFrame.cameraRowsYDown`: Rz·Ry·Rx conjugated for a y-down canvas.
    static func cameraRowsYDown(_ rx: Float, _ ry: Float, _ rz: Float) -> (rowX: SIMD3<Float>, rowY: SIMD3<Float>, rowZ: SIMD3<Float>) {
        let cx = cos(rx), sx = sin(rx)
        let cy = cos(ry), sy = sin(ry)
        let cz = cos(rz), sz = sin(rz)
        let m00 = cz * cy, m01 = cz * sy * sx - sz * cx, m02 = cz * sy * cx + sz * sx
        let m10 = sz * cy, m11 = sz * sy * sx + cz * cx, m12 = sz * sy * cx - cz * sx
        let m20 = -sy, m21 = cy * sx, m22 = cy * cx
        return (SIMD3(m00, -m01, m02), SIMD3(-m10, m11, -m12), SIMD3(m20, -m21, m22))
    }

    /// `agentFrame.r3SubCellOffset`.
    static func r3SubCellOffset(_ frameIdx: Int, cell: Float) -> SIMD3<Float> {
        let f = Double(frameIdx)
        return SIMD3(Float((f * r3Alpha.x).truncatingRemainder(dividingBy: 1)) * cell,
                     Float((f * r3Alpha.y).truncatingRemainder(dividingBy: 1)) * cell,
                     Float((f * r3Alpha.z).truncatingRemainder(dividingBy: 1)) * cell)
    }

    /// `agentFrame.pointerToShapeLocal`.
    static func pointerToShapeLocal(pointer: SIMD2<Float>, center: SIMD2<Float>, scale: Float, rotC: Float, rotS: Float, aspect: Float) -> SIMD2<Float> {
        let dxAc = (pointer.x - center.x) * aspect
        let dyv = pointer.y - center.y
        return SIMD2((dxAc * rotC + dyv * rotS) / scale, -((dyv * rotC - dxAc * rotS) / scale))
    }

    /// CPU mirror of the GPU `rotateVec3` (`rotateVecCpu`, ZXY order).
    static func rotateVec(_ v: SIMD3<Float>, cos c: SIMD3<Float>, sin s: SIMD3<Float>) -> SIMD3<Float> {
        let x1 = v.x * c.y + v.z * s.y
        let z1 = -v.x * s.y + v.z * c.y
        let y2 = v.y * c.x - z1 * s.x
        let z2 = v.y * s.x + z1 * c.x
        return SIMD3(x1 * c.z - y2 * s.z, x1 * s.z + y2 * c.z, z2)
    }

    /// `agentFrame.omegaFromRotationDeltas`; nil on the first frame.
    static func omegaFromRotationDeltas(_ prev: SIMD3<Float>?, _ next: SIMD3<Float>, dt: Float) -> SIMD3<Float>? {
        guard let prev else { return nil }
        let w = (next - prev) / dt
        let c = SIMD3(cos(next.x), cos(next.y), cos(next.z))
        let s = SIMD3(sin(next.x), sin(next.y), sin(next.z))
        let ex = rotateVec(SIMD3(1, 0, 0), cos: c, sin: s)
        let ey = rotateVec(SIMD3(0, 1, 0), cos: c, sin: s)
        let ez = rotateVec(SIMD3(0, 0, 1), cos: c, sin: s)
        return SIMD3(-simd_dot(ex, w), -simd_dot(ey, w), -simd_dot(ez, w))
    }

    /// `agentFrame.entrainmentFromOmega`.
    static func entrainmentFromOmega(_ om: SIMD3<Float>, cap: Float, gainRate: Float, gainMax: Float) -> (omega: SIMD3<Float>, entrain: Float) {
        let len = simd_length(om)
        let k: Float = len > cap ? cap / len : 1
        return (om * k, min(1, len * gainRate) * gainMax)
    }
}

/// `agentFrame.createMotionAxis`: a unit heading that follows the pointer's recent travel.
final class AgentMotionAxis {
    private let smoothing: Float
    private let teleport: Float
    private var last = SIMD2<Float>(0.5, 0.5)
    private var axis = SIMD2<Float>(1, 0)

    init(smoothing: Float = 0.1, teleport: Float = 0.25) {
        self.smoothing = smoothing
        self.teleport = teleport
    }

    func update(_ x: Float, _ y: Float) -> SIMD2<Float> {
        let mv = SIMD2(x, y) - last
        let len = simd_length(mv)
        if len > 1e-3 && len < teleport {
            axis += (mv / len - axis) * smoothing
            let al = simd_length(axis)
            axis /= al > 0 ? al : 1
        }
        last = SIMD2(x, y)
        return axis
    }
}

/// `createPointerVelocityTracker` (kit/host/pointer.ts). `seen` maps upstream's "a real pointer
/// event has reached the canvas" flag; ShadersKit derives it from `pointerActive` having been true.
final class AgentPointerTracker {
    struct Frame {
        var x: Float, y: Float, prevX: Float, prevY: Float
        var dx: Float, dy: Float, dragDist: Float
        var velX: Float, velY: Float
        var teleport: Bool, moving: Bool
    }

    private let smoothing: Float = 0.2
    private let teleportGuard: Float = 0.25
    private let minDrag: Float = 0.0006
    private var prev = SIMD2<Float>(0.5, 0.5)
    private var smoothVel = SIMD2<Float>(0, 0)
    private var sawUnseen = false
    private var snappedToFirstReal = false

    func update(_ pointer: SIMD2<Float>, seen: Bool, dt: Float) -> Frame {
        let parked = !seen
        if parked { sawUnseen = true }
        else if sawUnseen && !snappedToFirstReal {
            snappedToFirstReal = true
            prev = pointer
        }
        let old = prev
        let p = parked ? prev : pointer
        let raw = p - old
        let dragDist = simd_length(raw)
        let teleport = dragDist >= teleportGuard
        prev = p
        let d = teleport ? SIMD2<Float>(0, 0) : raw
        let vel = d * (1 / max(dt, 0.001))
        smoothVel = smoothVel * (1 - smoothing) + vel * smoothing
        return Frame(x: p.x, y: p.y, prevX: old.x, prevY: old.y, dx: d.x, dy: d.y, dragDist: dragDist,
                     velX: vel.x, velY: vel.y, teleport: teleport, moving: !teleport && dragDist > minDrag)
    }
}

/// `createIdleGate` (kit/host/pointer.ts): skip frames once the field has settled.
final class AgentIdleGate {
    private let warmupFrames: Int
    private var everActive = false
    private var simSinceActive: Float = 0
    private var frames = 0

    init(warmupFrames: Int) { self.warmupFrames = warmupFrames }

    func markActive() {
        everActive = true
        simSinceActive = 0
    }

    func tickFrame(_ dt: Float) {
        frames += 1
        simSinceActive += dt
    }

    func shouldSkip(_ fadeSeconds: Float, driving: Bool) -> Bool {
        if driving { return false }
        if frames < warmupFrames { return false }
        if !everActive { return true }
        return simSinceActive > fadeSeconds
    }
}

/// `pathStampRibbon`: stamp positions interpolated along this frame's drag path.
enum AgentStampRibbon {
    static func stamps(fromX: Float, fromY: Float, dx: Float, dy: Float, dragDist: Float, stepSize: Float, maxSteps: Int, scale: Float) -> [SIMD2<Float>] {
        let n = min(maxSteps, max(1, Int((dragDist / stepSize).rounded(.up))))
        return (0..<n).map { s in
            let t = (Float(s) + 0.5) / Float(n)
            return SIMD2((fromX + dx * t) * scale, (fromY + dy * t) * scale)
        }
    }
}
#endif
