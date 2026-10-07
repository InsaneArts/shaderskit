# GridDistortion

Interactive grid distortion controlled by mouse position

- Category: Interactive · Role: warp
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    GridDistortion(intensity: 1, decay: 3, radius: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
GridDistortion(intensity: Float = 1, decay: Float = 3, radius: Float = 1, gridSize: Float = 20, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `1` | 0 … 5, step 0.1 | Strength of the distortion effect |
| `decay` | `Float` | `3` | 0 … 10, step 0.1 | Rate of distortion decay (higher = faster) |
| `radius` | `Float` | `1` | 0 … 3, step 0.1 | Radius of the distortion effect |
| `gridSize` | `Float` | `20` | 8 … 128, step 1 | Resolution of the distortion grid (higher = more detailed) |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "GridDistortion", props: ["intensity": .number(1), "decay": .number(3)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
