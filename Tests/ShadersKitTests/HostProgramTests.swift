import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal

/// Reads every pixel of a bgra8Unorm texture as (r, g, b, a) in 0...1.
private func readPixels(_ tex: MTLTexture) -> [SIMD4<Float>] {
    var raw = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
    tex.getBytes(&raw, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
    return stride(from: 0, to: raw.count, by: 4).map {
        SIMD4<Float>(Float(raw[$0 + 2]) / 255, Float(raw[$0 + 1]) / 255, Float(raw[$0]) / 255, Float(raw[$0 + 3]) / 255)
    }
}

private func maxDifference(_ a: [SIMD4<Float>], _ b: [SIMD4<Float>]) -> Float {
    zip(a, b).map { simd_reduce_max(abs($0 - $1)) }.max() ?? 0
}

/// Summed per-channel variance over the image (0 for a flat color).
private func variance(_ px: [SIMD4<Float>]) -> Float {
    let n = Float(px.count)
    let mean = px.reduce(SIMD4<Float>(repeating: 0), +) / n
    let v = px.reduce(SIMD4<Float>(repeating: 0)) { $0 + ($1 - mean) * ($1 - mean) } / n
    return simd_reduce_add(v)
}

private func meanAlpha(_ px: [SIMD4<Float>]) -> Float { px.map(\.w).reduce(0, +) / Float(px.count) }

@Suite("Host programs (per-frame CPU hooks)", .serialized)
struct HostProgramTests {
    static let size = 96

    private func renderer() throws -> ShaderRenderer {
        ShaderRenderer(device: try #require(ShaderDevice.shared), options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
    }

    /// Renders `nodes` for `frames` frames (1/60 s each) and returns the last frame's pixels.
    private func run(_ r: ShaderRenderer, _ nodes: [ShaderNode], frames: Int = 4, startFrame: Int = 0, pointer: (Int) -> SIMD2<Float> = { _ in SIMD2(0.5, 0.5) }) throws -> [SIMD4<Float>] {
        var last: MTLTexture?
        for i in startFrame..<(startFrame + frames) {
            let frame = FrameInput(time: Float(i) / 60, deltaTime: 1.0 / 60, pixelSize: SIMD2(Float(Self.size), Float(Self.size)), pointer: pointer(i), pointerActive: true)
            last = r.renderOffscreen(nodes, frame: frame)
        }
        return readPixels(try #require(last))
    }

    private func expectClean(_ r: ShaderRenderer, _ name: String) {
        #expect(r.stats.compileErrors.isEmpty, "\(r.stats.compileErrors)")
        #expect(!r.stats.unsupportedNodes.contains(name), "\(r.stats.unsupportedNodes)")
    }

    private var gradient: ShaderNode {
        ShaderNode(type: "LinearGradient", props: ["colorA": "#000000", "colorB": "#ffffff", "start": .position(.xy(x: .number(0), y: .number(0.5))), "end": .position(.xy(x: .number(1), y: .number(0.5)))])
    }

    @Test func registered() {
        for n in ["FlowingGradient", "Beam", "MeshGradient", "Blob", "StudioBackground", "FilmGrain", "Form3D"] {
            #expect(HostFieldsHooks.hook(for: n) != nil, "\(n)")
        }
        for n in ["Ascii", "ChromaFlow", "CursorTrail"] {
            #expect(MediaPrograms.program(for: n) != nil, "\(n)")
        }
    }

    @Test func flowingGradientDefaultIsOpaqueAndNotFlat() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "FlowingGradient")])
        expectClean(r, "FlowingGradient")
        #expect(meanAlpha(px) > 0.9)
        #expect(variance(px) > 1e-4)
        let solid = try run(try renderer(), [ShaderNode(type: "SolidColor")])
        #expect(maxDifference(px, solid) > 0.1)
    }

    @Test func beamPreconvertedColorSpace() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "Beam", props: ["colorSpace": "oklch"])])
        expectClean(r, "Beam")
        // Centre row of the beam: opaque-ish and colored, not black from zero preconverted colors.
        let mid = px[(Self.size / 2) * Self.size + Self.size / 2]
        #expect(mid.w > 0.3, "\(mid)")
        #expect(max(mid.x, mid.y, mid.z) > 0.2, "\(mid)")
        let linear = try run(try renderer(), [ShaderNode(type: "Beam", props: ["colorSpace": "linear"])])
        #expect(maxDifference(px, linear) > 0.02)
    }

    @Test func meshGradientDefaultIsNotFlat() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "MeshGradient")])
        expectClean(r, "MeshGradient")
        #expect(variance(px) > 1e-3, "\(variance(px))")
    }

    /// Value pinned against upstream `packScatterAnchors(5, 3, 0.5, 1.5, 7.25)` (run in Node).
    @Test func meshAnchorsMatchUpstream() {
        let golden: [Float] = [0.5524264574050903, 0.6799716949462891, 0.6926062107086182, 0.1531815528869629, 1.1530297994613647, 0.733228325843811, -0.10982197523117065, 0.5866094827651978, 1.2277730703353882, -0.12374645471572876, 0.7450599670410156, 1.0759015083312988, -0.3401321768760681, 0.09673380851745605, 2.071998119354248, 0.4725227653980255]
        let got = MeshGradientHostHook.pack(count: 5, seed: 3, drift: 0.5, aspect: 1.5, animTime: 7.25)
        for (a, b) in zip(got, golden) { #expect(abs(a - b) < 1e-5, "\(got)") }
    }

    @Test func blobRendersLitDisc() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "Blob")])
        expectClean(r, "Blob")
        #expect(px.contains { $0.w > 0.5 })
        #expect(variance(px) > 1e-3)
        // The light direction only reaches the GPU through the normL* extraFields.
        let left = try run(try renderer(), [ShaderNode(type: "Blob", props: ["highlightX": -1, "highlightY": 0, "highlightZ": 0.2, "highlightIntensity": 2])])
        let right = try run(try renderer(), [ShaderNode(type: "Blob", props: ["highlightX": 1, "highlightY": 0, "highlightZ": 0.2, "highlightIntensity": 2])])
        #expect(maxDifference(left, right) > 0.05)
    }

    @Test func studioBackgroundAmbientMoves() throws {
        let r = try renderer()
        let a = try run(r, [ShaderNode(type: "StudioBackground", props: ["ambientIntensity": 100])], frames: 2)
        expectClean(r, "StudioBackground")
        let b = try run(r, [ShaderNode(type: "StudioBackground", props: ["ambientIntensity": 100])], frames: 120, startFrame: 2)
        #expect(meanAlpha(a) > 0.99)
        #expect(maxDifference(a, b) > 0.004)
    }

    @Test func filmGrainAnimatesOnlyWhenAnimated() throws {
        let child = ShaderNode(type: "SolidColor", props: ["color": "#404040"])
        let r = try renderer()
        let node = ShaderNode(type: "FilmGrain", props: ["animated": true, "strength": 1], children: [child])
        let a = try run(r, [node], frames: 1)
        let b = try run(r, [node], frames: 1, startFrame: 1)
        expectClean(r, "FilmGrain")
        #expect(maxDifference(a, b) > 0.02)
        let s = try renderer()
        let still = ShaderNode(type: "FilmGrain", props: ["animated": false, "strength": 1], children: [child])
        let c = try run(s, [still], frames: 1)
        let d = try run(s, [still], frames: 1, startFrame: 1)
        #expect(maxDifference(c, d) == 0)
    }

    @Test func form3DRibbonRenders() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "Form3D", children: [gradient])])
        expectClean(r, "Form3D")
        #expect(px.contains { $0.w > 0.5 })
        #expect(px.contains { $0.w < 0.1 })
        // The shape JSON only reaches the GPU through the _f3p* extraFields.
        let wide = try run(try renderer(), [ShaderNode(type: "Form3D", props: ["shape3d": .string(#"{"type":"ribbon","angle":0,"twist":0,"width":100,"thickness":20,"seed":0}"#)], children: [gradient])])
        #expect(maxDifference(px, wide) > 0.1)
    }

    @Test func asciiShowsGlyphStructure() throws {
        let r = try renderer()
        let px = try run(r, [ShaderNode(type: "Ascii", props: ["cellSize": 60], children: [gradient])], frames: 2)
        expectClean(r, "Ascii")
        let lit = px.filter { $0.w > 0.5 && max($0.x, $0.y, $0.z) > 0.2 }.count
        let empty = px.filter { $0.w < 0.05 }.count
        #expect(lit > px.count / 50, "lit \(lit)")
        #expect(empty > px.count / 10, "empty \(empty)")
    }

    @Test func cursorTrailDrawsAlongSweep() throws {
        let r = try renderer()
        let node = ShaderNode(type: "CursorTrail", props: ["length": 2])
        let idle = try run(r, [node], frames: 3)
        expectClean(r, "CursorTrail")
        #expect(idle.allSatisfy { $0.w < 0.01 })
        // Sweep left → right along y = 0.5.
        let px = try run(r, [node], frames: 12, startFrame: 3) { i in SIMD2(0.5 + Float(i - 3) * 0.03, 0.5) }
        let row = Self.size / 2
        let covered = (Int(Float(Self.size) * 0.55)..<Int(Float(Self.size) * 0.8)).filter { px[row * Self.size + $0].w > 0.3 }.count
        #expect(covered > 10, "covered \(covered)")
        #expect(px[Self.size * 5 + 5].w < 0.01)
    }

    @Test func chromaFlowReactsToPointer() throws {
        let r = try renderer()
        let node = ShaderNode(type: "ChromaFlow")
        let still = try run(r, [node], frames: 3)
        expectClean(r, "ChromaFlow")
        let moved = try run(r, [node], frames: 10, startFrame: 3) { i in SIMD2(0.5 + Float(i - 3) * 0.03, 0.5) }
        #expect(maxDifference(still, moved) > 0.05)
    }
}
#endif
