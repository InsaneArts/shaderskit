import SwiftUI
import ShadersKit

/// Generates the `ShaderView { … }` Swift snippet for a node tree, using the typed layer
/// structs and emitting only props that differ from their defaults.
enum CodeExporter {
    /// Type names that SwiftUI also declares; the snippet qualifies them with the module.
    static let qualified: Set<String> = ["Circle", "Ellipse", "Text", "Group", "Grid", "Glass", "Mirror", "LinearGradient", "RadialGradient", "MeshGradient"]

    static func swift(for nodes: [ShaderNode], viewName: String = "MyShaderView", imports: Bool = true) -> String {
        var lines = imports ? ["import SwiftUI", "import ShadersKit", ""] : []
        lines += ["struct \(viewName): View {", "    var body: some View {", "        ShaderView {"]
        for node in nodes { emit(node, indent: 3, into: &lines) }
        lines += ["        }", "    }", "}"]
        return lines.joined(separator: "\n")
    }

    private static func emit(_ node: ShaderNode, indent: Int, into lines: inout [String]) {
        let pad = String(repeating: "    ", count: indent)
        guard let descriptor = ShaderRegistry.descriptor(node.type) else {
            lines.append("\(pad)ShaderNode(type: \(quote(node.type)))")
            return
        }
        var args: [String] = []
        var fallbacks: [String] = []
        for prop in descriptor.props {
            guard let value = node.props[prop.name], !value.isNull, value != prop.defaultValue else { continue }
            if let literal = literal(value, for: prop) {
                args.append("\(prop.name): \(literal)")
            } else {
                fallbacks.append(".prop(\(quote(prop.name)), \(propValueLiteral(value)))")
            }
        }
        let typeName = qualified.contains(node.type) ? "ShadersKit.\(node.type)" : node.type
        let call = args.isEmpty ? typeName : "\(typeName)(\(args.joined(separator: ", ")))"
        if descriptor.acceptsChildren, !node.children.isEmpty {
            lines.append("\(pad)\(call) {")
            for child in node.children { emit(child, indent: indent + 1, into: &lines) }
            lines.append("\(pad)}")
        } else {
            lines.append("\(pad)\(args.isEmpty ? typeName + "()" : call)")
        }
        let modPad = pad + "    "
        for fallback in fallbacks { lines.append(modPad + fallback) }
        let a = node.attributes
        if a.blendMode != .normal { lines.append("\(modPad).blendMode(.\(String(describing: a.blendMode)))") }
        if a.opacity != 1 { lines.append("\(modPad).opacity(\(PropValue.format(a.opacity)))") }
        if !a.visible { lines.append("\(modPad).visible(false)") }
        if let id = a.id { lines.append("\(modPad).layerID(\(quote(id)))") }
        if let t = a.transform, !t.isIdentity {
            lines.append("\(modPad).layerTransform(LayerTransform(offsetX: \(PropValue.format(t.offsetX)), offsetY: \(PropValue.format(t.offsetY)), rotation: \(PropValue.format(t.rotation)), scale: \(PropValue.format(t.scale))))")
        }
        if let mask = a.mask, case .layer(let ref) = mask.source {
            lines.append("\(modPad).mask(\(quote(ref)), type: .\(String(describing: mask.type)))")
        }
    }

    /// A typed argument literal, or nil when the value needs the dynamic `.prop` modifier.
    private static func literal(_ value: PropValue, for prop: PropDescriptor) -> String? {
        let type = prop.ui.types.first { $0 != "map" } ?? ""
        switch (type, value) {
        case ("color", .string(let css)):
            return quote(CSSColorBridge.hex(css: css))
        case (_, .number(let n)) where type != "select" && type != "checkbox":
            return PropValue.format(n)
        case (_, .dimensional(let d)):
            return d.unit == .px ? ".px(\(PropValue.format(d.value)))" : PropValue.format(d.value)
        case ("checkbox", _):
            return (value.boolValue ?? false) ? "true" : "false"
        case ("position", .position(let input)):
            let p = ShaderPosition(input)
            guard let x = p.x.uvValue, let y = p.y.uvValue else { return nil }
            return "ShaderPosition(x: \(PropValue.format(x)), y: \(PropValue.format(y)))"
        case ("origin", .string(let raw)):
            return ShaderOrigin(rawValue: raw).map { ".\(String(describing: $0))" }
        case ("select", _):
            let raw = value.conditionKey
            switch prop.transform {
            case .colorSpace: return ColorSpace(rawValue: raw).map { ".\(String(describing: $0))" }
            case .edges: return EdgeMode(rawValue: raw).map { ".\(String(describing: $0))" }
            case .strokePosition: return StrokePosition(rawValue: raw).map { ".\(String(describing: $0))" }
            default: return enumCaseName(raw).map { ".\($0)" }
            }
        case ("gradient-stops", .colorStops(let stops)):
            let items = stops.map { "ColorStop(\(quote(CSSColorBridge.hex(css: $0.color))), at: \(PropValue.format($0.position)))" }
            return "[\(items.joined(separator: ", "))]"
        case (_, .string(let s)):
            return quote(s)
        case (_, .bool(let b)):
            return b ? "true" : "false"
        default:
            return nil
        }
    }

    /// Mirrors the generator's enum case naming: "top-left" → topLeft, "IBM Plex Mono" → ibmPlexMono.
    static func enumCaseName(_ raw: String) -> String? {
        let words = raw.split { $0 == "-" || $0 == " " || $0 == "_" }.map(String.init)
        guard let first = words.first, first.first?.isLetter == true else { return nil }
        var out = first.allSatisfy { $0.isUppercase || $0.isNumber } ? first.lowercased() : first.prefix(1).lowercased() + first.dropFirst()
        for word in words.dropFirst() { out += word.prefix(1).uppercased() + word.dropFirst() }
        return out
    }

    private static func propValueLiteral(_ value: PropValue) -> String {
        switch value {
        case .number(let n): return PropValue.format(n)
        case .bool(let b): return b ? "true" : "false"
        case .string(let s): return quote(s)
        default: return "nil"
        }
    }

    private static func quote(_ s: String) -> String {
        if s.contains("\"") || s.contains("\\") { return "#\"\(s)\"#" }
        return "\"\(s)\""
    }
}

/// Syntax-highlighted code with copy and share.
struct CodeExportSheet: View {
    let title: String
    let code: String
    /// When set, the toolbar offers "Copy Agent Prompt" for this tree.
    var promptNodes: [ShaderNode]? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var copied = 0
    @State private var showPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                Text(SwiftHighlighter.highlight(code, scheme: .dark))
                    .font(.system(.callout, design: .monospaced))
                    #if !os(tvOS)
                    .textSelection(.enabled)
                    #endif
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.11))
            .environment(\.colorScheme, .dark)
            .navigationTitle("\(title).swift")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if promptNodes != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showPrompt = true
                        } label: {
                            Label("Agent Prompt", systemImage: "sparkles")
                        }
                    }
                }
                if Pasteboard.isAvailable {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Pasteboard.copy(code)
                            copied += 1
                        } label: {
                            Label(copied > 0 ? "Copied" : "Copy", systemImage: copied > 0 ? "checkmark" : "doc.on.doc")
                        }
                        .impactHaptic(trigger: copied)
                    }
                }
            }
        }
        .sheet(isPresented: $showPrompt) {
            AgentPromptSheet(title: title, nodes: promptNodes ?? [])
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
    }
}

/// Swift syntax colouring with Xcode-like palettes for dark and light appearance.
enum SwiftHighlighter {
    struct Palette {
        let base, keyword, type, member, string, number, comment: Color
    }

    static func palette(_ scheme: ColorScheme) -> Palette {
        func c(_ hex: UInt32) -> Color {
            Color(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
        }
        return scheme == .dark
            ? Palette(base: c(0xDFDFE4), keyword: c(0xF27BB5), type: c(0x8DCCF2), member: c(0x7FC8B4), string: c(0xF08D77), number: c(0xD9C97C), comment: c(0x7F8C98))
            : Palette(base: c(0x1D1D22), keyword: c(0xAD3DA4), type: c(0x2B6B94), member: c(0x2F7A70), string: c(0xC4402F), number: c(0x2F45C2), comment: c(0x707F8C))
    }

    static func highlight(_ code: String, scheme: ColorScheme = .dark) -> AttributedString {
        let p = palette(scheme)
        var text = AttributedString(code)
        text.foregroundColor = p.base
        apply(#"\b[A-Z][A-Za-z0-9]*\b"#, p.type, to: &text, in: code)
        apply(#"\.[a-z][A-Za-z0-9]*"#, p.member, to: &text, in: code)
        apply(#"\b(import|struct|var|let|some|true|false|nil|func|return)\b"#, p.keyword, to: &text, in: code)
        apply(#"(?<![A-Za-z_])-?\d+(\.\d+)?\b"#, p.number, to: &text, in: code)
        apply(##"#?"[^"\n]*"#?"##, p.string, to: &text, in: code)
        apply(#"//[^\n]*"#, p.comment, to: &text, in: code)
        return text
    }

    private static func apply(_ pattern: String, _ color: Color, to text: inout AttributedString, in code: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            if let range = Range(match.range, in: text) {
                text[range].foregroundColor = color
            }
        }
    }
}
