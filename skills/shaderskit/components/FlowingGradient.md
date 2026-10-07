# FlowingGradient

Liquid silk gradient with organic flowing color bands

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FlowingGradient(colorA: "#0a0015", colorB: "#6b17e6", colorC: "#ff4d6a")
}
```

Initializer (all parameters optional, defaults shown):

```swift
FlowingGradient(colorA: ShaderColor = "#0a0015", colorB: ShaderColor = "#6b17e6", colorC: ShaderColor = "#ff4d6a", colorD: ShaderColor = "#ff6b35", colorSpace: ColorSpace = .oklch, speed: Float = 1, distortion: Float = 0.5, seed: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#0a0015"` | CSS color string | Deep background color |
| `colorB` | `ShaderColor` | `"#6b17e6"` | CSS color string | Primary accent color |
| `colorC` | `ShaderColor` | `"#ff4d6a"` | CSS color string | Secondary accent color |
| `colorD` | `ShaderColor` | `"#ff6b35"` | CSS color string | Tertiary accent color |
| `colorSpace` | `ColorSpace` | `"oklch"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `speed` | `Float` | `1` | 0 … 10, step 0.1 | Animation speed |
| `distortion` | `Float` | `0.5` | 0 … 2, step 0.1 | Organic distortion intensity |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for variation |

Dynamic form (same values): `ShaderNode(type: "FlowingGradient", props: ["colorA": .string("#0a0015"), "colorB": .string("#6b17e6")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
