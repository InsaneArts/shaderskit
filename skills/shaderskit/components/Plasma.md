# Plasma

Animated effect of glowing plasma

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Plasma(density: 2, speed: 2, intensity: 1.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Plasma(density: Float = 2, speed: Float = 2, intensity: Float = 1.5, warp: Float = 0.4, contrast: Float = 1, balance: Float = 50, colorA: ShaderColor = "#7018be", colorB: ShaderColor = "#000000", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `density` | `Float` | `2` | 0 … 4, step 0.1 | Density of the plasma pattern |
| `speed` | `Float` | `2` | 0 … 5, step 0.1 | Animation speed |
| `intensity` | `Float` | `1.5` | 0.1 … 3, step 0.1 | Brightness and spread of the plasma glow |
| `warp` | `Float` | `0.4` | 0 … 1, step 0.01 | How much the flow distorts and swirls |
| `contrast` | `Float` | `1` | 0 … 3, step 0.1 | Push darks darker and lights lighter |
| `balance` | `Float` | `50` | 0 … 100, step 1 | Skew color balance toward A (higher) or B (lower) |
| `colorA` | `ShaderColor` | `"#7018be"` | CSS color string | Primary color |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Secondary color |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Plasma", props: ["density": .number(2), "speed": .number(2)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
