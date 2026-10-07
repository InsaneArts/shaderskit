import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
/// Renders a grid of representative shaders to a PNG for visual inspection (path from env SHADERS_CONTACT_SHEET).
@Suite("Contact sheet")
struct ContactSheetTests {
    @Test("render contact sheet")
    func contactSheet() throws {
        guard let out = ProcessInfo.processInfo.environment["SHADERS_CONTACT_SHEET"] else { return }
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .displayP3Linear, backgroundColor: SIMD4(0.05, 0.05, 0.06, 1)))
        let subject = LinearGradient(colorA: "#ff6b6b", colorB: "#4ecdc4", angle: 35).node
        let cells: [(String, [ShaderNode])] = [
            ("LinearGradient", [LinearGradient(colorA: "#0f172a", colorB: "#7c3aed", angle: 45).node]),
            ("MeshGradient", [ShaderNode(type: "MeshGradient")]),
            ("Aurora", [ShaderNode(type: "Aurora")]),
            ("Plasma", [ShaderNode(type: "Plasma")]),
            ("Voronoi", [ShaderNode(type: "Voronoi")]),
            ("Circle+Star", [ShadersKit.Circle(color: "#ffd166", radius: 0.6).node, Star(color: "#ef476f").opacity(0.9).blendMode(.multiply)]),
            ("Halftone", [ShaderNode(type: "Halftone", children: [subject])]),
            ("Pixelate", [ShaderNode(type: "Pixelate", props: ["scale": 24], children: [subject])]),
            ("Twirl", [ShaderNode(type: "Twirl", props: ["intensity": 4], children: [ShaderNode(type: "Checkerboard")])]),
            ("Kaleidoscope", [ShaderNode(type: "Kaleidoscope", children: [ShaderNode(type: "Plasma")])]),
            ("Blur", [ShaderNode(type: "Blur", props: ["intensity": 60], children: [ShadersKit.Circle(color: "#ffffff", radius: 0.5).node])]),
            ("ChromaticAb.", [ShaderNode(type: "ChromaticAberration", props: ["intensity": 2], children: [ShaderNode(type: "Grid")])]),
            ("Vignette", [ShaderNode(type: "Vignette", children: [ShaderNode(type: "DotGrid")])]),
            ("FilmGrain", [ShaderNode(type: "FilmGrain", children: [subject])]),
            ("Heart", [Heart(color: "#ff2b6e").node]),
            ("Ripples", [ShaderNode(type: "Ripples")]),
        ]
        let cell = 192
        let cols = 4
        let rows = (cells.count + cols - 1) / cols
        let w = cols * cell
        let h = rows * cell
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var failures: [String] = []
        for (i, (name, nodes)) in cells.enumerated() {
            guard let img = renderer.renderImage(nodes, size: CGSize(width: cell, height: cell), time: 2.0) else { failures.append(name); continue }
            if !renderer.stats.compileErrors.isEmpty { failures.append("\(name): \(renderer.stats.compileErrors)") }
            let x = (i % cols) * cell
            let y = h - ((i / cols) + 1) * cell
            ctx.draw(img, in: CGRect(x: x, y: y, width: cell, height: cell))
        }
        let sheet = try #require(ctx.makeImage())
        let url = URL(fileURLWithPath: out)
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, sheet, nil)
        #expect(CGImageDestinationFinalize(dest))
        #expect(failures.isEmpty, "\(failures)")
    }
}
#endif
