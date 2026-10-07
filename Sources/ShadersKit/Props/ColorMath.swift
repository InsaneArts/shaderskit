import Foundation
import simd

/// Color conversion math for the prop layer.
///
/// The type has three groups of functions:
/// - sRGB transfer functions and sRGB / Display P3 matrices that match colorjs.io, the library
///   upstream uses to parse CSS colors. `CSSColor.linear` uses these.
/// - 1:1 ports of the `colorMixing.ts` conversions (TypeGPU dual functions). They use `Float`,
///   like the GPU code they mirror, and keep the upstream constants.
/// - `convertP3ToMixSpaceCPU`, the port of the upstream CPU helper. It computes in `Double`,
///   like the JavaScript it mirrors, and returns `Float`.
public enum ColorMath {

    // MARK: - sRGB transfer function (colorjs.io `srgb` space)

    /// Converts one gamma-encoded sRGB channel to linear light. Keeps the sign of negative input.
    public static func srgbToLinear(_ value: Float) -> Float {
        Float(srgbToLinearD(Double(value)))
    }

    /// Converts one linear-light channel to gamma-encoded sRGB. Keeps the sign of negative input.
    public static func linearToSrgb(_ value: Float) -> Float {
        Float(linearToSrgbD(Double(value)))
    }

    /// Converts gamma-encoded sRGB to linear light, per channel.
    public static func srgbToLinear(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(srgbToLinear(rgb.x), srgbToLinear(rgb.y), srgbToLinear(rgb.z))
    }

    /// Converts linear light to gamma-encoded sRGB, per channel.
    public static func linearToSrgb(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3(linearToSrgb(rgb.x), linearToSrgb(rgb.y), linearToSrgb(rgb.z))
    }

    // MARK: - Linear sRGB <-> linear Display P3 (colorjs.io matrices, via XYZ D65)

    /// Converts linear sRGB to linear Display P3 through XYZ D65, with the colorjs.io matrices.
    public static func linearSRGBToLinearP3(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(linearSRGBToLinearP3D(SIMD3<Double>(rgb)))
    }

    /// Converts linear Display P3 to linear sRGB through XYZ D65, with the colorjs.io matrices.
    public static func linearP3ToLinearSRGB(_ p3: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(linearP3ToLinearSRGBD(SIMD3<Double>(p3)))
    }

    // MARK: - Double-precision internals (used by CSSColor)

    static func srgbToLinearD(_ value: Double) -> Double {
        let sign: Double = value < 0 ? -1 : 1
        let magnitude = value * sign
        if magnitude <= 0.04045 {
            return value / 12.92
        }
        return sign * pow((magnitude + 0.055) / 1.055, 2.4)
    }

    static func linearToSrgbD(_ value: Double) -> Double {
        let sign: Double = value < 0 ? -1 : 1
        let magnitude = value * sign
        if magnitude > 0.0031308 {
            return sign * (1.055 * pow(magnitude, 1 / 2.4) - 0.055)
        }
        return 12.92 * value
    }

    static func linearSRGBToLinearP3D(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        xyzToLinearP3 * (linearSRGBToXYZ * rgb)
    }

    static func linearP3ToLinearSRGBD(_ p3: SIMD3<Double>) -> SIMD3<Double> {
        xyzToLinearSRGB * (linearP3ToXYZ * p3)
    }

    // colorjs.io 0.5.2 `srgb-linear` toXYZ_M / fromXYZ_M.
    private static let linearSRGBToXYZ = simd_double3x3(rows: [
        SIMD3(0.41239079926595934, 0.357584339383878, 0.1804807884018343),
        SIMD3(0.21263900587151027, 0.715168678767756, 0.07219231536073371),
        SIMD3(0.01933081871559182, 0.11919477979462598, 0.9505321522496607),
    ])
    private static let xyzToLinearSRGB = simd_double3x3(rows: [
        SIMD3(3.2409699419045226, -1.537383177570094, -0.4986107602930034),
        SIMD3(-0.9692436362808796, 1.8759675015077202, 0.04155505740717559),
        SIMD3(0.05563007969699366, -0.20397695888897652, 1.0569715142428786),
    ])
    // colorjs.io 0.5.2 `p3-linear` toXYZ_M / fromXYZ_M.
    private static let linearP3ToXYZ = simd_double3x3(rows: [
        SIMD3(0.4865709486482162, 0.26566769316909306, 0.1982172852343625),
        SIMD3(0.2289745640697488, 0.6917385218365064, 0.079286914093745),
        SIMD3(0.0, 0.04511338185890264, 1.043944368900976),
    ])
    private static let xyzToLinearP3 = simd_double3x3(rows: [
        SIMD3(2.493496911941425, -0.9313836179191239, -0.40271078445071684),
        SIMD3(-0.8294889695615747, 1.7626640603183463, 0.023624685841943577),
        SIMD3(0.03584583024378447, -0.07617238926804182, 0.9568845240076872),
    ])

    // MARK: - colorMixing.ts constants

    private static let epsilon: Float = 0.0001
    private static let piOver3: Float = 1.0471975512
    private static let labDelta: Float = Float(6.0 / 29.0)
    private static let labKappa: Float = 500.0
    private static let labLambda: Float = 200.0
    private static let labDelta3: Float = Float((6.0 / 29.0) * (6.0 / 29.0) * (6.0 / 29.0))
    private static let labOffset: Float = Float(4.0 / 29.0)
    private static let labFwdSlope: Float = Float(1.0 / (3.0 * (6.0 / 29.0) * (6.0 / 29.0)))
    private static let labInvSlope: Float = Float(3.0 * (6.0 / 29.0) * (6.0 / 29.0))

    // MARK: - colorMixing.ts: P3 <-> sRGB (linear, upstream's rounded matrices)

    /// Port of `p3ToSRGB`: linear P3 to linear sRGB with upstream's 7-digit matrix.
    public static func p3ToSRGB(_ p3: SIMD3<Float>) -> SIMD3<Float> {
        let r = p3.x * 1.2249401 - p3.y * 0.2249404 - p3.z * 0.0
        let g = p3.x * -0.0420569 + p3.y * 1.0420571 + p3.z * 0.0
        let b = p3.x * -0.0196376 - p3.y * 0.0786361 + p3.z * 1.0982735
        return SIMD3(r, g, b)
    }

    /// Port of `sRGBToP3`: linear sRGB to linear P3 with upstream's 7-digit matrix.
    public static func sRGBToP3(_ srgb: SIMD3<Float>) -> SIMD3<Float> {
        let r = srgb.x * 0.8224621 + srgb.y * 0.1775380 + srgb.z * 0.0
        let g = srgb.x * 0.0331941 + srgb.y * 0.9668058 + srgb.z * 0.0
        let b = srgb.x * 0.0170826 + srgb.y * 0.0723974 + srgb.z * 0.9105199
        return SIMD3(r, g, b)
    }

    // MARK: - colorMixing.ts: OKLab <-> RGB / OKLCh

    /// Port of `rgbToOklab`: linear sRGB to OKLab, with a sign-preserving cube root.
    public static func rgbToOklab(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z

        let l = r * 0.4122214708 + g * 0.5363325363 + b * 0.0514459929
        let m = r * 0.2119034982 + (g * 0.6806995451 + b * 0.1073969566)
        let s = r * 0.0883024619 + g * 0.2817188376 + b * 0.6299787005

        let l_ = wgslSign(l) * pow(abs(l), 1.0 / 3.0)
        let m_ = wgslSign(m) * pow(abs(m), 1.0 / 3.0)
        let s_ = wgslSign(s) * pow(abs(s), 1.0 / 3.0)

        return SIMD3(
            l_ * 0.2104542553 + m_ * 0.7936177850 - s_ * 0.0040720468,
            l_ * 1.9779984951 - m_ * 2.4285922050 + s_ * 0.4505937099,
            l_ * 0.0259040371 + m_ * 0.7827717662 - s_ * 0.8086757660
        )
    }

    /// Port of `oklabToRgb`: OKLab to linear sRGB.
    public static func oklabToRgb(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let L = lab.x
        let a = lab.y
        let b = lab.z

        let l_ = L + a * 0.3963377774 + b * 0.2158037573
        let m_ = L - a * 0.1055613458 - b * 0.0638541728
        let s_ = L - a * 0.0894841775 - b * 1.2914855480

        let l = pow(l_, 3.0)
        let m = pow(m_, 3.0)
        let s = pow(s_, 3.0)

        return SIMD3(
            l * 4.0767416621 - m * 3.3077115913 + s * 0.2309699292,
            l * -1.2684380046 + m * 2.6097574011 - s * 0.3413193965,
            l * -0.0041960863 - m * 0.7034186147 + s * 1.7076147010
        )
    }

    /// Port of `oklabToOklch`: OKLab to OKLCh. Hue is in radians.
    public static func oklabToOklch(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let a = lab.y
        let b = lab.z
        return SIMD3(lab.x, (a * a + b * b).squareRoot(), atan2(b, a))
    }

    /// Port of `oklchToOklab`: OKLCh to OKLab. Hue is in radians.
    public static func oklchToOklab(_ lch: SIMD3<Float>) -> SIMD3<Float> {
        let C = lch.y
        let h = lch.z
        return SIMD3(lch.x, C * cos(h), C * sin(h))
    }

    // MARK: - colorMixing.ts: HSL / HSV

    /// Port of `selectRGBBySector`: picks the RGB layout for a hue sector 0...5.
    public static func selectRGBBySector(c: Float, x: Float, sector: Float) -> SIMD3<Float> {
        var r: Float = 0
        var g: Float = 0
        var b: Float = 0
        if sector < 1.0 {
            r = c
            g = x
        } else if sector < 2.0 {
            r = x
            g = c
        } else if sector < 3.0 {
            g = c
            b = x
        } else if sector < 4.0 {
            g = x
            b = c
        } else if sector < 5.0 {
            r = x
            b = c
        } else {
            r = c
            b = x
        }
        return SIMD3(r, g, b)
    }

    /// Port of `rgbToHsl`: linear sRGB to HSL. Hue is in radians.
    public static func rgbToHsl(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z

        let maxVal = max(max(r, g), b)
        let minVal = min(min(r, g), b)
        let delta = maxVal - minVal

        let l = (maxVal + minVal) * 0.5
        let satDenom = max(1.0 - abs(l * 2.0 - 1.0), epsilon)
        let s = delta / satDenom

        let hue = gpuHue(r: r, g: g, b: b, maxVal: maxVal, delta: delta)
        return SIMD3(hue * piOver3, s, l)
    }

    /// Port of `hslToRgb`: HSL (hue in radians) to linear sRGB.
    public static func hslToRgb(_ hsl: SIMD3<Float>) -> SIMD3<Float> {
        let h = hsl.x
        let s = hsl.y
        let l = hsl.z

        let c = s * (1.0 - abs(l * 2.0 - 1.0))
        let hPrime = h / piOver3
        let x = c * (1.0 - abs(hPrime.truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = l - c * 0.5
        let sector = floor(hPrime)
        return selectRGBBySector(c: c, x: x, sector: sector) + m
    }

    /// Port of `rgbToHsv`: linear sRGB to HSV. Hue is in radians.
    public static func rgbToHsv(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z

        let maxVal = max(max(r, g), b)
        let minVal = min(min(r, g), b)
        let delta = maxVal - minVal

        let v = maxVal
        let s = delta / max(maxVal, epsilon)

        let hue = gpuHue(r: r, g: g, b: b, maxVal: maxVal, delta: delta)
        return SIMD3(hue * piOver3, s, v)
    }

    /// Port of `hsvToRgb`: HSV (hue in radians) to linear sRGB.
    public static func hsvToRgb(_ hsv: SIMD3<Float>) -> SIMD3<Float> {
        let h = hsv.x
        let s = hsv.y
        let v = hsv.z

        let c = v * s
        let hPrime = h / piOver3
        let x = c * (1.0 - abs(hPrime.truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = v - c
        let sector = floor(hPrime)
        return selectRGBBySector(c: c, x: x, sector: sector) + m
    }

    // MARK: - colorMixing.ts: CIE Lab <-> RGB / LCh

    /// Port of `rgbToLab`: linear sRGB to CIE Lab (D65).
    public static func rgbToLab(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z

        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

        let xn = x / 0.95047
        let yn = y / 1.00000
        let zn = z / 1.08883

        let fx = xn > labDelta3 ? pow(xn, 1.0 / 3.0) : xn * labFwdSlope + labOffset
        let fy = yn > labDelta3 ? pow(yn, 1.0 / 3.0) : yn * labFwdSlope + labOffset
        let fz = zn > labDelta3 ? pow(zn, 1.0 / 3.0) : zn * labFwdSlope + labOffset

        return SIMD3(fy * 116.0 - 16.0, (fx - fy) * labKappa, (fy - fz) * labLambda)
    }

    /// Port of `labToRgb`: CIE Lab (D65) to linear sRGB.
    public static func labToRgb(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let L = lab.x
        let a = lab.y
        let b = lab.z

        let fy = (L + 16.0) / 116.0
        let fx = a / labKappa + fy
        let fz = fy - b / labLambda

        let xn = fx > labDelta ? pow(fx, 3.0) : (fx - labOffset) * labInvSlope
        let yn = fy > labDelta ? pow(fy, 3.0) : (fy - labOffset) * labInvSlope
        let zn = fz > labDelta ? pow(fz, 3.0) : (fz - labOffset) * labInvSlope

        let x = xn * 0.95047
        let y = yn * 1.00000
        let z = zn * 1.08883

        let r = x * 3.2404542 - y * 1.5371385 - z * 0.4985314
        let g = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        let bRgb = x * 0.0556434 - y * 0.2040259 + z * 1.0572252
        return SIMD3(r, g, bRgb)
    }

    /// Port of `labToLch`: CIE Lab to LCh. Hue is in radians.
    public static func labToLch(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let a = lab.y
        let b = lab.z
        return SIMD3(lab.x, (a * a + b * b).squareRoot(), atan2(b, a))
    }

    /// Port of `lchToLab`: LCh to CIE Lab. Hue is in radians.
    public static func lchToLab(_ lch: SIMD3<Float>) -> SIMD3<Float> {
        let C = lch.y
        let h = lch.z
        return SIMD3(lch.x, C * cos(h), C * sin(h))
    }

    // MARK: - colorMixing.ts: CPU forward conversion

    /// Port of `convertP3ToMixSpaceCPU`: converts linear P3 to the mix space of `mode`.
    ///
    /// Modes: 0 linear (returns the input), 1 OKLCh, 2 OKLab, 3 HSL, 4 HSV, 5 LCh. Unknown modes
    /// act like 0. The math runs in `Double`, like the upstream JavaScript.
    public static func convertP3ToMixSpaceCPU(r: Float, g: Float, b: Float, mode: Int) -> SIMD3<Float> {
        let srgb = p3ToSRGBCPU(Double(r), Double(g), Double(b))
        let out: SIMD3<Double>
        switch mode {
        case 1:
            let lab = rgbToOklabCPU(srgb)
            out = SIMD3(lab.x, (lab.y * lab.y + lab.z * lab.z).squareRoot(), atan2(lab.z, lab.y))
        case 2:
            out = rgbToOklabCPU(srgb)
        case 3:
            out = rgbToHslCPU(srgb)
        case 4:
            out = rgbToHsvCPU(srgb)
        case 5:
            let lab = rgbToLabCPU(srgb)
            out = SIMD3(lab.x, (lab.y * lab.y + lab.z * lab.z).squareRoot(), atan2(lab.z, lab.y))
        default:
            return SIMD3(r, g, b)
        }
        return SIMD3<Float>(out)
    }

    private static let epsCPU = 0.0001
    private static let labDeltaCPU = 6.0 / 29.0

    private static func p3ToSRGBCPU(_ r: Double, _ g: Double, _ b: Double) -> SIMD3<Double> {
        SIMD3(
            r * 1.2249401 - g * 0.2249404,
            r * -0.0420569 + g * 1.0420571,
            r * -0.0196376 - g * 0.0786361 + b * 1.0982735
        )
    }

    private static func rgbToOklabCPU(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let (r, g, b) = (rgb.x, rgb.y, rgb.z)
        let l = cbrt(r * 0.4122214708 + g * 0.5363325363 + b * 0.0514459929)
        let m = cbrt(r * 0.2119034982 + g * 0.6806995451 + b * 0.1073969566)
        let s = cbrt(r * 0.0883024619 + g * 0.2817188376 + b * 0.6299787005)
        return SIMD3(
            l * 0.2104542553 + m * 0.7936177850 - s * 0.0040720468,
            l * 1.9779984951 - m * 2.4285922050 + s * 0.4505937099,
            l * 0.0259040371 + m * 0.7827717662 - s * 0.8086757660
        )
    }

    private static func rgbHueCPU(_ rgb: SIMD3<Double>, maxVal: Double, delta: Double) -> Double {
        let (r, g, b) = (rgb.x, rgb.y, rgb.z)
        let den = max(delta, epsCPU)
        let hue: Double
        if maxVal == r {
            hue = (g - b) / den
        } else if maxVal == g {
            hue = 2 + (b - r) / den
        } else {
            hue = 4 + (r - g) / den
        }
        return hue * (Double.pi / 3)
    }

    private static func rgbToHslCPU(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let maxVal = max(rgb.x, rgb.y, rgb.z)
        let minVal = min(rgb.x, rgb.y, rgb.z)
        let delta = maxVal - minVal
        let l = (maxVal + minVal) * 0.5
        let s = delta / max(1 - abs(2 * l - 1), epsCPU)
        return SIMD3(rgbHueCPU(rgb, maxVal: maxVal, delta: delta), s, l)
    }

    private static func rgbToHsvCPU(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let maxVal = max(rgb.x, rgb.y, rgb.z)
        let delta = maxVal - min(rgb.x, rgb.y, rgb.z)
        let s = delta / max(maxVal, epsCPU)
        return SIMD3(rgbHueCPU(rgb, maxVal: maxVal, delta: delta), s, maxVal)
    }

    private static func rgbToLabCPU(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let (r, g, b) = (rgb.x, rgb.y, rgb.z)
        let x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883
        let delta3 = pow(labDeltaCPU, 3)
        func f(_ t: Double) -> Double {
            t > delta3 ? cbrt(t) : t / (3 * labDeltaCPU * labDeltaCPU) + 4 / 29
        }
        let fx = f(x)
        let fy = f(y)
        let fz = f(z)
        return SIMD3(fy * 116 - 16, (fx - fy) * 500, (fy - fz) * 200)
    }

    // MARK: - Helpers

    /// WGSL `sign`: -1, 0 or 1.
    private static func wgslSign(_ v: Float) -> Float {
        v > 0 ? 1 : (v < 0 ? -1 : 0)
    }

    /// The `std.select` hue chain shared by `rgbToHsl` and `rgbToHsv`, before the π/3 scale.
    private static func gpuHue(r: Float, g: Float, b: Float, maxVal: Float, delta: Float) -> Float {
        let hueR = (g - b) / max(delta, epsilon)
        let hueG = 2.0 + (b - r) / max(delta, epsilon)
        let hueB = 4.0 + (r - g) / max(delta, epsilon)
        if maxVal == r { return hueR }
        if maxVal == g { return hueG }
        return hueB
    }
}
