# MultiPointGradient

Five individually placed color points blended together by proximity — drag each point to shape the gradient

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    MultiPointGradient(colorA: "#4776E6", colorB: "#C44DFF", colorC: "#1ABC9C")
}
```

Initializer (all parameters optional, defaults shown):

```swift
MultiPointGradient(colorA: ShaderColor = "#4776E6", positionA: ShaderPosition = ShaderPosition(x: 0.2, y: 0.2), colorB: ShaderColor = "#C44DFF", positionB: ShaderPosition = ShaderPosition(x: 0.8, y: 0.2), colorC: ShaderColor = "#1ABC9C", positionC: ShaderPosition = ShaderPosition(x: 0.2, y: 0.8), colorD: ShaderColor = "#F8BBD9", positionD: ShaderPosition = ShaderPosition(x: 0.8, y: 0.8), colorE: ShaderColor = "#FF8C42", positionE: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), colorSpace: ColorSpace = .linear, smoothness: Float = 2, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#4776E6"` | CSS color string | Color of control point A |
| `positionA` | `ShaderPosition` | `(0.2, 0.2)` | `ShaderPosition` (0…1, top-left origin) | Position of control point A |
| `colorB` | `ShaderColor` | `"#C44DFF"` | CSS color string | Color of control point B |
| `positionB` | `ShaderPosition` | `(0.8, 0.2)` | `ShaderPosition` (0…1, top-left origin) | Position of control point B |
| `colorC` | `ShaderColor` | `"#1ABC9C"` | CSS color string | Color of control point C |
| `positionC` | `ShaderPosition` | `(0.2, 0.8)` | `ShaderPosition` (0…1, top-left origin) | Position of control point C |
| `colorD` | `ShaderColor` | `"#F8BBD9"` | CSS color string | Color of control point D |
| `positionD` | `ShaderPosition` | `(0.8, 0.8)` | `ShaderPosition` (0…1, top-left origin) | Position of control point D |
| `colorE` | `ShaderColor` | `"#FF8C42"` | CSS color string | Color of control point E |
| `positionE` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Position of control point E |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `smoothness` | `Float` | `2` | 0 … 5, step 0.01 | Controls how smoothly colors blend. |

Dynamic form (same values): `ShaderNode(type: "MultiPointGradient", props: ["colorA": .string("#4776E6"), "positionA": .position(.xy(x: .number(0.2), y: .number(0.2)))])`
