import Testing
import SwiftUI
import Foundation
@testable import ShadersKit

/// The snippets from skills/shaderskit (SKILL.md, REFERENCE.md, RECIPES.md, components/*.md)
/// must type-check against the real API. This file mirrors them; if it stops compiling, the
/// docs are wrong.
@Suite("Skill recipes compile")
struct RecipeCompileTests {
    @ShaderLayerBuilder private func quickStart() -> [ShaderNode] {
        ShadersKit.MeshGradient()
        Vignette(intensity: 0.6) {
            ShadersKit.Circle(color: "#ff2b6e", radius: 0.4)
        }
        .blendMode(.screen)
        .opacity(0.8)
    }

    @ShaderLayerBuilder private func recipes(angle: Float, progress: Float) -> [ShaderNode] {
        Vignette(intensity: 0.5) {
            FilmGrain(strength: 0.25) {
                ShadersKit.MeshGradient(speed: 0.4)
            }
        }
        Aurora()
        Glass(scale: 0.8) { Aurora() }
        Glow(intensity: 3, size: 60) {
            Star(color: "#ffffff", radius: 0.3)
        }
        ShadersKit.LinearGradient(colorA: "#ff2b6e", colorB: "#7c3aed", angle: 45)
            .mask("logo", type: .alpha)
        Heart(color: "#ffffff", radius: 0.5).layerID("logo").visible(false)
        Liquify(intensity: 1.2) { Checkerboard(cells: 8) }
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed", angle: angle)
        IrisWipe(progress: progress) {
            ImageTexture(url: "asset:after", objectFit: .cover)
        }
        Blur(intensity: 40) {
            Checkerboard()
            ShadersKit.Circle(color: "#ff0000", radius: 0.3).blendMode(.multiply)
        }
        ShadersKit.MeshGradient(colorA: "#1a0533", colorB: "#ffdf8e", speed: 0.4)
        SunBurst(color: "#ffdd88", background: "#000000", rayCount: 12)
        Repeater(mode: .radial) { Star() }
        ShadersKit.LinearGradient(edges: .wrap, colorSpace: .oklch)
        ShadersKit.Circle(strokePosition: .inside)
        Plasma().layerTransform(LayerTransform(offsetX: 0.1, offsetY: 0, rotation: 15, scale: 1.2))
        Plasma().prop("speed", .number(2))
    }

    @Test("documented snippets type-check and lower to nodes")
    func snippets() throws {
        let nodes = quickStart() + recipes(angle: 90, progress: 0.5)
        #expect(nodes.count > 10)
        let dyn = ShaderNode(type: "LinearGradient", props: ["angle": .number(90)], children: [], attributes: LayerAttributes(opacity: 0.5))
        let json = try ShaderPreset(name: "r", components: nodes + [dyn]).json()
        let preset = try ShaderPreset(json: json)
        #expect(preset.components.count == nodes.count + 1)
        _ = ShaderNode.swiftSource(for: preset.components)
        _ = ShaderColor.rgb(1, 0.5, 0, alpha: 0.5)
        _ = ShaderColor(Color.red)
        _ = ShaderPosition.px(40, 20)
        _ = ShaderPosition.keyword("top left")
        _ = DimensionalValue.px(24)
        _ = [ColorStop("#f00", at: 0), ColorStop("#00f", at: 1)]
        _ = ShaderRegistry.descriptor("SunBurst")?.props.first?.ui.min
        #if canImport(Metal) && !os(watchOS)
        if let device = ShaderDevice.shared {
            let renderer = ShaderRenderer(device: device)
            #expect(renderer.renderImage([Plasma().node], size: CGSize(width: 32, height: 32), scale: 1) != nil)
            ViewTextureRegistry.shared.register(id: "chart") { AnyView(SwiftUI.Text("hi")) }
            _ = HTMLInCanvas().prop("source", "chart")
            _ = ShadersKit.Text(text: "Hello", fontSize: 0.1)
            _ = VideoTexture(url: "file:///missing.mp4", objectFit: .cover)
        }
        #endif
    }
}
