# Ellipse

Ellipse with independently adjustable horizontal and vertical radii

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Ellipse(color: "#ffffff", radiusX: 0.35, radiusY: 0.2)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Ellipse(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radiusX: Float = 0.35, radiusY: Float = 0.2, rotation: Float = 0, softness: Float = 0, strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Fill color of the ellipse |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the ellipse |
| `radiusX` | `Float` | `0.35` | 0.01 … 1, step 0.01 | Horizontal semi-axis radius |
| `radiusY` | `Float` | `0.2` | 0.01 … 1, step 0.01 | Vertical semi-axis radius |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees |
| `softness` | `Float` | `0` | 0 … 0.1, step 0.001 | Edge softness for antialiasing |
| `strokeThickness` | `Float` | `0` | 0 … 0.2, step 0.005 | Stroke thickness. Zero means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the shape edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors |

Dynamic form (same values): `ShaderNode(type: "Ellipse", props: ["origin": .string("center"), "color": .string("#ffffff")])`

## Notes

- `Ellipse` also exists in SwiftUI or the standard library: write `ShadersKit.Ellipse` in files that import SwiftUI.
