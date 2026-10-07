# Watercolor

Painterly watercolor look — Kuwahara flattening, pigment edge darkening, paper grain and bleeding

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Watercolor(radius: 3, bleed: 1, strength: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Watercolor(radius: Float = 3, bleed: Float = 1, strength: Float = 1, paper: Float = 0.35, paperColor: ShaderColor = "#fbf7ec", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `radius` | `Float` | `3` | 1 … 8, step 1 | Brush size — radius of the painterly flattening |
| `bleed` | `Float` | `1` | 0 … 3, step 0.01 | Amount the pigment bleeds and wobbles past hard edges |
| `strength` | `Float` | `1` | 0 … 1, step 0.01 | Blend between the original image (0) and the full watercolor effect (1) |
| `paper` | `Float` | `0.35` | 0 … 1, step 0.01 | Strength of the paper grain the pigment settles into |
| `paperColor` | `ShaderColor` | `"#fbf7ec"` | CSS color string | Tint of the paper grain |

Dynamic form (same values): `ShaderNode(type: "Watercolor", props: ["radius": .number(3), "bleed": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
