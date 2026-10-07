#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream `fluidSim` (std/sim/fluids.ts) over the Stable-Fluids scaffold
/// (gpu/scaffolds/fluids.ts). One program type serves the whole family. The scaffold owns the N×N
/// state buffers, the output texture, the frame clock, the pointer tracker and the solve chain.
/// Each shader declares its own parts (`Config`) as its upstream `index.ts` does; see
/// `FluidsFamilyShaders.swift`.
///
/// Upstream frame order: [container pre-march] → [init + warm-up when stale] → emitter ticks →
/// idle-gate skip → params write → [container mask pass] → emitter dispatches → pre-solve stages →
/// curl…advect chain → post-solve stages → output.
final class FluidsFamilyProgram: ComputeProgram {
    static let shaderNames = ["Fog", "InkFlow", "Smoke", "SmokeFill", "SmokeFlow"]

    /// Cells per grid side. Every upstream fluid shader uses 256.
    static let n = 256
    /// Upstream `maxDeltaTime` default.
    static let maxDeltaTime = 0.033

    /// Per-frame uniform values keyed by the WGSL field path.
    typealias Values = [String: Double]

    /// One shader's parts (upstream `FluidSimConfig`).
    struct Config {
        /// Index of the curl kernel. The nine solver kernels (curl, vorticity, divergence, jacobi,
        /// gradSubtract, advectVel, copyVel, advectDye, copyDye) are consecutive from here.
        var solverBase: Int
        var outputKernel: Int
        /// The `compute_N` key the final pass samples the fluid output under.
        var outputKey = "compute_0"
        /// The kernel uniform that holds the per-frame values.
        var paramsUniform = "params"
        var jacobiIters = 10
        /// Track the pointer for a cursor force (stroke emitters track their own).
        var pointer: PointerTracker.Options? = nil
        var container: ShapeContainer? = nil
        var initPart: SeededFieldInit? = nil
        var inject: [Emitter] = []
        /// Kernels run before (`ambientForce`) and after (`restoreToward`) every solve.
        var solvePre: [Int] = []
        var solvePost: [Int] = []
        var values: (Frame) -> Values
    }

    /// One frame as every part sees it (upstream `FluidFrame`).
    struct Frame {
        let ctx: ComputeContext
        /// Clamped frame delta in seconds.
        let dt: Double
        /// The simulation clock. An init part can reset it.
        var elapsed: Double
        /// The renderer's pointer this frame (upstream `frameParams.pointer`).
        let pointer: PointerSample
        /// The scaffold tracker's sample when the config declares `pointer`.
        let ptr: PointerFrame?

        /// Upstream `f.num`: the prop's number, or `fallback` when it is not a number.
        func num(_ key: String, _ fallback: Double) -> Double {
            if case .number(let v)? = ctx.props[key] { return Double(v) }
            return fallback
        }

        func string(_ key: String) -> String? {
            ctx.props[key]?.stringValue
        }

        /// A vector prop as the node's uniform block holds it (post-transform, which is what
        /// upstream `getCpuValue` returns for positions and colors).
        func uniformVector(_ prop: String) -> [Double]? {
            guard let f = ctx.descriptor.uniformLayout.field("n_x.\(prop)") else { return nil }
            let comps: Int
            switch f.type {
            case "vec2f": comps = 2
            case "vec3f": comps = 3
            case "vec4f": comps = 4
            default: comps = 1
            }
            return (0..<comps).map { Double(ctx.uniformBytes.load(fromByteOffset: f.offset + $0 * 4, as: Float.self)) }
        }
    }

    /// The per-frame encoding surface (upstream's ordered `nodes` list). Writes and dispatches
    /// are encoded in call order, so every dispatch sees exactly the writes before it.
    struct Pass {
        let program: FluidsFamilyProgram
        let ctx: ComputeContext
        let encoder: MTLComputeCommandEncoder
        let pointer: PointerSample

        func write(_ uniform: String, _ values: Values) {
            program.writeUniform(uniform, values.mapValues { [$0] })
        }

        func write(_ uniform: String, vectors values: [String: [Double]]) {
            program.writeUniform(uniform, values)
        }

        func dispatch(_ kernel: Int, width: Int = FluidsFamilyProgram.n, height: Int = FluidsFamilyProgram.n) throws {
            try program.dispatch(kernel, width: width, height: height, pass: self)
        }

        func solve(jacobiIters: Int) throws {
            try program.solve(jacobiIters: jacobiIters, pass: self)
        }
    }

    private let kernels: [ComputeKernelDescriptor]
    private let layouts: [String: UniformLayout]
    private var buffers: [String: MTLBuffer] = [:]
    private var textures: [String: MTLTexture] = [:]
    private let output: MTLTexture
    /// Current contents of each kernel uniform. Each dispatch snapshots them with `setBytes`, which
    /// reproduces the upstream `device.queue` order contract for per-dispatch uniform writes.
    private var uniforms: [String: [UInt8]] = [:]

    private var config: Config
    private var tracker: PointerTracker?
    private var variantKey: String
    private var needsClear = true
    private var elapsed = 0.0
    /// Renderer-level pointer state: the last real position is held once one has landed.
    private var pointerSeen = false
    private var heldPointer = SIMD2<Double>(0.5, 0.5)

    init(context ctx: ComputeContext) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingResource("\(name) compute block") }
        let sorted = info.kernels.sorted { $0.index < $1.index }
        guard sorted.enumerated().allSatisfy({ $0.offset == $0.element.index }) else {
            throw ShaderEngineError.missingResource("\(name) contiguous kernel indices")
        }
        kernels = sorted
        layouts = info.uniformLayouts

        let count = Self.n * Self.n
        func stateBuffer(_ label: String, _ stride: Int) throws -> MTLBuffer {
            guard let b = ctx.device.device.makeBuffer(length: count * stride, options: .storageModePrivate) else { throw ShaderEngineError.noMetalDevice }
            b.label = "\(name) \(label)"
            return b
        }
        for label in ["velA", "velB", "dyeA", "dyeB"] { buffers[label] = try stateBuffer(label, 16) }
        for label in ["pressure", "divergence"] { buffers[label] = try stateBuffer(label, 4) }
        guard let out = ctx.makeTexture(width: Self.n, height: Self.n, format: .rgba16Float, label: "\(name) fluid output") else {
            throw ShaderEngineError.noMetalDevice
        }
        output = out
        textures["outTex"] = out

        config = try Self.config(for: name, ctx)
        tracker = config.pointer.map(PointerTracker.init)
        variantKey = Self.variantKey(ctx)
        if let c = config.container {
            buffers["maskBuf"] = try stateBuffer("maskBuf", 16)
            textures["fieldTex"] = c.field
            textures["field_1"] = c.field
        }

        // Every kernel binding must resolve to a resource this program owns.
        for k in kernels {
            for b in k.buffers {
                let found = b.space == "uniform" ? layouts[b.name] != nil : buffers[b.name] != nil
                if !found { throw ShaderEngineError.missingResource("\(k.entry) binding \(b.name)") }
            }
            for t in k.textures where textures[t.name] == nil {
                throw ShaderEngineError.missingResource("\(k.entry) texture \(t.name)")
            }
        }
    }

    /// Upstream rebuilds the compute node when a compile-time prop changes the composition.
    private static func variantKey(_ ctx: ComputeContext) -> String {
        UniformPacker(descriptor: ctx.descriptor).selectVariant(ctx.props)?.passes.last?.entry ?? ""
    }

    private func reset(_ ctx: ComputeContext) throws {
        config = try Self.config(for: ctx.descriptor.name, ctx)
        tracker = config.pointer.map(PointerTracker.init)
        if let c = config.container {
            textures["fieldTex"] = c.field
            textures["field_1"] = c.field
        }
        uniforms.removeAll()
        elapsed = 0
        needsClear = true
    }

    /// WebGPU zero-initialises buffers and textures. Metal private resources start undefined.
    private func clearState(_ ctx: ComputeContext) {
        if let blit = ctx.commandBuffer.makeBlitCommandEncoder() {
            blit.label = "\(ctx.descriptor.name) clear state"
            for b in buffers.values { blit.fill(buffer: b, range: 0..<b.length, value: 0) }
            blit.endEncoding()
        }
        for tex in [output, config.container?.field].compactMap({ $0 }) {
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = tex
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            rpd.colorAttachments[0].storeAction = .store
            ctx.commandBuffer.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding()
        }
    }

    private func outputs() -> ComputeOutputs {
        var out = ComputeOutputs(textures: [config.outputKey: output])
        if let c = config.container {
            out.textures.merge(c.outputs) { a, _ in a }
            out.extraFields = c.extraFields
        }
        return out
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        let key = Self.variantKey(ctx)
        if key != variantKey {
            variantKey = key
            try reset(ctx)
        }
        if needsClear {
            clearState(ctx)
            needsClear = false
        }
        if ctx.frame.pointerActive {
            heldPointer = SIMD2(Double(ctx.frame.pointer.x), Double(ctx.frame.pointer.y))
            pointerSeen = true
        }
        let sample = PointerSample(x: heldPointer.x, y: heldPointer.y, seen: pointerSeen)

        guard let encoder = ctx.commandBuffer.makeComputeCommandEncoder() else { return outputs() }
        defer { encoder.endEncoding() }
        encoder.label = "\(ctx.descriptor.name) fluid"
        let pass = Pass(program: self, ctx: ctx, encoder: encoder, pointer: sample)

        // A pending container march runs even on a frame too short to step the fluid.
        try config.container?.preFrame(pass)
        let dt = min(Double(ctx.frame.deltaTime), Self.maxDeltaTime)
        if dt < 0.001 { return outputs() }
        elapsed += dt

        var f = Frame(ctx: ctx, dt: dt, elapsed: elapsed, pointer: sample, ptr: tracker?.update(sample, dt: dt))
        if let initPart = config.initPart, initPart.stale(f) {
            try initPart.run(&f, pass, paramsUniform: config.paramsUniform)
            elapsed = f.elapsed
        }
        for e in config.inject { e.tick(f) }
        // A skipped frame keeps the settled field on screen. An init chain already encoded above
        // still runs, like upstream's `ranInit ? nodes : null`.
        for e in config.inject where e.skip(f) { return outputs() }

        let v = config.values(f)
        pass.write(config.paramsUniform, v)
        if let c = config.container { try pass.dispatch(c.maskKernel) }
        for e in config.inject { try e.emit(f, v, pass) }
        try pass.solve(jacobiIters: config.jacobiIters)
        try pass.dispatch(config.outputKernel)
        return outputs()
    }

    // MARK: - Encoding

    fileprivate func writeUniform(_ name: String, _ values: [String: [Double]]) {
        guard let layout = layouts[name] else { return }
        // Upstream writes every member each time; a missing key here is a typo in a port.
        assert(layout.fields.allSatisfy { values[$0.path] != nil }, "\(name): missing \(layout.fields.map(\.path).filter { values[$0] == nil })")
        uniforms[name] = Self.pack(layout, values)
    }

    /// Packs a kernel uniform struct following its WGSL layout (`compute.uniformLayouts`).
    static func pack(_ layout: UniformLayout, _ values: [String: [Double]]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: layout.size)
        bytes.withUnsafeMutableBytes { p in
            for f in layout.fields {
                guard let v = values[f.path], let first = v.first else { continue }
                switch f.type {
                case "i32": p.storeBytes(of: Int32(clamping: Int(first.rounded(.towardZero))), toByteOffset: f.offset, as: Int32.self)
                case "u32": p.storeBytes(of: UInt32(clamping: Int(max(0, first).rounded(.towardZero))), toByteOffset: f.offset, as: UInt32.self)
                default:
                    for (i, x) in v.prefix(f.size / 4).enumerated() {
                        p.storeBytes(of: Float(x), toByteOffset: f.offset + i * 4, as: Float.self)
                    }
                }
            }
        }
        return bytes
    }

    fileprivate func dispatch(_ index: Int, width: Int, height: Int, pass: Pass) throws {
        let k = kernels[index]
        try pass.ctx.dispatch(pass.encoder, k, threads: SIMD3(UInt32(width), UInt32(height), 1)) { e in
            for b in k.buffers {
                if b.space == "uniform" {
                    let bytes = uniforms[b.name] ?? [UInt8](repeating: 0, count: layouts[b.name]?.size ?? 16)
                    bytes.withUnsafeBytes { e.setBytes($0.baseAddress!, length: $0.count, index: b.slot) }
                } else {
                    e.setBuffer(buffers[b.name], offset: 0, index: b.slot)
                }
            }
            for t in k.textures { e.setTexture(textures[t.name], index: t.slot) }
        }
    }

    /// Upstream `solveSteps` wrapped in the shader's pre/post stages: curl → vorticity →
    /// divergence → J× jacobi → gradSubtract → advectVel → copyVel → advectDye → copyDye.
    fileprivate func solve(jacobiIters: Int, pass: Pass) throws {
        for k in config.solvePre { try pass.dispatch(k) }
        let b = config.solverBase
        try pass.dispatch(b)
        try pass.dispatch(b + 1)
        try pass.dispatch(b + 2)
        for _ in 0..<jacobiIters { try pass.dispatch(b + 3) }
        for i in 4...8 { try pass.dispatch(b + i) }
        for k in config.solvePost { try pass.dispatch(k) }
    }
}
#endif
