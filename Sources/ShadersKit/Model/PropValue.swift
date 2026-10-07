import Foundation
import simd

/// A dynamically typed prop value, the currency between typed layer structs, presets, the
/// inspector UI and the renderer. Mirrors the JavaScript values the upstream components accept.
public enum PropValue: Equatable, Sendable {
    case number(Float)
    case bool(Bool)
    case string(String)
    case position(PositionInput)
    case dimensional(DimensionalValue)
    case colorStops([ColorStop])
    case list([[String: ListItemValue]])
    case null

    public var numberValue: Float? {
        switch self {
        case .number(let v): return v
        case .bool(let b): return b ? 1 : 0
        case .dimensional(let d): return d.value
        case .string(let s): return Float(s)
        default: return nil
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let v): return v != 0
        case .string(let s): return s == "true" ? true : s == "false" ? false : nil
        default: return nil
        }
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

extension PropValue: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByStringLiteral, ExpressibleByNilLiteral {
    public init(floatLiteral value: Double) { self = .number(Float(value)) }
    public init(integerLiteral value: Int) { self = .number(Float(value)) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(nilLiteral: ()) { self = .null }
}

// MARK: - JSON coding (presets)

extension PropValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(Float(n)); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let p = try? c.decode(PositionJSON.self) { self = .position(p.input); return }
        if let d = try? c.decode(DimensionalJSON.self), let dv = d.dimensional { self = .dimensional(dv); return }
        if let stops = try? c.decode([ColorStopJSON].self) { self = .colorStops(stops.map { ColorStop(color: $0.color, position: Float($0.position)) }); return }
        if let items = try? c.decode([[String: ListItemJSON]].self) {
            self = .list(items.map { $0.mapValues { $0.value } })
            return
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported prop value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let v): try c.encode(Double(v))
        case .bool(let b): try c.encode(b)
        case .string(let s): try c.encode(s)
        case .position(let p): try c.encode(PositionJSON(p))
        case .dimensional(let d): try c.encode(DimensionalJSON(value: d))
        case .colorStops(let stops): try c.encode(stops.map { ColorStopJSON(color: $0.color, position: Double($0.position)) })
        case .list(let items): try c.encode(items.map { $0.mapValues { ListItemJSON(value: $0) } })
        case .null: try c.encodeNil()
        }
    }
}

private struct ColorStopJSON: Codable {
    var color: String
    var position: Double
}

private struct DimensionalJSON: Codable {
    var value: Float
    var unit: String
    var dimensional: DimensionalValue? {
        guard let u = DimensionalValue.Unit(rawValue: unit) else { return nil }
        return DimensionalValue(value: value, unit: u)
    }
    init(value: DimensionalValue) {
        self.value = value.value
        self.unit = value.unit.rawValue
    }
}

private struct PositionJSON: Codable {
    var x: AxisJSON
    var y: AxisJSON

    init(_ p: PositionInput) {
        switch p {
        case .xy(let x, let y):
            self.x = AxisJSON(x)
            self.y = AxisJSON(y)
        case .keyword(let k):
            // keyword positions encode as their resolved numeric center
            let v = PropTransforms.transformPosition(.keyword(k))
            self.x = .number(v.x)
            self.y = .number(1 - v.y)
        }
    }

    var input: PositionInput { .xy(x: x.axis, y: y.axis) }
}

private enum AxisJSON: Codable {
    case number(Float)
    case keyword(String)
    case dimensional(Float, String)

    init(_ a: AxisInput) {
        switch a {
        case .number(let v): self = .number(v)
        case .keyword(let k): self = .keyword(k)
        case .dimensional(let d): self = .dimensional(d.value, d.unit.rawValue)
        }
    }

    var axis: AxisInput {
        switch self {
        case .number(let v): return .number(v)
        case .keyword(let k): return .keyword(k)
        case .dimensional(let v, let u): return .dimensional(DimensionalValue(value: v, unit: DimensionalValue.Unit(rawValue: u) ?? .uv))
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Double.self) { self = .number(Float(n)); return }
        if let s = try? c.decode(String.self) { self = .keyword(s); return }
        let d = try c.decode(DimensionalJSON.self)
        self = .dimensional(d.value, d.unit)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let v): try c.encode(Double(v))
        case .keyword(let k): try c.encode(k)
        case .dimensional(let v, let u): try c.encode(DimensionalJSON(value: DimensionalValue(value: v, unit: DimensionalValue.Unit(rawValue: u) ?? .uv)))
        }
    }
}

private struct ListItemJSON: Codable {
    var value: ListItemValue

    init(value: ListItemValue) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = .bool(b); return }
        if let n = try? c.decode(Double.self) { value = .number(Float(n)); return }
        if let s = try? c.decode(String.self) { value = .string(s); return }
        let p = try c.decode(PositionJSON.self)
        value = .position(p.input)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(Double(n))
        case .string(let s): try c.encode(s)
        case .position(let p): try c.encode(PositionJSON(p))
        }
    }
}
