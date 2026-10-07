import Foundation

// JSON coding for layer trees. The format mirrors the upstream JavaScript `createShader` preset
// shape (`{ "type": "LinearGradient", "props": { ... }, "children": [ ... ] }`) extended with the
// per-layer attributes, so compositions can be saved, shared and loaded on every platform.

extension LayerTransform {}

extension MaskConfig: Codable {
    private enum CodingKeys: String, CodingKey { case source, node, type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(MaskType.self, forKey: .type) ?? .alpha
        if let id = try c.decodeIfPresent(String.self, forKey: .source) {
            self.init(source: .layer(id), type: type)
        } else {
            self.init(source: .node(try c.decode(ShaderNode.self, forKey: .node)), type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        switch source {
        case .layer(let id): try c.encode(id, forKey: .source)
        case .node(let n): try c.encode(n, forKey: .node)
        }
    }
}

extension LayerAttributes: Codable {
    private enum CodingKeys: String, CodingKey { case blendMode, opacity, visible, id, mask, transform }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            blendMode: try c.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal,
            opacity: try c.decodeIfPresent(Float.self, forKey: .opacity) ?? 1,
            visible: try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true,
            id: try c.decodeIfPresent(String.self, forKey: .id),
            mask: try c.decodeIfPresent(MaskConfig.self, forKey: .mask),
            transform: try c.decodeIfPresent(LayerTransform.self, forKey: .transform)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if blendMode != .normal { try c.encode(blendMode, forKey: .blendMode) }
        if opacity != 1 { try c.encode(opacity, forKey: .opacity) }
        if !visible { try c.encode(visible, forKey: .visible) }
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(mask, forKey: .mask)
        if let t = transform, !t.isIdentity || t.edges != .transparent { try c.encode(t, forKey: .transform) }
    }
}

extension ShaderNode: Codable {
    private enum CodingKeys: String, CodingKey { case type, props, children, blendMode, opacity, visible, id, mask, transform }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let props = try c.decodeIfPresent([String: PropValue].self, forKey: .props) ?? [:]
        let children = try c.decodeIfPresent([ShaderNode].self, forKey: .children) ?? []
        let attributes = try LayerAttributes(from: decoder)
        self.init(type: type, props: props, children: children, attributes: attributes)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        if !props.isEmpty { try c.encode(props, forKey: .props) }
        if !children.isEmpty { try c.encode(children, forKey: .children) }
        try attributes.encode(to: encoder)
    }
}

/// A saved composition: the upstream preset document shape (`components` top-to-bottom).
public struct ShaderPreset: Codable, Equatable, Sendable {
    public var name: String?
    public var components: [ShaderNode]
    public var options: PresetOptions?

    public struct PresetOptions: Codable, Equatable, Sendable {
        public var toneMapping: ToneMapping?
        public var colorSpace: String?
        public var background: String?
        public init(toneMapping: ToneMapping? = nil, colorSpace: String? = nil, background: String? = nil) {
            self.toneMapping = toneMapping
            self.colorSpace = colorSpace
            self.background = background
        }
    }

    public init(name: String? = nil, components: [ShaderNode], options: PresetOptions? = nil) {
        self.name = name
        self.components = components
        self.options = options
    }

    public init(json data: Data) throws {
        self = try JSONDecoder().decode(ShaderPreset.self, from: data)
    }

    public func json(prettyPrinted: Bool = true) throws -> Data {
        let e = JSONEncoder()
        if prettyPrinted { e.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try e.encode(self)
    }

    /// Render options derived from the preset's `options`.
    public var renderOptions: RenderOptions {
        var o = RenderOptions()
        if let t = options?.toneMapping { o.toneMapping = t }
        if options?.colorSpace == "srgb" { o.colorSpace = .sRGBLinear }
        if let bg = options?.background {
            let c = ShaderColor(bg).linear(mode: o.colorSpace)
            o.backgroundColor = c
        }
        return o
    }
}

// MARK: - Swift code export

public extension ShaderNode {
    /// Component names that also exist in SwiftUI or the standard library and must be qualified
    /// as `ShadersKit.<Name>` in files that import both.
    static let swiftUIClashingNames: Set<String> = ["Circle", "Ellipse", "Text", "Group", "Grid", "Glass", "Mirror", "LinearGradient", "RadialGradient", "MeshGradient"]

    /// A Swift source snippet (`ShaderView { ... }` body) that recreates this node tree with the
    /// typed layer API. Props equal to their defaults are omitted.
    static func swiftSource(for nodes: [ShaderNode]) -> String {
        var lines: [String] = ["ShaderView {"]
        for n in nodes { lines.append(contentsOf: n.swiftLines(indent: "    ")) }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func swiftLines(indent: String) -> [String] {
        let desc = ShaderRegistry.descriptor(type)
        var args: [String] = []
        if let desc {
            for p in desc.props {
                guard let v = props[p.name], v != p.defaultValue, !v.isNull else { continue }
                args.append("\(p.name): \(Self.swiftLiteral(v, prop: p))")
            }
        } else {
            for (k, v) in props.sorted(by: { $0.key < $1.key }) { args.append("\(k): \(Self.swiftLiteral(v, prop: nil))") }
        }
        let typeName = ShaderNode.swiftUIClashingNames.contains(type) ? "ShadersKit.\(type)" : type
        var head = "\(indent)\(typeName)(\(args.joined(separator: ", ")))"
        var out: [String] = []
        if children.isEmpty {
            out.append(head)
        } else {
            head += " {"
            out.append(head)
            for c in children { out.append(contentsOf: c.swiftLines(indent: indent + "    ")) }
            out.append("\(indent)}")
        }
        var mods: [String] = []
        if attributes.blendMode != .normal { mods.append(".blendMode(.\(Self.caseName(attributes.blendMode.rawValue)))") }
        if attributes.opacity != 1 { mods.append(".opacity(\(Self.num(attributes.opacity)))") }
        if !attributes.visible { mods.append(".visible(false)") }
        if let id = attributes.id { mods.append(".layerID(\"\(id)\")") }
        if let m = attributes.mask, case .layer(let id) = m.source { mods.append(".mask(\"\(id)\", type: .\(m.type.rawValue))") }
        if let t = attributes.transform, !t.isIdentity { mods.append(".layerTransform(LayerTransform(offsetX: \(Self.num(t.offsetX)), offsetY: \(Self.num(t.offsetY)), rotation: \(Self.num(t.rotation)), scale: \(Self.num(t.scale))))") }
        for m in mods { out[out.count - 1] += "" ; out.append("\(indent)    \(m)") }
        return out
    }

    private static func num(_ v: Float) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.4g", v)
    }

    private static func caseName(_ raw: String) -> String {
        let parts = raw.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard let first = parts.first else { return raw }
        return ([first.prefix(1).lowercased() + first.dropFirst()] + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }).joined()
    }

    private static func swiftLiteral(_ v: PropValue, prop: PropDescriptor?) -> String {
        switch v {
        case .number(let n): return num(n)
        case .bool(let b): return b ? "true" : "false"
        case .string(let s):
            if let prop, prop.ui.options != nil || prop.transform == .edges || prop.transform == .colorSpace || prop.transform == .strokePosition || prop.ui.types.contains("origin") {
                return ".\(caseName(s))"
            }
            return "\"\(s)\""
        case .position(let p):
            if case .xy(let x, let y) = p, case .number(let xv) = x, case .number(let yv) = y { return "ShaderPosition(x: \(num(xv)), y: \(num(yv)))" }
            return "ShaderPosition(\(PropTransforms.transformPosition(p).x), \(1 - PropTransforms.transformPosition(p).y))"
        case .dimensional(let d): return d.unit == .px ? ".px(\(num(d.value)))" : num(d.value)
        case .colorStops(let stops): return "[" + stops.map { "ColorStop(color: \"\($0.color)\", position: \(num($0.position)))" }.joined(separator: ", ") + "]"
        case .list: return "[]"
        case .null: return "nil"
        }
    }
}
