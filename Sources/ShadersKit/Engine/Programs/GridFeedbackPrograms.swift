#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of `createFeedbackTrailSim` (gpu/scaffolds/feedbackSim.ts) as driven by `feedbackSim`
/// (std/sim/feedback.ts): a ping-pong state pair + a display copy the fragment samples, optional
/// lockstep extra slots and plain textures, the child RTT as input, and a clamped speed-scaled
/// clock. The orientation swaps only on frames that dispatched.
final class GridFeedbackSim {
    struct Slot {
        let state: MTLTexture
        let extra: [String: MTLTexture]
    }
    struct Tick {
        let read: Slot
        let write: Slot
        let dt: Float
        let localTime: Float
    }

    let display: MTLTexture
    let textures: [String: MTLTexture]
    private var pair: GridKit.PingPong<Slot>
    private let speedProp: String?
    private let maxDeltaTime: Float
    private var localTime: Float = 0
    private var needsZero = true

    init(_ ctx: ComputeContext, width: Int, height: Int, format: MTLPixelFormat, extraSlots: [String: (Int, Int)] = [:],
         textures: [String: (Int, Int)] = [:], speedProp: String? = nil, maxDeltaTime: Float = 0.05) throws {
        func make(_ w: Int, _ h: Int, _ label: String) throws -> MTLTexture { try GridKit.texture(ctx, w, h, format, label: label) }
        let name = ctx.descriptor.name
        var extraA: [String: MTLTexture] = [:], extraB: [String: MTLTexture] = [:]
        for (k, s) in extraSlots {
            extraA[k] = try make(s.0, s.1, "\(name) \(k) A")
            extraB[k] = try make(s.0, s.1, "\(name) \(k) B")
        }
        pair = GridKit.PingPong(Slot(state: try make(width, height, "\(name) state A"), extra: extraA),
                                Slot(state: try make(width, height, "\(name) state B"), extra: extraB))
        display = try make(width, height, "\(name) display")
        var plain: [String: MTLTexture] = [:]
        for (k, s) in textures { plain[k] = try make(s.0, s.1, "\(name) \(k)") }
        self.textures = plain
        self.speedProp = speedProp
        self.maxDeltaTime = maxDeltaTime
    }

    /// The body of `getComputeNodes`: advance the clock, run `frame`, swap when it dispatched.
    func tick(_ ctx: ComputeContext, _ frame: (Tick) throws -> Bool) rethrows {
        if needsZero {
            var all = [pair.a.state, pair.b.state, display] + Array(textures.values)
            all += Array(pair.a.extra.values) + Array(pair.b.extra.values)
            GridKit.zero(textures: all, cb: ctx.commandBuffer)
            needsZero = false
        }
        let speed = speedProp.map { GridKit.num(ctx, $0, 1) } ?? 1
        let dt = min(ctx.frame.deltaTime, maxDeltaTime) * (speed.isFinite ? speed : 1)
        localTime += dt
        if try frame(Tick(read: pair.read, write: pair.write, dt: dt, localTime: localTime)) { pair.swap() }
    }
}

/// DataMosh (shaders/DataMosh): the macroblock hold/refresh decode rule on the feedback scaffold,
/// 768² rgba16float, clocked by the sim's own speed-scaled `localTime`.
final class GridDataMoshProgram: ComputeProgram {
    static let shaderNames = ["DataMosh"]
    private static let stateRes = 768

    private let step: ComputeKernelDescriptor
    private let layout: UniformLayout
    private let sim: GridFeedbackSim

    init(context ctx: ComputeContext) throws {
        step = try GridKit.kernel(ctx, 0)
        layout = try GridKit.uniformLayout(ctx, step)
        sim = try GridFeedbackSim(ctx, width: Self.stateRes, height: Self.stateRes, format: .rgba16Float, speedProp: "speed")
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let child = GridKit.child(ctx) else { return ComputeOutputs() }
        try sim.tick(ctx) { t in
            let params = GridKit.pack(layout, [
                "time": [t.localTime], "dt": [t.dt],
                "seed": [GridKit.num(ctx, "seed", 0)], "intensity": [GridKit.num(ctx, "intensity", 0.7)],
                "blockSize": [GridKit.num(ctx, "blockSize", 48)], "drift": [GridKit.num(ctx, "drift", 0.35)],
                "churn": [GridKit.num(ctx, "churn", 0.4)],
            ])
            guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return false }
            defer { enc.endEncoding() }
            enc.label = "DataMosh decode"
            try ctx.dispatch(enc, step, threads: SIMD3(UInt32(Self.stateRes), UInt32(Self.stateRes), 1)) { e in
                GridKit.setTexture(e, step, "src", child)
                GridKit.setTexture(e, step, "prev", t.read.state)
                GridKit.setTexture(e, step, "next", t.write.state)
                GridKit.setTexture(e, step, "display", sim.display)
                GridKit.setUniform(e, step, params)
            }
            return true
        }
        return ComputeOutputs(textures: ["compute_0": sim.display])
    }
}

/// TimeTrail (shaders/TimeTrail): the feedback-trail step (advect → tent diffuse + decay →
/// frame-difference gate → stamp) on the feedback scaffold, 640² (384² on mobile GPUs).
///
/// The shipped kernel is the Motion / untinted variant. The Alpha source variant is specialized
/// from it at runtime (stamp unconditionally, publish the stamped state). The Rainbow hue-cycle
/// variant needs the HSL helpers the transpiler did not emit, so Rainbow runs untinted.
final class GridTimeTrailProgram: ComputeProgram {
    static let shaderNames = ["TimeTrail"]
    /// The kernel bakes 640 (desktop tier); the mobile tier is specialized.
    private static let bakedRes = 640
    private static let stateRes = GridKit.isMobileGpu ? 384 : 640
    private static let rainbowRate: Float = 0.35

    private let step: ComputeKernelDescriptor
    private let layout: UniformLayout
    private var sim: GridFeedbackSim?
    private var library: MTLLibrary?
    private var structure = ""

    init(context ctx: ComputeContext) throws {
        step = try GridKit.kernel(ctx, 0)
        layout = try GridKit.uniformLayout(ctx, step)
    }

    /// trailBlend → the kernel's stamp mode: screen/add accumulate light inside the history.
    static func stampMode(_ blend: String?) -> Float {
        switch blend {
        case "screen": return 1
        case "add", "linearDodge": return 2
        default: return 0
        }
    }

    static func patches(alpha: Bool, res: Int) -> [GridKit.Patch] {
        var p: [GridKit.Patch] = []
        if res != bakedRes {
            p.append(GridKit.Patch("const float r = \(bakedRes).0f;", "const float r = \(res).0f;"))
            // The diffusion half-offset is DIFFUSE_HALF_UV = 2.5 * 0.5 / STATE_RES (0.001953125 at 640).
            p.append(GridKit.Patch("diffusion * 0.001953125f", "diffusion * \(String(format: "%.9g", 1.25 / Double(res)))f"))
        }
        if alpha {
            p.append(GridKit.Patch("""
                const float4 pl = prevLive.read(uint2(cx, cy), 0);
                    const float m = frameDiffMask(live, pl, params.motionThreshold);
                    next.write(timeTrailStamp(live, m, trail, params), uint2(cx, cy));
                    display.write(trail, uint2(cx, cy));
                    prevLiveOut.write(live, uint2(cx, cy));
                """, """
                const float4 outC = timeTrailStamp(live, 1.0f, trail, params);
                    next.write(outC, uint2(cx, cy));
                    display.write(outC, uint2(cx, cy));
                """))
        }
        return p
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let child = GridKit.child(ctx) else { return ComputeOutputs() }
        // trailSource / tintMode / trailBlend are compile-time upstream: a change recomposes.
        let isMotion = ctx.scalar("trailSource") > 0.5
        let tintMode = ctx.scalar("tintMode")
        let blendMode = Self.stampMode(GridKit.string(ctx, "trailBlend"))
        let key = "\(isMotion)/\(tintMode)/\(blendMode)"
        if key != structure || sim == nil {
            let res = Self.stateRes
            library = try GridKit.specializedLibrary(ctx, key: "\(isMotion ? "motion" : "alpha")\(res)", patches: Self.patches(alpha: !isMotion, res: res))
            // The Alpha kernel never touches prevLive: 1×1 stubs fill the bind slots.
            sim = try GridFeedbackSim(ctx, width: res, height: res, format: .rgba16Float,
                                      extraSlots: ["prevLive": isMotion ? (res, res) : (1, 1)], speedProp: "speed")
            structure = key
        }
        guard let sim, let library else { return ComputeOutputs() }
        let kctx = GridKit.with(ctx, library: library)
        try sim.tick(ctx) { t in
            // Idle skip, and only this one: at trailOpacity 0 the composite is the live frame.
            if GridKit.num(ctx, "trailOpacity", 1) == 0 { return false }
            let zoom = GridKit.num(ctx, "zoom", 1)
            let trailLength = max(GridKit.num(ctx, "trailLength", 0.6), 0.001)
            let params = GridKit.pack(layout, [
                "persistence": [exp(-t.dt / trailLength)],
                "diffusion": [GridKit.num(ctx, "diffusion", 0.3)],
                "driftX": [GridKit.num(ctx, "driftX", 0)], "driftY": [GridKit.num(ctx, "driftY", 0)],
                "dt": [t.dt],
                "zoom": [pow(zoom, t.dt * 60)],
                "hueRate": [tintMode == 2 ? Self.rainbowRate * t.dt : 0],
                "blendMode": [blendMode],
                "motionThreshold": [GridKit.num(ctx, "motionThreshold", 0.06)],
            ])
            guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return false }
            defer { enc.endEncoding() }
            enc.label = "TimeTrail step"
            try kctx.dispatch(enc, step, threads: SIMD3(UInt32(Self.stateRes), UInt32(Self.stateRes), 1)) { e in
                GridKit.setTexture(e, step, "src", child)
                GridKit.setTexture(e, step, "prev", t.read.state)
                GridKit.setTexture(e, step, "next", t.write.state)
                GridKit.setTexture(e, step, "display", sim.display)
                if let pl = t.read.extra["prevLive"] { GridKit.setTexture(e, step, "prevLive", pl) }
                if let pl = t.write.extra["prevLive"] { GridKit.setTexture(e, step, "prevLiveOut", pl) }
                e.setSamplerState(ctx.device.linearClamp, index: 0) // `samp`: filtering, clamp-to-edge
                GridKit.setUniform(e, step, params)
            }
            return true
        }
        return ComputeOutputs(textures: ["compute_0": sim.display])
    }
}

/// KeyFrames (shaders/KeyFrames, gpu/kit/trackerSim.ts `createTrackerPursuitSim`): a 96² feature
/// grid scored from the child each frame, then a per-tracker mean-shift pursuit kernel over
/// ping-pong state rows (15 × 64, rgba32float) with a `present` copy the HUD fragment reads.
/// Pure GPU tracking of the child's pixels: no camera or ML detection is involved.
///
/// The shipped kernels score `bright` features; the other `detect` modes are specialized at
/// runtime from upstream `featureScoreFn`.
final class GridKeyFramesProgram: ComputeProgram {
    static let shaderNames = ["KeyFrames"]
    private static let trackerMax = 64
    private static let stateWidth = 2 + 12 + 1 // head, meta, trail ring, AABB
    private static let featGrid = 96

    private let feature: ComputeKernelDescriptor
    private let pursuit: ComputeKernelDescriptor
    private let layout: UniformLayout
    private var sim: GridFeedbackSim?
    private var library: MTLLibrary?
    private var mode = ""

    init(context ctx: ComputeContext) throws {
        feature = try GridKit.kernel(ctx, 0)
        pursuit = try GridKit.kernel(ctx, 1)
        layout = try GridKit.uniformLayout(ctx, pursuit)
    }

    /// Upstream `featureScoreFn(mode)` bodies (premultiplied child texel → feature score).
    static func scoreBody(_ mode: String) -> String? {
        let a = "const float a = max(c.w, 1.0e-4f);"
        let gate = "select(0.0f, 1.0f, ((c.w > 0.02f)))"
        switch mode {
        case "alpha": return "return c.w;"
        case "dark":
            return "\(a) const float lumaU = clamp(((c.x * 0.299f) + (c.y * 0.587f) + (c.z * 0.114f)) / a, 0.0f, 1.0f); return (1.0f - lumaU) * select(0.0f, 1.0f, ((c.w > 0.5f)));"
        case "red":
            return "\(a) return clamp(c.x / a, 0.0f, 1.0f) * select(0.0f, 1.0f, c.x >= c.y) * select(0.0f, 1.0f, c.x >= c.z) * \(gate);"
        case "green":
            return "\(a) return clamp(c.y / a, 0.0f, 1.0f) * select(0.0f, 1.0f, c.y >= c.x) * select(0.0f, 1.0f, c.y >= c.z) * \(gate);"
        case "blue":
            return "\(a) return clamp(c.z / a, 0.0f, 1.0f) * select(0.0f, 1.0f, c.z >= c.x) * select(0.0f, 1.0f, c.z >= c.y) * \(gate);"
        default: return nil // 'bright' is the shipped kernel
        }
    }

    static func patches(mode: String) -> [GridKit.Patch] {
        guard let body = scoreBody(mode) else { return [] }
        return [GridKit.Patch("featureScore_bright(src.read(", "featureScore_\(mode)(src.read(", count: 2),
                GridKit.Patch("static void featureGridScan(", "static float featureScore_\(mode)(float4 c) { \(body) }\n\nstatic void featureGridScan(")]
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let child = GridKit.child(ctx) else { return ComputeOutputs() }
        // `detect` is compile-time upstream: a change recomposes (fresh trackers).
        let detect = GridKit.string(ctx, "detect") ?? "bright"
        if detect != mode || sim == nil {
            library = try GridKit.specializedLibrary(ctx, key: "detect-\(detect)", patches: Self.patches(mode: detect))
            sim = try GridFeedbackSim(ctx, width: Self.stateWidth, height: Self.trackerMax, format: .rgba32Float,
                                      textures: ["grid": (Self.featGrid, Self.featGrid)])
            mode = detect
        }
        guard let sim, let library, let grid = sim.textures["grid"] else { return ComputeOutputs() }
        let kctx = GridKit.with(ctx, library: library)
        try sim.tick(ctx) { t in
            let params = GridKit.pack(layout, [
                "dt": [t.dt],
                "trackersF": [GridKit.num(ctx, "trackers", 4)],
                "agility": [GridKit.num(ctx, "agility", 0.5)],
                "threshold": [GridKit.num(ctx, "threshold", 0.15)],
                "variance": [GridKit.num(ctx, "variance", 0.5)],
                "lifespan": [GridKit.num(ctx, "lifespan", 6)],
            ])
            guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return false }
            defer { enc.endEncoding() }
            enc.label = "KeyFrames trackers"
            try kctx.dispatch(enc, feature, threads: SIMD3(UInt32(Self.featGrid), UInt32(Self.featGrid), 1)) { e in
                GridKit.setTexture(e, feature, "src", child)
                GridKit.setTexture(e, feature, "grid", grid)
            }
            try kctx.dispatch(enc, pursuit, threads: SIMD3(UInt32(Self.trackerMax), 1, 1)) { e in
                GridKit.setTexture(e, pursuit, "src", child)
                GridKit.setTexture(e, pursuit, "featGrid", grid)
                GridKit.setTexture(e, pursuit, "prev", t.read.state)
                GridKit.setTexture(e, pursuit, "next", t.write.state)
                GridKit.setTexture(e, pursuit, "present", sim.display)
                GridKit.setUniform(e, pursuit, params)
            }
            return true
        }
        return ComputeOutputs(textures: ["compute_0": sim.display])
    }
}
#endif
