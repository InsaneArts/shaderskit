# PolarCoordinates

Convert rectangular coordinates to polar space

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    PolarCoordinates(wrap: 1, radius: 1, intensity: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
PolarCoordinates(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), wrap: Float = 1, radius: Float = 1, intensity: Float = 1, edges: EdgeMode = .transparent, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point for polar coordinate conversion |
| `wrap` | `Float` | `1` | 0 … 2, step 0.1 | Controls how much of the angular range to use (1 = full 360°, 0.5 = 180°) |
| `radius` | `Float` | `1` | 0 … 2, step 0.1 | Controls how much of the radius range to use (affects the radial mapping) |
| `intensity` | `Float` | `1` | 0 … 1, step 0.1 | Blends between original UVs (0) and polar coordinates (1) |
| `edges` | `EdgeMode` | `"transparent"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "PolarCoordinates", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "wrap": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
