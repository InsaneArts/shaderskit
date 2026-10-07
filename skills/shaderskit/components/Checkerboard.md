# Checkerboard

Classic checkerboard pattern with two alternating colors

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Checkerboard(colorA: "#cccccc", colorB: "#999999", cells: 8)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Checkerboard(colorA: ShaderColor = "#cccccc", colorB: ShaderColor = "#999999", cells: DimensionalValue = 8, softness: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#cccccc"` | CSS color string | First color of the checkerboard pattern |
| `colorB` | `ShaderColor` | `"#999999"` | CSS color string | Second color of the checkerboard pattern |
| `cells` | `DimensionalValue` | `8` | 1 … 50, step 1 | Number of cells along the canvas height (creates square cells). Switch the unit to px in the editor to set an absolute cell size instead. |
| `softness` | `Float` | `0` | 0 … 1, step 0.1 | Smoothness of the transition between colors (0 = hard edges, 1 = very soft) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Checkerboard", props: ["colorA": .string("#cccccc"), "colorB": .string("#999999")])`
