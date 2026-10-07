# Voronoi

Cellular pattern where each pixel is colored by its distance to the nearest of many scattered points

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Voronoi(colorA: "#3186cf", colorB: "#fc02dd", colorBorder: "#000000")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Voronoi(colorA: ShaderColor = "#3186cf", colorB: ShaderColor = "#fc02dd", stops: [ColorStop]? = nil, colorBorder: ShaderColor = "#000000", scale: Float = 6, speed: Float = 0.5, seed: Float = 0, edgeIntensity: Float = 0.5, edgeSoftness: Float = 0.05, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#3186cf"` | CSS color string | Color near each cell's center point |
| `colorB` | `ShaderColor` | `"#fc02dd"` | CSS color string | Color at cell boundaries, far from any center point |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorBorder` | `ShaderColor` | `"#000000"` | CSS color string | Color of the cell boundary lines |
| `scale` | `Float` | `6` | 1 … 20, step 0.5 | Number of cells across the canvas |
| `speed` | `Float` | `0.5` | 0 … 5, step 0.1 | Animation speed — how fast the cell points drift |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — shifts the cell pattern without changing the overall structure |
| `edgeIntensity` | `Float` | `0.5` | 0 … 1, step 0.01 | Controls how much of the cell interior is filled by the edge color. Low = center color dominates with a sharp boundary. High = edge color spreads further into the cell. |
| `edgeSoftness` | `Float` | `0.05` | 0 … 0.4, step 0.005 | Width of the cell boundary lines. |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Voronoi", props: ["colorA": .string("#3186cf"), "colorB": .string("#fc02dd")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
