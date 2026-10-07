# Stripes

Alternating colored stripes with animation

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Stripes(colorA: "#000000", colorB: "#ffffff", angle: 45)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Stripes(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", angle: Float = 45, density: Float = 5, balance: Float = 0.5, softness: Float = 0, speed: Float = 0.2, offset: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | First stripe color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Second stripe color |
| `angle` | `Float` | `45` | -180 … 180, step 1, degrees | Angle of stripes in degrees |
| `density` | `Float` | `5` | 1 … 30, step 1 | Number of stripe pairs visible |
| `balance` | `Float` | `0.5` | 0 … 1, step 0.1 | Ratio of the two colors |
| `softness` | `Float` | `0` | 0 … 1, step 0.1 | Edge softness |
| `speed` | `Float` | `0.2` | -1 … 1, step 0.1 | Animation speed |
| `offset` | `Float` | `0` | 0 … 1, step 0.1 | Phase offset for pattern positioning |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolation |

Dynamic form (same values): `ShaderNode(type: "Stripes", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
