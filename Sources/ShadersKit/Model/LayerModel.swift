import Foundation

/// How a layer is composited over the layers below it. Mirrors the upstream `BlendMode` union;
/// `rawValue` is the upstream string (used by presets and the design editor export).
public enum BlendMode: String, CaseIterable, Codable, Sendable, Hashable {
    case normal
    case normalOklch = "normal-oklch"
    case normalOklab = "normal-oklab"
    case multiply
    case screen
    case linearDodge
    case overlay
    case difference
    case colorDodge
    case exclusion
    case color
    case luminosity
    case darken
    case lighten
    case colorBurn
    case linearBurn
    case softLight
    case hardLight
    case hue
    case saturation

    /// Index into the compositor's blend table (matches `Compositor.metal`).
    public var shaderIndex: Int { BlendMode.allCases.firstIndex(of: self) ?? 0 }
}

/// Which channel of the mask layer drives the masked layer's alpha.
public enum MaskType: String, CaseIterable, Codable, Sendable, Hashable {
    case alpha
    case alphaInverted
    case luminance
    case luminanceInverted

    public var shaderIndex: Int { MaskType.allCases.firstIndex(of: self) ?? 0 }
}

/// Tone mapping curve applied in the present pass.
public enum ToneMapping: String, CaseIterable, Codable, Sendable, Hashable {
    case linear, reinhard, cineon, aces, agx, neutral, hable, unreal

    public var shaderIndex: Int { ToneMapping.allCases.firstIndex(of: self) ?? 0 }
}

/// Edge handling for coordinates outside 0...1 (gradients, warps, layer transforms).
public enum EdgeMode: String, CaseIterable, Codable, Sendable, Hashable {
    case stretch, transparent, mirror, wrap

    /// The uniform encoding upstream `transformEdges` produces.
    public var uniformValue: Float { Float(EdgeMode.allCases.firstIndex(of: self) ?? 0) }
}

/// Color space used when interpolating between colors.
public enum ColorSpace: String, CaseIterable, Codable, Sendable, Hashable {
    case linear, oklch, oklab, hsl, hsv, lch

    public var uniformValue: Float { Float(ColorSpace.allCases.firstIndex(of: self) ?? 0) }
}

/// Stroke placement relative to a shape's edge.
public enum StrokePosition: String, CaseIterable, Codable, Sendable, Hashable {
    case outside, center, inside

    public var uniformValue: Float { Float(StrokePosition.allCases.firstIndex(of: self) ?? 1) }
}

/// Anchor used when positioning a bounded layer.
public enum ShaderOrigin: String, CaseIterable, Codable, Sendable, Hashable {
    case center
    case topLeft = "top-left"
    case top
    case topRight = "top-right"
    case left
    case right
    case bottomLeft = "bottom-left"
    case bottom
    case bottomRight = "bottom-right"
}

/// Media sizing mode (`object-fit`).
public enum ObjectFit: String, CaseIterable, Codable, Sendable, Hashable {
    case cover, contain, fill
    case scaleDown = "scale-down"
}

/// Where a mask layer comes from.
public indirect enum MaskSource: Equatable, Sendable {
    /// Another layer in the same `ShaderView`, referenced by its `layerID`.
    case layer(String)
    /// An inline layer tree rendered only as the mask.
    case node(ShaderNode)
}

/// Mask configuration carried on a layer's attributes.
public struct MaskConfig: Equatable, Sendable {
    public var source: MaskSource
    public var type: MaskType

    public init(source: MaskSource, type: MaskType = .alpha) {
        self.source = source
        self.type = type
    }
}

/// Offset / rotation / scale applied to a finished layer before compositing.
public struct LayerTransform: Equatable, Sendable, Codable {
    public var offsetX: Float = 0
    public var offsetY: Float = 0
    /// Degrees.
    public var rotation: Float = 0
    public var scale: Float = 1
    public var anchorX: Float = 0.5
    public var anchorY: Float = 0.5
    public var edges: EdgeMode = .transparent

    public init(offsetX: Float = 0, offsetY: Float = 0, rotation: Float = 0, scale: Float = 1, anchorX: Float = 0.5, anchorY: Float = 0.5, edges: EdgeMode = .transparent) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
        self.scale = scale
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.edges = edges
    }

    public var isIdentity: Bool {
        offsetX == 0 && offsetY == 0 && rotation == 0 && scale == 1
    }
}

/// Per-layer compositing attributes (blend mode, opacity, mask, id, transform).
public struct LayerAttributes: Equatable, Sendable {
    public var blendMode: BlendMode = .normal
    public var opacity: Float = 1
    public var visible: Bool = true
    /// Stable identifier, used by masks and by simulations to keep their state across frames.
    public var id: String? = nil
    public var mask: MaskConfig? = nil
    public var transform: LayerTransform? = nil

    public init(blendMode: BlendMode = .normal, opacity: Float = 1, visible: Bool = true, id: String? = nil, mask: MaskConfig? = nil, transform: LayerTransform? = nil) {
        self.blendMode = blendMode
        self.opacity = opacity
        self.visible = visible
        self.id = id
        self.mask = mask
        self.transform = transform
    }
}

/// A node in the shader layer tree: a component type, its prop values, nested children and
/// compositing attributes. Every typed layer struct lowers to one of these.
public struct ShaderNode: Equatable, Sendable {
    /// Component name, e.g. `"LinearGradient"`.
    public var type: String
    public var props: [String: PropValue]
    public var children: [ShaderNode]
    public var attributes: LayerAttributes

    public init(type: String, props: [String: PropValue] = [:], children: [ShaderNode] = [], attributes: LayerAttributes = LayerAttributes()) {
        self.type = type
        self.props = props
        self.children = children
        self.attributes = attributes
    }

    /// The component's descriptor, when the type is part of the library.
    public var descriptor: ShaderDescriptor? { ShaderRegistry.descriptor(type) }

    /// Depth-first walk over this node and all descendants (including inline mask nodes).
    public func forEachNode(_ body: (ShaderNode) -> Void) {
        body(self)
        for c in children { c.forEachNode(body) }
        if case .node(let m)? = attributes.mask?.source { m.forEachNode(body) }
    }
}

/// Anything that can appear inside a `ShaderView` body.
public protocol ShaderLayer {
    var node: ShaderNode { get }
}

extension ShaderNode: ShaderLayer {
    public var node: ShaderNode { self }
}

/// Result builder collecting layers top-to-bottom. Layers are composited in declaration order:
/// the first layer is the bottom-most, later layers blend over it.
@resultBuilder
public enum ShaderLayerBuilder {
    public static func buildBlock(_ parts: [ShaderNode]...) -> [ShaderNode] { parts.flatMap { $0 } }
    public static func buildExpression(_ layer: any ShaderLayer) -> [ShaderNode] { [layer.node] }
    public static func buildExpression(_ layers: [any ShaderLayer]) -> [ShaderNode] { layers.map(\.node) }
    public static func buildExpression(_ nodes: [ShaderNode]) -> [ShaderNode] { nodes }
    public static func buildOptional(_ part: [ShaderNode]?) -> [ShaderNode] { part ?? [] }
    public static func buildEither(first: [ShaderNode]) -> [ShaderNode] { first }
    public static func buildEither(second: [ShaderNode]) -> [ShaderNode] { second }
    public static func buildArray(_ parts: [[ShaderNode]]) -> [ShaderNode] { parts.flatMap { $0 } }
    public static func buildLimitedAvailability(_ part: [ShaderNode]) -> [ShaderNode] { part }
}

// MARK: - Layer modifiers

public extension ShaderLayer {
    /// Sets the blend mode used when compositing this layer over the layers below.
    func blendMode(_ mode: BlendMode) -> ShaderNode {
        var n = node
        n.attributes.blendMode = mode
        return n
    }

    /// Sets the layer opacity (0...1).
    func opacity(_ value: Float) -> ShaderNode {
        var n = node
        n.attributes.opacity = value
        return n
    }

    /// Hides the layer without removing it (hidden layers can still act as mask sources).
    func visible(_ flag: Bool) -> ShaderNode {
        var n = node
        n.attributes.visible = flag
        return n
    }

    /// Gives the layer a stable identifier (mask references, simulation state).
    func layerID(_ id: String) -> ShaderNode {
        var n = node
        n.attributes.id = id
        return n
    }

    /// Masks the layer with another layer referenced by `layerID`.
    func mask(_ layerID: String, type: MaskType = .alpha) -> ShaderNode {
        var n = node
        n.attributes.mask = MaskConfig(source: .layer(layerID), type: type)
        return n
    }

    /// Masks the layer with an inline layer tree.
    func mask(type: MaskType = .alpha, @ShaderLayerBuilder _ content: () -> [ShaderNode]) -> ShaderNode {
        var n = node
        let nodes = content()
        let source: ShaderNode = nodes.count == 1 ? nodes[0] : ShaderNode(type: "Group", children: nodes)
        n.attributes.mask = MaskConfig(source: .node(source), type: type)
        return n
    }

    /// Applies an offset / rotation / scale to the finished layer.
    func layerTransform(_ transform: LayerTransform) -> ShaderNode {
        var n = node
        n.attributes.transform = transform
        return n
    }

    /// Overrides a prop by name (dynamic access, e.g. from an inspector).
    func prop(_ name: String, _ value: PropValue) -> ShaderNode {
        var n = node
        n.props[name] = value
        return n
    }
}
