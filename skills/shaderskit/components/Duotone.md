# Duotone

Map colors to two tones based on luminance

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Duotone(colorA: "#ff0000", colorB: "#023af4", blend: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Duotone(colorA: ShaderColor = "#ff0000", colorB: ShaderColor = "#023af4", blend: Float = 0.5, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ff0000"` | CSS color string | First color (used for darker areas) |
| `colorB` | `ShaderColor` | `"#023af4"` | CSS color string | Second color (used for brighter areas) |
| `blend` | `Float` | `0.5` | 0 … 1, step 0.1 | Blend point between the two colors |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Duotone", props: ["colorA": .string("#ff0000"), "colorB": .string("#023af4")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
