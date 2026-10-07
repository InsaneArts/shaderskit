import Foundation
import simd

/// The value kinds a list item field can hold. Mirrors upstream `ListItemFieldKind`.
public enum ListItemFieldKind: String, Equatable, Sendable {
    case position
    case color
    case number
    case boolean
}

/// A raw list item field value.
public enum ListItemValue: Equatable, Sendable {
    case number(Float)
    case string(String)
    case position(PositionInput)
    case bool(Bool)
}

/// One field of a list prop item: its name, kind, default and UI hints.
///
/// Mirrors upstream `ListItemFieldConfig`, plus the field name (the record key upstream).
public struct ListItemFieldConfig: Equatable, Sendable {
    public var name: String
    public var kind: ListItemFieldKind
    /// Upstream `default`: the value used when an item does not set this field.
    public var defaultValue: ListItemValue
    public var label: String?
    public var description: String?
    public var min: Float?
    public var max: Float?
    public var step: Float?

    public init(
        name: String,
        kind: ListItemFieldKind,
        defaultValue: ListItemValue,
        label: String? = nil,
        description: String? = nil,
        min: Float? = nil,
        max: Float? = nil,
        step: Float? = nil
    ) {
        self.name = name
        self.kind = kind
        self.defaultValue = defaultValue
        self.label = label
        self.description = description
        self.min = min
        self.max = max
        self.step = step
    }
}

/// The spec of a list prop. Mirrors upstream `ListPropSpec`.
///
/// `fields` is upstream `item` (a record keyed by field name). It is an array here so the
/// declaration order of the fields is kept.
public struct ListPropSpec: Equatable, Sendable {
    public var fields: [ListItemFieldConfig]
    public var maxItems: Int
    public var minItems: Int?
    public var itemLabel: String?

    public init(fields: [ListItemFieldConfig], maxItems: Int, minItems: Int? = nil, itemLabel: String? = nil) {
        self.fields = fields
        self.maxItems = maxItems
        self.minItems = minItems
        self.itemLabel = itemLabel
    }
}

/// A resolved list item field: a position in the `(x, 1 - y)` convention, a linear RGBA color,
/// or a number (booleans resolve to ±1).
public enum ResolvedListValue: Equatable, Sendable {
    case position(SIMD2<Float>)
    case color(SIMD4<Float>)
    case number(Float)
}

/// A resolved list item, keyed by field name. Mirrors upstream `ResolvedListItem`.
public typealias ResolvedListItem = [String: ResolvedListValue]

/// A list packed into per-field vec4 lanes. Mirrors the return value of upstream `packList`.
public struct PackedList: Equatable, Sendable {
    /// Number of items (upstream `count`).
    public var count: Int
    /// Per field name: `maxItems * 4` floats, one vec4 lane per item.
    public var fields: [String: [Float]]

    public init(count: Int, fields: [String: [Float]]) {
        self.count = count
        self.fields = fields
    }
}

/// Ports of upstream `utilities/listProps.ts`. Mouse-position drivers are not supported.
public enum ListProps {

    /// Uniform name of one field array: `<prop>_<field>`.
    public static func listFieldName(_ prop: String, _ field: String) -> String {
        "\(prop)_\(field)"
    }

    /// Uniform name of the item count: `<prop>Count`.
    public static func listCountName(_ prop: String) -> String {
        "\(prop)Count"
    }

    /// Port of `resolveListItems`: drops items past `maxItems` and resolves every field.
    ///
    /// A missing field takes the field default. Positions go through
    /// `PropTransforms.transformPosition`, colors through `CSSColor.linear(_:mode:)`.
    public static func resolveListItems(
        _ items: [[String: ListItemValue]],
        spec: ListPropSpec,
        mode: ColorSpaceMode = .displayP3Linear
    ) -> [ResolvedListItem] {
        items.prefix(max(0, spec.maxItems)).map { item in
            var out: ResolvedListItem = [:]
            for field in spec.fields {
                let value = item[field.name] ?? field.defaultValue
                out[field.name] = resolveField(field.kind, value, mode: mode)
            }
            return out
        }
    }

    private static func resolveField(_ kind: ListItemFieldKind, _ value: ListItemValue, mode: ColorSpaceMode) -> ResolvedListValue {
        switch kind {
        case .position:
            switch value {
            case .position(let p): return .position(PropTransforms.transformPosition(p))
            case .string(let s): return .position(PropTransforms.transformPosition(.keyword(s)))
            default: return .position(SIMD2(0.5, 0.5))
            }
        case .color:
            let css: String
            if case .string(let s) = value { css = s } else { css = "#ffffff" }
            let c = CSSColor.linear(css, mode: mode)
            return .color(SIMD4(c.r, c.g, c.b, c.a))
        case .boolean:
            return .number(isTruthy(value) ? 1 : -1)
        case .number:
            if case .number(let n) = value { return .number(n) }
            return .number(0)
        }
    }

    /// JavaScript truthiness of a field value.
    private static func isTruthy(_ value: ListItemValue) -> Bool {
        switch value {
        case .bool(let b): return b
        case .number(let n): return n != 0 && !n.isNaN
        case .string(let s): return !s.isEmpty
        case .position: return true
        }
    }

    /// Port of `listFieldLane`: a resolved field as its vec4 lane. A missing field gives zeros.
    public static func listFieldLane(_ value: ResolvedListValue?) -> SIMD4<Float> {
        switch value {
        case .number(let n)?: return SIMD4(n, 0, 0, 0)
        case .color(let c)?: return c
        case .position(let p)?: return SIMD4(p.x, p.y, 0, 0)
        case nil: return .zero
        }
    }

    /// Port of `packList`: packs resolved items into flat `maxItems * 4` float lanes per field.
    public static func packList(_ items: [ResolvedListItem], spec: ListPropSpec) -> PackedList {
        let maxItems = max(0, spec.maxItems)
        var fields: [String: [Float]] = [:]
        for field in spec.fields {
            var lanes = [Float](repeating: 0, count: maxItems * 4)
            for i in 0..<min(items.count, maxItems) {
                let lane = listFieldLane(items[i][field.name])
                lanes[i * 4] = lane.x
                lanes[i * 4 + 1] = lane.y
                lanes[i * 4 + 2] = lane.z
                lanes[i * 4 + 3] = lane.w
            }
            fields[field.name] = lanes
        }
        return PackedList(count: items.count, fields: fields)
    }
}
