#if canImport(Metal)
import Foundation
import Metal

extension FluidsFamilyProgram {
    /// SmokeFill's container: confines the fluid to the shape. Port of upstream
    /// `shapeContainerField` (shaders/SmokeFill) on its volumetric route:
    /// `createVolumetricFieldComputeNode` + `createAnalytic3dSdfSetup` (kit/sdf3d.ts).
    ///
    /// The generated march kernel bakes `sdSphere(p, pA)` (the default `sphere3D` shape), and the
    /// generated variants only carry the volumetric mask and fragment sampler. So every shape is
    /// marched as a sphere: `pA` is the shape's `radius` sub-prop (auto-animate and mouse drivers
    /// included). Other 3D types, flat shapes and SVG shapes are approximated by that sphere.
    final class ShapeContainer {
        /// The field texture's aspect-fit domain (upstream `getFieldDomain`, the `_vf*` extra fields).
        struct Domain {
            var originX = 0.0
            var originY = 0.0
            var spanX = 1.0
            var spanY = 1.0
            var activeRes = 1.0
            var rBound = 0.6
        }

        private struct MarchKey: Equatable {
            var pA: Double
            var rBound: Double
            var rot: [Double]
            var activeRes: Int
        }

        let marchKernel: Int
        let maskKernel: Int
        let field: MTLTexture
        private(set) var domain = Domain()

        private let maxRes: Int
        private let mobile: Bool
        private var activeRes: Int
        private var lastKey: MarchKey?
        private var changedFrames = 0
        // Shape setup state.
        private var elapsed = 0.0
        private var lastShapeJson = ""
        private var lastCfg: [String: Any] = [:]
        private var springs: [String: (current: Double, velocity: Double)] = [:]
        // `makeSubPropResolver` parses on its own (an unparsable shape falls back to defaults).
        private var subJson = ""
        private var subCfg: [String: Any] = [:]

        /// Upstream `VOLUMETRIC_FIELD_RES` / `VOLUMETRIC_FIELD_RES_MOBILE`.
        private static let fieldRes = 1536
        private static let fieldResMobile = 768
        private static let activeResBuckets = [256, 320, 384, 512, 640, 768, 896, 1024, 1280, 1536]
        /// `SHAPE3D_DEFAULTS.sphere3D`.
        private static let sphereDefaults: [String: Double] = ["radius": 0.35, "rotX": 0, "rotY": 0, "rotZ": 0]

        init(_ ctx: ComputeContext, marchKernel: Int, maskKernel: Int) throws {
            self.marchKernel = marchKernel
            self.maskKernel = maskKernel
            #if os(iOS)
            mobile = true // upstream `isMobileGpuViewport` (coarse pointer)
            #else
            mobile = false
            #endif
            maxRes = mobile ? Self.fieldResMobile : Self.fieldRes
            activeRes = maxRes
            guard let tex = ctx.makeTexture(width: maxRes, height: maxRes, format: .rgba32Float, label: "SmokeFill volumetric field") else {
                throw ShaderEngineError.noMetalDevice
            }
            field = tex
        }

        var outputs: [String: MTLTexture] { ["compute_0": field] }

        var extraFields: [String: [Float]] {
            [
                "_vfOriginX": [Float(domain.originX)],
                "_vfOriginY": [Float(domain.originY)],
                "_vfSpanX": [Float(domain.spanX)],
                "_vfSpanY": [Float(domain.spanY)],
                "_vfActiveRes": [Float(domain.activeRes)],
                "_vfRBound": [Float(domain.rBound)],
            ]
        }

        private static func parseShape(_ raw: String) -> [String: Any]? {
            guard let data = raw.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }

        private static func number(_ v: Any?) -> Double? {
            guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
            return n.doubleValue
        }

        /// Upstream `makeSubPropResolver` (SmokeFill): the analytic SDF sub-props for `FillParams`.
        func analyticSubProps(_ f: Frame) -> Values {
            let raw = f.ctx.props["shape"]?.stringValue ?? ""
            if raw != subJson {
                subJson = raw
                subCfg = Self.parseShape(raw) ?? [:]
            }
            let c = subCfg
            func num(_ keys: [String], _ fallback: Double) -> Double {
                for k in keys { if let v = Self.number(c[k]) { return v } }
                return fallback
            }
            return [
                "saRadius": num(["radius", "width", "bottomWidth"], 0.35),
                "saSides": num(["sides"], 6),
                "saRounding": num(["rounding"], 0),
                "saInnerRatio": num(["innerRatio", "thickness", "spread", "topWidth", "topRatio"], 0.4),
                "saRotation": num(["rotation"], 0),
                "saHeight": num(["height"], 0.25),
                "saOffset": num(["offset", "skew"], 0.2),
                "saAperture": num(["aperture"], 270),
            ]
        }

        /// Runs ahead of the fluid every frame: resolves the shape, picks the active resolution and
        /// re-marches the field only when its state key changes.
        func preFrame(_ pass: Pass) throws {
            let ctx = pass.ctx
            let deltaTime = Double(ctx.frame.deltaTime)
            elapsed += deltaTime
            if let raw = ctx.props["shape"]?.stringValue, raw != lastShapeJson {
                lastShapeJson = raw
                if let cfg = Self.parseShape(raw) { lastCfg = cfg }
            }
            func sub(_ key: String) -> Double {
                resolveSubProp(lastCfg[key], Self.sphereDefaults[key] ?? 0, key: key, deltaTime: deltaTime, pointer: pass.pointer)
            }
            let pA = sub("radius")
            // `shape3dBoundingRadius` for a sphere + 0.02.
            let rBound = Self.subPropMax(lastCfg["radius"], 0.35) + 0.02
            let deg = Double.pi / 180
            let rx = sub("rotX") * deg, ry = sub("rotY") * deg, rz = sub("rotZ") * deg
            let rot = [cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)]
            // Aspect-fit domain (isotropic for analytic primitives).
            let rPad = rBound + 0.05
            let span = rPad * 2
            let origin = 0.5 - rPad

            let scale: Double
            if case .number(let s)? = ctx.props["scale"] { scale = Double(s) } else { scale = 1 }
            activeRes = resolveActiveRes(span: span, scale: scale, canvasHeight: Double(ctx.height))
            let key = MarchKey(pA: pA, rBound: rBound, rot: rot, activeRes: activeRes)
            if key == lastKey { return }
            changedFrames += 1
            // Mobile re-march throttle: march every 2nd changed frame.
            if mobile && changedFrames % 2 != 0 { return }
            lastKey = key
            domain = Domain(originX: origin, originY: origin, spanX: span, spanY: span, activeRes: Double(activeRes), rBound: rBound)

            var march: [String: [Double]] = [
                "rot.cx": [rot[0]], "rot.sx": [rot[1]], "rot.cy": [rot[2]], "rot.sy": [rot[3]], "rot.cz": [rot[4]], "rot.sz": [rot[5]],
                "rBound": [rBound], "spanX": [span], "spanY": [span], "originX": [origin], "originY": [origin],
                "activeRes": [Double(activeRes)],
                "pA": [pA], "pB": [0.3], "pC": [0.3], "pD": [0],
            ]
            for i in 0..<8 { march["mb\(i)"] = [0, 0, 0] }
            pass.write("params", vectors: march)
            try pass.dispatch(marchKernel, width: activeRes, height: activeRes)
        }

        /// Upstream `resolveActiveFieldRes`: one field texel per device pixel along the shape's
        /// footprint, snapped up to a bucket, with a shrink deadband.
        private func resolveActiveRes(span: Double, scale: Double, canvasHeight: Double) -> Int {
            guard canvasHeight > 0, scale > 0 else { return maxRes }
            let targetPx = span * scale * canvasHeight * (mobile ? 0.5 : 1)
            var res = maxRes
            for b in Self.activeResBuckets {
                if b > maxRes { break }
                if Double(b) >= targetPx { res = b; break }
            }
            if activeRes > 0 && res < activeRes && targetPx > Double(activeRes) * 0.78 { res = min(activeRes, maxRes) }
            return res
        }

        /// Upstream `shapeSubPropMax`.
        private static func subPropMax(_ value: Any?, _ fallback: Double) -> Double {
            if let n = number(value) { return n }
            if let d = value as? [String: Any], let type = d["type"] as? String, type == "auto-animate" || type == "mouse" {
                return max(number(d["outputMin"]) ?? fallback, number(d["outputMax"]) ?? fallback)
            }
            return fallback
        }

        /// Upstream `resolveShapeSubProp`: a number, an auto-animate config or a mouse config.
        private func resolveSubProp(_ value: Any?, _ fallback: Double, key: String, deltaTime: Double, pointer: PointerSample) -> Double {
            if let n = Self.number(value) { return n }
            guard let d = value as? [String: Any], let type = d["type"] as? String else { return fallback }
            let oMin = Self.number(d["outputMin"]) ?? fallback
            let oMax = Self.number(d["outputMax"]) ?? fallback
            switch type {
            case "auto-animate":
                let globalT = elapsed * (Self.number(d["speed"]) ?? 1) * 0.2
                let t01 = (globalT.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                let t = (d["mode"] as? String) == "loop" ? t01 : (t01 < 0.5 ? t01 * 2 : (1 - t01) * 2)
                let easing = (d["easing"] as? String) ?? (d["waveform"] as? String) ?? "sine"
                return oMin + Self.applyEasing(t, easing) * (oMax - oMin)
            case "mouse":
                let target = (d["axis"] as? String) == "y" ? pointer.y : pointer.x
                var st = springs[key] ?? (current: target, velocity: 0)
                let (np, nv) = Self.applySpring(st.current, st.velocity, target, smoothing: Self.number(d["smoothing"]) ?? 0, momentum: Self.number(d["momentum"]) ?? 0, dt: deltaTime)
                st = (np, nv)
                springs[key] = st
                let smoothed = max(0.001, np)
                let exponent = pow(2, -(Self.number(d["curve"]) ?? 0) * 2)
                return oMin + pow(smoothed, exponent) * (oMax - oMin)
            default:
                return fallback
            }
        }

        /// Upstream `applyEasing` (kit/sdf3d).
        private static func applyEasing(_ t: Double, _ easing: String) -> Double {
            switch easing {
            case "linear": return t
            case "quad": return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            case "expo":
                if t == 0 { return 0 }
                if t == 1 { return 1 }
                return t < 0.5 ? pow(2, 20 * t - 10) / 2 : (2 - pow(2, -20 * t + 10)) / 2
            case "bounce":
                let n1 = 7.5625, d1 = 2.75
                var x = t
                if x < 1 / d1 { return n1 * x * x }
                if x < 2 / d1 { x -= 1.5 / d1; return n1 * x * x + 0.75 }
                if x < 2.5 / d1 { x -= 2.25 / d1; return n1 * x * x + 0.9375 }
                x -= 2.625 / d1
                return n1 * x * x + 0.984375
            default: return (1 - cos(Double.pi * t)) / 2
            }
        }

        /// Upstream `applySpring` (gpu/frame.ts).
        private static func applySpring(_ current: Double, _ velocity: Double, _ target: Double, smoothing: Double, momentum: Double, dt: Double) -> (Double, Double) {
            if smoothing == 0 && momentum == 0 { return (target, 0) }
            let stiffness = 200 * pow(0.01, smoothing)
            let damping = 2 * stiffness.squareRoot() * (1 - momentum * 0.85)
            let maxSubstep = 1.0 / 60
            let steps = dt > maxSubstep ? Int((dt / maxSubstep).rounded(.up)) : 1
            let h = dt / Double(steps)
            var pos = current
            var vel = velocity
            for _ in 0..<steps {
                vel += (stiffness * (target - pos) - damping * vel) * h
                pos += vel * h
            }
            return (pos, vel)
        }
    }
}
#endif
