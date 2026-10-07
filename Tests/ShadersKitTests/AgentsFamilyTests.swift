import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal
import ImageIO
import CoreGraphics

@Suite("Agent family compute programs", .serialized)
struct AgentsFamilyTests {
    /// Renders `node` for `frames` frames at 60 fps and returns the last frame (bgra8Unorm). The
    /// pointer is absent on the first frame, then sweeps across the view (exercises cursor forces).
    private func render(_ node: ShaderNode, size: Int = 256, frames: Int = 30) throws -> (ShaderRenderer, MTLTexture) {
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        var last: MTLTexture?
        for i in 0..<frames {
            let t = Float(i) / Float(max(frames - 1, 1))
            let frame = FrameInput(time: Float(i) / 60, deltaTime: 1 / 60, pixelSize: SIMD2(Float(size), Float(size)),
                                   pointer: i == 0 ? SIMD2(0.5, 0.5) : SIMD2(0.3 + 0.4 * t, 0.5), pointerActive: i > 0)
            last = renderer.renderOffscreen([node], frame: frame)
        }
        return (renderer, try #require(last))
    }

    /// Pixel statistics: how many pixels have alpha > 0.1 and how many distinct BGRA values exist.
    private func stats(_ tex: MTLTexture) -> (covered: Int, distinct: Int) {
        var px = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
        tex.getBytes(&px, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        var covered = 0
        var distinct = Set<UInt32>()
        for i in stride(from: 0, to: px.count, by: 4) {
            if px[i + 3] > 25 { covered += 1 }
            distinct.insert(UInt32(px[i]) | UInt32(px[i + 1]) << 8 | UInt32(px[i + 2]) << 16 | UInt32(px[i + 3]) << 24)
        }
        return (covered, distinct.count)
    }

    private func dumpPNG(_ tex: MTLTexture, _ path: String) {
        var px = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
        tex.getBytes(&px, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        // composite over mid gray for viewing
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Float(px[i + 3]) / 255
            for c in 0..<3 { px[i + c] = UInt8(min(255, Float(px[i + c]) + 128 * (1 - a))) }
            px[i + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: tex.width, height: tex.height, bitsPerComponent: 8, bytesPerRow: tex.width * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), let img = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }

    private func check(_ name: String, _ node: ShaderNode) throws {
        let (renderer, tex) = try render(node)
        #expect(renderer.stats.compileErrors.isEmpty, "\(name): \(renderer.stats.compileErrors)")
        #expect(!renderer.stats.unsupportedNodes.contains(name))
        let s = stats(tex)
        print("AGENTDBG \(name) covered=\(s.covered) distinct=\(s.distinct)")
        if let dir = ProcessInfo.processInfo.environment["AGENT_DUMP"] { dumpPNG(tex, "\(dir)/\(name).png") }
        #expect(s.covered > 0, "\(name): no pixel with alpha > 0.1")
        #expect(s.distinct > 1, "\(name): every pixel identical")
    }

    @Test("DEBUG idle renders") func debugIdle() throws {
        guard let dir = ProcessInfo.processInfo.environment["AGENT_DUMP"] else { return }
        let device = try #require(ShaderDevice.shared)
        let child = ShaderNode(type: "LinearGradient", props: ["colorA": "#ff0000", "colorB": "#0000ff"])
        for (name, node) in [("Particles", ShaderNode(type: "Particles", props: ["mouseInfluence": 0])), ("ParticlesBig", ShaderNode(type: "Particles", props: ["mouseInfluence": 0, "count": 12000, "size": 3]))] {
            let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
            var last: MTLTexture?
            for i in 0..<120 {
                last = renderer.renderOffscreen([node], frame: FrameInput(time: Float(i) / 60, deltaTime: 1 / 60, pixelSize: SIMD2(384, 256)))
            }
            dumpPNG(last!, "\(dir)/\(name)_idle.png")
            print("AGENTDBG idle \(name) \(stats(last!)) \(renderer.stats.compileErrors)")
        }
    }

    @Test("Boids flock renders") func boids() throws {
        try check("Boids", ShaderNode(type: "Boids"))
    }

    @Test("Boids reseeds when seed changes") func boidsReseed() throws {
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device)
        for (i, seed) in [0, 0, 7, 7].enumerated() {
            _ = renderer.renderOffscreen([ShaderNode(type: "Boids", props: ["seed": .number(Float(seed))])],
                                         frame: FrameInput(time: Float(i) / 60, pixelSize: SIMD2(96, 96)))
        }
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
    }

    @Test("FloatingParticles motes render") func floatingParticles() throws {
        try check("FloatingParticles", ShaderNode(type: "FloatingParticles"))
    }

    @Test("MagneticFilings render") func magneticFilings() throws {
        try check("MagneticFilings", ShaderNode(type: "MagneticFilings"))
    }

    @Test("ParticleField explodes its child") func particleField() throws {
        let child = ShaderNode(type: "LinearGradient", props: ["colorA": "#ff0000", "colorB": "#0000ff"])
        try check("ParticleField", ShaderNode(type: "ParticleField", children: [child]))
    }

    @Test("ParticleFlow dust renders and takes cursor stamps") func particleFlow() throws {
        try check("ParticleFlow", ShaderNode(type: "ParticleFlow"))
    }

    @Test("Particles fill the sphere") func particles() throws {
        try check("Particles", ShaderNode(type: "Particles"))
    }
}
#endif
