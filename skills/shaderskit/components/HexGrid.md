# HexGrid

Honeycomb hexagonal grid pattern

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    HexGrid(colorA: "#000000", colorB: "#ffffff", cells: 8)
}
```

Initializer (all parameters optional, defaults shown):

```swift
HexGrid(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", cells: Float = 8, thickness: Float = 1, rotation: Float = 0, softness: Float = 0, variation: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | Cell fill color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Grid line color |
| `cells` | `Float` | `8` | 1 … 40, step 1 | Number of hexagons along the canvas height (the width fits as many as the aspect ratio allows) |
| `thickness` | `Float` | `1` | 0 … 10, step 0.1 | Thickness of the hex grid lines |
| `rotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the grid in degrees |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the line edges (0 = crisp, 1 = very soft) |
| `variation` | `Float` | `0` | 0 … 1, step 0.01 | Per-cell random lightening/darkening of the cell fill color |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "HexGrid", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`
