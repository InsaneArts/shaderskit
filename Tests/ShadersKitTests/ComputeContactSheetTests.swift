import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
/// Renders compute-backed and media shaders after a short warm-up to a PNG (SHADERS_COMPUTE_SHEET env var).
@Suite("Compute contact sheet")
struct ComputeContactSheetTests {
    @Test("render compute contact sheet")
    func sheet() throws {
        guard let out = ProcessInfo.processInfo.environment["SHADERS_COMPUTE_SHEET"] else { return }
        let device = try #require(ShaderDevice.shared)
        let subject = LinearGradient(colorA: "#ff6b6b", colorB: "#4ecdc4", angle: 35).node
        let photoish = ShaderNode(type: "Checkerboard", props: ["cells": 6])
        func wrap(_ name: String, _ props: [String: PropValue] = [:]) -> [ShaderNode] { [ShaderNode(type: name, props: props, children: [subject])] }
        let allCells: [(String, [ShaderNode])] = [
            ("Blur", wrap("Blur", ["intensity": 60])),
            ("BokehBlur", wrap("BokehBlur")),
            ("ProgressiveBlur", wrap("ProgressiveBlur")),
            ("Glow", [ShaderNode(type: "Glow", children: [ShadersKit.Circle(color: "#ffffff", radius: 0.4).node])]),
            ("FilmStock", wrap("FilmStock")),
            ("CompressionArtifacts", [ShaderNode(type: "CompressionArtifacts", children: [photoish])]),
            ("Chrome", [ShaderNode(type: "Chrome")]),
            ("Glass", [ShaderNode(type: "Glass", children: [photoish])]),
            ("Neon", [ShaderNode(type: "Neon")]),
            ("LiquidMetal", [ShaderNode(type: "LiquidMetal")]),
            ("Voxels", [ShaderNode(type: "Voxels")]),
            ("Irradiance", [ShaderNode(type: "Irradiance")]),
            ("Smoke", [ShaderNode(type: "Smoke")]),
            ("InkFlow", [ShaderNode(type: "InkFlow")]),
            ("Boids", [ShaderNode(type: "Boids")]),
            ("Particles", [ShaderNode(type: "Particles")]),
            ("ReactionDiffusion", [ShaderNode(type: "ReactionDiffusion")]),
            ("TimeTrail", wrap("TimeTrail")),
            ("Shatter", wrap("Shatter")),
            ("Surface3D", [ShaderNode(type: "Surface3D")]),
            ("CursorRipples", wrap("CursorRipples")),
            ("GridDistortion", [ShaderNode(type: "GridDistortion", children: [photoish])]),
            ("Liquify", [ShaderNode(type: "Liquify", children: [photoish])]),
            ("PixelSort", wrap("PixelSort")),
            ("Text", [ShaderNode(type: "Text", props: ["text": "ShadersKit", "fontSize": 0.18])]),
            ("ThinFilm", [ShaderNode(type: "ThinFilm")]),
            ("LightEdge", [ShaderNode(type: "LightEdge")]),
            ("Water", [ShaderNode(type: "Water")]),
            ("Fog", [ShaderNode(type: "Fog")]),
            ("MagneticFilings", [ShaderNode(type: "MagneticFilings")]),
        ]
        let diag: [(String, [ShaderNode])] = [
            ("Surface3D", [ShaderNode(type: "Surface3D")]),
            ("Surface3D+child", [ShaderNode(type: "Surface3D", children: [photoish])]),
            ("Glow 100", [ShaderNode(type: "Glow", props: ["intensity": 100], children: [ShadersKit.Circle(color: "#ffffff", radius: 0.3).node])]),
            ("Glow t0 s100", [ShaderNode(type: "Glow", props: ["intensity": 3, "threshold": 0, "size": 100], children: [ShadersKit.Circle(color: "#ff8800", radius: 0.25).node])]),
            ("Glow on gradient", [ShaderNode(type: "Glow", props: ["intensity": 2, "threshold": 0.2, "size": 60], children: [ShaderNode(type: "Star", props: ["color": "#ffffff"])])]),
            ("CursorRipples", wrap("CursorRipples", ["intensity": 1])),
            ("PixelSort", wrap("PixelSort", ["threshold": 0.2])),
            ("TimeTrail", [ShaderNode(type: "TimeTrail", children: [ShaderNode(type: "Ripples")])]),
            ("Compression q10", [ShaderNode(type: "CompressionArtifacts", props: ["quality": 10], children: [subject])]),
            ("ReflectivePlane", wrap("ReflectivePlane")),
            ("TiltShift", wrap("TiltShift")),
            ("DataMosh", [ShaderNode(type: "DataMosh", children: [ShaderNode(type: "Ripples")])]),
        ]
        let cells = ProcessInfo.processInfo.environment["SHADERS_SHEET_DIAG"] != nil ? diag : allCells
        let cell = 192
        let cols = 5
        let rows = (cells.count + cols - 1) / cols
        let w = cols * cell
        let h = rows * cell
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var notes: [String] = []
        for (i, (name, nodes)) in cells.enumerated() {
            let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .displayP3Linear, backgroundColor: SIMD4(0.08, 0.08, 0.1, 1)))
            var last: CGImage? = nil
            for f in 0..<36 {
                let t = Float(f) / 60
                // sweep the pointer through the middle for pointer-driven effects
                let p = SIMD2<Float>(0.3 + 0.4 * Float(f) / 35, 0.5)
                let frame = FrameInput(time: t, deltaTime: 1.0 / 60.0, pixelSize: SIMD2(Float(cell), Float(cell)), pointer: p, pointerActive: f > 4 && f < 30)
                renderer.blockingCompile = true
                guard let tex = renderer.renderOffscreen(nodes, frame: frame) else { continue }
                if f == 35 { last = ShaderRenderer.cgImage(from: tex, colorSpace: .displayP3Linear) }
            }
            if !renderer.stats.compileErrors.isEmpty { notes.append("\(name): \(renderer.stats.compileErrors)") }
            if !renderer.stats.unsupportedNodes.isEmpty { notes.append("\(name): unsupported \(renderer.stats.unsupportedNodes)") }
            if let img = last {
                let x = (i % cols) * cell
                let y = h - ((i / cols) + 1) * cell
                ctx.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell))
            }
        }
        let sheet = try #require(ctx.makeImage())
        let dest = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, sheet, nil)
        #expect(CGImageDestinationFinalize(dest))
        print("NOTES:\n" + notes.joined(separator: "\n"))
        #expect(notes.isEmpty, Comment(rawValue: notes.joined(separator: "\n")))
    }
}
#endif
