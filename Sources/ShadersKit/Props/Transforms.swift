import Foundation
import simd

/// One position axis: a UV number, a CSS keyword (`left`, `center`, …) or a dimensional value.
///
/// Mirrors upstream `PositionAxisInput`.
public enum AxisInput: Equatable, Sendable {
    case number(Float)
    case keyword(String)
    case dimensional(DimensionalValue)
}

/// A position prop value: an `{x, y}` pair or a CSS-style keyword string such as `"top left"`.
public enum PositionInput: Equatable, Sendable {
    case xy(x: AxisInput, y: AxisInput)
    case keyword(String)
}

/// Ports of the prop transforms in upstream `utilities/transformations.ts`.
///
/// `transformColor` maps to `CSSColor.linear(_:mode:)`.
public enum PropTransforms {

    /// Converts a boolean to 1 (true) or -1 (false).
    public static func transformBoolean(_ value: Bool) -> Float {
        value ? 1 : -1
    }

    /// Converts a position to UV with the y axis flipped: the result is `(x, 1 - y)`.
    ///
    /// Keywords: `left` / `right` / `center` for x and `top` / `bottom` / `center` for y.
    /// Unknown input resolves to the center.
    public static func transformPosition(_ value: PositionInput) -> SIMD2<Float> {
        var x: Float = 0.5
        var y: Float = 0.5

        switch value {
        case .keyword(let string):
            let parts = string.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            if parts.contains("left") {
                x = 0
            } else if parts.contains("right") {
                x = 1
            } else if parts.contains("center") || (parts.count == 1 && (parts[0] == "top" || parts[0] == "bottom")) {
                x = 0.5
            }

            if parts.contains("top") {
                y = 0
            } else if parts.contains("bottom") {
                y = 1
            } else if parts.contains("center") || (parts.count == 1 && (parts[0] == "left" || parts[0] == "right")) {
                y = 0.5
            }

            if parts.count == 1 && parts[0] == "center" {
                x = 0.5
                y = 0.5
            }
        case .xy(let ax, let ay):
            x = parsePositionValue(ax, isVertical: false)
            y = parsePositionValue(ay, isVertical: true)
        }

        return SIMD2(x, 1.0 - y)
    }

    /// Resolves one position axis to a UV number. A dimensional value passes its raw value.
    private static func parsePositionValue(_ value: AxisInput, isVertical: Bool) -> Float {
        switch value {
        case .number(let v):
            return v
        case .dimensional(let d):
            return d.value
        case .keyword(let raw):
            let str = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if isVertical {
                if str == "top" { return 0 }
                if str == "bottom" { return 1 }
                if str == "center" { return 0.5 }
            } else {
                if str == "left" { return 0 }
                if str == "right" { return 1 }
                if str == "center" { return 0.5 }
            }
            return 0.5
        }
    }

    /// Wraps an angle in degrees into 0..<360, as `((v % 360) + 360) % 360`.
    public static func transformAngle(_ value: Float) -> Float {
        Float(wrapDegrees(Double(value)))
    }

    /// Converts a CSS gradient direction (`"to right"`, `"from top"`) or an angle string
    /// (`"45deg"`, `"1rad"`, `"0.5turn"`, `"90"`) to degrees in 0..<360. Unknown input returns 0.
    public static func transformAngle(_ value: String) -> Float {
        let str = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direction = angleDirections[str] {
            return direction
        }

        // Upstream regex: /^(-?\d*\.?\d+)(deg|rad|turn)?$/
        var numberPart = Substring(str)
        var unit = "deg"
        for candidate in ["deg", "rad", "turn"] where str.hasSuffix(candidate) {
            numberPart = numberPart.dropLast(candidate.count)
            unit = candidate
            break
        }
        guard isAngleNumber(numberPart), let n = Double(String(numberPart)) else {
            return 0
        }
        switch unit {
        case "rad": return Float(wrapDegrees(n * 180 / Double.pi))
        case "turn": return Float(wrapDegrees(n * 360))
        default: return Float(wrapDegrees(n))
        }
    }

    private static let angleDirections: [String: Float] = [
        "to right": 0,
        "to bottom": 90,
        "to left": 180,
        "to top": 270,
        "to bottom right": 45,
        "to right bottom": 45,
        "to bottom left": 135,
        "to left bottom": 135,
        "to top left": 225,
        "to left top": 225,
        "to top right": 315,
        "to right top": 315,
        "from left": 0,
        "from top": 90,
        "from right": 180,
        "from bottom": 270,
        "from top left": 45,
        "from top right": 135,
        "from bottom right": 225,
        "from bottom left": 315,
    ]

    private static func wrapDegrees(_ v: Double) -> Double {
        (v.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Matches `-?\d*\.?\d+`: an optional minus, then digits with at most one dot, ending in a digit.
    private static func isAngleNumber(_ s: Substring) -> Bool {
        var body = s
        if body.first == "-" { body = body.dropFirst() }
        let isDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }
        if let dot = body.firstIndex(of: ".") {
            let before = body[body.startIndex..<dot]
            let after = body[body.index(after: dot)...]
            return before.allSatisfy(isDigit) && !after.isEmpty && after.allSatisfy(isDigit)
        }
        return !body.isEmpty && body.allSatisfy(isDigit)
    }

    /// Edge mode: `stretch` 0, `transparent` 1, `mirror` 2, `wrap` 3. Unknown input returns 0.
    public static func transformEdges(_ value: String) -> Float {
        edgeModes[value.lowercased()] ?? 0
    }

    private static let edgeModes: [String: Float] = [
        "stretch": 0,
        "transparent": 1,
        "mirror": 2,
        "wrap": 3,
    ]

    /// Stroke position: `outside` 0, `center` 1, `inside` 2. Unknown input returns 1.
    public static func transformStrokePosition(_ value: String) -> Float {
        strokePositions[value.lowercased()] ?? 1
    }

    private static let strokePositions: [String: Float] = ["outside": 0, "center": 1, "inside": 2]

    /// Color mix space: `linear` 0, `oklch` 1, `oklab` 2, `hsl` 3, `hsv` 4, `lch` 5.
    /// Unknown input returns 0.
    public static func transformColorSpace(_ value: String) -> Float {
        colorSpaces[value.lowercased()] ?? 0
    }

    private static let colorSpaces: [String: Float] = [
        "linear": 0,
        "oklch": 1,
        "oklab": 2,
        "hsl": 3,
        "hsv": 4,
        "lch": 5,
    ]
}
