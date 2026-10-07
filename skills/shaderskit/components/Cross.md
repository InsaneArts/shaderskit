# Cross

Plus / cross shape with adjustable arm length, width, and rounding

- Category: Shapes · Role: shape
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Cross(color: "#ffffff", radius: 0.35, thickness: 0.08)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Cross(origin: ShaderOrigin = .center, color: ShaderColor = "#ffffff", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), radius: Float = 0.35, thickness: Float = 0.08, rounding: Float = 0, rotation: Float = 0, softness: Float = 0, strokeThickness: Float = 0, strokeColor: ShaderColor = "#000000", strokePosition: StrokePosition = .center, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Fill color of the cross |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the cross |
| `radius` | `Float` | `0.35` | 0 … 1, step 0.01 | Arm half-length — distance from center to the end of each arm |
| `thickness` | `Float` | `0.08` | 0.01 … 0.5, step 0.005 | Arm half-width — controls how wide each arm is |
| `rounding` | `Float` | `0` | 0 … 0.2, step 0.005 | Corner rounding — rounds the arm ends and concave corners |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees (45° turns a plus into an ×) |
| `softness` | `Float` | `0` | 0 … 0.1, step 0.001 | Edge softness for antialiasing |
| `strokeThickness` | `Float` | `0` | 0 … 0.2, step 0.005 | Stroke thickness. Zero means no stroke. |
| `strokeColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the stroke outline |
| `strokePosition` | `StrokePosition` | `"center"` | `outside`, `center`, `inside` | Position of the stroke relative to the shape edge |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending fill and stroke colors |

Dynamic form (same values): `ShaderNode(type: "Cross", props: ["origin": .string("center"), "color": .string("#ffffff")])`
