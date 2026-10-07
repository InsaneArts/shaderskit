# Truchet

Quarter-circle arc tiles that connect to form organic, maze-like flowing curves

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Truchet(colorA: "#000000", colorB: "#ffffff", cells: 10)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Truchet(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", cells: Float = 10, thickness: Float = 2, rotation: Float = 0, softness: Float = 0, seed: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | Background color between the arcs |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Arc line color |
| `cells` | `Float` | `10` | 2 … 40, step 1 | Number of tiles across the shortest canvas edge |
| `thickness` | `Float` | `2` | 0 … 20, step 0.1 | Thickness of the arc lines |
| `rotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the tiling in degrees |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the arc edges (0 = crisp, 1 = very soft) |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — changes which tiles flip, producing a different maze pattern |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Truchet", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`
