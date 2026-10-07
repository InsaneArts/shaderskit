# DotGrid

Grid of dots with optional twinkling animation

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DotGrid(color: "#ffffff", density: 30, dotSize: 0.3)
}
```

Initializer (all parameters optional, defaults shown):

```swift
DotGrid(color: ShaderColor = "#ffffff", density: Float = 30, dotSize: Float = 0.3, offset: Float = 0, speed: Float = 0, speedVariance: Float = 0.3, twinkle: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | The color of the dot |
| `density` | `Float` | `30` | 1 … 200, step 1 | The number of dots along the canvas height (the width fits as many as the aspect ratio allows) |
| `dotSize` | `Float` | `0.3` | 0 … 1, step 0.01 | The size of each dot, zero (0) being invisible, one (1) filled the grid with no gaps |
| `offset` | `Float` | `0` | 0 … 1, step 0.01 | Horizontal stagger of alternating rows (0.5 = classic polka-dot brick offset) |
| `speed` | `Float` | `0` | -3 … 3, step 0.01 | Animates the rows drifting horizontally (0 = static) |
| `speedVariance` | `Float` | `0.3` | 0 … 1, step 0.01 | Per-row random speed variance for irregular drifting motion |
| `twinkle` | `Float` | `0` | 0 … 1, step 0.1 | Intensity of the twinkle effect (0 = off, 1 = full twinkle) |

Dynamic form (same values): `ShaderNode(type: "DotGrid", props: ["color": .string("#ffffff"), "density": .number(30)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
