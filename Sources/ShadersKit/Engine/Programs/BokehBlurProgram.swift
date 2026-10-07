#if canImport(Metal)
import Foundation
import Metal
import simd

/// CPU aperture tap table (upstream kit/blur.ts `generateBokehTaps` and its SDF mirrors).
/// Computed in Double like the JS original, then uploaded as Float.
enum BokehTaps {
    struct Tap: Equatable { var x: Double; var y: Double; var rim: Double }

    static let tapCount = 100
    private static let goldenAngle = Double.pi * (3 - 5.0.squareRoot())
    private static let twoPi = Double.pi * 2
    private static let edgeBoost = 0.6
    private static let edgePower = 8.0
    private static let rimBand = 0.25
    private static let sqrt2Over4 = 2.0.squareRoot() / 4

    /// JS `Math.round` (halves round toward +∞).
    private static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
    /// JS `Math.sign` (0 for 0).
    private static func jsSign(_ x: Double) -> Double { x > 0 ? 1 : (x < 0 ? -1 : 0) }

    private static func resolvePoints(_ bladeCount: Double) -> Double {
        let n = jsRound(bladeCount)
        return n >= 3 ? n : 5
    }

    static func polygonRadius(_ theta: Double, _ sides: Double) -> Double {
        if sides < 3 { return 1 }
        let a = twoPi / sides
        let m = theta - a * (theta / a + 0.5).rounded(.down)
        return cos(a * 0.5) / cos(m)
    }

    private static func sdfHeart(_ dx: Double, _ dy: Double) -> Double {
        let s = 1 / 0.75
        let px = abs(dx) / s
        let py = -dy / s + 0.6
        if px + py > 1 {
            return (hypot(px - 0.25, py - 0.75) - sqrt2Over4) * s
        }
        let b1y = py - 1
        let dot1 = px * px + b1y * b1y
        let m = max(px + py, 0) * 0.5
        let b2x = px - m
        let b2y = py - m
        return min(dot1, b2x * b2x + b2y * b2y).squareRoot() * jsSign(px - py) * s
    }

    private static func sdfStar(_ dx: Double, _ dy: Double, _ sides: Double, _ innerRatio: Double) -> Double {
        let len = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let sector = twoPi / sides
        let idx = (angle / sector + 0.5).rounded(.down)
        let bn = angle - idx * sector
        let fpx = abs(len * sin(bn))
        let fpy = len * cos(bn)
        let an = Double.pi / sides
        let ex = innerRatio * sin(an)
        let ey = innerRatio * cos(an) - 1
        let qx = fpx
        let qy = fpy - 1
        let t = min(max((qx * ex + qy * ey) / (ex * ex + ey * ey), 0), 1)
        let nx = fpx - ex * t
        let ny = fpy - (1 + ey * t)
        return hypot(nx, ny) * jsSign(ex * qy - ey * qx)
    }

    private static func sdfFlower(_ dx: Double, _ dy: Double, _ sides: Double, _ innerRatio: Double) -> Double {
        let angle = atan2(dy, dx)
        let len = hypot(dx, dy)
        let tAngle = angle * sides / twoPi
        let tFrac = tAngle - tAngle.rounded(.down)
        let t = abs(tFrac * 2 - 1)
        return len - (innerRatio + (1 - innerRatio) * t)
    }

    private static func sdfCross(_ dx: Double, _ dy: Double) -> Double {
        let px = abs(dx), py = abs(dy)
        let dHoriz = max(px - 0.92, py - 0.3)
        let dVert = max(py - 0.92, px - 0.3)
        return min(dHoriz, dVert) - 0.08
    }

    private static func sdfRing(_ dx: Double, _ dy: Double) -> Double {
        abs(hypot(dx, dy) - 0.72) - 0.28
    }

    private static func halton(_ index: Int, _ base: Int) -> Double {
        var f = 1.0, r = 0.0, i = index
        while i > 0 {
            f /= Double(base)
            r += f * Double(i % base)
            i /= base
        }
        return r
    }

    /// Upstream `APERTURE_SDF_SHAPES` (star/flower tips rotated to point up via `toTipUp`).
    private static func shapeSDF(_ shape: String) -> ((Double, Double, Double) -> Double)? {
        switch shape {
        case "star": return { x, y, p in sdfStar(-y, x, p, 0.5) }
        case "flower": return { x, y, p in sdfFlower(-y, x, p, 0.55) }
        case "heart": return { x, y, _ in sdfHeart(x, y) }
        case "cross": return { x, y, _ in sdfCross(x, y) }
        case "ring": return { x, y, _ in sdfRing(x, y) }
        default: return nil
        }
    }

    static func generate(shape: String, bladeCount: Double, tapCount: Int = tapCount) -> [Tap] {
        var taps: [Tap] = []
        guard let sdf = shapeSDF(shape) else {
            // 'blades' / 'circle' (and any unknown value): Vogel spiral warped by the polygon radius.
            let sides = shape == "circle" ? 0 : bladeCount
            for i in 0..<tapCount {
                let t = (Double(i) + 0.5) / Double(tapCount)
                let rNorm = t.squareRoot()
                let theta = Double(i) * goldenAngle
                let r = rNorm * polygonRadius(theta, sides)
                taps.append(Tap(x: -cos(theta) * r, y: -sin(theta) * r, rim: 1 + edgeBoost * pow(rNorm, edgePower)))
            }
            return taps
        }
        let points = resolvePoints(bladeCount)
        var idx = 1
        while taps.count < tapCount && idx <= 20000 {
            let x = halton(idx, 2) * 2 - 1
            let y = halton(idx, 3) * 2 - 1
            idx += 1
            let dist = sdf(x, y, points)
            if dist > 0 { continue }
            let prox = min(max(1 + dist / rimBand, 0), 1)
            taps.append(Tap(x: -x, y: -y, rim: 1 + edgeBoost * prox * prox))
        }
        if taps.isEmpty { return generate(shape: "circle", bladeCount: 0, tapCount: tapCount) }
        var i = 0
        while taps.count < tapCount { taps.append(taps[i % taps.count]); i += 1 }
        let maxLen = taps.reduce(0) { max($0, hypot($1.x, $1.y)) }
        if maxLen > 1 {
            let inv = 1 / maxLen
            for k in taps.indices { taps[k].x *= inv; taps[k].y *= inv }
        }
        return taps
    }
}

/// Port of upstream `bokehDefocus` (std/effects/blurs, static-radius path): one scatter-as-gather
/// pass over the CPU aperture tap table. The tap uniform is rewritten only when (shape, blades)
/// changes. Publishes the premultiplied defocused buffer as `compute_0`.
///
/// Upstream sizes the gather grid to the canvas aspect; the generated kernel fixes it at the
/// recorded size (1024×768). The gather works in input pixels, so discs stay round either way.
final class BokehBlurProgram: ComputeProgram {
    static let shaderNames = ["BokehBlur"]
    private static let radiusScale: Float = 0.8
    private static let degToRad: Float = .pi / 180

    private let kernel: ComputeKernelDescriptor
    private let layout: UniformLayout
    private let params: MTLBuffer
    private let taps: MTLBuffer
    private let output: MTLTexture
    private let computeWidth: Int
    private let computeHeight: Int
    private var tapKey = ""

    init(context ctx: ComputeContext) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute") }
        kernel = try BlurKit.kernel(info, binding: "output", shader: name)
        layout = try BlurKit.uniformLayout(info, kernel, shader: name)
        let size = BlurKit.computeSize(info, default: (1024, 768))
        computeWidth = size.width
        computeHeight = size.height
        output = try BlurKit.makeTexture(ctx, size.width, size.height, .rgba16Float, "\(name) gather")
        params = try BlurKit.makeBuffer(ctx, layout.size, "\(name) params")
        taps = try BlurKit.makeBuffer(ctx, BokehTaps.tapCount * 16, "\(name) taps")
    }

    /// Upstream `apertureTable`: regenerate only when the `shape|count` key changes.
    private func ensureTaps(_ ctx: ComputeContext) {
        let shape = ctx.string("bladeShape") ?? "blades"
        let count = ctx.scalar("bladeCount")
        let key = "\(shape)|\(count)"
        if key == tapKey { return }
        tapKey = key
        let table = BokehTaps.generate(shape: shape, bladeCount: Double(count))
        let p = taps.contents().bindMemory(to: SIMD4<Float>.self, capacity: BokehTaps.tapCount)
        for (i, t) in table.prefix(BokehTaps.tapCount).enumerated() {
            p[i] = SIMD4(Float(t.x), Float(t.y), Float(t.rim), 0)
        }
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let input = BlurKit.childInput(ctx) else { return ComputeOutputs() }
        ensureTaps(ctx)
        let rot = ctx.scalar("bladeRotation") * Self.degToRad
        ctx.pack(layout, [
            "radius": [ctx.scalar("radius") * Self.radiusScale],
            "highlightGain": [ctx.scalar("highlightGain")],
            "highlightThreshold": [ctx.scalar("highlightThreshold")],
            "rotCos": [cos(rot)],
            "rotSin": [sin(rot)],
            "chromaticFringe": [ctx.scalar("chromaticFringe")],
            "inputWidth": [Float(max(1, ctx.width))],
            "inputHeight": [Float(max(1, ctx.height))],
        ], into: params)

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        defer { enc.endEncoding() }
        enc.label = "BokehBlur gather"
        try ctx.dispatch(enc, kernel, threads: SIMD3(UInt32(computeWidth), UInt32(computeHeight), 1)) { e in
            if let s = kernel.texture("input") { e.setTexture(input, index: s.slot) }
            if let s = kernel.texture("output") { e.setTexture(output, index: s.slot) }
            if let s = kernel.buffer("params") { e.setBuffer(params, offset: 0, index: s.slot) }
            if let s = kernel.buffer("taps") { e.setBuffer(taps, offset: 0, index: s.slot) }
        }
        return ComputeOutputs(textures: ["compute_0": output])
    }
}
#endif
