#if canImport(Metal)
import Foundation

// Each shader's own parts, ported from its upstream `shaders/<Name>/index.ts` `fluidSim(...)` call.
// Kernel indices follow the generated `<Name>_k<N>` entries (see the descriptor `compute` block).

extension FluidsFamilyProgram {
    static func config(for name: String, _ ctx: ComputeContext) throws -> Config {
        switch name {
        case "Smoke": return smoke()
        case "SmokeFlow": return smokeFlow()
        case "InkFlow": return inkFlow()
        case "Fog": return fog()
        case "SmokeFill": return try smokeFill(ctx)
        default: throw ShaderEngineError.unknownShader(name)
        }
    }

    /// Cursor-shove fields shared by Smoke, Fog and SmokeFill (`FluidCursorForceParams`).
    private static func cursorValues(_ f: Frame, mouseInfluence: Double, mouseRadius: Double) -> Values {
        let n = Double(Self.n)
        let ptr = f.ptr!
        let active = ptr.moving && mouseInfluence > 0
        let mouseRadGrid = mouseRadius * n
        return [
            "cursorX": active ? ptr.x * n : 0,
            "cursorY": active ? ptr.y * n : 0,
            "cursorVelX": active ? ptr.dx * n * 15 * mouseInfluence : 0,
            "cursorVelY": active ? ptr.dy * n * 15 * mouseInfluence : 0,
            "mouseActive": active ? 1 : 0,
            "mouseRadSq": mouseRadGrid * mouseRadGrid,
        ]
    }

    // MARK: - Smoke

    /// Kernels: 0 cone-emitter splat, 1…9 solver, 10 output.
    private static func smoke() -> Config {
        let n = Double(Self.n)
        return Config(solverBase: 1, outputKernel: 10, pointer: .init(minDrag: 0.0005), inject: [Splat(kernel: 0)]) { f in
            let speed = f.num("speed", 3.0)
            let dirRad = f.num("direction", 0) * .pi / 180
            let spreadHalf = min(89 * .pi / 180, f.num("spread", 45) * .pi / 360)
            // `emitFrom` post-transform: y is already flipped (1 - authored y).
            let emitPos = f.uniformVector("emitFrom")
            let epx = emitPos?[0] ?? 0.5
            let epy = emitPos?[1] ?? 0.0
            let velMag = speed * n * 0.15
            var v: Values = [
                "dt": f.dt,
                "emitX": epx * n,
                "emitY": (1 - epy) * n,
                "emitVelX": sin(dirRad) * velMag,
                "emitVelY": -cos(dirRad) * velMag,
                "perpDirX": cos(dirRad),
                "perpDirY": sin(dirRad),
                "spreadFactor": tan(spreadHalf),
                "emitRad": f.num("emitRadius", 0.06) * n,
                "emitIntensity": f.num("intensity", 0.7),
                "dyeFade": f.num("dissipation", 1.0),
                "velFade": 0.2,
                "curlStrength": f.num("detail", 30.0),
                "gravity": f.num("gravity", 0.5),
                "colorDecay": f.num("colorDecay", 1.0),
            ]
            v.merge(cursorValues(f, mouseInfluence: f.num("mouseInfluence", 0.5), mouseRadius: f.num("mouseRadius", 0.12))) { $1 }
            return v
        }
    }

    // MARK: - SmokeFlow

    /// Kernels: 0 gated-puff splat, 1…9 solver, 10 output.
    private static func smokeFlow() -> Config {
        let n = Double(Self.n)
        // The emission gate is the smoothed speed squared: a slow graze emits a wisp, a flick a full puff.
        let speedGateOf = { (smoothSpeed: Double) in min(smoothSpeed * smoothSpeed * 60, 1.0) }
        let strokes = CursorRibbon(
            // Teleport guard disabled: a fast flick must emit.
            tracker: .init(teleportGuard: .infinity),
            kernel: 0,
            activeWhen: { ptr, _ in speedGateOf(ptr.smoothSpeed) > 0.005 },
            fadeSeconds: { f in decayFadeSeconds(255, f.num("dissipation", 0.4)) },
            ribbon: { f, _, values in
                RibbonSpec(stepSize: max(0.004, f.num("emitRadius", 0.07) * 0.5), maxSteps: 16) { pass, emitX, emitY, _ in
                    var v = values
                    v["emitX"] = emitX
                    v["emitY"] = emitY
                    pass.write("params", v)
                }
            }
        )
        return Config(solverBase: 1, outputKernel: 10, inject: [strokes]) { f in
            let ptr = strokes.ptr!
            let momentumScale = f.num("momentum", 1.2)
            let speedGate = speedGateOf(ptr.smoothSpeed)
            return [
                "dt": f.dt,
                "emitX": ptr.x * n,
                "emitY": ptr.y * n,
                "emitGate": strokes.active ? speedGate : 0,
                "emitVelX": ptr.smoothVelX * n * momentumScale * 0.12,
                "emitVelY": ptr.smoothVelY * n * momentumScale * 0.12,
                "emitRad": f.num("emitRadius", 0.07) * n,
                "emitIntensity": f.num("intensity", 1.2),
                "dyeFade": f.num("dissipation", 0.4),
                "velFade": 0.2,
                "curlStrength": f.num("detail", 28.0),
                "gravity": f.num("gravity", -0.3),
                "colorDecay": f.num("colorDecay", 0.5),
            ]
        }
    }

    // MARK: - InkFlow

    private static func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Upstream `hueToLinearRgb`: an HSV hue at full saturation/value, linearised.
    static func hueToLinearRgb(_ hue: Double) -> SIMD3<Double> {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let i = Int((h * 6).rounded(.down))
        let f = h * 6 - Double(i)
        let q = 1 - f
        let rgb: SIMD3<Double>
        switch i {
        case 0: rgb = SIMD3(1, f, 0)
        case 1: rgb = SIMD3(q, 1, 0)
        case 2: rgb = SIMD3(0, 1, f)
        case 3: rgb = SIMD3(0, q, 1)
        case 4: rgb = SIMD3(f, 0, 1)
        default: rgb = SIMD3(1, 0, q)
        }
        return SIMD3(srgbToLinear(rgb.x), srgbToLinear(rgb.y), srgbToLinear(rgb.z))
    }

    /// Kernels: 0 brush splat (`sparams`), 1…9 solver, 10 output.
    private static func inkFlow() -> Config {
        let n = Double(Self.n)
        let impulseK = 0.16
        let cyclePerSplat = 0.006
        let cycleTimeRate = 0.06
        // The generated splat kernel is upstream's colorSpace-0 variant (`inkFlowSplat0`, linear
        // mixing), so the brush endpoints are preconverted for mode 0 to match it.
        let spaceMode = 0
        var hueCursor = 0.0

        // A color prop as the uniform block holds it (upstream `getCpuValue` → transformColor).
        func rgb(_ f: Frame, _ prop: String, _ fallback: SIMD3<Double>) -> SIMD3<Double> {
            guard let c = f.uniformVector(prop), c.count >= 3 else { return fallback }
            return SIMD3(c[0], c[1], c[2])
        }
        func conv(_ c: SIMD3<Double>) -> SIMD3<Double> {
            SIMD3<Double>(ColorMath.convertP3ToMixSpaceCPU(r: Float(c.x), g: Float(c.y), b: Float(c.z), mode: spaceMode))
        }

        let strokes = CursorRibbon(
            kernel: 0,
            activeWhen: { ptr, _ in ptr.moving },
            // Idle-skip once the ink has decayed after the last stroke.
            fadeSeconds: { f in decayFadeSeconds(64, f.num("decay", 0.5)) },
            // The color cycle drifts with time even between strokes.
            onFrame: { f, _ in hueCursor += f.dt * cycleTimeRate * f.num("colorSpeed", 1) },
            ribbon: { f, ptr, _ in
                let force = f.num("force", 1)
                // radius is a 10× UI scale: radius 1 is 10% of the field width.
                let radiusGrid = max(f.num("radius", 0.3) * 0.1 * n, 1)
                let colorSpeed = f.num("colorSpeed", 1)
                let mode = f.string("colorMode").flatMap { $0.isEmpty ? nil : $0 } ?? "rainbow"
                let customStops: [SIMD3<Double>]? = mode == "custom" ? [
                    conv(rgb(f, "color1", SIMD3(0.26, 0.22, 1))),
                    conv(rgb(f, "color2", SIMD3(1, 0.18, 0.49))),
                    conv(rgb(f, "color3", SIMD3(0.1, 0.89, 1))),
                ] : nil

                // Each splat advances the color cycle and resolves two working-space endpoints plus
                // a mix position (custom runs the closed loop c1 → c2 → c3 → c1).
                func brushSplat() -> (a: SIMD3<Double>, b: SIMD3<Double>, t: Double) {
                    hueCursor += cyclePerSplat * colorSpeed
                    if let stops = customStops {
                        let h = (hueCursor.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                        let seg = min(2, Int((h * 3).rounded(.down)))
                        return (stops[seg], stops[(seg + 1) % 3], h * 3 - Double(seg))
                    }
                    if mode == "single" {
                        let c = conv(rgb(f, "color", SIMD3(1, 0.18, 0.49)))
                        return (c, c, 0)
                    }
                    let c = conv(hueToLinearRgb(hueCursor))
                    return (c, c, 0)
                }

                let velX = ptr.velX * n * force * impulseK
                let velY = ptr.velY * n * force * impulseK
                return RibbonSpec(stepSize: max(0.004, (radiusGrid / n) * 0.6), maxSteps: 16) { pass, posX, posY, _ in
                    let bc = brushSplat()
                    pass.write("sparams", [
                        "posX": posX, "posY": posY, "velX": velX, "velY": velY,
                        "colR": bc.a.x, "colG": bc.a.y, "colB": bc.a.z,
                        "col2R": bc.b.x, "col2G": bc.b.y, "col2B": bc.b.z, "mixT": bc.t,
                        "radius": radiusGrid, "strength": 1,
                    ])
                }
            }
        )

        return Config(solverBase: 1, outputKernel: 10, inject: [strokes]) { f in
            let momentum = min(max(f.num("momentum", 0.6), 0), 1)
            return [
                "dt": f.dt,
                "curlStrength": f.num("curl", 0),
                // Momentum maps exponentially onto velocity fade: 0 → 4 (dies fast), 1 → 0.05.
                "velFade": 4 * pow(0.05 / 4, momentum),
                "dyeFade": f.num("decay", 0.5),
            ]
        }
    }

    // MARK: - Fog

    /// Kernels: 0 noise-field init, 1 turbulence force (pre-solve), 2 color restore (post-solve),
    /// 3…11 toroidal solver, 12 output.
    private static func fog() -> Config {
        // The warm-up and the per-frame write share this params shape; only dt/time/cursor differ.
        func fieldValues(_ f: Frame) -> Values {
            [
                "seed": f.num("seed", 0),
                "turbulence": f.num("turbulence", 1.0),
                "curlStrength": f.num("detail", 15.0),
                "velFade": 0.15,
                "blending": f.num("blending", 0.3),
            ]
        }
        let initPart = SeededFieldInit(
            kernel: 0,
            seed: { $0.num("seed", 0) },
            warmSteps: 50, warmJacobiIters: 6, warmDt: 0.1,
            startTime: { Double.random(in: 0..<60) },
            values: { t, f in
                fieldValues(f).merging([
                    "dt": 0.1, "time": t,
                    "cursorX": 0, "cursorY": 0, "cursorVelX": 0, "cursorVelY": 0, "mouseActive": 0, "mouseRadSq": 1,
                ]) { $1 }
            }
        )
        return Config(solverBase: 3, outputKernel: 12, pointer: .init(minDrag: 0.0005), initPart: initPart, solvePre: [1], solvePost: [2]) { f in
            let mouseInf = f.num("mouseInfluence", 0.1)
            var v = fieldValues(f)
            v["dt"] = f.dt * f.num("speed", 1.0)
            v["time"] = f.elapsed
            v.merge(cursorValues(f, mouseInfluence: mouseInf, mouseRadius: f.num("mouseRadius", 0.1))) { $1 }
            return v
        }
    }

    // MARK: - SmokeFill

    /// Kernels: 0 volumetric field march, 1 field mask, 2 masked cone splat, 3…11 masked solver,
    /// 12 output. The field texture is `compute_0`, the smoke `compute_1`.
    private static func smokeFill(_ ctx: ComputeContext) throws -> Config {
        let n = Double(Self.n)
        let container = try ShapeContainer(ctx, marchKernel: 0, maskKernel: 1)
        return Config(solverBase: 3, outputKernel: 12, outputKey: "compute_1", paramsUniform: "params_2",
                      pointer: .init(minDrag: 0.0005), container: container, inject: [Splat(kernel: 2)]) { f in
            let speed = f.num("speed", 2.0)
            let dirRad = f.num("direction", 0) * .pi / 180
            let spreadHalf = min(89 * .pi / 180, f.num("spread", 60) * .pi / 360)
            let centerView = f.uniformVector("center")
            let emitView = f.uniformVector("emitFrom")
            let h = Double(f.ctx.height)
            let aspect = h > 0 ? Double(f.ctx.width) / h : 1
            let velMag = speed * n * 0.15
            // Read after the container's pre-march, so the domain matches the field's contents.
            let dom = container.domain
            var v: Values = [
                "dt": f.dt,
                "emitX": (emitView?[0] ?? 0.5) * n,
                "emitY": (1 - (emitView?[1] ?? 0.5)) * n,
                "emitVelX": sin(dirRad) * velMag,
                "emitVelY": -cos(dirRad) * velMag,
                "perpDirX": cos(dirRad),
                "perpDirY": sin(dirRad),
                "spreadFactor": tan(spreadHalf),
                "emitRad": f.num("emitRadius", 0.03) * n,
                "emitIntensity": f.num("intensity", 0.8),
                "dyeFade": f.num("dissipation", 0.5),
                "velFade": 0.2,
                "curlStrength": f.num("detail", 30.0),
                "gravity": f.num("gravity", 0.5),
                "colorDecay": f.num("colorDecay", 1.0),
                "centerX": centerView?[0] ?? 0.5,
                "centerY": 1 - (centerView?[1] ?? 0.5),
                "scale": f.num("scale", 1.0),
                "rotation": f.num("rotation", 0) * .pi / 180,
                "aspect": aspect,
                "vfOriginX": dom.originX,
                "vfOriginY": dom.originY,
                "vfSpanX": dom.spanX,
                "vfSpanY": dom.spanY,
                "vfActiveRes": dom.activeRes,
            ]
            v.merge(cursorValues(f, mouseInfluence: f.num("mouseInfluence", 0.5), mouseRadius: f.num("mouseRadius", 0.12))) { $1 }
            v.merge(container.analyticSubProps(f)) { $1 }
            return v
        }
    }
}
#endif
