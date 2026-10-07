# RectangularCoordinates

Convert polar coordinates back to rectangular space

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    RectangularCoordinates(scale: 1, intensity: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
RectangularCoordinates(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, intensity: Float = 1, edges: EdgeMode = .transparent, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point for rectangular coordinate conversion |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.1 | Scale factor for the rectangular output |
| `intensity` | `Float` | `1` | 0 … 1, step 0.1 | Blends between original UVs (0) and rectangular coordinates (1) |
| `edges` | `EdgeMode` | `"transparent"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "RectangularCoordinates", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "scale": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
