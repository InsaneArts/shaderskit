import Foundation
import simd

/// A color prop value: any CSS color string (`"#7c3aed"`, `"rgb(255 0 0 / 50%)"`, `"oklch(...)"`
/// is not supported, named colors are). Converted to linear light in the active color space when
/// uploaded to the GPU.
public struct ShaderColor: Equatable, Sendable, Hashable, ExpressibleByStringLiteral {
    public var css: String

    public init(_ css: String) { self.css = css }
    public init(stringLiteral value: String) { self.css = value }

    /// sRGB components in 0...1 (gamma encoded), alpha 0...1.
    public static func rgb(_ r: Float, _ g: Float, _ b: Float, alpha: Float = 1) -> ShaderColor {
        let c = { (v: Float) in Int((min(max(v, 0), 1) * 255).rounded()) }
        return ShaderColor("rgba(\(c(r)), \(c(g)), \(c(b)), \(alpha))")
    }

    /// Hex string, with or without the leading `#`.
    public static func hex(_ hex: String) -> ShaderColor {
        ShaderColor(hex.hasPrefix("#") ? hex : "#\(hex)")
    }

    public static let transparent = ShaderColor("transparent")
    public static let black = ShaderColor("#000000")
    public static let white = ShaderColor("#ffffff")

    /// Parsed sRGB gamma-encoded components, or nil when the string is not a valid CSS color.
    public var rgba: RGBA? { CSSColor.parse(css) }

    /// Linear-light components in the given working color space (what the GPU receives).
    public func linear(mode: ColorSpaceMode = .displayP3Linear) -> SIMD4<Float> {
        let c = CSSColor.linear(css, mode: mode)
        return SIMD4(c.r, c.g, c.b, c.a)
    }

    public var propValue: PropValue { .string(css) }
}

#if canImport(SwiftUI)
import SwiftUI

public extension ShaderColor {
    /// Converts a SwiftUI color by resolving it in the sRGB color space.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *)
    init(_ color: Color, environment: EnvironmentValues = EnvironmentValues()) {
        let r = color.resolve(in: environment)
        self = .rgb(r.red, r.green, r.blue, alpha: r.opacity)
    }
}
#endif

/// A 2D position prop (0...1 UV space with the top-left origin upstream uses, or keywords such as
/// `"top left"`). Axes may also be given in pixels.
public struct ShaderPosition: Equatable, Sendable, Hashable {
    public var x: AxisInput
    public var y: AxisInput

    public init(x: AxisInput, y: AxisInput) {
        self.x = x
        self.y = y
    }

    public init(x: Float, y: Float) {
        self.x = .number(x)
        self.y = .number(y)
    }

    public init(_ x: Float, _ y: Float) {
        self.init(x: x, y: y)
    }

    /// Pixel offsets from the top-left corner.
    public static func px(_ x: Float, _ y: Float) -> ShaderPosition {
        ShaderPosition(x: .dimensional(DimensionalValue(value: x, unit: .px)), y: .dimensional(DimensionalValue(value: y, unit: .px)))
    }

    /// Keyword position such as `"center"`, `"top left"`, `"bottom right"`.
    public static func keyword(_ keyword: String) -> ShaderPosition {
        let v = PropTransforms.transformPosition(.keyword(keyword))
        return ShaderPosition(x: v.x, y: 1 - v.y)
    }

    public static let center = ShaderPosition(x: 0.5, y: 0.5)

    public var input: PositionInput { .xy(x: x, y: y) }
    public var propValue: PropValue { .position(input) }

    public init(_ input: PositionInput) {
        switch input {
        case .xy(let x, let y):
            self.x = x
            self.y = y
        case .keyword(let k):
            self = .keyword(k)
        }
    }
}

extension AxisInput: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .number(let v): hasher.combine(0); hasher.combine(v)
        case .keyword(let k): hasher.combine(1); hasher.combine(k)
        case .dimensional(let d): hasher.combine(2); hasher.combine(d.value); hasher.combine(d.unit.rawValue)
        }
    }
}

extension DimensionalValue: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    /// A bare number is a fraction of the canvas (upstream `uv` unit).
    public init(floatLiteral value: Double) { self.init(value: Float(value), unit: .uv) }
    public init(integerLiteral value: Int) { self.init(value: Float(value), unit: .uv) }

    /// Pixel length.
    public static func px(_ value: Float) -> DimensionalValue { DimensionalValue(value: value, unit: .px) }
    /// Fraction of the reference canvas dimension.
    public static func fraction(_ value: Float) -> DimensionalValue { DimensionalValue(value: value, unit: .uv) }

    public var propValue: PropValue { unit == .uv ? .number(value) : .dimensional(self) }
}

extension ColorStop {
    public init(_ color: ShaderColor, at position: Float) {
        self.init(color: color.css, position: position)
    }
}
