# Scratches

Fine hairline scratches, like a worn film or scratched surface

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Scratches(colorA: "#ffffff", colorB: "#000000", scale: 2)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Scratches(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#000000", scale: Float = 2, thickness: Float = 1, seed: Float = 0, speed: Float = 1, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | First color |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Second color |
| `scale` | `Float` | `2` | -2 … 5, step 0.1 | Pattern scale (higher = more, finer scratches) |
| `thickness` | `Float` | `1` | 0.2 … 5, step 0.01 | Thickness of the scratches (higher = bolder streaks) |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |
| `speed` | `Float` | `1` | 0 … 5, step 0.1 | Animation speed |

Dynamic form (same values): `ShaderNode(type: "Scratches", props: ["colorA": .string("#ffffff"), "colorB": .string("#000000")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
