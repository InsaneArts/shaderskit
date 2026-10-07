# GradientMap

Maps source luminance through an animated color gradient (Photoshop-style gradient map)

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    GradientMap(colorLow: "#1a0b2e", colorMid: "#e94560", colorHigh: "#f9ed69") {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
GradientMap(palette: Palette = .rainbow, colorLow: ShaderColor = "#1a0b2e", colorMid: ShaderColor = "#e94560", colorHigh: ShaderColor = "#f9ed69", speed: Float = 0.15, contrast: Float = 1, blackPoint: Float = 0, whitePoint: Float = 1, strength: Float = 1, colorSpace: ColorSpace = .oklch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `GradientMap.Palette`: .rainbow, .sunset, .ocean, .fire, .pastel, .neon, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `palette` | `Palette` | `"rainbow"` | `rainbow`, `sunset`, `ocean`, `fire`, `pastel`, `neon`, `custom` | Built-in cosine palette, or Custom Colors to pick your own stops |
| `colorLow` | `ShaderColor` | `"#1a0b2e"` | CSS color string | Color for the darkest tones |
| `colorMid` | `ShaderColor` | `"#e94560"` | CSS color string | Color for the midtones |
| `colorHigh` | `ShaderColor` | `"#f9ed69"` | CSS color string | Color for the brightest tones |
| `speed` | `Float` | `0.15` | -2 … 2, step 0.01 | Gradient animation speed (0 = static). The gradient cycles seamlessly. |
| `contrast` | `Float` | `1` | 0 … 3, step 0.01 | Steepness of the luminance-to-gradient mapping |
| `blackPoint` | `Float` | `0` | 0 … 1, step 0.01 | Input shadow clip — luminance at/below this maps to the start of the gradient |
| `whitePoint` | `Float` | `1` | 0 … 1, step 0.01 | Input highlight clip — luminance at/above this maps to the end of the gradient |
| `strength` | `Float` | `1` | 0 … 1, step 0.01 | Blend between the original image (0) and the gradient-mapped result (1) |
| `colorSpace` | `ColorSpace` | `"oklch"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolating custom colors |

Dynamic form (same values): `ShaderNode(type: "GradientMap", props: ["palette": .string("rainbow"), "colorLow": .string("#1a0b2e")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
