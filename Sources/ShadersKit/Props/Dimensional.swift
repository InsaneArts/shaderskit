import Foundation

/// A shape position or size value in pixels or UV. Mirrors upstream `DimensionalValue`.
public struct DimensionalValue: Equatable, Sendable {
    /// The unit of a dimensional value.
    public enum Unit: String, Equatable, Sendable {
        case px
        case uv
    }

    public var value: Float
    public var unit: Unit

    public init(value: Float, unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

/// How a scalar size prop converts from pixels to UV. Mirrors upstream `SizeConversion`.
public enum SizeConversion: String, Equatable, Sendable {
    /// `uv = px / canvasHeight`.
    case canvasHeight = "canvas-height"
    /// `uv = px / (2 * canvasHeight)`.
    case halfCanvasHeight = "half-canvas-height"
    /// `uv = px / canvasWidth`.
    case canvasWidth = "canvas-width"
    /// Inverse conversion: `count = canvasHeight / px`.
    case countCanvasHeight = "count-canvas-height"
}

/// One bounding-box axis binding: which prop drives the axis and how it converts.
///
/// Mirrors upstream `BoundingBoxAxisBinding`. `as` is one of `position-x`, `position-y`,
/// `half-canvas-height`, `canvas-height` or `degrees`.
public struct PropBinding: Equatable, Sendable {
    public var prop: String
    public var `as`: String

    public init(prop: String, as binding: String) {
        self.prop = prop
        self.as = binding
    }
}

/// The props that drive each bounding-box axis. Mirrors upstream `BoundingBoxPropBindings`.
public struct PropBindings: Equatable, Sendable {
    public var x: PropBinding?
    public var y: PropBinding?
    public var width: PropBinding?
    public var height: PropBinding?
    public var rotation: PropBinding?

    public init(
        x: PropBinding? = nil,
        y: PropBinding? = nil,
        width: PropBinding? = nil,
        height: PropBinding? = nil,
        rotation: PropBinding? = nil
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
}

/// The edge-softness handle of a shape: the prop and its pixel conversions.
///
/// Mirrors upstream `BoundingBoxDeclaration.softnessBinding`. The closures take
/// `(value, canvasWidth, canvasHeight)`.
public struct SoftnessBinding: Sendable {
    public var prop: String
    public var toPx: @Sendable (Float, Float, Float) -> Float
    public var fromPx: @Sendable (Float, Float, Float) -> Float

    public init(
        prop: String,
        toPx: @escaping @Sendable (Float, Float, Float) -> Float,
        fromPx: @escaping @Sendable (Float, Float, Float) -> Float
    ) {
        self.prop = prop
        self.toPx = toPx
        self.fromPx = fromPx
    }
}

/// The bounding-box declaration of a shader, reduced to the parts the prop layer reads.
///
/// Mirrors upstream `BoundingBoxDeclaration` without `computeBounds` / `writeBounds` and the
/// editor-only flags.
public struct BoundingBoxDeclaration: Sendable {
    public var propBindings: PropBindings?
    public var softnessBinding: SoftnessBinding?

    public init(propBindings: PropBindings? = nil, softnessBinding: SoftnessBinding? = nil) {
        self.propBindings = propBindings
        self.softnessBinding = softnessBinding
    }
}

/// A raw shape prop value as dimensional resolution sees it.
public enum DimensionalPropValue: Equatable, Sendable {
    case number(Float)
    case dimensional(DimensionalValue)
    case position(PositionInput)
    case string(String)
}

/// Which props of a shader are dimensional. Mirrors upstream `DimensionalPlan`.
public struct DimensionalPlan: Equatable, Sendable {
    /// Props that hold `{x, y}` positions (resolved with the origin).
    public var positionProps: Set<String>
    /// Scalar size props and their px-to-UV conversion.
    public var sizeProps: [String: SizeConversion]

    public init(positionProps: Set<String>, sizeProps: [String: SizeConversion]) {
        self.positionProps = positionProps
        self.sizeProps = sizeProps
    }
}

/// Per-axis half-extent of a shape's bounding box, in canvas UV.
public struct HalfExtents: Equatable, Sendable {
    public var hwx: Float
    public var hhy: Float

    public init(hwx: Float, hhy: Float) {
        self.hwx = hwx
        self.hhy = hhy
    }
}

/// The reference edge of one axis: left/top is `start`, right/bottom is `end`.
public enum OriginEdge: Equatable, Sendable {
    case start
    case end
    case center
}

/// Ports of upstream `utilities/dimensionalProps.ts`: px to UV conversion and origin resolution
/// for shape position and size props, against the live canvas size.
public enum DimensionalProps {

    /// Port of `buildExtraSizeProps`. Input maps a prop name to its `ui.dimensional` marker.
    /// - Returns: the props with a valid marker, or `nil` if there are none.
    public static func buildExtraSizeProps(_ markers: [String: String]) -> [String: SizeConversion]? {
        var out: [String: SizeConversion] = [:]
        for (name, marker) in markers {
            if let conversion = SizeConversion(rawValue: marker) {
                out[name] = conversion
            }
        }
        return out.isEmpty ? nil : out
    }

    /// Port of `buildDimensionalPlan`. Reads the x/y/width/height bindings and merges
    /// `extraSizeProps`.
    /// - Returns: `nil` if the shader has no dimensional props.
    public static func buildDimensionalPlan(
        _ decl: BoundingBoxDeclaration?,
        extraSizeProps: [String: SizeConversion]? = nil
    ) -> DimensionalPlan? {
        var positionProps = Set<String>()
        var sizeProps: [String: SizeConversion] = [:]
        if let pb = decl?.propBindings {
            for binding in [pb.x, pb.y, pb.width, pb.height] {
                guard let b = binding else { continue }
                if b.as == "position-x" || b.as == "position-y" {
                    positionProps.insert(b.prop)
                } else if b.as == SizeConversion.canvasHeight.rawValue {
                    sizeProps[b.prop] = .canvasHeight
                } else if b.as == SizeConversion.halfCanvasHeight.rawValue {
                    sizeProps[b.prop] = .halfCanvasHeight
                }
            }
        }
        if let extraSizeProps {
            for (prop, conversion) in extraSizeProps {
                sizeProps[prop] = conversion
            }
        }
        if positionProps.isEmpty && sizeProps.isEmpty { return nil }
        return DimensionalPlan(positionProps: positionProps, sizeProps: sizeProps)
    }

    /// Port of `resolveOriginEdges`. Splits an origin such as `top-left` or `center` into one
    /// edge per axis, by substring match.
    public static func resolveOriginEdges(_ origin: String) -> (ox: OriginEdge, oy: OriginEdge) {
        let ox: OriginEdge = origin.contains("left") ? .start : (origin.contains("right") ? .end : .center)
        let oy: OriginEdge = origin.contains("top") ? .start : (origin.contains("bottom") ? .end : .center)
        return (ox, oy)
    }

    /// Port of `resolveOriginCenter`. Moves an anchor to the box center by the half-extent `he`.
    public static func resolveOriginCenter(_ anchorUV: Float, edge: OriginEdge, he: Float) -> Float {
        switch edge {
        case .start: return anchorUV + he
        case .end: return anchorUV - he
        case .center: return anchorUV
        }
    }

    /// Port of `bindingSizePx`: the pixel size of a width/height binding. A UV number scales by
    /// the canvas dimension of the binding. Unsupported values and bindings return 0.
    public static func bindingSizePx(
        _ binding: PropBinding,
        _ value: DimensionalPropValue?,
        width: Float,
        height: Float
    ) -> Float {
        func toPx(_ dim: Float) -> Float {
            switch value {
            case .dimensional(let d)?: return d.unit == .px ? d.value : d.value * dim
            case .number(let n)?: return n * dim
            default: return 0
            }
        }
        switch binding.as {
        case "canvas-height": return toPx(height)
        case "half-canvas-height": return toPx(2 * height)
        case "canvas-width": return toPx(width)
        default: return 0
        }
    }

    /// Port of `boxHalfExtentsUV` for the `propBindings` path. The `computeBounds` path is not
    /// ported. Returns zero if no size information is available.
    public static func boxHalfExtentsUV(
        _ decl: BoundingBoxDeclaration?,
        props: [String: DimensionalPropValue],
        width: Float,
        height: Float
    ) -> HalfExtents {
        var hwx: Float = 0
        var hhy: Float = 0
        if let b = decl?.propBindings?.width, width > 0 {
            hwx = bindingSizePx(b, props[b.prop], width: width, height: height) / (2 * width)
        }
        if let b = decl?.propBindings?.height, height > 0 {
            hhy = bindingSizePx(b, props[b.prop], width: width, height: height) / (2 * height)
        }
        return HalfExtents(hwx: hwx, hhy: hhy)
    }

    /// Port of `resolvePositionAxis`. Converts one axis to a UV number and applies the origin
    /// offset `he`. Keywords are returned unchanged for `transformPosition` to parse.
    ///
    /// A px value is a gap from the named edge: `end` gives `1 - gap`, `center` gives
    /// `0.5 + gap`, `start` gives `gap`.
    public static func resolvePositionAxis(_ value: AxisInput, dim: Float, edge: OriginEdge, he: Float) -> AxisInput {
        let anchorUV: Float
        switch value {
        case .dimensional(let d):
            if d.unit == .px {
                let gap = dim > 0 ? d.value / dim : 0
                switch edge {
                case .end: anchorUV = 1 - gap
                case .center: anchorUV = 0.5 + gap
                case .start: anchorUV = gap
                }
            } else {
                anchorUV = d.value
            }
        case .number(let n):
            anchorUV = n
        case .keyword:
            return value
        }
        return .number(resolveOriginCenter(anchorUV, edge: edge, he: he))
    }

    /// Port of `resolveSize`: converts a size value to UV (or to a count for
    /// `countCanvasHeight`). UV values pass through.
    public static func resolveSize(_ value: DimensionalValue, conversion: SizeConversion, width: Float, height: Float) -> Float {
        if value.unit != .px { return value.value }
        if conversion == .canvasWidth { return width > 0 ? value.value / width : value.value }
        if height <= 0 { return value.value }
        if conversion == .countCanvasHeight { return value.value > 0 ? height / value.value : value.value }
        return conversion == .canvasHeight ? value.value / height : value.value / (2 * height)
    }

    /// Port of `resolveDimensionalProps`: resolves all dimensional props to plain UV values,
    /// with the `origin` prop applied (default `center`).
    ///
    /// With the default origin, a position without dimensional axes is left unchanged.
    public static func resolveDimensionalProps(
        _ decl: BoundingBoxDeclaration?,
        rawProps: [String: DimensionalPropValue],
        width: Float,
        height: Float,
        extraSizeProps: [String: SizeConversion]? = nil
    ) -> [String: DimensionalPropValue] {
        guard let plan = buildDimensionalPlan(decl, extraSizeProps: extraSizeProps) else { return rawProps }

        var origin = "center"
        if case .string(let o)? = rawProps["origin"] { origin = o }
        let (ox, oy) = resolveOriginEdges(origin)
        let isDefaultOrigin = origin == "center"
        let he = isDefaultOrigin
            ? HalfExtents(hwx: 0, hhy: 0)
            : boxHalfExtentsUV(decl, props: rawProps, width: width, height: height)

        var out = rawProps
        for prop in plan.positionProps {
            guard case .position(.xy(let x, let y))? = rawProps[prop] else { continue }
            let hasDim = isDimensional(x) || isDimensional(y)
            if isDefaultOrigin && !hasDim { continue }
            out[prop] = .position(.xy(
                x: resolvePositionAxis(x, dim: width, edge: ox, he: he.hwx),
                y: resolvePositionAxis(y, dim: height, edge: oy, he: he.hhy)
            ))
        }
        for (prop, conversion) in plan.sizeProps {
            guard case .dimensional(let d)? = rawProps[prop] else { continue }
            out[prop] = .number(resolveSize(d, conversion: conversion, width: width, height: height))
        }
        return out
    }

    /// Port of `resolveDimensionalProp`: resolves one prop value against the given origin,
    /// canvas size and optional half-extent `he`.
    public static func resolveDimensionalProp(
        _ decl: BoundingBoxDeclaration?,
        propName: String,
        rawValue: DimensionalPropValue,
        origin: String,
        width: Float,
        height: Float,
        extraSizeProps: [String: SizeConversion]? = nil,
        he: HalfExtents? = nil
    ) -> DimensionalPropValue {
        guard let plan = buildDimensionalPlan(decl, extraSizeProps: extraSizeProps) else { return rawValue }
        let (ox, oy) = resolveOriginEdges(origin)
        if plan.positionProps.contains(propName) {
            guard case .position(.xy(let x, let y)) = rawValue else { return rawValue }
            return .position(.xy(
                x: resolvePositionAxis(x, dim: width, edge: ox, he: he?.hwx ?? 0),
                y: resolvePositionAxis(y, dim: height, edge: oy, he: he?.hhy ?? 0)
            ))
        }
        if let conversion = plan.sizeProps[propName], case .dimensional(let d) = rawValue {
            return .number(resolveSize(d, conversion: conversion, width: width, height: height))
        }
        return rawValue
    }

    /// Port of `isDimensionalProp`.
    public static func isDimensionalProp(
        _ decl: BoundingBoxDeclaration?,
        propName: String,
        extraSizeProps: [String: SizeConversion]? = nil
    ) -> Bool {
        guard let plan = buildDimensionalPlan(decl, extraSizeProps: extraSizeProps) else { return false }
        return plan.positionProps.contains(propName) || plan.sizeProps[propName] != nil
    }

    /// Port of `dimensionalPropNames`: position props, then size props, each sorted by name.
    /// Upstream returns insertion order instead.
    public static func dimensionalPropNames(
        _ decl: BoundingBoxDeclaration?,
        extraSizeProps: [String: SizeConversion]? = nil
    ) -> [String] {
        guard let plan = buildDimensionalPlan(decl, extraSizeProps: extraSizeProps) else { return [] }
        return plan.positionProps.sorted() + plan.sizeProps.keys.sorted()
    }

    private static func isDimensional(_ axis: AxisInput) -> Bool {
        if case .dimensional = axis { return true }
        return false
    }
}
