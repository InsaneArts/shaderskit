# ContourLines

Draw topographical contour lines based on luminance or alpha

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ContourLines(levels: 5, lineWidth: 2, softness: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ContourLines(levels: Float = 5, lineWidth: Float = 2, softness: Float = 0, gamma: Float = 0.5, invert: Bool = false, source: Source = .luminance, colorMode: ColorMode = .source, lineColor: ShaderColor = "#000000", backgroundColor: ShaderColor = "transparent", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `ContourLines.Source`: .luminance, .alpha
- `ContourLines.ColorMode`: .source, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `levels` | `Float` | `5` | 2 … 30, step 1 | Number of contour levels |
| `lineWidth` | `Float` | `2` | 0.5 … 5, step 0.1 | Width of the contour lines in pixels |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Edge softness of the lines (0 = sharp, 1 = soft) |
| `gamma` | `Float` | `0.5` | 0.1 … 2, step 0.01 | Contour distribution. <1 clusters in bright, >1 clusters in dark |
| `invert` | `Bool` | `false` | — | Invert the source values |
| `source` | `Source` | `"luminance"` | `luminance`, `alpha` | Use luminance or alpha channel for contours |
| `colorMode` | `ColorMode` | `"source"` | `source`, `custom` | Use source image colors or custom colors |
| `lineColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the contour lines (custom mode) |
| `backgroundColor` | `ShaderColor` | `"transparent"` | CSS color string | Background color (custom mode) |

Dynamic form (same values): `ShaderNode(type: "ContourLines", props: ["levels": .number(5), "lineWidth": .number(2)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
