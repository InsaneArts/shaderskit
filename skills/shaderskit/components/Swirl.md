# Swirl

Flowing swirl pattern with multi-layered noise

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Swirl(colorA: "#1275d8", colorB: "#e19136", speed: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Swirl(colorA: ShaderColor = "#1275d8", colorB: ShaderColor = "#e19136", stops: [ColorStop]? = nil, speed: Float = 1, detail: Float = 1, blend: Float = 50, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#1275d8"` | CSS color string | Primary gradient color |
| `colorB` | `ShaderColor` | `"#e19136"` | CSS color string | Secondary gradient color |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `speed` | `Float` | `1` | 0 … 5, step 0.1 | Flow animation speed |
| `detail` | `Float` | `1` | 0 … 5, step 0.1 | Level of detail and intricacy in the swirl patterns |
| `blend` | `Float` | `50` | 0 … 100, step 1 | Skew color balance toward A (lower values) or B (higher values) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Swirl", props: ["colorA": .string("#1275d8"), "colorB": .string("#e19136")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
