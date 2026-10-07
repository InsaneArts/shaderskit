import Foundation
import simd

// Per-frame CPU hooks that only write uniform `extraFields` (no GPU resources), ported from the
// upstream `params.onBeforeRender(() => params.setExtraField(...))` drivers. They are Metal-free so
// both the Metal renderer and the watchOS CPU rasterizer run them.

/// Inputs for a host-fields hook.
public struct HostFieldsContext {
    public let descriptor: ShaderDescriptor
    public let frame: FrameInput
    public let props: [String: PropValue]
    public let options: RenderOptions
    public let state: NodeState
    public let width: Int
    public let height: Int

    public func string(_ name: String) -> String? {
        (props[name] ?? descriptor.prop(name)?.defaultValue)?.stringValue
    }

    public func scalar(_ name: String) -> Float {
        guard let p = descriptor.prop(name) else { return 0 }
        return UniformPacker(descriptor: descriptor).scalar(p, props[name] ?? p.defaultValue)
    }

    /// Upstream `getCpuValue(colorProp)`: the color transformed to linear RGBA in the working space.
    public func linearColor(_ name: String) -> SIMD4<Float> {
        let c = CSSColor.linear(string(name) ?? "#000000", mode: options.colorSpace)
        return SIMD4(c.r, c.g, c.b, c.a)
    }

    /// Integer encoding of the `colorSpace` select prop (0 linear, 1 oklch, 2 oklab, 3 hsl, 4 hsv, 5 lch).
    public func colorSpaceMode(_ name: String = "colorSpace") -> Int {
        Int(PropTransforms.transformColorSpace(string(name) ?? "linear"))
    }
}

/// A CPU-only per-frame hook producing `extraFields` values for one or more shaders.
public protocol HostFieldsHook: AnyObject {
    static var shaderNames: [String] { get }
    init()
    func fields(_ context: HostFieldsContext) -> [String: [Float]]
}

public enum HostFieldsHooks {
    nonisolated(unsafe) private static var table: [String: HostFieldsHook.Type] = [:]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registeredBuiltins = false

    public static func register(_ type: HostFieldsHook.Type) {
        lock.lock(); defer { lock.unlock() }
        for n in type.shaderNames { table[n] = type }
    }

    static func hook(for shader: String) -> HostFieldsHook.Type? {
        lock.lock(); defer { lock.unlock() }
        if !registeredBuiltins {
            registeredBuiltins = true
            for t in builtinHostFieldsHooks { for n in t.shaderNames { table[n] = t } }
        }
        return table[shader]
    }

    /// Runs the shader's hook (if any) and merges the result into the node state's `extraFields`.
    static func apply(descriptor: ShaderDescriptor, props: [String: PropValue], frame: FrameInput, options: RenderOptions, state: NodeState, width: Int, height: Int) -> Bool {
        guard let type = hook(for: descriptor.name) else { return false }
        let hook: HostFieldsHook
        if let existing = state.storage["__hostFields"] as? HostFieldsHook {
            hook = existing
        } else {
            hook = type.init()
            state.storage["__hostFields"] = hook
        }
        let ctx = HostFieldsContext(descriptor: descriptor, frame: frame, props: props, options: options, state: state, width: width, height: height)
        let out = hook.fields(ctx)
        for (k, v) in out { state.extraFields[k] = v }
        return !out.isEmpty
    }
}

let builtinHostFieldsHooks: [HostFieldsHook.Type] = [
    FlowingGradientHostHook.self,
    BeamHostHook.self,
    BlobHostHook.self,
    FilmGrainHostHook.self,
    StudioBackgroundHostHook.self,
    MeshGradientHostHook.self,
    Form3DHostHook.self,
]

/// Upstream `colorMixing.convertP3ToMixSpaceCPU` over named color props, keyed into vec3 extraFields.
func preconvertedColorFields(_ ctx: HostFieldsContext, _ pairs: [(prop: String, field: String)]) -> [String: [Float]] {
    let mode = ctx.colorSpaceMode()
    guard mode != 0 else { return [:] }
    var out: [String: [Float]] = [:]
    for (prop, field) in pairs {
        let c = ctx.linearColor(prop)
        let conv = ColorMath.convertP3ToMixSpaceCPU(r: c.x, g: c.y, b: c.z, mode: mode)
        out[field] = [conv.x, conv.y, conv.z]
    }
    return out
}

/// FlowingGradient (std/paint/fields.ts `quadBlend`): for a non-linear color space the four
/// endpoint colors are converted P3 → mix space on the CPU into `convA`…`convD`.
final class FlowingGradientHostHook: HostFieldsHook {
    static let shaderNames = ["FlowingGradient"]
    init() {}
    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        preconvertedColorFields(ctx, [("colorA", "convA"), ("colorB", "convB"), ("colorC", "convC"), ("colorD", "convD")])
    }
}

/// Beam (std/paint/gradients.ts `beam`): inside/outside colors preconverted into `convA`/`convB`.
final class BeamHostHook: HostFieldsHook {
    static let shaderNames = ["Beam"]
    init() {}
    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        preconvertedColorFields(ctx, [("insideColor", "convA"), ("outsideColor", "convB")])
    }
}

/// Blob (std/signal.ts `driveUnitDirection`): the highlight direction normalized into `normL*`.
final class BlobHostHook: HostFieldsHook {
    static let shaderNames = ["Blob"]
    init() {}
    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        let x = ctx.scalar("highlightX"), y = ctx.scalar("highlightY"), z = ctx.scalar("highlightZ")
        let len = (x * x + y * y + z * z).squareRoot()
        let n: (Float, Float, Float) = len > 0 ? (x / len, y / len, z / len) : (0, 0, 0)
        return ["normLx": [n.0], "normLy": [n.1], "normLz": [n.2]]
    }
}

/// FilmGrain (std/effects/color.ts `filmGrain`): `animTime += deltaTime · animated · 10`.
final class FilmGrainHostHook: HostFieldsHook {
    static let shaderNames = ["FilmGrain"]
    private var animTimeAcc: Float = 0
    init() {}
    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        let on: Float = ctx.scalar("animated") > 0 ? 1 : 0
        animTimeAcc += ctx.frame.deltaTime * on * 10
        return ["animTime": [animTimeAcc]]
    }
}

/// StudioBackground: the four ambient-light orbits. The ambient clock integrates
/// `deltaTime · ambientSpeed`; seed-hash orbit constants are recomputed when `seed` changes.
final class StudioBackgroundHostHook: HostFieldsHook {
    static let shaderNames = ["StudioBackground"]
    private struct Orbit { var sizeSq, radiusX, radiusY, freqX, freqY, phaseX, phaseY: Double }
    private var ambTime: Double = 0
    private var lastSeed = Double.nan
    private var orbits: [Orbit] = []

    init() {}

    /// std/signal.ts `cpuHash01`: `fract(sin(x·12.9898)·43758.5453)` in f64.
    private static func hash01(_ x: Double) -> Double {
        let v = sin(x * 12.9898) * 43758.5453
        return v - v.rounded(.down)
    }

    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        ambTime += Double(ctx.frame.deltaTime) * Double(ctx.scalar("ambientSpeed"))
        let seed = Double(ctx.scalar("seed"))
        if seed != lastSeed {
            lastSeed = seed
            let tau = Double.pi * 2
            orbits = (0..<4).map { i in
                let sd = seed + Double(i) * 73.1
                let sizeVal = Self.hash01(sd + 311.0) * 0.12 + 0.1
                return Orbit(sizeSq: sizeVal * sizeVal,
                             radiusX: Self.hash01(sd) * 0.5 + 0.2,
                             radiusY: Self.hash01(sd + 37.0) * 0.25 + 0.1,
                             freqX: Self.hash01(sd + 91.0) * 0.3 + 0.1,
                             freqY: Self.hash01(sd + 143.0) * 0.25 + 0.08,
                             phaseX: Self.hash01(sd + 200.0) * tau,
                             phaseY: Self.hash01(sd + 257.0) * tau)
            }
        }
        let off = orbits.map { c in
            [Float(sin(ambTime * c.freqX + c.phaseX) * c.radiusX), Float(cos(ambTime * c.freqY + c.phaseY) * c.radiusY)]
        }
        return [
            "ambPosA": off[0] + off[1],
            "ambPosB": off[2] + off[3],
            "ambSizeSq": orbits.map { Float($0.sizeSq) },
        ]
    }
}

/// MeshGradient (std/paint/fields.ts `scatteredAnchors` → utilities/scatterAnchors.ts
/// `packScatterAnchors`): the 8 golden-spiral anchors on the node's `_animTime` clock, packed
/// two per vec4 into `meshAnchors`. The hash/lattice arithmetic is f32 like the GPU mirror.
final class MeshGradientHostHook: HostFieldsHook {
    static let shaderNames = ["MeshGradient"]
    static let scatterMax = 8
    static let driftRate: Float = 0.11
    private static let golden = Float(2.39996322972865332)
    private static let tau = Float(Double.pi * 2)
    private static let u32 = Float(4294967295.0)

    init() {}

    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        let w = ctx.frame.logicalSize.x, h = ctx.frame.logicalSize.y
        let aspect = w / max(h, 1e-6)
        let t = ctx.state.animTime["_animTime"] ?? 0
        return ["meshAnchors": Self.pack(count: ctx.scalar("count"), seed: ctx.scalar("seed"), drift: ctx.scalar("drift"), aspect: aspect, animTime: t)]
    }

    static func hash11(_ p: Float) -> Float {
        let u = (p * Float(3141592653)).bitPattern
        return Float((u &* u) &* 3141592653) / u32
    }

    static func hash22(_ x: Float, _ y: Float) -> (Float, Float) {
        let ux = (x * Float(141421356)).bitPattern
        let uy = (y * Float(2718281828)).bitPattern
        let h = ux ^ uy
        return (Float(h &* 3141592653) / u32, Float(h &* 1618033988) / u32)
    }

    private static func fsin(_ x: Float) -> Float { Float(sin(Double(x))) }
    private static func fcos(_ x: Float) -> Float { Float(cos(Double(x))) }

    static func spiralScatter(_ fi: Float, count: Float, seed: Float, drift: Float, aspect: Float, animTime: Float) -> (Float, Float) {
        let theta = fi * golden + hash11(seed * Float(0.7311) + Float(1.618)) * tau
        let r = ((fi + 0.5) / count).squareRoot()
        let jh = hash22(fi * Float(3.77) + Float(0.917), seed * Float(1.093) + Float(2.236))
        let jx = (jh.0 - 0.5) * Float(0.26)
        let jy = (jh.1 - 0.5) * Float(0.26)
        let ph = hash22(fi * Float(7.13) + Float(1.618), seed * Float(0.531) + Float(3.71))
        let phx = ph.0 * tau
        let phy = ph.1 * tau
        let w1 = 0.5 + hash11(fi * Float(5.417) + seed * Float(0.291) + Float(0.917)) * Float(0.7)
        let tw = animTime * driftRate * w1
        let dx = fsin(tw + phx)
        let dy = fcos(tw * Float(1.37) + phy)
        let nx = (fcos(theta) * r * Float(0.62) + jx) + dx * drift * Float(0.16)
        let ny = (fsin(theta) * r * Float(0.62) + jy) + dy * drift * Float(0.16)
        return ((0.5 + nx) * aspect, 0.5 + ny)
    }

    static func pack(count: Float, seed: Float, drift: Float, aspect: Float, animTime: Float) -> [Float] {
        var out = [Float](repeating: 0, count: scatterMax * 2)
        for i in 0..<scatterMax {
            let (x, y) = spiralScatter(Float(i), count: count, seed: seed, drift: drift, aspect: aspect, animTime: animTime)
            out[i * 2] = x
            out[i * 2 + 1] = y
        }
        return out
    }
}
