# Liquify

Liquid-like interactive deformation effect

- Category: Interactive · Role: warp
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Liquify(intensity: 10, stiffness: 3, damping: 3) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Liquify(intensity: Float = 10, stiffness: Float = 3, damping: Float = 3, radius: Float = 1, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `10` | 0 … 20, step 0.1 | Scale of the fabric displacement effect |
| `stiffness` | `Float` | `3` | 1 … 30, step 0.5 | Fabric rigidity (higher = stiffer canvas, lower = stretchy silk) |
| `damping` | `Float` | `3` | 0 … 10, step 0.1 | How quickly fabric motion settles |
| `radius` | `Float` | `1` | 0.1 … 1.5, step 0.1 | Cursor influence area |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Liquify", props: ["intensity": .number(10), "stiffness": .number(3)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
