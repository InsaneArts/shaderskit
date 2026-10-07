# Vignette

Darkens or tints the edges of the frame, drawing attention toward the center

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Vignette(color: "#000000", radius: 0.5, falloff: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Vignette(color: ShaderColor = "#000000", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radius: Float = 0.5, falloff: Float = 0.5, intensity: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#000000"` | CSS color string | Color of the vignette at the edges |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center of the clear area where the vignette begins |
| `radius` | `Float` | `0.5` | 0 … 1.5, step 0.01 | Distance from center where the vignette begins to fade in |
| `falloff` | `Float` | `0.5` | 0.01 … 1.5, step 0.01 | Width of the transition zone from clear to full vignette |
| `intensity` | `Float` | `1` | 0 … 1, step 0.01 | Strength of the vignette effect |

Dynamic form (same values): `ShaderNode(type: "Vignette", props: ["color": .string("#000000"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
