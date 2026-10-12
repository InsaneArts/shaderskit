import Foundation

/// Light sweeping through a glass shape, with a refracting edge and a soft halo
///
/// The shape is the alpha of the wrapped content (an image, text, a captured SwiftUI view). The
/// light loops every 6 seconds at `speed` 1.
///
/// Category: Shape Effects · Role: filter · wraps child layers · compute-backed · hand-written
public struct GlassGlow: ShaderLayer, Equatable, Sendable {

    /// Animation speed (1 = one 6 second loop)
    public var speed: Float
    /// Brightness of the light inside the glass
    public var intensity: Float
    /// Strength of the halo around the shape
    public var glow: Float
    /// How far the glass edge bends the light inward
    public var refraction: Float
    /// Colour split along the glass edge
    public var dispersion: Float
    /// Blend mode, opacity, mask, id and transform.
    public var layer: LayerAttributes
    public var children: [ShaderNode]

    public init(speed: Float = 1, intensity: Float = 1, glow: Float = 1, refraction: Float = 1, dispersion: Float = 1, layer: LayerAttributes = LayerAttributes(), @ShaderLayerBuilder content: () -> [ShaderNode] = { [] }) {
        self.speed = speed
        self.intensity = intensity
        self.glow = glow
        self.refraction = refraction
        self.dispersion = dispersion
        self.layer = layer
        self.children = content()
    }

    public static let typeName = "GlassGlow"
    public static var descriptor: ShaderDescriptor? { ShaderRegistry.descriptor(typeName) }

    public var node: ShaderNode {
        ShaderNode(type: Self.typeName, props: [
            "speed": .number(speed),
            "intensity": .number(intensity),
            "glow": .number(glow),
            "refraction": .number(refraction),
            "dispersion": .number(dispersion),
        ], children: children, attributes: layer)
    }
}
