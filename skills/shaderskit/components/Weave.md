# Weave

Interlaced textile weave pattern with two thread colors going over and under each other

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Weave(colorA: "#c4c4c4", colorB: "#4d4d4d", cells: 10)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Weave(colorA: ShaderColor = "#c4c4c4", colorB: ShaderColor = "#4d4d4d", cells: Float = 10, gap: Float = 0.25, rotation: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#c4c4c4"` | CSS color string | Horizontal thread color |
| `colorB` | `ShaderColor` | `"#4d4d4d"` | CSS color string | Vertical thread color |
| `cells` | `Float` | `10` | 2 … 40, step 1 | Number of threads across the shortest canvas edge |
| `gap` | `Float` | `0.25` | 0 … 0.45, step 0.01 | Gap between threads (0 = no gap, 0.5 = maximum gap) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the weave pattern in degrees |

Dynamic form (same values): `ShaderNode(type: "Weave", props: ["colorA": .string("#c4c4c4"), "colorB": .string("#4d4d4d")])`
