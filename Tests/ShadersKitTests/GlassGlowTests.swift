import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

private func readPixel(_ t: MTLTexture, _ x: Int, _ y: Int) -> SIMD4<Float> {
    var b = [UInt8](repeating: 0, count: 4)
    t.getBytes(&b, bytesPerRow: t.width * 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
    return SIMD4(Float(b[2]), Float(b[1]), Float(b[0]), Float(b[3])) / 255
}

private func luma(_ p: SIMD4<Float>) -> Float { (p.x + p.y + p.z) / 3 }

@Suite("GlassGlow", .serialized)
struct GlassGlowTests {
    let size = SIMD2<Float>(256, 256)

    private func makeRenderer() throws -> ShaderRenderer {
        let device = try #require(ShaderDevice.shared)
        return ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, backgroundColor: SIMD4(0, 0, 0, 1)))
    }

    private func node(speed: Float = 1) -> ShaderNode {
        GlassGlow(speed: speed) { Circle(radius: 0.6) }.node
    }

    /// Renders one frame at clock time `t`: a first frame whose deltaTime sets the clock.
    private func render(_ renderer: ShaderRenderer, _ n: ShaderNode, at t: Float) throws -> MTLTexture {
        renderer.resetState()
        let tex = renderer.renderOffscreen([n], frame: FrameInput(time: t, deltaTime: t, pixelSize: size))
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(renderer.stats.unsupportedNodes.isEmpty, "\(renderer.stats.unsupportedNodes)")
        return try #require(tex)
    }

    @Test("is registered as a hand-written component")
    func registered() throws {
        let d = try #require(ShaderRegistry.descriptor("GlassGlow"))
        #expect(d.flags.requiresChild)
        #expect(d.animatedTimeSpeedProp == "speed")
        #expect(ShaderRegistry.allNames.contains("GlassGlow"))
        #expect(ComputePrograms.supportedShaders.contains("GlassGlow"))
    }

    @Test("lights the shape and leaves the far background dark")
    func lightsShape() throws {
        let renderer = try makeRenderer()
        // t = 0: the shape is lit (the loop starts bright).
        let shape = try #require(renderer.renderOffscreen([Circle(radius: 0.6).node], frame: FrameInput(pixelSize: size)))
        let top = try #require((0..<128).first { luma(readPixel(shape, 128, $0)) > 0.5 })
        let tex = try render(renderer, node(), at: 0)
        let centre = luma(readPixel(tex, 128, 128))
        let corner = luma(readPixel(tex, 2, 2))
        let halo = luma(readPixel(tex, 128, top - 6))   // just outside the circle
        #expect(centre > 0.5)
        #expect(corner < 0.03)
        #expect(halo > corner + 0.02)
    }

    @Test("loops every 6 seconds")
    func loops() throws {
        let renderer = try makeRenderer()
        let a = try render(renderer, node(), at: 1.3)
        let b = try render(renderer, node(), at: 7.3)
        let c = try render(renderer, node(), at: 3.3)
        var diffLoop: Float = 0, diffOther: Float = 0
        for y in stride(from: 8, to: 256, by: 16) {
            for x in stride(from: 8, to: 256, by: 16) {
                diffLoop = max(diffLoop, abs(luma(readPixel(a, x, y)) - luma(readPixel(b, x, y))))
                diffOther = max(diffOther, abs(luma(readPixel(a, x, y)) - luma(readPixel(c, x, y))))
            }
        }
        #expect(diffLoop < 0.02)
        #expect(diffOther > 0.1)
    }
}
#endif
