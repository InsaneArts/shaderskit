# Chevron

Animated chevron / zigzag stripe pattern

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Chevron(colorA: "#000000", colorB: "#ffffff", count: 5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Chevron(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", count: Float = 5, angle: Float = 0, balance: Float = 0.5, softness: Float = 0, speed: Float = 0, offset: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | First color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Second color |
| `count` | `Float` | `5` | 1 … 30, step 1 | Number of chevron pairs visible |
| `angle` | `Float` | `0` | -180 … 180, step 1, degrees | Rotation angle of the chevrons |
| `balance` | `Float` | `0.5` | 0 … 1, step 0.01 | Ratio of the two colors |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Edge softness |
| `speed` | `Float` | `0` | -2 … 2, step 0.1 | Animation speed |
| `offset` | `Float` | `0` | 0 … 1, step 0.01 | Phase offset for pattern positioning |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolation |

Dynamic form (same values): `ShaderNode(type: "Chevron", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
