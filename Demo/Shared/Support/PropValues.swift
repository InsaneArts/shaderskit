import SwiftUI
import ShadersKit

// Conversions between `PropValue` and the values SwiftUI controls edit.

extension PropValue {
    /// String form used for select options and `ui.condition` matching.
    var conditionKey: String {
        switch self {
        case .string(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return Self.format(n)
        case .dimensional(let d): return Self.format(d.value)
        case .null: return "null"
        default: return ""
        }
    }

    /// Number formatted without trailing zeros (`2`, `0.35`).
    static func format(_ value: Float) -> String {
        if value == value.rounded(), abs(value) < 1e7 { return String(Int(value)) }
        var s = String(format: "%.4f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// UV position (top-left origin), when the value is a position.
    var uvPoint: CGPoint? {
        guard case .position(let input) = self else { return nil }
        let p = ShaderPosition(input)
        guard let x = p.x.uvValue, let y = p.y.uvValue else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }

    static func uv(_ point: CGPoint) -> PropValue {
        .position(.xy(x: .number(Float(point.x)), y: .number(Float(point.y))))
    }

    /// Replaces the numeric part and keeps the unit of a dimensional value.
    func withNumber(_ value: Float) -> PropValue {
        if case .dimensional(let d) = self {
            return .dimensional(DimensionalValue(value: value, unit: d.unit))
        }
        return .number(value)
    }
}

extension AxisInput {
    var uvValue: Float? {
        switch self {
        case .number(let v): return v
        case .dimensional(let d): return d.unit == .uv ? d.value : nil
        case .keyword(let k):
            switch k {
            case "left", "top": return 0
            case "right", "bottom": return 1
            case "center": return 0.5
            default: return Float(k.replacingOccurrences(of: "%", with: "")).map { $0 / 100 }
            }
        }
    }
}

enum CSSColorBridge {
    /// SwiftUI color for a CSS color string (sRGB). Invalid strings become clear.
    static func color(_ css: String) -> Color {
        guard let c = CSSColor.parse(css) else { return .clear }
        return Color(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a))
    }

    /// `#rrggbb` (or `#rrggbbaa` when translucent) for a SwiftUI color.
    static func hex(_ color: Color) -> String {
        let r = color.resolve(in: EnvironmentValues())
        return hex(r: r.red, g: r.green, b: r.blue, a: r.opacity)
    }

    static func hex(r: Float, g: Float, b: Float, a: Float) -> String {
        func byte(_ v: Float) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        if byte(a) >= 255 {
            return String(format: "#%02x%02x%02x", byte(r), byte(g), byte(b))
        }
        return String(format: "#%02x%02x%02x%02x", byte(r), byte(g), byte(b), byte(a))
    }

    /// Normalizes any CSS color to hex (used by the code exporter and the color label).
    static func hex(css: String) -> String {
        guard let c = CSSColor.parse(css) else { return css }
        return hex(r: c.r, g: c.g, b: c.b, a: c.a)
    }
}

/// How the inspector edits one prop.
enum PropControl {
    case slider(ClosedRange<Double>, step: Double)
    case color
    case select([PropOption])
    case toggle
    case position
    case origin
    case stops
    case text(multiline: Bool)
    case readOnly(String)

    /// The control for a prop, or nil when the prop is hidden or internal.
    init?(_ prop: PropDescriptor) {
        if prop.ui.hidden { return nil }
        let types = prop.ui.types.filter { $0 != "map" }
        guard let type = types.first else { return nil }
        switch type {
        case "range", "number":
            let lo = Double(prop.ui.min ?? 0)
            var hi = Double(prop.ui.max ?? max(1, (prop.defaultValue.numberValue ?? 1) * 2))
            if hi <= lo { hi = lo + 1 }
            self = .slider(lo...hi, step: Double(prop.ui.step ?? 0))
        case "font-weight":
            self = .slider(100...900, step: 100)
        case "color": self = .color
        case "select": self = .select(prop.ui.options ?? [])
        case "checkbox": self = .toggle
        case "position": self = .position
        case "origin": self = .origin
        case "gradient-stops": self = .stops
        case "text", "font-family", "image-upload", "video-upload", "layer": self = .text(multiline: false)
        case "shape", "shape3d": self = .text(multiline: true)
        case "list": self = .readOnly("List")
        default: return nil
        }
    }
}

extension PropDescriptor {
    /// True when `ui.condition` allows the prop for the current values.
    func isVisible(in values: [String: PropValue], defaults: [String: PropValue]) -> Bool {
        guard let condition = ui.condition else { return true }
        for (other, allowed) in condition {
            let current = values[other] ?? defaults[other] ?? .null
            if !allowed.contains(current.conditionKey) { return false }
        }
        return true
    }
}
