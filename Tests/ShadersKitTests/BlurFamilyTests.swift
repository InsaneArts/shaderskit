import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

/// Reads one pixel of a bgra8Unorm texture as (r, g, b, a) in 0...1.
private func readPixel(_ t: MTLTexture, _ x: Int, _ y: Int) -> SIMD4<Float> {
    var b = [UInt8](repeating: 0, count: 4)
    t.getBytes(&b, bytesPerRow: t.width * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
    return SIMD4(Float(b[2]), Float(b[1]), Float(b[0]), Float(b[3])) / 255
}

private func pos(_ x: Float, _ y: Float) -> PropValue {
    .position(.xy(x: .number(x), y: .number(y)))
}

/// A hard two-colour edge: vertical (left `a`, right `b`) or horizontal (top `a`, bottom `b`) at the centre.
private func edge(_ a: String, _ b: String, vertical: Bool = true) -> ShaderNode {
    ShaderNode(type: "LinearGradient", props: [
        "colorA": .string(a), "colorB": .string(b), "edges": "stretch",
        "start": vertical ? pos(0.49, 0.5) : pos(0.5, 0.49),
        "end": vertical ? pos(0.51, 0.5) : pos(0.5, 0.51),
    ])
}

@Suite("Blur family compute programs", .serialized)
struct BlurFamilyTests {
    let size = SIMD2<Float>(128, 64)

    private func makeRenderer() throws -> ShaderRenderer {
        let device = try #require(ShaderDevice.shared)
        return ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
    }

    /// Renders `frames` frames of `nodes` and checks the compute program ran cleanly.
    private func render(_ renderer: ShaderRenderer, _ nodes: [ShaderNode], name: String, size: SIMD2<Float>? = nil, frames: Int = 1) throws -> MTLTexture {
        var tex: MTLTexture? = nil
        for i in 0..<frames {
            tex = renderer.renderOffscreen(nodes, frame: FrameInput(time: Float(i) / 60, pixelSize: size ?? self.size))
        }
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(!renderer.stats.unsupportedNodes.contains(name))
        return try #require(tex)
    }

    @Test("programs are registered for every blur-family shader")
    func registered() {
        let supported = Set(ComputePrograms.supportedShaders)
        for name in ["Blur", "ChannelBlur", "BokehBlur", "ProgressiveBlur", "TiltShift", "Glow", "FilmStock", "ReflectivePlane", "CompressionArtifacts"] {
            #expect(supported.contains(name), "\(name) has no compute program")
        }
    }

    @Test("ChannelBlur blurs only the channels it is asked to")
    func channelBlur() throws {
        let r = try makeRenderer()
        let out = try render(r, [ShaderNode(type: "ChannelBlur", props: ["redIntensity": 0, "greenIntensity": 0, "blueIntensity": 100], children: [edge("#ff0000", "#0000ff")])], name: "ChannelBlur")
        let p = readPixel(out, 60, 32)
        #expect(p.x > 0.9, "red stays sharp: \(p.x)")
        #expect(p.z > 0.05, "blue spreads: \(p.z)")
        #expect(p.w > 0.9)
    }

    @Test("BokehBlur defocuses a hard edge")
    func bokeh() throws {
        let r = try makeRenderer()
        let child = edge("#ff0000", "#0000ff")
        let sharp = try render(r, [ShaderNode(type: "BokehBlur", props: ["radius": 0], children: [child])], name: "BokehBlur")
        let blurred = try render(r, [ShaderNode(type: "BokehBlur", props: ["radius": 50], children: [child])], name: "BokehBlur")
        let s = readPixel(sharp, 54, 32)
        let b = readPixel(blurred, 54, 32)
        #expect(s.z < 0.05, "radius 0 passes through: \(s)")
        #expect(b.z > 0.1, "defocused blue channel \(b.z)")
        #expect(b.w > 0.9)
    }

    @Test("BokehBlur aperture shapes build full tap tables")
    func bokehTaps() {
        for shape in ["blades", "circle", "star", "heart", "flower", "cross", "ring"] {
            let taps = BokehTaps.generate(shape: shape, bladeCount: 6)
            #expect(taps.count == BokehTaps.tapCount, "\(shape)")
            let maxLen = taps.map { hypot($0.x, $0.y) }.max() ?? 0
            #expect(maxLen <= 1.0001 && maxLen > 0.5, "\(shape) extent \(maxLen)")
        }
        // Vogel spiral, tap 0: t = 0.005, theta 0 lands on the hexagon's apothem cos(30°).
        let first = BokehTaps.generate(shape: "blades", bladeCount: 6)[0]
        #expect(abs(first.x + 0.005.squareRoot() * cos(Double.pi / 6)) < 1e-12)
        #expect(abs(first.y) < 1e-12)
    }

    @Test("ProgressiveBlur ramps the blur along its angle")
    func progressive() throws {
        let r = try makeRenderer()
        let child = edge("#ff0000", "#0000ff")
        // center (0, 0.5): angle 0 blurs towards the right, angle 180 leaves everything right of it sharp.
        let blurred = try render(r, [ShaderNode(type: "ProgressiveBlur", props: ["intensity": 100, "falloff": 0.1, "angle": 0], children: [child])], name: "ProgressiveBlur")
        let sharp = try render(r, [ShaderNode(type: "ProgressiveBlur", props: ["intensity": 100, "falloff": 0.1, "angle": 180], children: [child])], name: "ProgressiveBlur")
        let b = readPixel(blurred, 58, 32)
        let s = readPixel(sharp, 58, 32)
        #expect(s.z < 0.05, "sharp side \(s)")
        #expect(b.z > 0.1, "blurred blue channel \(b.z)")
        #expect(b.w > 0.9)
    }

    @Test("TiltShift keeps the focus band sharp and blurs beyond it")
    func tiltShift() throws {
        let r = try makeRenderer()
        let out = try render(r, [ShaderNode(type: "TiltShift", props: ["intensity": 100], children: [edge("#ff0000", "#0000ff")])], name: "TiltShift")
        let inFocus = readPixel(out, 58, 32)
        let outOfFocus = readPixel(out, 58, 2)
        #expect(inFocus.z < 0.05, "focus band \(inFocus)")
        #expect(outOfFocus.z > 0.1, "outside the band \(outOfFocus)")
        #expect(outOfFocus.w > 0.9)
    }

    @Test("Glow spreads a halo from bright pixels")
    func glow() throws {
        let r = try makeRenderer()
        let child = edge("#000000", "#ffffff")
        let off = try render(r, [ShaderNode(type: "Glow", props: ["size": 0, "intensity": 5], children: [child])], name: "Glow", size: SIMD2(128, 96))
        let on = try render(r, [ShaderNode(type: "Glow", props: ["size": 100, "intensity": 5], children: [child])], name: "Glow", size: SIMD2(128, 96))
        let o = readPixel(off, 56, 48)
        let g = readPixel(on, 56, 48)
        #expect(o.x < 0.05, "size 0 passes through: \(o)")
        #expect(g.x > 0.1, "halo \(g)")
        #expect(g.w > 0.9)
        // 4:1 canvas: the halo reaches as far vertically as horizontally (radius converted per axis).
        let glow = { (c: ShaderNode) in ShaderNode(type: "Glow", props: ["size": 100, "intensity": 5], children: [c]) }
        let horizontal = try render(r, [glow(child)], name: "Glow", size: SIMD2(256, 64))
        let vertical = try render(r, [glow(edge("#000000", "#ffffff", vertical: false))], name: "Glow", size: SIMD2(256, 64))
        let hx = readPixel(horizontal, 122, 32).x
        let vy = readPixel(vertical, 128, 26).x
        #expect(hx > 0.1 && vy > 0.1, "halo 6px from the edge: horizontal \(hx), vertical \(vy)")
        #expect(vy / max(hx, 1e-3) > 0.6 && vy / max(hx, 1e-3) < 1.6, "halo shape horizontal \(hx) vs vertical \(vy)")
    }

    @Test("FilmStock grades through its LUT, adds halation and runs the weave clock")
    func filmStock() throws {
        let r = try makeRenderer()
        let gray = ShaderNode(type: "SolidColor", props: ["color": "#808080"])
        let graded = try render(r, [ShaderNode(type: "FilmStock", props: ["halation": 0, "strength": 1], children: [gray])], name: "FilmStock")
        let g = readPixel(graded, 64, 32)
        // A missing LUT samples zero and grades to black; the measured LUT keeps mid-gray mid-gray.
        #expect(g.x > 0.2 && g.y > 0.2 && g.z > 0.2, "graded gray \(g)")
        #expect(g.w > 0.9)

        let child = edge("#000000", "#ffffff")
        let plain = try render(r, [ShaderNode(type: "FilmStock", props: ["halation": 0, "strength": 0], children: [child])], name: "FilmStock")
        let halo = try render(r, [ShaderNode(type: "FilmStock", props: ["halation": 1, "halationRadius": 100, "strength": 0, "weave": 1], children: [child])], name: "FilmStock", frames: 4)
        let p = readPixel(plain, 58, 32)
        let h = readPixel(halo, 58, 32)
        #expect(p.x < 0.05, "no halation \(p)")
        #expect(h.x > 0.1 && h.x > h.z, "warm halation \(h)")

        // Gate weave: the `weaveTime` clock advances while weave > 0, so the sway moves the edge.
        let woven = ShaderNode(type: "FilmStock", props: ["halation": 0, "strength": 0, "weave": 1], children: [child])
        let wide = SIMD2<Float>(512, 64)
        let w = ShaderRenderer(device: r.device, options: r.options)
        var first: SIMD4<Float>? = nil
        var last = SIMD4<Float>(repeating: 0)
        for i in 0..<10 {
            let t = try #require(w.renderOffscreen([woven], frame: FrameInput(time: Float(i) * 0.1, deltaTime: 0.1, pixelSize: wide)))
            last = readPixel(t, 256, 32)
            if first == nil { first = last }
        }
        #expect(w.stats.compileErrors.isEmpty, "\(w.stats.compileErrors)")
        let moved = abs(last - (first ?? last))
        #expect(max(moved.x, moved.z) > 0.02, "edge pixel moved by \(moved)")
    }

    @Test("ReflectivePlane blurs the reflection with depth below the line")
    func reflectivePlane() throws {
        let r = try makeRenderer()
        let child = edge("#ff0000", "#0000ff")
        let sharp = try render(r, [ShaderNode(type: "ReflectivePlane", props: ["blur": 0], children: [child])], name: "ReflectivePlane")
        let blurred = try render(r, [ShaderNode(type: "ReflectivePlane", props: ["blur": 3], children: [child])], name: "ReflectivePlane")
        // Row 60 (uv.y 0.95) is 0.25 below the 0.7 line: the reflection is at full blur there.
        let s = readPixel(sharp, 54, 60)
        let b = readPixel(blurred, 54, 60)
        let above = readPixel(blurred, 54, 10)
        #expect(s.z < 0.05, "unblurred reflection \(s)")
        #expect(b.z > 0.1, "blurred reflection \(b)")
        #expect(above.z < 0.05, "content above the line stays sharp \(above)")
        #expect(b.w > 0.9)
    }

    @Test("CompressionArtifacts quantizes blocks")
    func compression() throws {
        let r = try makeRenderer()
        let child = edge("#ff0000", "#0000ff")
        let sharp = try render(r, [child], name: "LinearGradient")
        let out = try render(r, [ShaderNode(type: "CompressionArtifacts", props: ["quality": 1], children: [child])], name: "CompressionArtifacts")
        var maxDiff: Float = 0
        for x in stride(from: 0, to: 128, by: 2) {
            let d = abs(readPixel(out, x, 20) - readPixel(sharp, x, 20))
            maxDiff = max(maxDiff, d.x, d.y, d.z)
        }
        #expect(maxDiff > 0.05, "max channel difference \(maxDiff)")
        #expect(readPixel(out, 64, 32).w > 0.9)
    }
}
#endif
