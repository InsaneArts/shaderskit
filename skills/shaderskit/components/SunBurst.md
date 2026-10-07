# SunBurst

Radial sunburst rays emanating from a center point

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    SunBurst(color: "#ffdd88", background: "#000000", rayCount: 12)
}
```

Initializer (all parameters optional, defaults shown):

```swift
SunBurst(color: ShaderColor = "#ffdd88", background: ShaderColor = "#000000", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), rayCount: Float = 12, softness: Float = 0.3, radius: Float = 0.8, feather: Float = 0.5, speed: Float = 0.2, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ffdd88"` | CSS color string | Ray color |
| `background` | `ShaderColor` | `"#000000"` | CSS color string | Background color |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the sunburst |
| `rayCount` | `Float` | `12` | 3 … 64, step 1 | Number of rays |
| `softness` | `Float` | `0.3` | 0 … 1, step 0.01 | Softness of ray edges |
| `radius` | `Float` | `0.8` | 0 … 1.2, step 0.01 | How far the rays extend from the center |
| `feather` | `Float` | `0.5` | 0 … 5, step 0.01 | How gradually the rays fade at their outer edge |
| `speed` | `Float` | `0.2` | -2 … 2, step 0.1 | Rotation speed — positive values rotate clockwise |

Dynamic form (same values): `ShaderNode(type: "SunBurst", props: ["color": .string("#ffdd88"), "background": .string("#000000")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
