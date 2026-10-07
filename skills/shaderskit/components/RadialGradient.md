# RadialGradient

Radial gradient radiating from a center point

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.RadialGradient(colorA: "#ff0000", colorB: "#0000ff", radius: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.RadialGradient(colorA: ShaderColor = "#ff0000", colorB: ShaderColor = "#0000ff", stops: [ColorStop]? = nil, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radius: Float = 1, `repeat`: Float = 1, aspect: Float = 1, skewAngle: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ff0000"` | CSS color string | The starting color at the center of the gradient |
| `colorB` | `ShaderColor` | `"#0000ff"` | CSS color string | The ending color at the edge of the gradient |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the radial gradient |
| `radius` | `Float` | `1` | 0 … 2, step 0.1 | The radius of the gradient (normalized, 0.0-1.0) |
| `repeat` | `Float` | `1` | 1 … 20, step 0.5 | Number of times the gradient repeats. Values above 1 create concentric rings. |
| `aspect` | `Float` | `1` | 0.1 … 4, step 0.01 | Stretches the gradient into an ellipse. Values below 1 compress vertically, above 1 compress horizontally. |
| `skewAngle` | `Float` | `0` | 0 … 360, step 1 | Rotates the ellipse axis in degrees. Only visible when Aspect is not 1. |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "RadialGradient", props: ["colorA": .string("#ff0000"), "colorB": .string("#0000ff")])`

## Notes

- `RadialGradient` also exists in SwiftUI or the standard library: write `ShadersKit.RadialGradient` in files that import SwiftUI.
