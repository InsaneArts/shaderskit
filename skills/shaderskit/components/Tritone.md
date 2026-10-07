# Tritone

Map colors to three tones: shadows, midtones, highlights

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Tritone(colorA: "#ce1bea", colorB: "#2fff00", colorC: "#ffff00") {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Tritone(colorA: ShaderColor = "#ce1bea", colorB: ShaderColor = "#2fff00", colorC: ShaderColor = "#ffff00", blendMid: Float = 0.5, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ce1bea"` | CSS color string | First color (used for shadows/darkest areas) |
| `colorB` | `ShaderColor` | `"#2fff00"` | CSS color string | Second color (used for midtones) |
| `colorC` | `ShaderColor` | `"#ffff00"` | CSS color string | Third color (used for highlights/brightest areas) |
| `blendMid` | `Float` | `0.5` | 0 … 1, step 0.1 | Midpoint position between the three colors |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Tritone", props: ["colorA": .string("#ce1bea"), "colorB": .string("#2fff00")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
