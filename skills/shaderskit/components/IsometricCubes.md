# IsometricCubes

Isometric tumbling-blocks tiling — a 3D cube illusion (rhombille pattern)

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    IsometricCubes(colorA: "#7c5cff", colorB: "#ff5c9d", lineColor: "#000000")
}
```

Initializer (all parameters optional, defaults shown):

```swift
IsometricCubes(colorA: ShaderColor = "#7c5cff", colorB: ShaderColor = "#ff5c9d", lineColor: ShaderColor = "#000000", cells: Float = 6, thickness: Float = 1, rotation: Float = 0, softness: Float = 0, colorVariation: Float = 1, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#7c5cff"` | CSS color string | Base cube color |
| `colorB` | `ShaderColor` | `"#ff5c9d"` | CSS color string | Second cube color, mixed in per-cube for variation |
| `lineColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the cube edge lines |
| `cells` | `Float` | `6` | 1 … 30, step 1 | Number of cubes across the shortest canvas edge |
| `thickness` | `Float` | `1` | 0 … 10, step 0.1 | Thickness of the cube edge lines (0 = no edges) |
| `rotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the tiling in degrees |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the edge lines (0 = crisp, 1 = very soft) |
| `colorVariation` | `Float` | `1` | 0 … 1, step 0.01 | Per-cube random blend between the two colors (0 = uniform cubes, the clean 3D look) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "IsometricCubes", props: ["colorA": .string("#7c5cff"), "colorB": .string("#ff5c9d")])`
