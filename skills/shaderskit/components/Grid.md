# Grid

Simple grid lines pattern with adjustable thickness and rotation

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Grid(color: "#ffffff", cellColor: "transparent", cells: 10)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Grid(color: ShaderColor = "#ffffff", cellColor: ShaderColor = "transparent", cells: Float = 10, thickness: Float = 1, rotation: Float = 0, softness: Float = 0, variation: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | The color of the grid lines |
| `cellColor` | `ShaderColor` | `"transparent"` | CSS color string | Fill color of the cells (transparent = lines only). Pair with Variation for a tiled look. |
| `cells` | `Float` | `10` | 1 … 50, step 1 | Number of cells along the canvas height (cells stay square; the width fits as many as the aspect ratio allows) |
| `thickness` | `Float` | `1` | 0 … 20, step 0.1 | Thickness of grid lines (normalized, 0.0-1.0) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the grid in degrees. At 45° this produces a crosshatch/diamond pattern. |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the line edges (0 = crisp, 1 = very soft) |
| `variation` | `Float` | `0` | 0 … 1, step 0.01 | Per-cell random lightening/darkening of the cell fill color |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Grid", props: ["color": .string("#ffffff"), "cellColor": .string("transparent")])`

## Notes

- `Grid` also exists in SwiftUI or the standard library: write `ShadersKit.Grid` in files that import SwiftUI.
