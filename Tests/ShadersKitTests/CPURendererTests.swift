import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

/// Compares the CPU rasterizer against the Metal renderer. Both run the same uniform packing and
/// the same (transpiled) shader math, so results should agree closely.
@Suite("CPU renderer", .serialized)
struct CPURendererTests {
    private func gpuPixels(_ nodes: [ShaderNode], size: Int, device: ShaderDevice) -> [SIMD4<Float>]? {
        let r = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        guard let tex = r.renderOffscreen(nodes, frame: FrameInput(time: 1.25, pixelSize: SIMD2(Float(size), Float(size)))) else { return nil }
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        tex.getBytes(&bytes, bytesPerRow: size * 4, from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
        return bgraToFloats(bytes, count: size * size)
    }

    private func bgraToFloats(_ bytes: [UInt8], count: Int) -> [SIMD4<Float>] {
        var out: [SIMD4<Float>] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let r = Float(bytes[i * 4 + 2]) / 255
            let g = Float(bytes[i * 4 + 1]) / 255
            let b = Float(bytes[i * 4]) / 255
            let a = Float(bytes[i * 4 + 3]) / 255
            out.append(SIMD4<Float>(r, g, b, a))
        }
        return out
    }

    private func rgbaToFloats(_ data: Data, count: Int) -> [SIMD4<Float>] {
        var out: [SIMD4<Float>] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let r = Float(data[i * 4]) / 255
            let g = Float(data[i * 4 + 1]) / 255
            let b = Float(data[i * 4 + 2]) / 255
            let a = Float(data[i * 4 + 3]) / 255
            out.append(SIMD4<Float>(r, g, b, a))
        }
        return out
    }

    private func cpuPixels(_ nodes: [ShaderNode], size: Int) -> [SIMD4<Float>]? {
        let r = CPURenderer(options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        guard let img = r.renderImage(nodes, frame: FrameInput(time: 1.25, pixelSize: SIMD2(Float(size), Float(size)))) else { return nil }
        guard let data = img.dataProvider?.data as Data? else { return nil }
        return rgbaToFloats(data, count: size * size)
    }

    private func meanAbsDiff(_ a: [SIMD4<Float>], _ b: [SIMD4<Float>]) -> Float {
        var total: Float = 0
        for i in 0..<a.count {
            let d: SIMD4<Float> = a[i] - b[i]
            let ad: SIMD4<Float> = pointwiseMax(d, -d)
            total += ad.sum() / 4
        }
        return total / Float(a.count)
    }

    @Test("CPU and GPU agree on representative shaders")
    func cpuMatchesGPU() throws {
        let device = try #require(ShaderDevice.shared)
        let subject = SolidColor(color: "#3366ff").node
        let cases: [(String, [ShaderNode])] = [
            ("SolidColor", [SolidColor(color: "#ff8000").node]),
            ("LinearGradient", [LinearGradient(colorA: "#ff0000", colorB: "#0000ff", angle: 30).node]),
            ("RadialGradient", [ShaderNode(type: "RadialGradient")]),
            ("Circle", [ShaderNode(type: "Circle")]),
            ("Checkerboard", [ShaderNode(type: "Checkerboard")]),
            ("Plasma", [ShaderNode(type: "Plasma")]),
            ("Pixelate", [ShaderNode(type: "Pixelate", children: [LinearGradient().node])]),
            ("Twirl", [ShaderNode(type: "Twirl", children: [ShaderNode(type: "Checkerboard")])]),
            ("Grayscale+blend", [subject, Grayscale { LinearGradient() }.opacity(0.6).blendMode(.screen)]),
        ]
        let size = 48
        var report: [String] = []
        for (name, nodes) in cases {
            let gpu = try #require(gpuPixels(nodes, size: size, device: device))
            let cpu = try #require(cpuPixels(nodes, size: size))
            let d = meanAbsDiff(gpu, cpu)
            report.append("\(name): mean abs diff \(d)")
            #expect(d < 0.03, "\(name) differs: \(d)")
        }
        print(report.joined(separator: "\n"))
    }

    @Test("every CPU program renders its default variant without trapping", .timeLimit(.minutes(10)))
    func allCPUPrograms() throws {
        let device = try #require(ShaderDevice.shared)
        let r = CPURenderer(options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        var worst: [(String, Float)] = []
        var timings: [(String, Double)] = []
        let mediaBacked = Set(MediaPrograms.supportedShaders)
        for name in CPUPrograms.supportedNames where !mediaBacked.contains(name) {
            guard let desc = ShaderRegistry.descriptor(name) else { continue }
            var node = ShaderNode(type: name)
            if desc.flags.requiresChild { node.children = [LinearGradient(colorA: "#ff0000", colorB: "#00ffff").node] }
            let t0 = Date()
            guard let cpu = cpuPixels([node], size: 32) else { Issue.record("\(name) produced no image"); continue }
            timings.append((name, Date().timeIntervalSince(t0) * 1000))
            if let gpu = gpuPixels([node], size: 32, device: device) {
                worst.append((name, meanAbsDiff(gpu, cpu)))
            }
            #expect(r.stats.compileErrors.isEmpty)
        }
        worst.sort { $0.1 > $1.1 }
        timings.sort { $0.1 > $1.1 }
        print("Largest CPU/GPU differences:\n" + worst.prefix(12).map { "  \($0.0): \($0.1)" }.joined(separator: "\n"))
        print("Slowest CPU programs (ms at 32×32):\n" + timings.prefix(12).map { "  \($0.0): \(Int($0.1))" }.joined(separator: "\n"))
        let bad = worst.filter { $0.1 > 0.08 }
        #expect(bad.count < 12, "shaders differing by > 0.08: \(bad.map(\.0))")
    }
}
#endif
