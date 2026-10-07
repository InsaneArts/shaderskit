# Circle

Generate a circle with adjustable size and softness

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Circle(color: "#ffffff", radius: 1, softness: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Circle(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", radius: DimensionalValue = 1, softness: DimensionalValue = 0, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | The color of the circle |
| `radius` | `DimensionalValue` | `1` | 0 … 2, step 0.01, fraction or `.px(n)` | The radius of the circle. A value of one (1) is sets the circle to fit the canvas. |
| `softness` | `DimensionalValue` | `0` | 0 … 1, step 0.01 | Edge softness. Lower values like zero (0) are sharp, higher values like one (1) are softer. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | The center point of the circle |
| `strokeThickness` | `Float` | `0` | 0 … 0.5, step 0.01 | The thickness of the stroke outline. Zero (0) means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | The color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the circle edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors in soft edges |

Dynamic form (same values): `ShaderNode(type: "Circle", props: ["origin": .string("center"), "color": .string("#ffffff")])`

## Notes

- `Circle` also exists in SwiftUI or the standard library: write `ShadersKit.Circle` in files that import SwiftUI.
