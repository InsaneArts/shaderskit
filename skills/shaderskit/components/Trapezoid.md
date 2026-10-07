# Trapezoid

Trapezoid with adjustable top and bottom widths and height

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Trapezoid(color: "#ffffff", bottomWidth: 0.35, topWidth: 0.2)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Trapezoid(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), bottomWidth: DimensionalValue = 0.35, topWidth: Float = 0.2, height: DimensionalValue = 0.25, rotation: Float = 0, softness: Float = 0, strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Fill color of the trapezoid |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the trapezoid |
| `bottomWidth` | `DimensionalValue` | `0.35` | 0.01 … 1, step 0.01, fraction or `.px(n)` | Half-width of the bottom edge |
| `topWidth` | `Float` | `0.2` | 0.01 … 1, step 0.01 | Half-width of the top edge |
| `height` | `DimensionalValue` | `0.25` | 0.01 … 1, step 0.01, fraction or `.px(n)` | Half-height of the trapezoid |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees |
| `softness` | `Float` | `0` | 0 … 0.1, step 0.001 | Edge softness for antialiasing |
| `strokeThickness` | `Float` | `0` | 0 … 0.2, step 0.005 | Stroke thickness. Zero means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the shape edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors |

Dynamic form (same values): `ShaderNode(type: "Trapezoid", props: ["origin": .string("center"), "color": .string("#ffffff")])`
