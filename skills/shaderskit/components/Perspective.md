# Perspective

Rotate the plane in 3D space with pan and tilt

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Perspective(pan: 0, tilt: 0, fov: 60) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Perspective(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), pan: Float = 0, tilt: Float = 0, fov: Float = 60, zoom: Float = 1, offset: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), edges: EdgeMode = .transparent, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of rotation |
| `pan` | `Float` | `0` | -90 … 90, step 0.1 | Horizontal rotation (left/right) |
| `tilt` | `Float` | `0` | -90 … 90, step 0.1 | Vertical rotation (up/down) |
| `fov` | `Float` | `60` | 30 … 120, step 1 | Field of view - controls perspective intensity |
| `zoom` | `Float` | `1` | 0.5 … 3, step 0.1 | Zoom in to fill the frame after rotation |
| `offset` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Shift the result in X/Y |
| `edges` | `EdgeMode` | `"transparent"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges |

Dynamic form (same values): `ShaderNode(type: "Perspective", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "pan": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
