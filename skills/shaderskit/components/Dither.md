# Dither

Dithering effect with multiple pattern options

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Dither(pixelSize: 4, threshold: 0.5, spread: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Dither(pattern: Pattern = .bayer4, pixelSize: Float = 4, threshold: Float = 0.5, spread: Float = 1, colorMode: ColorMode = .custom, colorA: ShaderColor = "transparent", colorB: ShaderColor = "#ffffff", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Dither.Pattern`: .bayer2, .bayer4, .bayer8, .clusteredDot, .blueNoise, .whiteNoise, .floydSteinberg
- `Dither.ColorMode`: .custom, .source

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `pattern` | `Pattern` | `"bayer4"` | `bayer2`, `bayer4`, `bayer8`, `clusteredDot`, `blueNoise`, `whiteNoise`, `floydSteinberg` | Dithering pattern algorithm |
| `pixelSize` | `Float` | `4` | 1 … 20, step 1 | Size of dithering pixels |
| `threshold` | `Float` | `0.5` | 0 … 1, step 0.01 | Luminance threshold for dithering |
| `spread` | `Float` | `1` | 0 … 1, step 0.01 | How much of the luminance range participates in dithering (lower = more solid areas) |
| `colorMode` | `ColorMode` | `"custom"` | `custom`, `source` | How colors are determined |
| `colorA` | `ShaderColor` | `"transparent"` | CSS color string | Dark color for dithering |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Light color for dithering |

Dynamic form (same values): `ShaderNode(type: "Dither", props: ["pattern": .string("bayer4"), "pixelSize": .number(4)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
