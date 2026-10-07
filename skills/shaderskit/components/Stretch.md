# Stretch

Stretch content towards a direction from a center point

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Stretch(strength: 1, angle: 0, falloff: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Stretch(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), strength: Float = 1, angle: Float = 0, falloff: Float = 0, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the stretch effect |
| `strength` | `Float` | `1` | 0 … 1, step 0.01 | The intensity of the stretch effect |
| `angle` | `Float` | `0` | 0 … 360, step 1 | The direction of the stretch in degrees |
| `falloff` | `Float` | `0` | 0 … 1, step 0.01 | Controls the sharpness of the transition (0 = sharp edge, 1 = gradual transition) |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Stretch", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "strength": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
