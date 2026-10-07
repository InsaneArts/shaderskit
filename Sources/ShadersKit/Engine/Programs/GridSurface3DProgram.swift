#if canImport(Metal)
import Foundation
import Metal
import simd

/// Surface3D (shaders/Surface3D on gpu/scaffolds/heightField.ts): a z = h(x, y) surface raymarched
/// into a uvMask map (`compute_0`) and a lit map (`compute_1`), with the damped wave-equation
/// ripple layer (256², ping-pong f32 buffers + a stable snapshot) driven by the cursor. The orbit
/// camera and the cursor → wave-grid projection are resolved on the CPU each frame; an unchanged
/// frame over a settled field dispatches nothing.
///
/// The shipped march kernel was transpiled for one compose (800×600 grid, fractal, 2 octaves,
/// clamp edges, 16 steps). Upstream bakes these per compose, so the grid size, octave count,
/// wave family, edge mode and the mobile step count are specialized at runtime.
final class GridSurface3DProgram: ComputeProgram {
    static let shaderNames = ["Surface3D"]

    private static let computeMax = GridKit.isMobileGpu ? 960 : 1600
    private static let marchSteps = GridKit.isMobileGpu ? 12 : 16
    private static let waveGrid = 256
    private static let waveHalfExtent: Float = 3
    private static let cursorWaveBound: Float = 6
    private static let waveDecay: Float = 10
    private static let waveDecayPerStep: Float = 0.004
    private static let heightSlabPad: Float = 0.02
    /// `WAVE_SETTLE_MS`: when the propagation has damped below 1e-6.
    private static let waveSettleMs: Float = {
        let damp = 1 - waveDecay * waveDecayPerStep
        return damp >= 1 ? .infinity : min(30000, (log(Float(1e-6)) / log(max(damp, 0.001))) * 16.67)
    }()

    private let march: ComputeKernelDescriptor
    private let propagate: ComputeKernelDescriptor
    private let layout: UniformLayout
    private var wave: GridKit.PingPong<MTLBuffer>
    private let readBuf: MTLBuffer

    private var structure = ""
    private var library: MTLLibrary?
    private var uvMaskTex: MTLTexture?
    private var litTex: MTLTexture?
    private var computeW = 0, computeH = 0
    private var cursorEnabled = true
    private var needsZero = true

    private var prevPx: Float = 0.5, prevPy: Float = 0.5
    private var simSinceActive: Float = 0
    private var animT: Float = 0
    private var lastSig: [Float]?

    init(context ctx: ComputeContext) throws {
        march = try GridKit.kernel(ctx, 0)
        propagate = try GridKit.kernel(ctx, 1)
        layout = try GridKit.uniformLayout(ctx, march)
        let bytes = Self.waveGrid * Self.waveGrid * 4
        wave = GridKit.PingPong(try GridKit.privateBuffer(ctx, length: bytes, label: "Surface3D wave A"),
                                try GridKit.privateBuffer(ctx, length: bytes, label: "Surface3D wave B"))
        readBuf = try GridKit.privateBuffer(ctx, length: bytes, label: "Surface3D wave snapshot")
    }

    // MARK: Kernel specialization

    /// `buildSpectralHeightField` family bodies for sine (1) and ridge (2), `octaves` baked.
    static func waveBlock(waveType: Int, octaves: Int, invTotalWeight: String) -> String {
        let head = [
            "    {",
            waveType == 1 ? "        float accSin = 0.0f;" : "        float accR = 0.0f;",
            "        for (int i = 0; ((i < \(octaves))); i++) {",
            "            const float iF = float(i);",
            "            const float scale = exp2(iF);",
            "            const float weight = exp2(((iF * (-1.0f))));",
        ]
        let body: [String]
        if waveType == 1 {
            body = [
                "            const float cu = cos(((iF * 1.111f)));",
                "            const float su = sin(((iF * 1.111f)));",
                "            const float ru = ((u * cu) - (v * su));",
                "            const float phase = ((((ru * freq) * scale) * 6.283185307179586f) + (((*p)).t * (1.0f + (iF * 0.2f)))) + (seedU * (1.0f + (iF * 0.5f)));",
                "            accSin = accSin + (sin(phase) * weight);",
                "        }",
                "        waveVal = accSin * \(invTotalWeight)f;",
            ]
        } else {
            body = [
                "            const float driftX = cos(((iF * 2.39996f)));",
                "            const float driftY = sin(((iF * 2.39996f)));",
                "            const float2 coord = float2((((u * freq) * scale) + (((*p)).t * (driftX * 0.3f))) + seedU, (((v * freq) * scale) + (((*p)).t * (driftY * 0.3f))) + (seedU * 0.7f));",
                "            accR = accR + (mxNoiseFloat2(coord) * weight);",
                "        }",
                "        const float n = accR * \(invTotalWeight)f;",
                "        waveVal = ((1.0f - abs(n)) * 2.0f) - 1.0f;",
            ]
        }
        return (head + body + ["    }", ""]).joined(separator: "\n")
    }

    /// kit/edges routing on the hit UV (1 transparent, 2 mirror, 3 wrap; 0 is the shipped clamp).
    static func edgeBlock(_ mode: Int) -> String? {
        switch mode {
        case 1:
            return "const bool sk_inside = rawSampleUV.x >= 0.0f && rawSampleUV.x <= 1.0f && rawSampleUV.y >= 0.0f && rawSampleUV.y <= 1.0f;\n    const float outOfBoundsMask = select(0.0f, 1.0f, sk_inside);"
        case 2:
            return "const float outOfBoundsMask = 1.0f;\n    { const float mirrorX = fmod(abs(rawSampleUV.x), 2.0f); const float mirrorY = fmod(abs(rawSampleUV.y), 2.0f); finalUV = float2(select(mirrorX, 2.0f - mirrorX, mirrorX >= 1.0f), select(mirrorY, 2.0f - mirrorY, mirrorY >= 1.0f)); }"
        case 3:
            return "const float outOfBoundsMask = 1.0f;\n    finalUV = fract(rawSampleUV);"
        default:
            return nil
        }
    }

    static func patches(source: String, width: Int, height: Int, waveType: Int, octaves: Int, edgeMode: Int, steps: Int) -> [GridKit.Patch] {
        var p: [GridKit.Patch] = []
        if width != 800 { p.append(GridKit.Patch("/ 800.0f));", "/ \(width).0f));")) }
        if height != 600 { p.append(GridKit.Patch("/ 600.0f));", "/ \(height).0f));")) }
        if steps != 16 {
            p.append(GridKit.Patch("(tExit - tEnter)) / 16.0f));", "(tExit - tEnter)) / \(steps).0f));"))
            p.append(GridKit.Patch("((s < 16));", "((s < \(steps)));"))
        }
        let inv = String(format: "%.9g", 1 / (2 - pow(0.5, Double(max(octaves, 1) - 1))))
        if waveType == 0 {
            if octaves != 2 {
                p.append(GridKit.Patch("for (int i = 0; ((i < 2)); i++) {", "for (int i = 0; ((i < \(octaves))); i++) {"))
                p.append(GridKit.Patch("((accW * 0.6666666666666666f))", "((accW * \(inv)f))"))
            }
        } else if let region = GridKit.regionPatch(source, from: "    float waveVal = 0.0f;\n", to: "    const float cu = ((((u - 0.5f)) * 2.0f));",
                                                    with: waveBlock(waveType: waveType, octaves: octaves, invTotalWeight: inv)) {
            p.append(region)
        }
        if let edges = edgeBlock(edgeMode) {
            p.append(GridKit.Patch("const float outOfBoundsMask = 1.0f;\n    finalUV = clamp(rawSampleUV, float2(0), float2(1));", edges))
        }
        return p
    }

    // MARK: Camera

    private static func norm3(_ a: SIMD3<Float>) -> SIMD3<Float> {
        a / max(1e-6, (a * a).sum().squareRoot())
    }

    /// `resolveOrbitCamera`: tilt/roll (radians), height, zoom → position, basis, focal.
    static func orbitCamera(tilt: Float, roll: Float, height: Float, zoom: Float) -> (pos: SIMD3<Float>, fwd: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>, focal: Float) {
        let camDist = 0.85 / max(0.0001, zoom)
        let camY = -sin(tilt) * camDist
        let orbitZ = cos(tilt) * camDist
        let pos = SIMD3<Float>(0, camY, orbitZ + height)
        let fwd = norm3(SIMD3(0, -camY, -orbitZ))
        let right0 = SIMD3<Float>(1, 0, 0)
        let up0 = norm3(simd_cross(right0, fwd))
        let cr = cos(roll), sr = sin(roll)
        return (pos, fwd, right0 * cr + up0 * sr, up0 * cr - right0 * sr, 1.5)
    }

    // MARK: Frame

    /// Compile-time props upstream (a change recomposes: fresh grid size, state and clock).
    private func rebuildIfNeeded(_ ctx: ComputeContext) throws {
        let rawType = GridKit.string(ctx, "waveType")
        let waveType = rawType == "sine" ? 1 : rawType == "ridge" ? 2 : 0
        let octaves = max(1, Int(GridKit.num(ctx, "octaves", 2).rounded(.down)))
        let edgeMode = Int(ctx.scalar("edges"))
        let lighting = GridKit.num(ctx, "lighting", 30) >= 0.01
        let cursor = GridKit.num(ctx, "cursorIntensity", 1) >= 0.01
        let key = "\(waveType)/\(octaves)/\(edgeMode)/\(lighting)/\(cursor)"
        if key == structure, library != nil { return }

        // Aspect-fit the march grid to the canvas within the device cap (sized once per compose).
        var w = min(Self.computeMax, 1600)
        var h = min(Int((Float(Self.computeMax) * 900 / 1600).rounded()), 900)
        if ctx.width >= 16 && ctx.height >= 16 {
            let fit = min(1, Float(Self.computeMax) / Float(max(ctx.width, ctx.height)))
            w = max(16, Int(GridKit.jsRound(Float(ctx.width) * fit)))
            h = max(16, Int(GridKit.jsRound(Float(ctx.height) * fit)))
        }
        guard let src = ShaderRegistry.mslSource(ctx.descriptor.msl) else { throw ShaderEngineError.missingResource("\(ctx.descriptor.msl).metal") }
        let patches = Self.patches(source: src, width: w, height: h, waveType: waveType, octaves: octaves, edgeMode: edgeMode, steps: Self.marchSteps)
        library = try GridKit.specializedLibrary(ctx, key: "\(w)x\(h)/\(waveType)/\(octaves)/\(edgeMode)/\(Self.marchSteps)", patches: patches)
        uvMaskTex = try GridKit.texture(ctx, w, h, label: "Surface3D uvMask")
        litTex = try GridKit.texture(ctx, w, h, label: "Surface3D lit")
        computeW = w; computeH = h
        cursorEnabled = cursor
        structure = key
        needsZero = true
        prevPx = 0.5; prevPy = 0.5
        simSinceActive = 0
        animT = 0
        lastSig = nil
        wave.reset()
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        try rebuildIfNeeded(ctx)
        guard let library, let uvMaskTex, let litTex else { return ComputeOutputs() }
        if needsZero {
            GridKit.zero(textures: [uvMaskTex, litTex], buffers: [wave.a, wave.b, readBuf], cb: ctx.commandBuffer)
            needsZero = false
        }
        let out = ComputeOutputs(textures: ["compute_0": uvMaskTex, "compute_1": litTex])

        let dt = min(ctx.frame.deltaTime, 0.016)
        let px = ctx.frame.pointer.x, py = ctx.frame.pointer.y
        let rawVelX: Float = dt > 0 ? (px - prevPx) / dt : 0
        let rawVelY: Float = dt > 0 ? (py - prevPy) / dt : 0
        let mouseSpeed = min((rawVelX * rawVelX + rawVelY * rawVelY).squareRoot(), 2)
        prevPx = px; prevPy = py
        if mouseSpeed > 0.01 { simSinceActive = 0 } else { simSinceActive += dt }
        animT += dt * GridKit.num(ctx, "speed", 0.5) // speed = 0 pauses
        let waveSettled = !cursorEnabled || (simSinceActive * 1000 > Self.waveSettleMs && mouseSpeed < 0.01)
        let cursorActive: Float = waveSettled ? 0 : 1

        // writeParams
        let aspect = Float(max(1, ctx.width)) / Float(max(1, ctx.height))
        let deg = Float.pi / 180
        let tilt = GridKit.num(ctx, "tilt", 35) * deg
        let roll = GridKit.num(ctx, "roll", 0) * deg
        let camHeight = GridKit.num(ctx, "height", 0)
        let zoom = GridKit.num(ctx, "zoom", 1)
        let cam = Self.orbitCamera(tilt: tilt, roll: roll, height: camHeight, zoom: zoom)
        // Cursor → z = 0 plane world UV → wave-grid UV.
        let cNdcX = (px - 0.5) * 2 * aspect
        let cNdcY = -(py - 0.5) * 2
        let rd = Self.norm3(cam.fwd * cam.focal + cam.right * cNdcX + cam.up * cNdcY)
        let cT0 = cam.pos.z / max(-rd.z, 0.001)
        let cursorWorldU = (cam.pos.x + rd.x * cT0) * 0.5 + 0.5
        let cursorWorldV = (cam.pos.y + rd.y * cT0) * 0.5 + 0.5
        let lc = GridKit.uniformFloats(ctx, "n_x.lightColor", count: 3) ?? [1, 1, 1]

        let amp = GridKit.num(ctx, "amplitude", 0.3)
        let cursorIntensity = GridKit.num(ctx, "cursorIntensity", 1)
        let freq = GridKit.num(ctx, "frequency", 1.5)
        let seed = GridKit.num(ctx, "seed", 0)
        let edgePin = GridKit.num(ctx, "edgePinning", 0)
        let lighting = GridKit.num(ctx, "lighting", 30) * 0.035
        let glossiness = GridKit.num(ctx, "glossiness", 0) * 0.01
        let highlights = GridKit.num(ctx, "highlights", 15) * 0.04
        let lightX = GridKit.num(ctx, "lightX", 0.4)
        let lightY = GridKit.num(ctx, "lightY", -0.6)
        let lightZ = GridKit.num(ctx, "lightZ", 0.7)
        let nearCutoff = GridKit.num(ctx, "nearCutoff", 0)
        let farCutoff = GridKit.num(ctx, "farCutoff", 1)
        let waveSpeed = GridKit.num(ctx, "cursorSpeed", 0.5)
        let cursorWaveX = (cursorWorldU - 0.5) / Self.waveHalfExtent + 0.5
        let cursorWaveY = (cursorWorldV - 0.5) / Self.waveHalfExtent + 0.5
        // |z| the surface can reach: base wave + the live ripple budget (dropped once settled).
        let heightEnvelope = amp + Self.heightSlabPad + (cursorActive > 0 ? cursorIntensity * 0.05 * Self.cursorWaveBound : 0)

        let params = GridKit.pack(layout, [
            "amp": [amp], "freq": [freq], "seed": [seed], "edgePin": [edgePin], "cursorIntensity": [cursorIntensity],
            "t": [animT], "aspect": [aspect], "focal": [cam.focal],
            "camPos": [cam.pos.x, cam.pos.y, cam.pos.z], "camForward": [cam.fwd.x, cam.fwd.y, cam.fwd.z],
            "camRight": [cam.right.x, cam.right.y, cam.right.z], "camUp": [cam.up.x, cam.up.y, cam.up.z],
            "lighting": [lighting], "glossiness": [glossiness], "highlights": [highlights],
            "lightX": [lightX], "lightY": [lightY], "lightZ": [lightZ], "lightColor": Array(lc.prefix(3)),
            "nearCutoff": [nearCutoff], "farCutoff": [farCutoff],
            "cursorWaveX": [cursorWaveX], "cursorWaveY": [cursorWaveY], "mouseSpeed": [mouseSpeed],
            "dt": [0.016], "decay": [Self.waveDecay], "radius": [0.025], "waveSpeed": [waveSpeed],
            "heightEnvelope": [heightEnvelope], "cursorActive": [cursorActive],
        ])
        let sig: [Float] = [amp, freq, seed, edgePin, cursorIntensity, animT, aspect, tilt, roll, camHeight, zoom,
                            lighting, glossiness, highlights, lightX, lightY, lightZ] + lc +
                           [nearCutoff, farCutoff, cursorWaveX, cursorWaveY, mouseSpeed, waveSpeed, heightEnvelope, cursorActive]
        // Identical params over a settled field reproduce the previous frame exactly.
        if waveSettled && sig == lastSig { return out }
        lastSig = sig

        let kctx = GridKit.with(ctx, library: library)
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "Surface3D"
        if !waveSettled {
            let read = wave.read, write = wave.write
            try kctx.dispatch(enc, propagate, threads: SIMD3(UInt32(Self.waveGrid), UInt32(Self.waveGrid), 1)) { e in
                GridKit.setBuffer(e, propagate, "readSrc", read)
                GridKit.setBuffer(e, propagate, "writeBuf", write)
                GridKit.setBuffer(e, propagate, "readBuf", readBuf)
                GridKit.setUniform(e, propagate, params)
            }
            wave.swap()
        }
        try kctx.dispatch(enc, march, threads: SIMD3(UInt32(computeW), UInt32(computeH), 1)) { e in
            GridKit.setBuffer(e, march, "readBuf", readBuf)
            GridKit.setUniform(e, march, params)
            GridKit.setTexture(e, march, "uvMaskTex", uvMaskTex)
            GridKit.setTexture(e, march, "litTex", litTex)
        }
        return out
    }
}
#endif
