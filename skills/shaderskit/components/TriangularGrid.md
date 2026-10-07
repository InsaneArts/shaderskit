# TriangularGrid

Tiling grid of equilateral triangles with optional animated row offsets

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    TriangularGrid(colorA: "#1a1a1a", colorB: "#ffffff", cells: 8)
}
```

Initializer (all parameters optional, defaults shown):

```swift
TriangularGrid(colorA: ShaderColor = "#1a1a1a", colorB: ShaderColor = "#ffffff", cells: Float = 8, thickness: Float = 1, rotation: Float = 0, softness: Float = 0, variation: Float = 0, speed: Float = 0, speedVariance: Float = 0.3, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#1a1a1a"` | CSS color string | Triangle fill color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Grid line color |
| `cells` | `Float` | `8` | 1 … 40, step 1 | Number of triangle rows down the shortest canvas edge |
| `thickness` | `Float` | `1` | 0 … 10, step 0.1 | Thickness of the grid lines (0 = no lines) |
| `rotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the grid in degrees |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the line edges (0 = crisp, 1 = very soft) |
| `variation` | `Float` | `0` | 0 … 1, step 0.01 | Per-triangle random lightening/darkening of the fill color |
| `speed` | `Float` | `0` | -3 … 3, step 0.01 | Animates the triangle rows drifting horizontally (0 = static) |
| `speedVariance` | `Float` | `0.3` | 0 … 1, step 0.01 | Per-row random speed variance for irregular drifting motion |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "TriangularGrid", props: ["colorA": .string("#1a1a1a"), "colorB": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
