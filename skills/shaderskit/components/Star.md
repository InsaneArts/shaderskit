# Star

Classic star polygon with straight sides and sharp pointed tips

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Star(color: "#ffffff", radius: 0.4, sides: 5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Star(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radius: Float = 0.4, sides: Float = 5, innerRatio: Float = 0.4, rotation: Float = 0, softness: Float = 0, strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Fill color of the star |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the star |
| `radius` | `Float` | `0.4` | 0 … 1, step 0.01 | Outer tip radius — distance from center to the pointed tips |
| `sides` | `Float` | `5` | 3 … 12, step 1 | Number of points on the star |
| `innerRatio` | `Float` | `0.4` | 0.1 … 0.9, step 0.01 | Inner vertex radius as a ratio of outer radius (0.382 = golden-ratio 5-star) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees |
| `softness` | `Float` | `0` | 0 … 0.1, step 0.001 | Edge softness for antialiasing |
| `strokeThickness` | `Float` | `0` | 0 … 0.2, step 0.005 | Stroke thickness. Zero means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the shape edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors |

Dynamic form (same values): `ShaderNode(type: "Star", props: ["origin": .string("center"), "color": .string("#ffffff")])`
