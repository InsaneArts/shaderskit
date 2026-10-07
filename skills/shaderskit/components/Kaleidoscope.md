# Kaleidoscope

Create a kaleidoscope effect with radial mirrored segments

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Kaleidoscope(segments: 6, angle: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Kaleidoscope(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), segments: Float = 6, angle: Float = 0, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the kaleidoscope effect |
| `segments` | `Float` | `6` | 2 … 24, step 1 | Number of radial segments in the kaleidoscope |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Rotation offset for the entire kaleidoscope pattern |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Kaleidoscope", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "segments": .number(6)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
