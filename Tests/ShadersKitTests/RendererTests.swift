import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

/// Reads back the center pixel of a bgra8Unorm texture as (r, g, b, a) in 0...1.
private func centerPixel(_ tex: MTLTexture) -> SIMD4<Float> {
    var px = [UInt8](repeating: 0, count: 4)
    tex.getBytes(&px, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(tex.width / 2, tex.height / 2, 1, 1), mipmapLevel: 0)
    return SIMD4(Float(px[2]), Float(px[1]), Float(px[0]), Float(px[3])) / 255
}

private func pixel(_ tex: MTLTexture, _ x: Int, _ y: Int) -> SIMD4<Float> {
    var px = [UInt8](repeating: 0, count: 4)
    tex.getBytes(&px, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
    return SIMD4(Float(px[2]), Float(px[1]), Float(px[0]), Float(px[3])) / 255
}

@Suite("Metal renderer", .serialized)
struct RendererTests {
    let device = ShaderDevice.shared

    @Test("registry lists every shipped component")
    func registry() throws {
        #expect(ShaderRegistry.index.count == 199)
        let lg = try #require(ShaderRegistry.descriptor("LinearGradient"))
        #expect(lg.props.count == 8)
        #expect(lg.variants.count == 48)
        #expect(lg.uniformLayout.field("n_x.colorA")?.offset == 16)
    }

    @Test("solid color renders the expected sRGB value")
    func solidColor() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        let tex = try #require(renderer.renderOffscreen([SolidColor(color: "#ff8000").node], frame: FrameInput(pixelSize: SIMD2(64, 64))))
        let p = centerPixel(tex)
        #expect(abs(p.x - 1.0) < 0.02)
        #expect(abs(p.y - 0.502) < 0.02)
        #expect(abs(p.z - 0.0) < 0.02)
        #expect(p.w == 1)
        #expect(renderer.stats.compileErrors.isEmpty)
    }

    @Test("linear gradient varies left to right")
    func linearGradient() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        let tex = try #require(renderer.renderOffscreen([LinearGradient(colorA: "#000000", colorB: "#ffffff").node], frame: FrameInput(pixelSize: SIMD2(128, 32))))
        let left = pixel(tex, 2, 16)
        let right = pixel(tex, 125, 16)
        #expect(left.x < 0.2)
        #expect(right.x > 0.8)
        #expect(renderer.stats.compileErrors.isEmpty)
    }

    @Test("filter over a child and blend modes composite")
    func filterAndBlend() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        let nodes: [ShaderNode] = [
            SolidColor(color: "#ff0000").node,
            Grayscale { SolidColor(color: "#00ff00") }.opacity(0.5),
        ]
        let tex = try #require(renderer.renderOffscreen(nodes, frame: FrameInput(pixelSize: SIMD2(32, 32))))
        let p = centerPixel(tex)
        // 50% gray over red, in linear light then encoded: red channel stays high, green rises
        #expect(p.x > 0.6)
        #expect(p.y > 0.3)
        #expect(renderer.stats.blendPasses == 2)
        #expect(renderer.stats.compileErrors.isEmpty)
    }

    @Test("every shader's default variant compiles and renders without errors", .timeLimit(.minutes(10)))
    func allShadersRender() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device)
        var failures: [String] = []
        for entry in ShaderRegistry.index {
            guard let desc = ShaderRegistry.descriptor(entry.name) else { failures.append("\(entry.name): no descriptor"); continue }
            var node = ShaderNode(type: entry.name)
            if desc.flags.requiresChild { node.children = [SolidColor(color: "#4080ff").node] }
            _ = renderer.renderOffscreen([node], frame: FrameInput(pixelSize: SIMD2(64, 64)))
            if !renderer.stats.compileErrors.isEmpty { failures.append("\(entry.name): \(renderer.stats.compileErrors.joined(separator: "; "))") }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
#endif

#if canImport(Metal) && !os(watchOS)
@Suite("Compute programs", .serialized)
struct ComputeProgramTests {
    @Test("Blur softens a hard edge")
    func blur() throws {
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        // a hard vertical edge: left half red, right half blue (checkerboard with 2 cells would also do)
        let edge = ShaderNode(type: "LinearGradient", props: ["colorA": "#ff0000", "colorB": "#0000ff", "edges": "stretch", "start": .position(.xy(x: .number(0.49), y: .number(0.5))), "end": .position(.xy(x: .number(0.51), y: .number(0.5)))])
        let sharp = try #require(renderer.renderOffscreen([edge], frame: FrameInput(pixelSize: SIMD2(128, 64))))
        let blurred = try #require(renderer.renderOffscreen([ShaderNode(type: "Blur", props: ["intensity": 80], children: [edge])], frame: FrameInput(pixelSize: SIMD2(128, 64))))
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(!renderer.stats.unsupportedNodes.contains("Blur"))
        func px(_ t: MTLTexture, _ x: Int) -> SIMD4<Float> {
            var b = [UInt8](repeating: 0, count: 4)
            t.getBytes(&b, bytesPerRow: t.width * 4, from: MTLRegionMake2D(x, 32, 1, 1), mipmapLevel: 0)
            return SIMD4(Float(b[2]), Float(b[1]), Float(b[0]), Float(b[3])) / 255
        }
        // 10px left of the edge: sharp is pure red, blurred has picked up blue
        let s = px(sharp, 54)
        let b = px(blurred, 54)
        #expect(s.z < 0.05)
        #expect(b.z > 0.1, "blurred blue channel \(b.z)")
        #expect(b.w > 0.9)
    }
}
#endif
