# Bulge

Magnify or pinch content around a center point

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Bulge(strength: 1, radius: 1, falloff: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Bulge(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), strength: Float = 1, radius: Float = 1, falloff: Float = 0.5, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the bulge effect |
| `strength` | `Float` | `1` | -1 … 1, step 0.01 | The intensity of the bulge effect (positive = bulge out, negative = pinch in) |
| `radius` | `Float` | `1` | 0 … 5, step 0.1 | The radius of the bulge effect area |
| `falloff` | `Float` | `0.5` | 0 … 1, step 0.01 | Controls the smoothness of the transition (0 = hard edge, 1 = very smooth) |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Bulge", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "strength": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
