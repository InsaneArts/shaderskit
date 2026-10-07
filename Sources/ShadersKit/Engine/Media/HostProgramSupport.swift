#if canImport(Metal)
import Foundation
import Metal

/// Helpers shared by the ported per-frame host hooks (`onBeforeRender` + `setExtraField`).
extension MediaContext {
    /// Upstream `getCpuValue(colorProp)`: the color prop transformed to linear RGBA in the
    /// renderer's working color space.
    func linearColor(_ name: String) -> SIMD4<Float> {
        let css = string(name) ?? "#000000"
        let c = CSSColor.linear(css, mode: options.colorSpace)
        return SIMD4(c.r, c.g, c.b, c.a)
    }

    /// Integer encoding of the `colorSpace` select prop (0 linear, 1 oklch, 2 oklab, 3 hsl, 4 hsv, 5 lch).
    func colorSpaceMode(_ name: String = "colorSpace") -> Int {
        Int(PropTransforms.transformColorSpace(string(name) ?? "linear"))
    }
}

#endif
