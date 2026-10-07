import Testing
import Foundation
@testable import ShadersKit

@Suite("Model")
struct ModelTests {
    @Test("typed layers lower to nodes with upstream prop values")
    func layerToNode() {
        let node = LinearGradient(colorA: "#ff0000", colorB: "#0000ff", angle: 45, edges: .mirror, colorSpace: .oklch).node
        #expect(node.type == "LinearGradient")
        #expect(node.props["colorA"] == .string("#ff0000"))
        #expect(node.props["angle"] == .number(45))
        #expect(node.props["edges"] == .string("mirror"))
        #expect(node.props["colorSpace"] == .string("oklch"))
        #expect(node.props["stops"] == .null)
    }

    @Test("builder collects layers in order and modifiers set attributes")
    func builder() {
        @ShaderLayerBuilder func make(_ flag: Bool) -> [ShaderNode] {
            SolidColor(color: "#000000")
            if flag {
                Grayscale { LinearGradient() }.opacity(0.5).blendMode(.screen).layerID("gray")
            }
        }
        let nodes = make(true)
        #expect(nodes.count == 2)
        #expect(nodes[1].type == "Grayscale")
        #expect(nodes[1].children.count == 1)
        #expect(nodes[1].attributes.opacity == 0.5)
        #expect(nodes[1].attributes.blendMode == .screen)
        #expect(nodes[1].attributes.id == "gray")
        #expect(make(false).count == 1)
    }

    @Test("prop values round-trip through JSON")
    func propValueJSON() throws {
        let values: [PropValue] = [
            .number(1.5), .bool(true), .string("#fff"), .null,
            .position(.xy(x: .number(0.25), y: .dimensional(DimensionalValue(value: 20, unit: .px)))),
            .dimensional(DimensionalValue(value: 0.3, unit: .uv)),
            .colorStops([ColorStop(color: "#ff0000", position: 0), ColorStop(color: "#0000ff", position: 1)]),
            .list([["position": .position(.xy(x: .number(0.3), y: .number(0.3))), "color": .string("#ffb347"), "intensity": .number(3)]]),
        ]
        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([PropValue].self, from: data)
        #expect(decoded == values)
    }

    @Test("descriptors expose prop metadata for the inspector")
    func descriptorMetadata() throws {
        let d = try #require(ShaderRegistry.descriptor("Circle"))
        #expect(d.role == .shape)
        let radius = try #require(d.prop("radius"))
        #expect(radius.ui.units?.contains("px") == true)
        #expect(radius.ui.min == 0)
        let stroke = try #require(d.prop("strokePosition"))
        #expect(stroke.transform == .strokePosition)
        #expect(stroke.ui.options?.map(\.value) == ["outside", "center", "inside"])
        let blur = try #require(ShaderRegistry.descriptor("Blur"))
        #expect(blur.flags.requiresChild)
        #expect(blur.flags.hasCompute)
        #expect(blur.compute?.kernels.count == 2)
    }

    @Test("CSS color conversion feeds uniforms in the selected color space")
    func colorModes() {
        let p3 = ShaderColor("#1aff00").linear(mode: .displayP3Linear)
        let srgb = ShaderColor("#1aff00").linear(mode: .sRGBLinear)
        #expect(abs(p3.x - 0.18603) < 1e-3)
        #expect(abs(p3.y - 0.96715) < 1e-3)
        #expect(srgb.x < p3.x)   // sRGB primaries put more energy in the green channel
        #expect(ShaderColor.transparent.linear().w == 0)
    }
}

@Suite("Presets")
struct PresetTests {
    @Test("node trees round-trip through preset JSON")
    func presetRoundTrip() throws {
        let nodes: [ShaderNode] = [
            LinearGradient(colorA: "#111111", colorB: "#eeeeee").node,
            Pixelate(scale: 30) { ShadersKit.Circle(radius: 0.4) }.opacity(0.75).blendMode(.overlay).layerID("pix"),
            SolidColor(color: "#ff00ff").mask("pix", type: .luminance),
        ]
        let preset = ShaderPreset(name: "test", components: nodes, options: .init(toneMapping: .aces))
        let data = try preset.json()
        let back = try ShaderPreset(json: data)
        #expect(back == preset)
        #expect(back.renderOptions.toneMapping == .aces)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"type\" : \"Pixelate\""))
    }

    @Test("upstream-style preset JSON decodes")
    func upstreamShape() throws {
        let json = """
        {"components": [
            {"type": "LinearGradient", "props": {"colorA": "#0f172a", "colorB": "#7c3aed", "angle": 45}},
            {"type": "Blur", "props": {"intensity": 20}, "children": [{"type": "Circle", "props": {"radius": 0.5}}], "blendMode": "screen", "opacity": 0.5}
        ]}
        """
        let preset = try ShaderPreset(json: Data(json.utf8))
        #expect(preset.components.count == 2)
        #expect(preset.components[1].children.first?.type == "Circle")
        #expect(preset.components[1].attributes.blendMode == .screen)
        #expect(preset.components[0].props["angle"] == .number(45))
    }

    @Test("Swift source export omits defaults and nests children")
    func swiftExport() {
        let nodes: [ShaderNode] = [
            LinearGradient(colorA: "#ff0000", edges: .wrap).node,
            Blur(intensity: 12) { ShadersKit.Circle(radius: 0.3) }.opacity(0.5),
        ]
        let src = ShaderNode.swiftSource(for: nodes)
        #expect(src.contains("LinearGradient(colorA: \"#ff0000\", edges: .wrap)"))
        #expect(src.contains("Blur(intensity: 12) {"))
        #expect(src.contains("ShadersKit.Circle(radius: 0.3)"))
        #expect(src.contains(".opacity(0.5)"))
        #expect(!src.contains("colorB"))
    }
}

@Suite("Uniform packing")
struct UniformPackingTests {
    @Test("dimensional px values resolve against the canvas")
    func dimensionalPx() throws {
        let desc = try #require(ShaderRegistry.descriptor("Circle"))
        let pk = UniformPacker(descriptor: desc)
        let buf = UnsafeMutableRawPointer.allocate(byteCount: pk.size, alignment: 16)
        defer { buf.deallocate() }
        let frame = FrameInput(pixelSize: SIMD2(400, 200))
        pk.pack(props: ["radius": .dimensional(.px(100))], state: NodeState(), frame: frame, options: RenderOptions(), into: buf)
        let field = try #require(desc.uniformLayout.field("n_x.radius"))
        let v = buf.load(fromByteOffset: field.offset, as: Float.self)
        #expect(abs(v - 0.5) < 1e-5)   // canvas-height conversion: 100px / 200px
        pk.pack(props: ["center": .position(.xy(x: .dimensional(.px(40)), y: .number(0.25)))], state: NodeState(), frame: frame, options: RenderOptions(), into: buf)
        let c = try #require(desc.uniformLayout.field("n_x.center"))
        let cx = buf.load(fromByteOffset: c.offset, as: Float.self)
        let cy = buf.load(fromByteOffset: c.offset + 4, as: Float.self)
        #expect(abs(cx - 0.6) < 1e-5)      // center origin: 0.5 + 40px / 400px (upstream semantics)
        #expect(abs(cy - 0.75) < 1e-5)     // upstream y flip: 1 - 0.25
    }

    @Test("select props encode through their tables and variants are picked")
    func selectsAndVariants() throws {
        let desc = try #require(ShaderRegistry.descriptor("LinearGradient"))
        let pk = UniformPacker(descriptor: desc)
        let v = try #require(pk.selectVariant(["edges": .string("mirror"), "colorSpace": .string("oklab")]))
        #expect(v.key["edges"] == .string("mirror"))
        #expect(v.key["colorSpace"] == .string("oklab"))
        let stops = try #require(pk.selectVariant(["stops": .colorStops([ColorStop(color: "#f00", position: 0), ColorStop(color: "#0f0", position: 1)])]))
        #expect(stops.key["stops"] != .null)
        let rep = try #require(ShaderRegistry.descriptor("Repeater"))
        let mode = try #require(rep.prop("mode"))
        #expect(UniformPacker(descriptor: rep).scalar(mode, .string("radial")) == 1)
    }
}
