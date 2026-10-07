# Ring

Annular ring (donut) with adjustable radius and band thickness

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Ring(color: "#ffffff", radius: 0.3, thickness: 0.07)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Ring(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radius: Float = 0.3, thickness: Float = 0.07, softness: Float = 0, strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Fill color of the ring |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the ring |
| `radius` | `Float` | `0.3` | 0 … 1, step 0.01 | Distance from center to the ring's midline in UV space |
| `thickness` | `Float` | `0.07` | 0.005 … 0.3, step 0.005 | Half-width of the ring band — total ring width is twice this value |
| `softness` | `Float` | `0` | 0 … 0.1, step 0.001 | Edge softness for antialiasing (applied to both inner and outer ring edges) |
| `strokeThickness` | `Float` | `0` | 0 … 0.1, step 0.005 | Stroke thickness. Zero means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the ring edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors |

Dynamic form (same values): `ShaderNode(type: "Ring", props: ["origin": .string("center"), "color": .string("#ffffff")])`
