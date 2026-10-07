#if canImport(Metal)
import Foundation
import Metal
import simd

/// Shared CPU orchestration for the shaped-surface (SDF field) family: ports of the pure-CPU parts of
/// upstream `gpu/kit/sdf3d.ts` (shape sub-prop resolution, bounding radius, `createAnalytic3dSdfSetup`,
/// `resolveActiveFieldRes`, `createVolumetricFieldComputeNode`) plus small Metal helpers.
enum SDFKit {
    // MARK: - Device class

    /// Upstream `isMobileGpuViewport`: a coarse-pointer device with a phone/tablet viewport. On Apple
    /// platforms that is iOS/iPadOS (every iPad's long side is ≤ 1366 pt); macOS, visionOS and tvOS
    /// count as desktop.
    static var isMobileGpuViewport: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    /// Upstream `VOLUMETRIC_FIELD_RES` / `VOLUMETRIC_FIELD_RES_MOBILE`.
    static var volumetricFieldRes: Int { isMobileGpuViewport ? 768 : 1536 }

    static let activeResBuckets = [256, 320, 384, 512, 640, 768, 896, 1024, 1280, 1536]

    /// Upstream `resolveActiveFieldRes`.
    static func resolveActiveFieldRes(spanX: Double, spanY: Double, scale: Double, canvasHeightDevicePx: Double, maxRes: Int, prevRes: Int) -> Int {
        if !(canvasHeightDevicePx > 0) || !(scale > 0) { return maxRes }
        let footprintScale = isMobileGpuViewport ? 0.5 : 1
        let targetPx = max(spanX, spanY) * scale * canvasHeightDevicePx * footprintScale
        var res = maxRes
        for b in activeResBuckets {
            if b > maxRes { break }
            if Double(b) >= targetPx { res = b; break }
        }
        if prevRes > 0, res < prevRes, targetPx > Double(prevRes) * 0.78 { res = min(prevRes, maxRes) }
        return res
    }

    // MARK: - Shape JSON

    static let shape3DTypes: Set<String> = [
        "sphere3D", "cube3D", "torus3D", "octahedron3D", "cylinder3D", "capsule3D",
        "cone3D", "pyramid3D", "prism3D", "ellipsoid3D", "diamond3D", "link3D",
        "gem3D", "helix3D", "metaballs3D", "dodecahedron3D", "hemisphere3D",
        "ribbon3D", "blob3D", "gyroscope3D",
    ]

    static let shape3DDefaults: [String: [String: Double]] = [
        "sphere3D": ["radius": 0.35, "rotX": 0, "rotY": 0, "rotZ": 0],
        "cube3D": ["sizeX": 0.27, "sizeY": 0.27, "sizeZ": 0.27, "rounding": 0.02, "rotX": 25, "rotY": 35, "rotZ": 0],
        "torus3D": ["radius": 0.3, "tube": 0.12, "rotX": 55, "rotY": 0, "rotZ": 0],
        "octahedron3D": ["radius": 0.42, "rotX": 10, "rotY": 25, "rotZ": 0],
        "cylinder3D": ["radius": 0.22, "height": 0.26, "rounding": 0.02, "rotX": 60, "rotY": 0, "rotZ": 30],
        "capsule3D": ["radius": 0.16, "height": 0.2, "rotX": 0, "rotY": 0, "rotZ": 35],
        "cone3D": ["radius": 0.3, "topRadius": 0.02, "height": 0.3, "rotX": 25, "rotY": 0, "rotZ": 15],
        "pyramid3D": ["size": 0.3, "height": 0.45, "rotX": -10, "rotY": 30, "rotZ": 0],
        "prism3D": ["radius": 0.28, "height": 0.14, "rotX": 25, "rotY": 30, "rotZ": 0],
        "ellipsoid3D": ["radiusX": 0.38, "radiusY": 0.22, "radiusZ": 0.3, "rotX": 0, "rotY": 0, "rotZ": 20],
        "diamond3D": ["radius": 0.3, "height": 0.42, "rotX": 15, "rotY": 0, "rotZ": 0],
        "link3D": ["radius": 0.18, "length": 0.15, "tube": 0.08, "rotX": 20, "rotY": 30, "rotZ": 0],
        "gem3D": ["radius": 0.3, "height": 0.32, "facets": 8, "rotX": 15, "rotY": 0, "rotZ": 0],
        "helix3D": ["radius": 0.22, "tube": 0.06, "pitch": 0.16, "rotX": 20, "rotY": 0, "rotZ": 0],
        "metaballs3D": ["balls": 4, "ballRadius": 0.16, "spread": 0.2, "blend": 0.12, "speed": 1, "rotX": 0, "rotY": 0, "rotZ": 0],
        "dodecahedron3D": ["radius": 0.34, "rotX": 20, "rotY": 10, "rotZ": 0],
        "hemisphere3D": ["radius": 0.4, "cut": 0, "rotX": 30, "rotY": 0, "rotZ": 0],
        "ribbon3D": ["width": 0.15, "thickness": 0.03, "length": 0.38, "wave": 0.1, "waveFrequency": 7, "twist": 140, "speed": 1, "rotX": 12, "rotY": 18, "rotZ": 0],
        "blob3D": ["radius": 0.3, "wobble": 0.07, "wobbliness": 5, "speed": 1, "rotX": 0, "rotY": 0, "rotZ": 0],
        "gyroscope3D": ["radius": 0.34, "width": 0.1, "thickness": 0.028, "rounding": 0.006, "core": 0.14, "speed": 1, "rotX": 15, "rotY": 0, "rotZ": 0],
    ]

    static let maxMetaballs = 8
    static let helixTurns = 3.0

    /// Upstream `parseShapeConfig`: a JSON string → its object (`{}` when unparsable).
    static func parseShapeConfig(_ raw: String?) -> [String: Any] {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    /// A JSON number (`typeof v === 'number'`); booleans are not numbers.
    static func jsonNumber(_ v: Any?) -> Double? {
        guard let n = v as? NSNumber else { return nil }
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        return n.doubleValue
    }

    /// Upstream `resolveShapeType`'s spine routing: the compile-time `shapeType` prop, else the JSON `type`.
    static func shapeType(prop: String?, config: [String: Any]) -> String {
        if let p = prop, !p.isEmpty { return p }
        return config["type"] as? String ?? ""
    }

    // MARK: - Sub-prop drivers (auto-animate / mouse)

    struct Spring { var current: Double; var velocity: Double }

    /// Upstream `applySpring` (gpu/frame.ts), sub-stepped at ≤ 1/60 s.
    static func applySpring(current: Double, velocity: Double, target: Double, smoothing: Double, momentum: Double, dt: Double) -> (Double, Double) {
        if smoothing == 0 && momentum == 0 { return (target, 0) }
        let stiffness = 200 * pow(0.01, smoothing)
        let criticalDamping = 2 * stiffness.squareRoot()
        let damping = criticalDamping * (1 - momentum * 0.85)
        let maxSub = 1.0 / 60.0
        let steps = dt > maxSub ? Int((dt / maxSub).rounded(.up)) : 1
        let h = dt / Double(steps)
        var pos = current
        var vel = velocity
        for _ in 0..<steps {
            let force = stiffness * (target - pos)
            vel += (force - damping * vel) * h
            pos += vel * h
        }
        return (pos, vel)
    }

    static func bounceEase(_ t0: Double) -> Double {
        var t = t0
        let n1 = 7.5625, d1 = 2.75
        if t < 1 / d1 { return n1 * t * t }
        if t < 2 / d1 { t -= 1.5 / d1; return n1 * t * t + 0.75 }
        if t < 2.5 / d1 { t -= 2.25 / d1; return n1 * t * t + 0.9375 }
        t -= 2.625 / d1
        return n1 * t * t + 0.984375
    }

    static func applyEasing(_ t: Double, _ easing: String) -> Double {
        switch easing {
        case "linear": return t
        case "quad": return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case "expo":
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            return t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, -20 * t + 10)) / 2
        case "bounce": return bounceEase(t)
        default: return (1 - cos(Double.pi * t)) / 2
        }
    }

    /// Upstream `resolveShapeSubProp`: a number, an auto-animate config or a mouse config.
    static func resolveSubProp(_ value: Any?, fallback: Double, elapsed: Double, deltaTime: Double, pointer: SIMD2<Double>, springs: inout [String: Spring], key: String) -> Double {
        if let n = jsonNumber(value) { return n }
        guard let cfg = value as? [String: Any] else { return fallback }
        let oMin = jsonNumber(cfg["outputMin"]) ?? fallback
        let oMax = jsonNumber(cfg["outputMax"]) ?? fallback
        switch cfg["type"] as? String {
        case "auto-animate":
            let globalT = elapsed * (jsonNumber(cfg["speed"]) ?? 1) * 0.2
            let t01 = fmod(fmod(globalT, 1) + 1, 1)
            let t = (cfg["mode"] as? String) == "loop" ? t01 : (t01 < 0.5 ? t01 * 2 : (1 - t01) * 2)
            let phase = applyEasing(t, (cfg["easing"] as? String) ?? (cfg["waveform"] as? String) ?? "sine")
            return oMin + phase * (oMax - oMin)
        case "mouse":
            let target = (cfg["axis"] as? String) == "y" ? pointer.y : pointer.x
            var st = springs[key] ?? Spring(current: target, velocity: 0)
            let (np, nv) = applySpring(current: st.current, velocity: st.velocity, target: target, smoothing: jsonNumber(cfg["smoothing"]) ?? 0, momentum: jsonNumber(cfg["momentum"]) ?? 0, dt: deltaTime)
            st.current = np
            st.velocity = nv
            springs[key] = st
            let smoothed = max(0.001, np)
            let exponent = pow(2, -(jsonNumber(cfg["curve"]) ?? 0) * 2)
            return oMin + pow(smoothed, exponent) * (oMax - oMin)
        default:
            return fallback
        }
    }

    /// Upstream `shapeSubPropMax`.
    static func subPropMax(_ value: Any?, fallback: Double) -> Double {
        if let n = jsonNumber(value) { return n }
        if let cfg = value as? [String: Any], let t = cfg["type"] as? String, t == "auto-animate" || t == "mouse" {
            let oMin = jsonNumber(cfg["outputMin"]) ?? fallback
            let oMax = jsonNumber(cfg["outputMax"]) ?? fallback
            return max(oMin, oMax)
        }
        return fallback
    }

    /// Upstream `shape3dBoundingRadius`.
    static func shape3DBoundingRadius(_ cfg: [String: Any], type: String) -> Double {
        let dflt = shape3DDefaults[type] ?? [:]
        func n(_ k: String, _ f: Double = 0.3) -> Double { subPropMax(cfg[k], fallback: dflt[k] ?? f) }
        func hypot3(_ a: Double, _ b: Double, _ c: Double) -> Double { (a * a + b * b + c * c).squareRoot() }
        switch type {
        case "cube3D": return hypot3(n("sizeX"), n("sizeY"), n("sizeZ")) + n("rounding", 0)
        case "torus3D": return n("radius") + n("tube")
        case "cylinder3D": return hypot(n("radius"), n("height")) + n("rounding", 0)
        case "capsule3D": return n("height") + n("radius")
        case "cone3D": return hypot(max(n("radius"), n("topRadius")), n("height"))
        case "pyramid3D": return hypot(n("size") * 2.0.squareRoot(), n("height") * 0.5)
        case "prism3D": return hypot(n("radius") * 1.1548, n("height"))
        case "ellipsoid3D": return max(n("radiusX"), n("radiusY"), n("radiusZ"))
        case "diamond3D": return max(n("radius"), n("height"))
        case "link3D": return n("length") + n("radius") + n("tube")
        case "gem3D": return max(n("radius"), n("height"))
        case "helix3D": return hypot(n("radius") + n("tube"), n("pitch") * 3 * 0.5 + n("tube"))
        case "metaballs3D": return n("spread") + n("ballRadius", 0.16) + n("blend", 0.12)
        case "dodecahedron3D": return n("radius") * 1.32
        case "hemisphere3D": return n("radius")
        case "ribbon3D": return hypot(n("length", 0.38), n("wave", 0.1) * 1.2 + hypot(n("width", 0.15), n("thickness", 0.03))) + 0.01
        case "blob3D": return n("radius", 0.3) + n("wobble", 0.07) + 0.02
        case "gyroscope3D": return n("radius", 0.34) + n("thickness", 0.028) * 0.5 + n("width", 0.1) * 0.5 + n("rounding", 0.006)
        default: return n("radius", 0.35)
        }
    }

    /// Upstream `analyticSubPropValues` (the `_sa*` bundle the radiance ABI carries).
    static func analyticSubPropValues(_ cfg: [String: Any]) -> [Float] {
        func num(_ v: Any?, _ f: Double) -> Double { jsonNumber(v) ?? f }
        return [
            num(cfg["radius"], num(cfg["width"], num(cfg["bottomWidth"], 0.35))),
            num(cfg["sides"], 6),
            num(cfg["rounding"], 0),
            num(cfg["innerRatio"], num(cfg["thickness"], num(cfg["spread"], num(cfg["topWidth"], num(cfg["topRatio"], 0.4))))),
            num(cfg["rotation"], 0),
            num(cfg["height"], 0.25),
            num(cfg["offset"], num(cfg["skew"], 0.2)),
            num(cfg["aperture"], 270),
        ].map { Float($0) }
    }

    struct Rotation: Equatable {
        var cx = 1.0, sx = 0.0, cy = 1.0, sy = 0.0, cz = 1.0, sz = 0.0
    }

    /// Upstream `rotateVecCpu` (ZXY order, matches the GPU `rotateVec3`).
    static func rotateVec(_ v: SIMD3<Double>, _ s: Rotation) -> SIMD3<Double> {
        let x1 = v.x * s.cy + v.z * s.sy
        let z1 = -v.x * s.sy + v.z * s.cy
        let y2 = v.y * s.cx - z1 * s.sx
        let z2 = v.y * s.sx + z1 * s.cx
        let x3 = x1 * s.cz - y2 * s.sz
        let y3 = x1 * s.sz + y2 * s.cz
        return SIMD3(x3, y3, z2)
    }

    // MARK: - Uniform helpers

    /// Reads a field of the node's packed uniform block (the live post-transform value upstream's
    /// `getCpuValue` returns).
    static func uniform(_ ctx: ComputeContext, _ path: String) -> [Float]? {
        guard let f = ctx.descriptor.uniformLayout.field(path), f.offset + f.size <= ctx.uniformSize else { return nil }
        return (0..<(f.size / 4)).map { ctx.uniformBytes.load(fromByteOffset: f.offset + $0 * 4, as: Float.self) }
    }

    /// A numeric prop as upstream's `getCpuValue` sees it: the packed uniform, else the raw prop.
    static func number(_ ctx: ComputeContext, _ name: String, _ fallback: Double) -> Double {
        if let v = uniform(ctx, "n_x.\(name)")?.first, v.isFinite { return Double(v) }
        if let v = ctx.props[name]?.numberValue, v.isFinite { return Double(v) }
        return fallback
    }

    /// Packs a small uniform struct following a kernel uniform layout into bytes (for `setBytes`).
    static func pack(_ layout: UniformLayout, _ values: [String: [Float]]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: max(16, layout.size))
        bytes.withUnsafeMutableBytes { raw in
            for f in layout.fields {
                guard let v = values[f.path], !v.isEmpty else { continue }
                if f.type == "i32" { raw.storeBytes(of: Int32(v[0]), toByteOffset: f.offset, as: Int32.self) }
                else if f.type == "u32" { raw.storeBytes(of: UInt32(max(0, v[0])), toByteOffset: f.offset, as: UInt32.self) }
                else {
                    for (i, x) in v.prefix(f.size / 4).enumerated() { raw.storeBytes(of: x, toByteOffset: f.offset + i * 4, as: Float.self) }
                }
            }
        }
        return bytes
    }

    static func setBytes(_ e: MTLComputeCommandEncoder, _ bytes: [UInt8], index: Int) {
        bytes.withUnsafeBytes { e.setBytes($0.baseAddress!, length: bytes.count, index: index) }
    }

    // MARK: - Dispatch

    /// `ComputeContext.dispatch` over an explicit library (the runtime-patched shape kernels).
    static func dispatch(_ ctx: ComputeContext, _ encoder: MTLComputeCommandEncoder, _ kernel: ComputeKernelDescriptor, library: MTLLibrary, threads: SIMD3<UInt32>, bind: (MTLComputeCommandEncoder) -> Void) throws {
        let pso = try ctx.device.computePipeline(library: library, name: kernel.entry)
        encoder.setComputePipelineState(pso)
        bind(encoder)
        var size = threads
        encoder.setBytes(&size, length: MemoryLayout<SIMD3<UInt32>>.stride, index: kernel.sizeSlot)
        let w = pso.threadExecutionWidth
        let h = max(1, pso.maxTotalThreadsPerThreadgroup / w)
        let tg = kernel.dims == 1 ? MTLSize(width: min(Int(threads.x), w * h), height: 1, depth: 1) : MTLSize(width: w, height: h, depth: 1)
        let grid = MTLSize(width: Int(threads.x), height: Int(threads.y), depth: Int(threads.z))
        if ctx.device.device.supportsFamily(.apple4) || ctx.device.device.supportsFamily(.mac2) {
            encoder.dispatchThreads(grid, threadsPerThreadgroup: tg)
        } else {
            let groups = MTLSize(width: (grid.width + tg.width - 1) / tg.width, height: (grid.height + tg.height - 1) / tg.height, depth: (grid.depth + tg.depth - 1) / tg.depth)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
        }
    }

    /// Fills a render-target-capable texture with one value (field textures start "far outside").
    static func clear(_ texture: MTLTexture, to value: MTLClearColor, commandBuffer: MTLCommandBuffer) {
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = texture
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = value
        rpd.colorAttachments[0].storeAction = .store
        commandBuffer.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding()
    }

    /// Upstream kit/blur `buildTruncatedWeights`.
    static func truncatedWeights(halfKernel: Int, sigma: Double) -> (weights: [Float], activeHalf: Int) {
        let size = halfKernel * 2 + 1
        let activeHalf = max(1, min(halfKernel, Int((sigma * 3).rounded(.up))))
        var weights = [Double](repeating: 0, count: size)
        var total = 0.0
        for i in -halfKernel...halfKernel where abs(i) <= activeHalf {
            let w = exp(-Double(i * i) / (2 * sigma * sigma))
            weights[i + halfKernel] = w
            total += w
        }
        return (weights.map { Float($0 / total) }, activeHalf)
    }
}

// MARK: - Analytic 3D shape setup

/// Port of upstream `createAnalytic3dSdfSetup`'s CPU half: resolves the shape JSON (incl. auto-animate /
/// mouse sub-props) into the `MarchParams` values each frame and exposes the dirty keys and footprint.
/// `type` is `nil` for a shape this port cannot march (flat 2D / SVG): it then resolves to an empty
/// field (a sphere of negative radius — every texel far outside).
final class SDFShape3DSetup {
    struct Footprint: Equatable {
        var spanX = 1.0, spanY = 1.0, originX = 0.0, originY = 0.0, rBound = 0.6
    }

    let type: String?
    private let defaults: [String: Double]
    private let extraPad: () -> Double

    private var elapsed = 0.0
    private var lastShapeJSON = ""
    private var lastCfg: [String: Any]
    private var springs: [String: SDFKit.Spring] = [:]
    private(set) var pA = 0.35, pB = 0.3, pC = 0.3, pD = 0.0
    private(set) var rBound = 0.6
    private(set) var rotation = SDFKit.Rotation()
    private(set) var footprint = Footprint()
    private(set) var activeRes: Int
    private(set) var mb = [SIMD3<Double>](repeating: .zero, count: SDFKit.maxMetaballs)

    init(type: String?, initialConfig: [String: Any], shapeJSON: String?, extraPad: @escaping () -> Double = { 0 }) {
        self.type = type
        defaults = SDFKit.shape3DDefaults[type ?? "sphere3D"] ?? SDFKit.shape3DDefaults["sphere3D"]!
        self.extraPad = extraPad
        lastCfg = initialConfig
        activeRes = SDFKit.volumetricFieldRes
        update(shapeJSON: shapeJSON, deltaTime: 0, pointer: SIMD2(0.5, 0.5))
    }

    /// Upstream `update(frameParams)`.
    func update(shapeJSON: String?, deltaTime: Double, pointer: SIMD2<Double>) {
        elapsed += deltaTime
        if let raw = shapeJSON, raw != lastShapeJSON {
            lastShapeJSON = raw
            if let data = raw.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                lastCfg = obj
            }
        }
        let cfg = lastCfg
        let defaults = self.defaults
        let elapsed = self.elapsed
        func sub(_ k: String) -> Double {
            SDFKit.resolveSubProp(cfg[k], fallback: defaults[k] ?? 0, elapsed: elapsed, deltaTime: deltaTime, pointer: pointer, springs: &springs, key: k)
        }

        pB = 0.3; pC = 0.3; pD = 0
        for i in 0..<mb.count { mb[i] = .zero }
        let twoPi = 2 * Double.pi
        switch type {
        case "cube3D":
            pA = sub("sizeX"); pB = sub("sizeY"); pC = sub("sizeZ"); pD = sub("rounding")
        case "torus3D":
            pA = sub("radius"); pB = sub("tube")
        case "cylinder3D":
            pA = sub("radius"); pB = sub("height"); pD = sub("rounding")
        case "capsule3D":
            pA = sub("radius"); pB = sub("height")
        case "cone3D":
            pA = sub("radius"); pB = sub("height"); pC = sub("topRadius")
        case "pyramid3D":
            pA = sub("size"); pB = sub("height")
        case "prism3D", "diamond3D":
            pA = sub("radius"); pB = sub("height")
        case "ellipsoid3D":
            pA = sub("radiusX"); pB = sub("radiusY"); pC = sub("radiusZ")
        case "link3D":
            pA = sub("radius"); pB = sub("length"); pC = sub("tube")
        case "gem3D":
            pA = sub("radius"); pB = sub("height"); pC = sub("facets")
        case "helix3D":
            pA = sub("radius"); pB = sub("tube"); pC = sub("pitch")
        case "metaballs3D":
            pA = sub("ballRadius"); pB = sub("spread"); pD = sub("blend")
            // JS Math.round (half up).
            let count = min(SDFKit.maxMetaballs, max(1, Int((sub("balls") + 0.5).rounded(.down))))
            let sp = pB
            let tt = elapsed * sub("speed") * 0.6
            for i in 0..<mb.count {
                if i >= count { mb[i] = SIMD3(0, 99, 0); continue }
                let phase = Double(i) * (twoPi / Double(count))
                let ang = phase + tt
                let wob = 0.75 + 0.25 * sin(tt * 1.3 + Double(i) * 1.7)
                mb[i] = SIMD3(sp * cos(ang) * wob, sp * 0.6 * sin(tt * 0.9 + phase * 1.5), sp * sin(ang) * wob)
            }
        case "hemisphere3D":
            pA = sub("radius"); pB = sub("cut")
        case "ribbon3D":
            pA = sub("width"); pB = sub("thickness"); pC = sub("length")
            let tt = elapsed * sub("speed")
            let amp = sub("wave") * (0.8 + 0.2 * sin(tt * 0.9))
            let wf = sub("waveFrequency")
            let twRate = sub("twist") * (Double.pi / 180) / max(pC * 2, 0.01)
            mb[0] = SIMD3(amp, wf, tt * 1.1)
            mb[1] = SIMD3(tt * 0.7 + 2.1, twRate, tt * 0.45)
            let slope = abs(amp) * wf + abs(twRate) * hypot(pA, pB)
            mb[2] = SIMD3(1 / (1 + slope * slope).squareRoot(), 0, 0)
        case "blob3D":
            pA = sub("radius")
            let tt = elapsed * sub("speed")
            let amp = sub("wobble") * (0.75 + 0.25 * sin(tt * 0.83))
            let wb = sub("wobbliness")
            mb[0] = SIMD3(amp, wb, tt * 1.2)
            mb[1] = SIMD3(tt * 0.77 + 1.3, 0, 0)
            mb[2] = SIMD3(1 / (1 + abs(amp) * wb * 1.3), 0, 0)
        case "gyroscope3D":
            pA = sub("radius"); pB = sub("width"); pC = sub("core"); pD = sub("thickness")
            let rnd = max(0, min(sub("rounding"), min(pB, pD) * 0.5))
            let tt = elapsed * sub("speed")
            let th1 = tt * 0.9
            let th2 = tt * 0.63 + 1.1
            let th3 = tt * 1.21 + 2.3
            mb[0] = SIMD3(cos(th1), sin(th1), 0)
            mb[1] = SIMD3(cos(th2), sin(th2), 0)
            mb[2] = SIMD3(cos(th3), sin(th3), 0)
            mb[3] = SIMD3(rnd, 0, 0)
        case nil:
            // Unsupported shape: an empty field (no surface anywhere).
            pA = -1
        default:
            pA = sub("radius")
        }
        rBound = SDFKit.shape3DBoundingRadius(cfg, type: type ?? "sphere3D") + 0.02 + extraPad()
        let deg = Double.pi / 180
        let rx = sub("rotX") * deg, ry = sub("rotY") * deg, rz = sub("rotZ") * deg
        rotation = SDFKit.Rotation(cx: cos(rx), sx: sin(rx), cy: cos(ry), sy: sin(ry), cz: cos(rz), sz: sin(rz))
        let rPad = rBound + 0.05
        footprint = Footprint(spanX: rPad * 2, spanY: rPad * 2, originX: 0.5 - rPad, originY: 0.5 - rPad, rBound: rBound)
    }

    func setActiveRes(_ res: Int) { activeRes = res }

    /// Upstream `getGeometryKey`.
    var geometryKey: [Double] {
        var k = [pA, pB, pC, pD, rBound]
        for m in mb { k += [m.x, m.y, m.z] }
        return k
    }

    /// Upstream `getStateKey`.
    var stateKey: [Double] {
        geometryKey + [rotation.cx, rotation.sx, rotation.cy, rotation.sy, rotation.cz, rotation.sz]
    }

    /// The `MarchParams` uniform values (written in full, like upstream `writeMarch`).
    var marchValues: [String: [Float]] {
        let fp = footprint
        var v: [String: [Float]] = [
            "rot.cx": [Float(rotation.cx)], "rot.sx": [Float(rotation.sx)],
            "rot.cy": [Float(rotation.cy)], "rot.sy": [Float(rotation.sy)],
            "rot.cz": [Float(rotation.cz)], "rot.sz": [Float(rotation.sz)],
            "rBound": [Float(rBound)],
            "spanX": [Float(fp.spanX)], "spanY": [Float(fp.spanY)],
            "originX": [Float(fp.originX)], "originY": [Float(fp.originY)],
            "activeRes": [Float(activeRes)],
            "pA": [Float(pA)], "pB": [Float(pB)], "pC": [Float(pC)], "pD": [Float(pD)],
        ]
        for (i, m) in mb.enumerated() { v["mb\(i)"] = [Float(m.x), Float(m.y), Float(m.z)] }
        return v
    }
}

// MARK: - Runtime shape kernels

/// The generated kernels bake the default shape's SDF (`sphere3D`) into `sdfFn`. For the other analytic
/// 3D shapes this rebuilds the shader's MSL with `sdfFn` swapped for the selected primitive (ported from
/// upstream kit/sdf3d §B and `createAnalytic3dSdfSetup`'s compile-time branch) — the equivalent of
/// upstream's per-shape recompile. Fragment functions are dropped from the patched source.
enum SDFShapeKernels {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Result<MTLLibrary, Error>] = [:]

    static let sdfFnSignature = "static float sdfFn(float3 p, constant MarchParams& params) {"

    /// The library whose kernels march `shapeType` (`nil` → the empty field, which the sphere kernel serves).
    static func library(_ ctx: ComputeContext, shapeType: String?) throws -> MTLLibrary {
        guard let type = shapeType, type != "sphere3D", let call = sdfCall[type] else { return ctx.library }
        let key = "\(ObjectIdentifier(ctx.device.device).hashValue)|\(ctx.descriptor.msl)|\(type)"
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return try cached.get()
        }
        lock.unlock()
        let result: Result<MTLLibrary, Error>
        if let src = ShaderRegistry.mslSource(ctx.descriptor.msl), let patched = patchedSource(src, call: call) {
            do {
                let lib = try ctx.device.device.makeLibrary(source: patched, options: ShaderDevice.compileOptions())
                lib.label = "ShadersKit.\(ctx.descriptor.msl).\(type)"
                result = .success(lib)
            } catch {
                result = .failure(ShaderEngineError.compile("\(ctx.descriptor.msl) [\(type)]", underlying: error))
            }
        } else {
            result = .failure(ShaderEngineError.missingFunction("\(ctx.descriptor.msl) sdfFn"))
        }
        lock.lock()
        cache[key] = result
        lock.unlock()
        return try result.get()
    }

    static func patchedSource(_ src: String, call: String) -> String? {
        guard let start = src.range(of: sdfFnSignature),
              let end = src.range(of: "\n}\n", range: start.upperBound..<src.endIndex) else { return nil }
        var out = src
        out.replaceSubrange(start.lowerBound..<end.upperBound, with: primitives + "\n\(sdfFnSignature)\n    return \(call);\n}\n")
        // Drop the fragment entry points (top-level, closed by a column-0 brace).
        var lines: [Substring] = []
        var skipping = false
        for line in out.split(separator: "\n", omittingEmptySubsequences: false) {
            if skipping {
                if line == "}" { skipping = false }
                continue
            }
            if line.hasPrefix("fragment ") { skipping = true; continue }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    /// Upstream `createAnalytic3dSdfSetup`'s `sdfFn` branches.
    static let sdfCall: [String: String] = [
        "cube3D": "sk3_sdRoundBox(p, params.pA, params.pB, params.pC, params.pD)",
        "torus3D": "sk3_sdTorus(p, params.pA, params.pB)",
        "octahedron3D": "sk3_sdOctahedron(p, params.pA)",
        "cylinder3D": "sk3_sdRoundCylinder(p, params.pA, params.pB, params.pD)",
        "capsule3D": "sk3_sdCapsule(p, params.pA, params.pB)",
        "cone3D": "sk3_sdCappedCone(p, params.pA, params.pC, params.pB)",
        "pyramid3D": "sk3_sdPyramid(p, params.pA, params.pB)",
        "prism3D": "sk3_sdHexPrism(p, params.pA, params.pB)",
        "ellipsoid3D": "sk3_sdEllipsoid(p, params.pA, params.pB, params.pC)",
        "diamond3D": "sk3_sdBicone(p, params.pA, params.pB)",
        "link3D": "sk3_sdLink(p, params.pB, params.pA, params.pC)",
        "gem3D": "sk3_sdGem(p, params.pA, params.pB, params.pC)",
        "helix3D": "sk3_sdHelix(p, params.pA, params.pB, params.pC, 3.0f)",
        "metaballs3D": "sk3_sdMetaballs(p, params.mb0, params.mb1, params.mb2, params.mb3, params.mb4, params.mb5, params.mb6, params.mb7, params.pA, params.pD)",
        "dodecahedron3D": "sk3_sdDodecahedron(p, params.pA)",
        "hemisphere3D": "sk3_sdCutSphere(p, params.pA, params.pB)",
        "ribbon3D": "sk3_sdRibbon(p, params.pA, params.pB, params.pC, params.mb0.x, params.mb0.y, params.mb0.z, params.mb1.x, params.mb1.y, params.mb1.z, params.mb2.x)",
        "blob3D": "sk3_sdWobbleBlob(p, params.pA, params.mb0.x, params.mb0.y, params.mb0.z, params.mb1.x, params.mb2.x)",
        "gyroscope3D": "sk3_sdGyroscope(p, params.pA, params.pB, params.pD, params.mb3.x, params.pC, params.mb0.x, params.mb0.y, params.mb1.x, params.mb1.y, params.mb2.x, params.mb2.y)",
    ]

    /// Upstream kit/sdf3d §B primitives, hand-ported to MSL (`sk3_` prefix avoids generated names).
    static let primitives = """
    static float sk3_sdRoundBox(float3 p, float hx, float hy, float hz, float rounding) {
        const float qx = abs(p.x) - hx + rounding;
        const float qy = abs(p.y) - hy + rounding;
        const float qz = abs(p.z) - hz + rounding;
        const float outer = length(float3(max(qx, 0.0f), max(qy, 0.0f), max(qz, 0.0f)));
        const float inner = min(max(qx, max(qy, qz)), 0.0f);
        return outer + inner - rounding;
    }
    static float sk3_sdTorus(float3 p, float ringR, float tubeR) {
        const float qx = length(float2(p.x, p.z)) - ringR;
        return length(float2(qx, p.y)) - tubeR;
    }
    static float sk3_sdOctahedron(float3 p, float s) {
        return (abs(p.x) + abs(p.y) + abs(p.z) - s) * 0.57735027f;
    }
    static float sk3_sdRoundCylinder(float3 p, float r, float h, float rounding) {
        const float dx = length(float2(p.x, p.z)) - r + rounding;
        const float dy = abs(p.y) - h + rounding;
        const float inner = min(max(dx, dy), 0.0f);
        const float outer = length(float2(max(dx, 0.0f), max(dy, 0.0f)));
        return inner + outer - rounding;
    }
    static float sk3_sdCapsule(float3 p, float r, float h) {
        const float cyc = clamp(p.y, -h, h);
        return length(float3(p.x, p.y - cyc, p.z)) - r;
    }
    static float sk3_sdCappedCone(float3 p, float r1, float r2, float h) {
        const float qx = length(float2(p.x, p.z));
        const float qy = p.y;
        const float k2x = r2 - r1;
        const float k2y = h * 2.0f;
        const float cax = qx - min(qx, qy < 0.0f ? r1 : r2);
        const float cay = abs(qy) - h;
        const float dotNum = (r2 - qx) * k2x + (h - qy) * k2y;
        const float dotDen = max(k2x * k2x + k2y * k2y, 0.000001f);
        const float t = clamp(dotNum / dotDen, 0.0f, 1.0f);
        const float cbx = qx - r2 + k2x * t;
        const float cby = qy - h + k2y * t;
        const float sInner = cay < 0.0f ? -1.0f : 1.0f;
        const float s = cbx < 0.0f ? sInner : 1.0f;
        const float dca = cax * cax + cay * cay;
        const float dcb = cbx * cbx + cby * cby;
        return s * sqrt(min(dca, dcb));
    }
    static float sk3_sdPyramid(float3 p, float b, float ht) {
        const float h2 = ht * 0.5f;
        const float denom = sqrt(ht * ht + b * b);
        const float dx = (ht * abs(p.x) + b * (p.y - h2)) / denom;
        const float dz = (ht * abs(p.z) + b * (p.y - h2)) / denom;
        const float dBase = -p.y - h2;
        return max(max(dx, dz), dBase);
    }
    static float sk3_sdHexPrism(float3 p, float r, float he) {
        const float kx = -0.8660254f;
        const float ky = 0.5f;
        const float kz = 0.57735f;
        const float ax = abs(p.x);
        const float ay = abs(p.y);
        const float az = abs(p.z);
        const float dk = min(kx * ax + ky * ay, 0.0f) * 2.0f;
        const float px = ax - dk * kx;
        const float py = ay - dk * ky;
        const float cx = clamp(px, -(kz * r), kz * r);
        const float ex = px - cx;
        const float ey = py - r;
        const float dHex = sqrt(ex * ex + ey * ey) * sign(py - r);
        const float dZ = az - he;
        const float inner = min(max(dHex, dZ), 0.0f);
        const float outer = length(float2(max(dHex, 0.0f), max(dZ, 0.0f)));
        return inner + outer;
    }
    static float sk3_sdEllipsoid(float3 p, float rx, float ry, float rz) {
        const float k0 = length(float3(p.x / rx, p.y / ry, p.z / rz));
        const float k1 = length(float3(p.x / (rx * rx), p.y / (ry * ry), p.z / (rz * rz)));
        return k0 * (k0 - 1.0f) / max(k1, 0.000001f);
    }
    static float sk3_sdBicone(float3 p, float r, float h) {
        const float qx = length(float2(p.x, p.z));
        const float qy = abs(p.y);
        const float abx = -r;
        const float aby = h;
        const float apx = qx - r;
        const float apy = qy;
        const float den = max(abx * abx + aby * aby, 0.000001f);
        const float t = clamp((apx * abx + apy * aby) / den, 0.0f, 1.0f);
        const float dxx = apx - abx * t;
        const float dyy = apy - aby * t;
        const float dist = sqrt(dxx * dxx + dyy * dyy);
        return dist * sign(h * qx + r * qy - r * h);
    }
    static float sk3_sdLink(float3 p, float le, float r1, float r2) {
        const float qy = max(abs(p.y) - le, 0.0f);
        const float ring = length(float2(p.x, qy)) - r1;
        return length(float2(ring, p.z)) - r2;
    }
    static float sk3_smin(float a, float b, float k) {
        const float h = clamp((b - a) / k * 0.5f + 0.5f, 0.0f, 1.0f);
        return mix(b, a, h) - k * h * (1.0f - h);
    }
    static float sk3_sdGem(float3 p, float r, float h, float sides) {
        const float base = sk3_sdBicone(p, r, h);
        const float lenXZ = length(float2(p.x, p.z));
        const float ang = atan2(p.z, p.x);
        const float sector = 6.283185307179586f / sides;
        const float idx = floor(ang / sector + 0.5f);
        const float ca = ang - idx * sector;
        const float ri = r * cos(3.141592653589793f / sides);
        const float facet = lenXZ * cos(ca) - ri;
        const float dd = max(base, facet);
        const float table = p.y - h * 0.45f;
        return max(dd, table);
    }
    static float sk3_sdHelix(float3 p, float R, float tube, float pitch, float turns) {
        const float psi = atan2(p.z, p.x);
        const float k = floor(p.y / pitch - psi / 6.283185307179586f + 0.5f);
        const float theta = psi + 6.283185307179586f * k;
        const float ccx = R * cos(theta);
        const float ccy = pitch * theta / 6.283185307179586f;
        const float ccz = R * sin(theta);
        const float dStrand = length(float3(p.x - ccx, p.y - ccy, p.z - ccz)) - tube;
        const float slab = abs(p.y) - pitch * turns * 0.5f;
        return max(dStrand, slab);
    }
    static float sk3_sdMetaballs(float3 p, float3 b0, float3 b1, float3 b2, float3 b3, float3 b4, float3 b5, float3 b6, float3 b7, float r, float k) {
        const float3 balls[8] = {b0, b1, b2, b3, b4, b5, b6, b7};
        float dd = length(p - balls[0]) - r;
        for (int i = 1; i < 8; i++) {
            dd = sk3_smin(dd, length(p - balls[i]) - r, k);
        }
        return dd;
    }
    static float sk3_sdDodecahedron(float3 p, float r) {
        const float3 q = abs(p);
        const float a = dot(q, float3(0.0f, 0.5257311f, 0.8506508f));
        const float b = dot(q, float3(0.8506508f, 0.0f, 0.5257311f));
        const float c = dot(q, float3(0.5257311f, 0.8506508f, 0.0f));
        return max(max(a, b), c) - r;
    }
    static float sk3_sdCutSphere(float3 p, float r, float h) {
        const float w = sqrt(max(r * r - h * h, 0.0f));
        const float qx = length(float2(p.x, p.z));
        const float qy = p.y;
        const float s = max((h - r) * qx * qx + w * w * (h + r - qy * 2.0f), h * qx - w * qy);
        const float case0 = length(float2(qx, qy)) - r;
        const float case1 = h - qy;
        const float case2 = length(float2(qx - w, qy - h));
        const float inner = qx < w ? case1 : case2;
        return s < 0.0f ? case0 : inner;
    }
    static float sk3_sdRibbon(float3 p, float w, float th, float len, float amp, float freq, float ph1, float ph2, float twRate, float twPh, float lip) {
        const float yc = amp * sin(freq * p.x + ph1);
        const float zc = amp * 0.6f * sin(freq * 0.8f * p.x + ph2);
        const float qy = p.y - yc;
        const float qz = p.z - zc;
        const float ang = twRate * p.x + twPh;
        const float c = cos(ang);
        const float s = sin(ang);
        const float ry = qy * c + qz * s;
        const float rz = qz * c - qy * s;
        const float rnd = th * 0.4f;
        const float bx = abs(ry) - w + rnd;
        const float by = abs(rz) - th + rnd;
        const float d2 = length(float2(max(bx, 0.0f), max(by, 0.0f))) + min(max(bx, by), 0.0f) - rnd;
        const float dx = abs(p.x) - len;
        const float dd = length(float2(max(d2, 0.0f), max(dx, 0.0f))) + min(max(d2, dx), 0.0f);
        return dd * lip;
    }
    static float sk3_sdWobbleBlob(float3 p, float r, float amp, float freq, float ph1, float ph2, float lip) {
        const float w = sin(p.x * freq + ph1) * sin(p.y * freq * 1.3f + ph2)
            + sin(p.y * freq * 0.8f + ph2 * 1.1f) * sin(p.z * freq * 1.1f + ph1 * 0.9f);
        const float dd = length(p) - r - amp * w * 0.5f;
        return dd * lip;
    }
    static float sk3_sdFlatBand(float radialDist, float axialDist, float R, float ht, float hw, float rnd) {
        const float bx = abs(radialDist - R) - ht + rnd;
        const float by = abs(axialDist) - hw + rnd;
        const float outer = length(float2(max(bx, 0.0f), max(by, 0.0f)));
        const float inner = min(max(bx, by), 0.0f);
        return outer + inner - rnd;
    }
    static float sk3_sdGyroscope(float3 p, float radius, float width, float thick, float rnd, float core, float c1, float s1, float c2, float s2, float c3, float s3) {
        const float hw = width * 0.5f;
        const float ht = thick * 0.5f;
        const float dCore = length(p) - core;
        const float p1y = p.y * c1 + p.z * s1;
        const float p1z = p.z * c1 - p.y * s1;
        const float d1 = sk3_sdFlatBand(length(float2(p.x, p1z)), p1y, radius, ht, hw, rnd);
        const float p2x = p.x * c2 - p.z * s2;
        const float p2z = p.z * c2 + p.x * s2;
        const float d2 = sk3_sdFlatBand(length(float2(p2x, p.y)), p2z, radius * 0.78f, ht, hw, rnd);
        const float p3x = p.x * c3 + p.y * s3;
        const float p3y = p.y * c3 - p.x * s3;
        const float d3 = sk3_sdFlatBand(length(float2(p3y, p.z)), p3x, radius * 0.56f, ht, hw, rnd);
        return min(min(dCore, d1), min(d2, d3));
    }
    """
}

// MARK: - Volumetric field pre-march

/// Port of upstream `createVolumetricFieldComputeNode` (+ `createVolumetricFieldCompute`): owns the
/// rgba32float field texture, resolves the shape each frame, re-marches only when the state key
/// changes, and publishes the `_vf*` sample domain.
final class SDFVolumetricField {
    struct Domain: Equatable {
        var originX = 0.0, originY = 0.0, spanX = 1.0, spanY = 1.0, activeRes = 1.0, rBound = 0.6
    }

    let texture: MTLTexture
    let maxRes: Int
    private let kernel: ComputeKernelDescriptor
    private let layout: UniformLayout
    private(set) var setup: SDFShape3DSetup
    private var library: MTLLibrary
    private var routeKey: String
    private var activeRes: Int
    private var lastKey: [Double]? = nil
    private let marchEvery: Int
    private var changedFrames = 0
    /// Mirrors the last `_vf*` publication (the extra-field initials before the first march).
    private(set) var domain = Domain()

    /// `kernelIndex` is the march kernel (`k0` in every shader of the family).
    init(context ctx: ComputeContext, kernelIndex: Int = 0) throws {
        guard let info = ctx.descriptor.compute, let k = info.kernel(kernelIndex) else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) field march kernel")
        }
        kernel = k
        guard let l = info.uniformLayouts[k.buffers.first { $0.type == "MarchParams" }?.name ?? "params"] else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) MarchParams layout")
        }
        layout = l
        maxRes = SDFKit.volumetricFieldRes
        guard let tex = ctx.makeTexture(width: maxRes, height: maxRes, format: .rgba32Float, label: "\(ctx.descriptor.name) volumetric field") else {
            throw ShaderEngineError.noMetalDevice
        }
        texture = tex
        SDFKit.clear(tex, to: MTLClearColor(red: 1000, green: 0, blue: 0, alpha: 0), commandBuffer: ctx.commandBuffer)
        activeRes = maxRes
        marchEvery = SDFKit.isMobileGpuViewport ? 2 : 1
        let route = Self.route(ctx)
        routeKey = route.key
        setup = SDFShape3DSetup(type: route.type, initialConfig: route.config, shapeJSON: ctx.string("shape"))
        library = try SDFShapeKernels.library(ctx, shapeType: route.type)
    }

    /// Upstream routing: an analytic 3D shape marches; SVG (`shapeSdfUrl`) and flat shapes return no
    /// volumetric field upstream (the fragment's analytic sampler takes over), which the generated
    /// fragment variant cannot do — they resolve to an empty field here.
    static func route(_ ctx: ComputeContext) -> (type: String?, config: [String: Any], key: String) {
        let cfg = SDFKit.parseShapeConfig(ctx.string("shape"))
        let sdfUrl = ctx.string("shapeSdfUrl") ?? ""
        let type = SDFKit.shapeType(prop: ctx.string("shapeType"), config: cfg)
        let supported = sdfUrl.isEmpty && SDFKit.shape3DTypes.contains(type)
        return (supported ? type : nil, cfg, "\(sdfUrl)|\(type)")
    }

    /// The `_vf*` extra fields as last published.
    var extraFields: [String: [Float]] {
        [
            "_vfOriginX": [Float(domain.originX)], "_vfOriginY": [Float(domain.originY)],
            "_vfSpanX": [Float(domain.spanX)], "_vfSpanY": [Float(domain.spanY)],
            "_vfActiveRes": [Float(domain.activeRes)], "_vfRBound": [Float(domain.rBound)],
        ]
    }

    /// The CPU half of upstream `getComputeNodes`: returns true when the field must be re-marched
    /// this frame (the domain is then already published).
    func prepare(_ ctx: ComputeContext) throws -> Bool {
        // A shape-type switch recompiles upstream (`shapeType` is compile-time); here it rebuilds the
        // setup and the march kernel in place.
        let route = Self.route(ctx)
        if route.key != routeKey {
            routeKey = route.key
            setup = SDFShape3DSetup(type: route.type, initialConfig: route.config, shapeJSON: ctx.string("shape"))
            library = try SDFShapeKernels.library(ctx, shapeType: route.type)
            lastKey = nil
        }
        setup.update(shapeJSON: ctx.string("shape"), deltaTime: Double(ctx.frame.deltaTime), pointer: SIMD2(Double(ctx.frame.pointer.x), Double(ctx.frame.pointer.y)))
        let fp = setup.footprint
        let scale = SDFKit.number(ctx, "scale", 1)
        activeRes = SDFKit.resolveActiveFieldRes(spanX: fp.spanX, spanY: fp.spanY, scale: scale, canvasHeightDevicePx: Double(ctx.height), maxRes: maxRes, prevRes: activeRes)
        let key = setup.stateKey + [Double(activeRes)]
        if key == lastKey { return false }
        changedFrames += 1
        if marchEvery > 1 && changedFrames % marchEvery != 0 { return false }
        lastKey = key
        setup.setActiveRes(activeRes)
        domain = Domain(originX: fp.originX, originY: fp.originY, spanX: fp.spanX, spanY: fp.spanY, activeRes: Double(activeRes), rBound: fp.rBound)
        return true
    }

    /// Dispatches the march over the active block (`activeRes²`).
    func encode(_ encoder: MTLComputeCommandEncoder, _ ctx: ComputeContext, extra: (MTLComputeCommandEncoder) -> Void = { _ in }) throws {
        let params = SDFKit.pack(layout, setup.marchValues)
        let k = kernel
        try SDFKit.dispatch(ctx, encoder, k, library: library, threads: SIMD3(UInt32(activeRes), UInt32(activeRes), 1)) { e in
            if let s = k.textures.first(where: { $0.type.hasPrefix("texture_storage_2d") }) { e.setTexture(texture, index: s.slot) }
            if let s = k.buffers.first(where: { $0.type == "MarchParams" }) { SDFKit.setBytes(e, params, index: s.slot) }
            extra(e)
        }
    }

    /// The library the current shape's kernels come from (Voxels reuses it for its bake).
    var currentLibrary: MTLLibrary { library }
}
#endif
