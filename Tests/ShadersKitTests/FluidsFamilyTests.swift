import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

@Suite("Fluids family", .serialized)
struct FluidsFamilyTests {
    static let shaders = ["Fog", "InkFlow", "Smoke", "SmokeFill", "SmokeFlow"]
    static let size = 96

    /// Every pixel of a bgra8Unorm texture as (r, g, b, a) in 0...1.
    private func pixels(_ tex: MTLTexture) -> [SIMD4<Float>] {
        var raw = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
        tex.getBytes(&raw, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        return stride(from: 0, to: raw.count, by: 4).map { (i: Int) -> SIMD4<Float> in
            let bgra = SIMD4<Float>(Float(raw[i + 2]), Float(raw[i + 1]), Float(raw[i]), Float(raw[i + 3]))
            return bgra / 255
        }
    }

    /// Renders `frames` frames at 60 fps. With `drag`, the pointer is active on frames 2...8 and
    /// moves left to right through the centre, which is what injects dye for the stroke emitters.
    private func render(_ name: String, frames: Int = 20, drag: Bool = true) throws -> (MTLTexture, ShaderRenderer) {
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device)
        let node = ShaderNode(type: name)
        var last: MTLTexture?
        for i in 0..<frames {
            let active = drag && (2...8).contains(i)
            let pointer = SIMD2<Float>(active ? 0.35 + 0.05 * Float(i - 2) : 0.5, 0.5)
            let frame = FrameInput(time: Float(i) / 60, deltaTime: 1.0 / 60, pixelSize: SIMD2(Float(Self.size), Float(Self.size)), pointer: pointer, pointerActive: active)
            last = renderer.renderOffscreen([node], frame: frame)
        }
        return (try #require(last), renderer)
    }

    @Test("renders non-uniform fluid content", arguments: shaders)
    func renders(_ name: String) throws {
        let (tex, renderer) = try render(name)
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(!renderer.stats.unsupportedNodes.contains(name))
        let alpha = pixels(tex).map(\.w)
        let maxA = try #require(alpha.max())
        let minA = try #require(alpha.min())
        #expect(maxA > 0.1, "\(name) max alpha \(maxA)")
        #expect(maxA - minA > 0.05, "\(name) alpha range \(minA)...\(maxA)")
    }

    @Test("InkFlow stays transparent until a stroke paints")
    func inkFlowIdle() throws {
        let (tex, renderer) = try render("InkFlow", frames: 5, drag: false)
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(pixels(tex).allSatisfy { $0.w == 0 })
    }
}
#endif

#if canImport(Metal) && !os(watchOS)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@Suite("Fluids debug dump")
struct FluidsDebugDump {
    @Test func dump() throws {
        guard let dir = ProcessInfo.processInfo.environment["FLUIDS_DUMP"] else { return }
        let device = try #require(ShaderDevice.shared)
        for name in ["Fog", "InkFlow", "Smoke", "SmokeFill", "SmokeFlow"] {
            let renderer = ShaderRenderer(device: device, options: RenderOptions(backgroundColor: SIMD4(0.02, 0.02, 0.03, 1)))
            let node = ShaderNode(type: name)
            for i in 0..<90 {
                let active = (5...40).contains(i)
                let a = Float(i - 5) / 35 * 2 * .pi
                let pointer = SIMD2<Float>(0.5 + 0.3 * cos(a), 0.5 + 0.3 * sin(a))
                let frame = FrameInput(time: Float(i) / 60, deltaTime: 1.0 / 60, pixelSize: SIMD2(256, 256), pointer: pointer, pointerActive: active)
                guard let tex = renderer.renderOffscreen([node], frame: frame) else { continue }
                if i == 30 || i == 89 {
                    var raw = [UInt8](repeating: 0, count: 256 * 256 * 4)
                    tex.getBytes(&raw, bytesPerRow: 256 * 4, from: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0)
                    let ctx = CGContext(data: &raw, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 256 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
                    let img = ctx.makeImage()!
                    let url = URL(fileURLWithPath: "\(dir)/\(name)_\(i).png")
                    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                    CGImageDestinationAddImage(dest, img, nil)
                    CGImageDestinationFinalize(dest)
                }
            }
            print("\(name) errors: \(renderer.stats.compileErrors) unsupported: \(renderer.stats.unsupportedNodes)")
        }
    }
}
#endif
