# BrickPattern

Classic brick wall pattern with alternating rows and mortar gaps

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BrickPattern(colorBrick: "#000000", colorMortar: "#ffffff", cellsX: 8)
}
```

Initializer (all parameters optional, defaults shown):

```swift
BrickPattern(colorBrick: ShaderColor = "#000000", colorMortar: ShaderColor = "#ffffff", cellsX: Float = 8, cellsY: Float = 10, mortar: Float = 0.05, softness: Float = 0, variation: Float = 0, rotation: Float = 0, speed: Float = 0, offset: Float = 0, speedVariance: Float = 0, seed: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorBrick` | `ShaderColor` | `"#000000"` | CSS color string | Brick color |
| `colorMortar` | `ShaderColor` | `"#ffffff"` | CSS color string | Mortar / gap color |
| `cellsX` | `Float` | `8` | 1 … 30, step 1 | Number of bricks per row |
| `cellsY` | `Float` | `10` | 1 … 30, step 1 | Number of brick rows |
| `mortar` | `Float` | `0.05` | 0 … 1, step 0.01 | Width of mortar gaps — equal pixel thickness in both directions |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the brick edges (0 = crisp, 1 = very soft) |
| `variation` | `Float` | `0` | 0 … 1, step 0.01 | Per-brick random lightening/darkening of the brick color |
| `rotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the pattern in degrees |
| `speed` | `Float` | `0` | -2 … 2, step 0.1 | Animation speed |
| `offset` | `Float` | `0` | 0 … 1, step 0.01 | Static horizontal offset — shifts the brick pattern without animating |
| `speedVariance` | `Float` | `0` | 0 … 1, step 0.01 | How much each row's speed varies — at high values rows move at different speeds and directions |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for per-row speed variation |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolation |

Dynamic form (same values): `ShaderNode(type: "BrickPattern", props: ["colorBrick": .string("#000000"), "colorMortar": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
