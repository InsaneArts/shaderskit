import SwiftUI
import ShadersKit

/// Content placed inside filters, warps and other wrapping components when previewing them.
enum Subject: String, CaseIterable, Identifiable, Codable {
    case scene, gradient, pattern, shapes, photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scene: return "Scene"
        case .gradient: return "Gradient"
        case .pattern: return "Pattern"
        case .shapes: return "Shapes"
        case .photo: return "Photo"
        }
    }

    var symbol: String {
        switch self {
        case .scene: return "mountain.2"
        case .gradient: return "circle.lefthalf.filled"
        case .pattern: return "checkerboard.rectangle"
        case .shapes: return "star.square.on.square"
        case .photo: return "photo"
        }
    }

    /// Animated gradient used by the Gradient and Scene subjects. (`MeshGradient` would be the
    /// natural choice but currently renders a single flat color; see `PreviewFactory`.)
    private static let flow = FlowingGradient(colorA: "#1a0533", colorB: "#6d2fd1", colorC: "#ff4d6a", colorD: "#ffb347", colorSpace: .linear, speed: 0.8, distortion: 0.8).node

    var nodes: [ShaderNode] {
        switch self {
        case .gradient:
            return [Self.flow]
        case .scene:
            return [
                Self.flow,
                Star(color: "#ffffff", radius: 0.3, innerRatio: 0.45, softness: 0.004).node,
            ]
        case .pattern:
            return [
                ShadersKit.LinearGradient(colorA: "#ff3d7f", colorB: "#3d5afe", angle: 35, colorSpace: .oklch).node,
                Checkerboard(colorA: "#ffffff", colorB: "#000000", cells: 10).opacity(0.22),
                ShadersKit.Grid(color: "#ffffff", cells: 10, thickness: 1.5).opacity(0.7),
            ]
        case .shapes:
            return [
                SolidColor(color: "#0d0a1f").node,
                ShadersKit.Circle(color: "#4dd6ff", radius: 0.42, center: ShaderPosition(x: 0.28, y: 0.38)).node,
                Heart(color: "#ff4d8d", center: ShaderPosition(x: 0.72, y: 0.4), radius: 0.24).node,
                Star(color: "#ffd166", center: ShaderPosition(x: 0.5, y: 0.72), radius: 0.2).node,
            ]
        case .photo:
            return [ShaderNode(type: "ImageTexture")]
        }
    }
}

/// Builds the node tree used to preview a component.
enum PreviewFactory {
    /// Demo-side workarounds for package gaps: `FlowingGradient` draws nothing in its default
    /// `oklch` color space (its `convA`…`convD` extra fields are never computed), so previews
    /// start in `linear`. `MeshGradient` has the same kind of gap (`meshAnchors` is never
    /// computed, so every anchor sits at the origin and it renders one flat color); no prop
    /// works around that one.
    static let initialProps: [String: [String: PropValue]] = [
        "FlowingGradient": ["colorSpace": .string("linear")],
    ]

    static func initialProps(for type: String) -> [String: PropValue] {
        initialProps[type] ?? [:]
    }

    static func defaultSubject(for entry: ShaderIndexEntry) -> Subject {
        switch entry.categoryName {
        case "Distortions": return entry.role == .shapeEffect ? .gradient : .pattern
        case "Blurs": return .shapes
        default: return .scene
        }
    }

    static func defaultSubject(forType type: String) -> Subject {
        Catalog.entry(named: type).map(defaultSubject(for:)) ?? .scene
    }

    /// The component itself, wrapped around `subject` when it takes children.
    static func node(type: String, props: [String: PropValue] = [:], attributes: LayerAttributes = LayerAttributes(), subject: Subject? = nil) -> ShaderNode {
        let wraps = ShaderRegistry.descriptor(type)?.acceptsChildren ?? false
        let children = wraps ? (subject ?? defaultSubject(forType: type)).nodes : []
        return ShaderNode(type: type, props: props, children: children, attributes: attributes)
    }

    static func nodes(for entry: ShaderIndexEntry) -> [ShaderNode] {
        [node(type: entry.name, props: initialProps(for: entry.name))]
    }
}
