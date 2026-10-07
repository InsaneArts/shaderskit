# DiamondGradient

Diamond-shaped gradient radiating from a center point using Manhattan distance

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DiamondGradient(colorA: "#4ffb4a", colorB: "#4f1238", size: 0.7)
}
```

Initializer (all parameters optional, defaults shown):

```swift
DiamondGradient(colorA: ShaderColor = "#4ffb4a", colorB: ShaderColor = "#4f1238", stops: [ColorStop]? = nil, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), size: Float = 0.7, rotation: Float = 0, `repeat`: Float = 1, roundness: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#4ffb4a"` | CSS color string | Color at the center of the diamond |
| `colorB` | `ShaderColor` | `"#4f1238"` | CSS color string | Color at the outer edges of the diamond |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the diamond |
| `size` | `Float` | `0.7` | 0.01 … 2, step 0.01 | Extent of the gradient — controls how far Color A reaches before transitioning to Color B |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees — tilts the diamond into a rhombus |
| `repeat` | `Float` | `1` | 1 … 16, step 0.5 | Number of times the gradient repeats outward. Values above 1 create concentric diamond or square bands. |
| `roundness` | `Float` | `0` | 0 … 1, step 0.01 | Morphs from a sharp diamond (0) to a square (1) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "DiamondGradient", props: ["colorA": .string("#4ffb4a"), "colorB": .string("#4f1238")])`
