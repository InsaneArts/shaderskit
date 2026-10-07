import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal
import ImageIO

/// RGBA (0...1) of every pixel of a bgra8Unorm texture.
private func sdfPixels(_ tex: MTLTexture) -> [SIMD4<Float>] {
    var bytes = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
    tex.getBytes(&bytes, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
    var out: [SIMD4<Float>] = []
    out.reserveCapacity(tex.width * tex.height)
    for i in 0..<(tex.width * tex.height) {
        let b = i * 4
        let px = SIMD4<Float>(Float(bytes[b + 2]), Float(bytes[b + 1]), Float(bytes[b]), Float(bytes[b + 3]))
        out.append(px / 255)
    }
    return out
}

private struct SDFRender {
    let pixels: [SIMD4<Float>]
    let size: Int
    let errors: [String]
    let unsupported: [String]

    func at(_ x: Int, _ y: Int) -> SIMD4<Float> { pixels[y * size + x] }
    var covered: Int { pixels.filter { $0.w > 0.5 }.count }
    var transparent: Int { pixels.filter { $0.w < 0.02 }.count }
}

private func sdfRender(_ nodes: [ShaderNode], size: Int = 128, frames: Int = 3, renderer: ShaderRenderer? = nil) throws -> SDFRender {
    let device = try #require(ShaderDevice.shared)
    let r = renderer ?? ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
    var tex: MTLTexture? = nil
    var errors: [String] = []
    var unsupported: [String] = []
    for i in 0..<frames {
        let frame = FrameInput(time: Float(i) / 60, deltaTime: 1 / 60, pixelSize: SIMD2(Float(size), Float(size)))
        tex = r.renderOffscreen(nodes, frame: frame)
        errors += r.stats.compileErrors
        unsupported += r.stats.unsupportedNodes
    }
    return SDFRender(pixels: sdfPixels(try #require(tex)), size: size, errors: errors, unsupported: unsupported)
}

/// Shaders whose output is the shape alone (transparent around it).
private let sdfStandalone = [
    "BrushedMetal", "CarbonFiber", "Chrome", "Frost", "Goo", "Heatmap", "Hologram", "Holographic",
    "Irradiance", "LightEdge", "LiquidMetal", "Nebula", "Neon", "Obsidian", "Plastic", "ThinFilm", "Water", "Voxels",
]

/// Shaders that draw only the silhouette edge of the shape.
private let sdfEdgeOnly: Set<String> = ["LightEdge", "Neon", "ThinFilm"]

@Suite("SDF family compute programs", .serialized)
struct SDFFamilyTests {
    @Test("every family shader has a registered program")
    func registered() {
        let supported = Set(ComputePrograms.supportedShaders)
        for name in sdfStandalone + ["Glass", "Crystal", "Emboss"] {
            #expect(supported.contains(name), "\(name) has no compute program")
        }
    }

    @Test("standalone shape shaders draw the default sphere and nothing around it", arguments: sdfStandalone)
    func standalone(_ name: String) throws {
        let out = try sdfRender([ShaderNode(type: name)])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(!out.unsupported.contains(name))
        // The default sphere (radius 0.35 of the field) covers the centre and leaves the corners empty.
        if sdfEdgeOnly.contains(name) {
            // Edge-only looks (neon tube, rim light, soap-bubble film): an opaque ring on the
            // silhouette (radius ≈ 0.35 · 128 px) around a see-through interior.
            #expect(out.at(64, 64).w < 0.5, "\(name) centre alpha \(out.at(64, 64).w)")
            let ring = (0..<360).map { a -> Float in
                let t = Double(a) * Double.pi / 180
                return (40...50).map { r in out.at(64 + Int(Double(r) * cos(t)), 64 + Int(Double(r) * sin(t))).w }.max()!
            }
            #expect(ring.filter { $0 > 0.5 }.count > 180, "\(name) ring coverage")
            #expect(out.covered > 300, "\(name) covered \(out.covered)")
        } else {
            #expect(out.at(64, 64).w > 0.5, "\(name) centre alpha \(out.at(64, 64).w)")
            #expect(out.covered > 128 * 128 / 10, "\(name) covered \(out.covered)")
        }
        #expect(out.transparent > 128 * 4, "\(name) transparent \(out.transparent)")
        #expect(out.at(1, 1).w < 0.02 || name == "Irradiance", "\(name) corner alpha \(out.at(1, 1).w)")
    }

    @Test("Glass and Crystal with cutout keep only the lens", arguments: ["Glass", "Crystal"])
    func cutoutFilters(_ name: String) throws {
        let child = SolidColor(color: "#4080ff").node
        let out = try sdfRender([ShaderNode(type: name, props: ["cutout": true], children: [child])])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(!out.unsupported.contains(name))
        #expect(out.at(64, 64).w > 0.5, "\(name) centre alpha \(out.at(64, 64).w)")
        #expect(out.covered > 128 * 128 / 10, "\(name) covered \(out.covered)")
        #expect(out.transparent > 128 * 4, "\(name) transparent \(out.transparent)")
    }

    @Test("Emboss reliefs the child inside the shape only")
    func emboss() throws {
        let child = SolidColor(color: "#808080").node
        let plain = try sdfRender([child], frames: 1)
        let out = try sdfRender([ShaderNode(type: "Emboss", children: [child])])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(!out.unsupported.contains("Emboss"))
        // Outside the shape the child passes through; the relief changes pixels inside it.
        #expect(simd_length(out.at(2, 2) - plain.at(2, 2)) < 0.02)
        let changed = (0..<out.pixels.count).filter { simd_length(out.pixels[$0] - plain.pixels[$0]) > 0.02 }.count
        #expect(changed > 200, "Emboss changed \(changed) pixels")
    }

    @Test("other analytic 3D shapes march through the patched kernel", arguments: [
        "{\"type\":\"cube3D\"}", "{\"type\":\"torus3D\"}", "{\"type\":\"metaballs3D\"}",
        "{\"type\":\"gyroscope3D\"}", "{\"type\":\"gem3D\"}", "{\"type\":\"ribbon3D\"}",
    ])
    func shapes(_ shape: String) throws {
        let out = try sdfRender([ShaderNode(type: "Plastic", props: ["shape": .string(shape)])])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(out.covered > 300, "\(shape) covered \(out.covered)")
        #expect(out.transparent > 128 * 4, "\(shape) transparent \(out.transparent)")
    }

    @Test("Voxels bakes other shapes too")
    func voxelsCube() throws {
        let out = try sdfRender([ShaderNode(type: "Voxels", props: ["shape": "{\"type\":\"torus3D\"}"])])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(out.covered > 300, "covered \(out.covered)")
        #expect(out.transparent > 128 * 4, "transparent \(out.transparent)")
    }

    @Test("a shape switch at runtime re-routes the march")
    func shapeSwitch() throws {
        let device = try #require(ShaderDevice.shared)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        let sphere = try sdfRender([ShaderNode(type: "Chrome")], renderer: renderer)
        let cube = try sdfRender([ShaderNode(type: "Chrome", props: ["shape": "{\"type\":\"cube3D\",\"sizeX\":0.2,\"sizeY\":0.2,\"sizeZ\":0.2}"])], renderer: renderer)
        #expect(sphere.errors.isEmpty && cube.errors.isEmpty, "\(sphere.errors + cube.errors)")
        #expect(cube.covered != sphere.covered)
    }

    @Test("an unsupported flat shape draws nothing instead of garbage")
    func flatShape() throws {
        let out = try sdfRender([ShaderNode(type: "Plastic", props: ["shape": "{\"type\":\"circleSDF\",\"radius\":0.3}"])])
        #expect(out.errors.isEmpty, "\(out.errors)")
        #expect(out.covered == 0)
    }

    @Test("the field is only re-marched when the shape state changes")
    func dirtyTracking() {
        let setup = SDFShape3DSetup(type: "sphere3D", initialConfig: ["type": "sphere3D", "radius": 0.35], shapeJSON: "{\"type\":\"sphere3D\",\"radius\":0.35}")
        let k0 = setup.stateKey
        setup.update(shapeJSON: "{\"type\":\"sphere3D\",\"radius\":0.35}", deltaTime: 1 / 60, pointer: SIMD2(0.5, 0.5))
        #expect(setup.stateKey == k0)
        setup.update(shapeJSON: "{\"type\":\"sphere3D\",\"radius\":0.3}", deltaTime: 1 / 60, pointer: SIMD2(0.5, 0.5))
        #expect(setup.stateKey != k0)
        #expect(abs(setup.rBound - 0.32) < 1e-9)
        #expect(abs(setup.footprint.spanX - 0.74) < 1e-9)
        #expect(abs(setup.footprint.originX - 0.13) < 1e-9)
        // An auto-animated rotation changes the key every frame.
        let spin = "{\"type\":\"cube3D\",\"rotY\":{\"type\":\"auto-animate\",\"outputMin\":0,\"outputMax\":360,\"mode\":\"loop\",\"easing\":\"linear\"}}"
        let animated = SDFShape3DSetup(type: "cube3D", initialConfig: [:], shapeJSON: spin)
        animated.update(shapeJSON: spin, deltaTime: 0.5, pointer: SIMD2(0.5, 0.5))
        let a = animated.stateKey
        animated.update(shapeJSON: spin, deltaTime: 0.5, pointer: SIMD2(0.5, 0.5))
        #expect(animated.stateKey != a)
        // 1 s at 0.2 cycles/s → 72°.
        #expect(abs(animated.rotation.sy - sin(72 * Double.pi / 180)) < 1e-9)
    }

    @Test("dump PNGs (SDF_DUMP=dir)")
    func dump() throws {
        guard let dir = ProcessInfo.processInfo.environment["SDF_DUMP"] else { return }
        let device = try #require(ShaderDevice.shared)
        for name in ["LightEdge", "Neon", "ThinFilm", "Plastic"] {
            let r = ShaderRenderer(device: device)
            for i in 0..<3 { _ = r.renderImage([ShaderNode(type: name)], size: CGSize(width: 256, height: 256), time: Float(i) / 60) }
            let img = try #require(r.renderImage([ShaderNode(type: name)], size: CGSize(width: 256, height: 256), time: 0.05))
            let url = URL(fileURLWithPath: dir).appendingPathComponent("sdf-\(name).png") as CFURL
            let dest = try #require(CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, img, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
    }

    @Test("active resolution snaps to the footprint buckets")
    func activeRes() {
        guard !SDFKit.isMobileGpuViewport else { return }
        #expect(SDFKit.resolveActiveFieldRes(spanX: 0.84, spanY: 0.84, scale: 1, canvasHeightDevicePx: 128, maxRes: 1536, prevRes: 1536) == 256)
        #expect(SDFKit.resolveActiveFieldRes(spanX: 0.84, spanY: 0.84, scale: 1, canvasHeightDevicePx: 1000, maxRes: 1536, prevRes: 0) == 896)
        // Shrink deadband: stays at the previous bucket while the footprint is above 78 % of it.
        #expect(SDFKit.resolveActiveFieldRes(spanX: 0.84, spanY: 0.84, scale: 1, canvasHeightDevicePx: 900, maxRes: 1536, prevRes: 896) == 896)
        #expect(SDFKit.resolveActiveFieldRes(spanX: 0.84, spanY: 0.84, scale: 0, canvasHeightDevicePx: 900, maxRes: 1536, prevRes: 896) == 1536)
    }
}
#endif
