# ConicGradient

Colors sweep in a full circle around a center point, like a color wheel

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ConicGradient(colorA: "#FF0080", colorB: "#00BFFF", rotation: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ConicGradient(colorA: ShaderColor = "#FF0080", colorB: ShaderColor = "#00BFFF", stops: [ColorStop]? = nil, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), rotation: Float = 0, `repeat`: Float = 1, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#FF0080"` | CSS color string | Starting color of the sweep |
| `colorB` | `ShaderColor` | `"#00BFFF"` | CSS color string | Ending color of the sweep (wraps back to Color A) |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the sweep |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation offset in degrees — shifts where Color A begins |
| `repeat` | `Float` | `1` | 1 … 24, step 1 | Number of times the gradient repeats around the circle. Values above 1 create a starburst pattern. |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "ConicGradient", props: ["colorA": .string("#FF0080"), "colorB": .string("#00BFFF")])`
