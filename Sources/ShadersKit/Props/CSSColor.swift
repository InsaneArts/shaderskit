import Foundation
import simd

/// A color with red, green, blue and alpha channels as `Float`.
public struct RGBA: Equatable, Sendable {
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

/// The linear color space that parsed colors convert to. Upstream defaults to Display P3.
public enum ColorSpaceMode: Sendable {
    /// Linear Display P3 (upstream `'p3-linear'`, the default).
    case displayP3Linear
    /// Linear sRGB (upstream `'srgb'`, which matches design tools such as Figma).
    case sRGBLinear
}

/// CSS color string parsing. It replaces colorjs.io, which upstream uses.
///
/// Supported syntax: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()` / `rgba()`,
/// `hsl()` / `hsla()`, `hwb()`, the 148 CSS named colors and `transparent`. Functions accept
/// comma or space separators and a `/` alpha. Like colorjs.io, channel values outside the
/// nominal range are not clamped, and alpha is clamped to 0...1.
public enum CSSColor {

    /// Parses a CSS color string into gamma-encoded sRGB channels.
    ///
    /// Channels are nominally in 0...1. Alpha is in 0...1.
    /// - Returns: `nil` if the string is not a supported CSS color.
    public static func parse(_ string: String) -> RGBA? {
        guard let c = parseD(string) else { return nil }
        return RGBA(r: Float(c.x), g: Float(c.y), b: Float(c.z), a: Float(c.w))
    }

    /// Port of upstream `transformColorGpu`: parses a CSS color into linear channels in `mode`.
    ///
    /// The conversion is sRGB gamma decode, then (for Display P3) linear sRGB to XYZ D65 to
    /// linear P3. It runs in `Double` and rounds to `Float` at the end, like upstream.
    /// - Returns: `RGBA(0, 0, 0, 0)` if the string is not a supported CSS color.
    public static func linear(_ string: String, mode: ColorSpaceMode = .displayP3Linear) -> RGBA {
        guard let c = parseD(string) else { return RGBA(r: 0, g: 0, b: 0, a: 0) }
        let lin = SIMD3(
            ColorMath.srgbToLinearD(c.x),
            ColorMath.srgbToLinearD(c.y),
            ColorMath.srgbToLinearD(c.z)
        )
        let out = mode == .displayP3Linear ? ColorMath.linearSRGBToLinearP3D(lin) : lin
        // Upstream coerces non-finite channels to 0 and a non-finite alpha to 1.
        func finite(_ v: Double, _ fallback: Float) -> Float { v.isFinite ? Float(v) : fallback }
        return RGBA(r: finite(out.x, 0), g: finite(out.y, 0), b: finite(out.z, 0), a: finite(c.w, 1))
    }

    // MARK: - Parsing

    /// Parses into gamma-encoded sRGB plus alpha, in `Double`.
    static func parseD(_ string: String) -> SIMD4<Double>? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.isEmpty { return nil }
        if s.hasPrefix("#") { return parseHex(s.dropFirst()) }
        if s == "transparent" { return SIMD4(0, 0, 0, 0) }
        if let hex = namedColors[s] {
            return SIMD4(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, 1)
        }
        return parseFunction(s)
    }

    private static func parseHex(_ digits: Substring) -> SIMD4<Double>? {
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        var values: [Double] = []
        if digits.count <= 4 {
            for ch in digits {
                guard let v = ch.hexDigitValue else { return nil }
                values.append(Double(v * 17) / 255)
            }
        } else {
            var index = digits.startIndex
            while index < digits.endIndex {
                let next = digits.index(index, offsetBy: 2)
                guard let v = UInt8(digits[index..<next], radix: 16) else { return nil }
                values.append(Double(v) / 255)
                index = next
            }
        }
        return SIMD4(values[0], values[1], values[2], values.count == 4 ? values[3] : 1)
    }

    private enum Token {
        case number(Double)
        case percentage(Double)
        case angle(degrees: Double)
    }

    private static func parseFunction(_ s: String) -> SIMD4<Double>? {
        guard let open = s.firstIndex(of: "("), s.hasSuffix(")") else { return nil }
        let name = s[s.startIndex..<open]
        let inner = s[s.index(after: open)..<s.index(before: s.endIndex)]
        guard !name.isEmpty, name.allSatisfy({ $0.isASCII && $0.isLetter }),
              !inner.contains("("), !inner.contains(")") else { return nil }

        let isSeparator: (Character) -> Bool = { $0 == "," || $0.isWhitespace }
        let halves = inner.split(separator: "/", omittingEmptySubsequences: false)
        guard halves.count <= 2 else { return nil }
        var rawTokens = halves[0].split(whereSeparator: isSeparator)
        var rawAlpha: Substring?
        if halves.count == 2 {
            let alphaTokens = halves[1].split(whereSeparator: isSeparator)
            guard alphaTokens.count == 1 else { return nil }
            rawAlpha = alphaTokens[0]
        } else if rawTokens.count == 4 {
            rawAlpha = rawTokens.removeLast()
        }
        guard rawTokens.count == 3 else { return nil }

        var tokens: [Token] = []
        for raw in rawTokens {
            guard let t = token(raw) else { return nil }
            tokens.append(t)
        }

        var alpha = 1.0
        if let rawAlpha {
            switch token(rawAlpha) {
            case .number(let v): alpha = v
            case .percentage(let v): alpha = v / 100
            default: return nil
            }
            alpha = min(max(alpha, 0), 1)
        }

        let rgb: SIMD3<Double>
        switch name {
        case "rgb", "rgba":
            var channels: [Double] = []
            for t in tokens {
                switch t {
                case .number(let v): channels.append(v / 255)
                case .percentage(let v): channels.append(v / 100)
                case .angle: return nil
                }
            }
            rgb = SIMD3(channels[0], channels[1], channels[2])
        case "hsl", "hsla":
            guard let h = hue(tokens[0]), let sat = fraction(tokens[1]), let light = fraction(tokens[2]) else { return nil }
            rgb = hslToSRGB(h: h, s: sat, l: light)
        case "hwb":
            guard let h = hue(tokens[0]), let w = fraction(tokens[1]), let bl = fraction(tokens[2]) else { return nil }
            rgb = hwbToSRGB(h: h, w: w, b: bl)
        default:
            return nil
        }
        return SIMD4(rgb.x, rgb.y, rgb.z, alpha)
    }

    /// Hue in degrees from a number (degrees) or an angle.
    private static func hue(_ t: Token) -> Double? {
        switch t {
        case .number(let v): return v
        case .angle(let deg): return deg
        case .percentage: return nil
        }
    }

    /// A 0...1 fraction from a percentage or a 0...100 number.
    private static func fraction(_ t: Token) -> Double? {
        switch t {
        case .number(let v), .percentage(let v): return v / 100
        case .angle: return nil
        }
    }

    private static let angleUnits: [(String, Double)] = [
        ("deg", 1), ("grad", 0.9), ("rad", 180 / Double.pi), ("turn", 360),
    ]

    private static func token(_ raw: Substring) -> Token? {
        if raw.hasSuffix("%") {
            return number(raw.dropLast()).map { .percentage($0) }
        }
        for (unit, factor) in angleUnits where raw.hasSuffix(unit) {
            return number(raw.dropLast(unit.count)).map { .angle(degrees: $0 * factor) }
        }
        return number(raw).map { .number($0) }
    }

    /// A plain decimal number: optional sign, digits, at most one dot. No exponent (as colorjs.io).
    private static func number(_ raw: Substring) -> Double? {
        var body = raw
        if let first = body.first, first == "-" || first == "+" { body = body.dropFirst() }
        var digits = 0
        var dots = 0
        for ch in body {
            if ch.isASCII && ch.isNumber {
                digits += 1
            } else if ch == "." {
                dots += 1
            } else {
                return nil
            }
        }
        guard digits > 0, dots <= 1 else { return nil }
        return Double(String(raw))
    }

    /// colorjs.io `hsl` toBase. `s` and `l` are fractions, `h` is in degrees.
    private static func hslToSRGB(h: Double, s: Double, l: Double) -> SIMD3<Double> {
        var hue = h.truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        func f(_ n: Double) -> Double {
            let k = (n + hue / 30).truncatingRemainder(dividingBy: 12)
            let a = s * min(l, 1 - l)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        return SIMD3(f(0), f(8), f(4))
    }

    /// CSS Color 4 `hwbToRgb`. `w` and `b` are fractions, `h` is in degrees.
    private static func hwbToSRGB(h: Double, w: Double, b: Double) -> SIMD3<Double> {
        if w + b >= 1 {
            let gray = w / (w + b)
            return SIMD3(repeating: gray)
        }
        return hslToSRGB(h: h, s: 1, l: 0.5) * (1 - w - b) + w
    }

    /// The 148 CSS named colors (colorjs.io `keywords.js`), as 0xRRGGBB.
    private static let namedColors: [String: UInt32] = [
        "aliceblue": 0xF0F8FF,
        "antiquewhite": 0xFAEBD7,
        "aqua": 0x00FFFF,
        "aquamarine": 0x7FFFD4,
        "azure": 0xF0FFFF,
        "beige": 0xF5F5DC,
        "bisque": 0xFFE4C4,
        "black": 0x000000,
        "blanchedalmond": 0xFFEBCD,
        "blue": 0x0000FF,
        "blueviolet": 0x8A2BE2,
        "brown": 0xA52A2A,
        "burlywood": 0xDEB887,
        "cadetblue": 0x5F9EA0,
        "chartreuse": 0x7FFF00,
        "chocolate": 0xD2691E,
        "coral": 0xFF7F50,
        "cornflowerblue": 0x6495ED,
        "cornsilk": 0xFFF8DC,
        "crimson": 0xDC143C,
        "cyan": 0x00FFFF,
        "darkblue": 0x00008B,
        "darkcyan": 0x008B8B,
        "darkgoldenrod": 0xB8860B,
        "darkgray": 0xA9A9A9,
        "darkgreen": 0x006400,
        "darkgrey": 0xA9A9A9,
        "darkkhaki": 0xBDB76B,
        "darkmagenta": 0x8B008B,
        "darkolivegreen": 0x556B2F,
        "darkorange": 0xFF8C00,
        "darkorchid": 0x9932CC,
        "darkred": 0x8B0000,
        "darksalmon": 0xE9967A,
        "darkseagreen": 0x8FBC8F,
        "darkslateblue": 0x483D8B,
        "darkslategray": 0x2F4F4F,
        "darkslategrey": 0x2F4F4F,
        "darkturquoise": 0x00CED1,
        "darkviolet": 0x9400D3,
        "deeppink": 0xFF1493,
        "deepskyblue": 0x00BFFF,
        "dimgray": 0x696969,
        "dimgrey": 0x696969,
        "dodgerblue": 0x1E90FF,
        "firebrick": 0xB22222,
        "floralwhite": 0xFFFAF0,
        "forestgreen": 0x228B22,
        "fuchsia": 0xFF00FF,
        "gainsboro": 0xDCDCDC,
        "ghostwhite": 0xF8F8FF,
        "gold": 0xFFD700,
        "goldenrod": 0xDAA520,
        "gray": 0x808080,
        "green": 0x008000,
        "greenyellow": 0xADFF2F,
        "grey": 0x808080,
        "honeydew": 0xF0FFF0,
        "hotpink": 0xFF69B4,
        "indianred": 0xCD5C5C,
        "indigo": 0x4B0082,
        "ivory": 0xFFFFF0,
        "khaki": 0xF0E68C,
        "lavender": 0xE6E6FA,
        "lavenderblush": 0xFFF0F5,
        "lawngreen": 0x7CFC00,
        "lemonchiffon": 0xFFFACD,
        "lightblue": 0xADD8E6,
        "lightcoral": 0xF08080,
        "lightcyan": 0xE0FFFF,
        "lightgoldenrodyellow": 0xFAFAD2,
        "lightgray": 0xD3D3D3,
        "lightgreen": 0x90EE90,
        "lightgrey": 0xD3D3D3,
        "lightpink": 0xFFB6C1,
        "lightsalmon": 0xFFA07A,
        "lightseagreen": 0x20B2AA,
        "lightskyblue": 0x87CEFA,
        "lightslategray": 0x778899,
        "lightslategrey": 0x778899,
        "lightsteelblue": 0xB0C4DE,
        "lightyellow": 0xFFFFE0,
        "lime": 0x00FF00,
        "limegreen": 0x32CD32,
        "linen": 0xFAF0E6,
        "magenta": 0xFF00FF,
        "maroon": 0x800000,
        "mediumaquamarine": 0x66CDAA,
        "mediumblue": 0x0000CD,
        "mediumorchid": 0xBA55D3,
        "mediumpurple": 0x9370DB,
        "mediumseagreen": 0x3CB371,
        "mediumslateblue": 0x7B68EE,
        "mediumspringgreen": 0x00FA9A,
        "mediumturquoise": 0x48D1CC,
        "mediumvioletred": 0xC71585,
        "midnightblue": 0x191970,
        "mintcream": 0xF5FFFA,
        "mistyrose": 0xFFE4E1,
        "moccasin": 0xFFE4B5,
        "navajowhite": 0xFFDEAD,
        "navy": 0x000080,
        "oldlace": 0xFDF5E6,
        "olive": 0x808000,
        "olivedrab": 0x6B8E23,
        "orange": 0xFFA500,
        "orangered": 0xFF4500,
        "orchid": 0xDA70D6,
        "palegoldenrod": 0xEEE8AA,
        "palegreen": 0x98FB98,
        "paleturquoise": 0xAFEEEE,
        "palevioletred": 0xDB7093,
        "papayawhip": 0xFFEFD5,
        "peachpuff": 0xFFDAB9,
        "peru": 0xCD853F,
        "pink": 0xFFC0CB,
        "plum": 0xDDA0DD,
        "powderblue": 0xB0E0E6,
        "purple": 0x800080,
        "rebeccapurple": 0x663399,
        "red": 0xFF0000,
        "rosybrown": 0xBC8F8F,
        "royalblue": 0x4169E1,
        "saddlebrown": 0x8B4513,
        "salmon": 0xFA8072,
        "sandybrown": 0xF4A460,
        "seagreen": 0x2E8B57,
        "seashell": 0xFFF5EE,
        "sienna": 0xA0522D,
        "silver": 0xC0C0C0,
        "skyblue": 0x87CEEB,
        "slateblue": 0x6A5ACD,
        "slategray": 0x708090,
        "slategrey": 0x708090,
        "snow": 0xFFFAFA,
        "springgreen": 0x00FF7F,
        "steelblue": 0x4682B4,
        "tan": 0xD2B48C,
        "teal": 0x008080,
        "thistle": 0xD8BFD8,
        "tomato": 0xFF6347,
        "turquoise": 0x40E0D0,
        "violet": 0xEE82EE,
        "wheat": 0xF5DEB3,
        "white": 0xFFFFFF,
        "whitesmoke": 0xF5F5F5,
        "yellow": 0xFFFF00,
        "yellowgreen": 0x9ACD32,
    ]
}
