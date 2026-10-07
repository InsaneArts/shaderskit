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
    var out: [SIMD4<Float>] = []
    out.reserveCapacity(raw.count / 4)
    for i in stride(from: 0, to: raw.count, by: 4) {
        let r = Float(raw[i + 2]) / 255
        let g = Float(raw[i + 1]) / 255
        let b = Float(raw[i]) / 255
        let a = Float(raw[i + 3]) / 255
        out.append(SIMD4<Float>(r, g, b, a))
    }
    return out
}

/// Largest per-channel difference between two equally sized renders.
private func maxDifference(_ a: [SIMD4<Float>], _ b: [SIMD4<Float>]) -> Float {
    zip(a, b).map { simd_reduce_max(abs($0 - $1)) }.max() ?? 0
}

/// Number of pixels whose color differs from the first pixel (a flat image scores 0).
private func distinctFromFirst(_ px: [SIMD4<Float>]) -> Int {
    guard let first = px.first else { return 0 }
    return px.filter { simd_reduce_max(abs($0 - first)) > 0.02 }.count
}

/// A left-to-right sweep through the centre (frames 2..<10): gives the velocity-driven sims motion.
private func centreSweep(_ frame: Int) -> SIMD2<Float>? {
    guard (2..<10).contains(frame) else { return nil }
    return SIMD2(0.3 + Float(frame - 2) * 0.05, 0.5)
}

@Suite("Grid / feedback family", .serialized)
struct GridFamilyTests {
    let device = ShaderDevice.shared
    static let size = 96
    static let frames = 20

    /// Renders `nodes` for `frames` frames (time advances 1/60 per frame) and returns the last frame.
    private func run(_ renderer: ShaderRenderer, _ nodes: [ShaderNode], frames: Int = GridFamilyTests.frames, pointer: (Int) -> SIMD2<Float>? = { _ in nil }) -> MTLTexture? {
        var last: MTLTexture?
        var held = SIMD2<Float>(0.5, 0.5)
        for i in 0..<frames {
            let p = pointer(i)
            if let p { held = p }
            let frame = FrameInput(time: Float(i) / 60, deltaTime: 1.0 / 60, pixelSize: SIMD2(Float(Self.size), Float(Self.size)), pointer: held, pointerActive: p != nil)
            last = renderer.renderOffscreen(nodes, frame: frame)
        }
        return last
    }

    private func renderer() throws -> ShaderRenderer {
        _ = ComputePrograms.supportedShaders // loads the family registry (also registers PixelThrow's media program)
        return ShaderRenderer(device: try #require(device), options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
    }

    private func expectClean(_ r: ShaderRenderer, _ name: String) {
        #expect(r.stats.compileErrors.isEmpty, "\(r.stats.compileErrors)")
        #expect(!r.stats.unsupportedNodes.contains(name), "\(r.stats.unsupportedNodes)")
    }

    private var stripes: ShaderNode { ShaderNode(type: "Stripes", props: ["angle": 90, "density": 6, "speed": 0]) }
    /// Varies along both axes, so a displacement in any direction is visible.
    private var checker: ShaderNode { ShaderNode(type: "Checkerboard", props: ["colorA": "#000000", "colorB": "#ffffff", "cells": 8]) }
    /// Stripes that vary along x (`angle: 0`) or y (`angle: 90`): many light/dark swaps along a sort axis.
    private func stripes(across angle: Float) -> ShaderNode { ShaderNode(type: "Stripes", props: ["angle": .number(angle), "density": 12, "speed": 0]) }
    private var gradient: ShaderNode { ShaderNode(type: "LinearGradient", props: ["colorA": "#000000", "colorB": "#ffffff", "start": .position(.xy(x: .number(0.5), y: .number(0))), "end": .position(.xy(x: .number(0.5), y: .number(1)))]) }

    /// Renders a filter over `child` with a pointer sweep and returns (filtered, plain child) pixels.
    private func filteredVersusChild(_ name: String, _ props: [String: PropValue] = [:], child: ShaderNode, pointer: @escaping (Int) -> SIMD2<Float>? = centreSweep) throws -> (out: [SIMD4<Float>], child: [SIMD4<Float>]) {
        let r = try renderer()
        let tex = try #require(run(r, [ShaderNode(type: name, props: props, children: [child])], pointer: pointer))
        expectClean(r, name)
        let plain = try #require(run(try renderer(), [child], frames: 1))
        return (readPixels(tex), readPixels(plain))
    }

    // MARK: Pointer fields

    @Test("GridDistortion displaces its child along the pointer sweep")
    func gridDistortion() throws {
        let (out, child) = try filteredVersusChild("GridDistortion", ["intensity": 5], child: checker)
        #expect(maxDifference(out, child) > 0.2)
        let (still, _) = try filteredVersusChild("GridDistortion", ["intensity": 5], child: checker, pointer: { _ in nil })
        #expect(maxDifference(still, child) < 0.05) // no motion → no displacement
    }

    @Test("GridDistortion re-specializes the baked grid size")
    func gridDistortionGridSize() throws {
        let (out, child) = try filteredVersusChild("GridDistortion", ["intensity": 5, "gridSize": 40], child: checker)
        #expect(maxDifference(out, child) > 0.2)
    }

    @Test("Liquify bends its child after a pointer push")
    func liquify() throws {
        let (out, child) = try filteredVersusChild("Liquify", ["intensity": 20], child: checker)
        #expect(maxDifference(out, child) > 0.2)
    }

    @Test("CursorRipples ripples its child after a pointer sweep")
    func cursorRipples() throws {
        let (out, child) = try filteredVersusChild("CursorRipples", ["intensity": 20], child: stripes)
        #expect(maxDifference(out, child) > 0.2)
    }

    // MARK: Grid sims

    @Test("ReactionDiffusion grows a pattern from its seed")
    func reactionDiffusion() throws {
        let r = try renderer()
        let tex = try #require(run(r, [ShaderNode(type: "ReactionDiffusion", props: ["speed": 16])], pointer: centreSweep))
        expectClean(r, "ReactionDiffusion")
        #expect(distinctFromFirst(readPixels(tex)) > 200)
    }

    @Test("PixelSort sorts under the brush (default vertical / descending)")
    func pixelSort() throws {
        let (out, child) = try filteredVersusChild("PixelSort", ["strength": 1, "radius": 0.6], child: stripes(across: 90), pointer: { _ in SIMD2(0.5, 0.5) })
        #expect(maxDifference(out, child) > 0.2)
    }

    @Test("PixelSort horizontal / ascending (the shipped kernel variant)")
    func pixelSortHorizontal() throws {
        let (out, child) = try filteredVersusChild("PixelSort", ["strength": 1, "radius": 0.6, "axis": "horizontal", "direction": "ascending"],
                                                   child: stripes(across: 0), pointer: { _ in SIMD2(0.5, 0.5) })
        #expect(maxDifference(out, child) > 0.2)
    }

    @Test("PixelThrow throws pixels along the pointer sweep")
    func pixelThrow() throws {
        let (out, child) = try filteredVersusChild("PixelThrow", ["strength": 1, "keyInfluence": 0], child: checker)
        #expect(maxDifference(out, child) > 0.2)
        let (still, _) = try filteredVersusChild("PixelThrow", ["strength": 1, "keyInfluence": 0], child: checker, pointer: { _ in nil })
        #expect(maxDifference(still, child) < 0.05) // no motion → no displacement
    }

    // MARK: Feedback sims

    @Test("DataMosh decodes its child into the display copy")
    func dataMosh() throws {
        // Held blocks re-sample the zero-initialised previous state, so early frames are partly
        // transparent (as upstream). With intensity 0 every block refreshes from the live child.
        let (fresh, _) = try filteredVersusChild("DataMosh", ["intensity": 0], child: stripes, pointer: { _ in nil })
        #expect(fresh.map(\.w).reduce(0, +) / Float(fresh.count) > 0.9)
        #expect(distinctFromFirst(fresh) > 200)
        let (moshed, _) = try filteredVersusChild("DataMosh", child: stripes, pointer: { _ in nil })
        #expect(maxDifference(moshed, fresh) > 0.2)
    }

    @Test("TimeTrail trails its child (motion and alpha sources)", arguments: ["motion", "alpha"])
    func timeTrail(source: String) throws {
        let moving = ShaderNode(type: "Stripes", props: ["angle": 90, "density": 6, "speed": 2])
        let (out, _) = try filteredVersusChild("TimeTrail", ["trailSource": .string(source)], child: moving, pointer: { _ in nil })
        #expect(out.map(\.w).reduce(0, +) / Float(out.count) > 0.9)
        #expect(distinctFromFirst(out) > 200)
    }

    @Test("KeyFrames draws tracker gizmos over its child", arguments: ["bright", "red", "dark"])
    func keyFrames(detect: String) throws {
        let spot = ShaderNode(type: "Circle", props: ["color": "#ff3030", "radius": 0.4])
        let backdrop = ShaderNode(type: "SolidColor", props: ["color": "#202020"])
        let child = ShaderNode(type: "Group", children: [backdrop, spot])
        let (out, plain) = try filteredVersusChild("KeyFrames", ["detect": .string(detect), "markerSize": 60, "lineWidth": 4], child: child, pointer: { _ in nil })
        #expect(maxDifference(out, plain) > 0.2)
    }

    // MARK: Fracture / height field

    @Test("Shatter cracks and shifts its child")
    func shatter() throws {
        let (out, child) = try filteredVersusChild("Shatter", ["intensity": 20], child: stripes)
        #expect(maxDifference(out, child) > 0.2)
    }

    @Test("Surface3D drapes its child over the raymarched surface", arguments: ["fractal", "sine", "ridge"])
    func surface3D(waveType: String) throws {
        let (out, child) = try filteredVersusChild("Surface3D", ["waveType": .string(waveType), "octaves": 3, "edges": "transparent"], child: stripes)
        #expect(maxDifference(out, child) > 0.2)
        #expect(out.contains { $0.w > 0.5 })
    }

    @Test("Surface3D edge modes specialize", arguments: ["stretch", "mirror", "wrap"])
    func surface3DEdges(edges: String) throws {
        let (out, _) = try filteredVersusChild("Surface3D", ["edges": .string(edges)], child: stripes)
        #expect(out.contains { $0.w > 0.5 })
    }

    // MARK: Host parts

    @Test("halfBits matches upstream toHalfFloat on non-tie values")
    func halfBits() {
        #expect(GridKit.halfBits(0) == 0)
        #expect(GridKit.halfBits(1) == 0x3C00)
        #expect(GridKit.halfBits(-2) == 0xC000)
        #expect(GridKit.halfBits(0.5) == 0x3800)
        #expect(GridKit.halfBits(65504) == 0x7BFF)
        #expect(GridKit.halfBits(1e9) == 0x7BFF) // saturates, not Inf
        #expect(GridKit.halfBits(0.1) == 0x2E66)
        #expect(GridKit.halfBits(1e-5) == 0x00A8) // subnormal
    }

    @Test("Shatter shard sites follow the double-precision seededRandom")
    func shatterSites() {
        let sites = GridShatterProgram.sites(2)
        // seededRandom(2) = frac(sin(2) * 10000) in double precision
        let x = sin(2.0) * 10000
        #expect(abs(Double(sites[0]) - (x - x.rounded(.down))) < 1e-6)
        #expect(sites.allSatisfy { $0 >= 0 && $0 < 1 })
    }
}
#endif
