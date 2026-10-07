# CursorRipples

Fluid-like ripple distortion

- Category: Interactive · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    CursorRipples(intensity: 10, decay: 10, radius: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
CursorRipples(intensity: Float = 10, decay: Float = 10, radius: Float = 0.5, chromaticSplit: Float = 1, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `10` | 0 … 20, step 0.1 | Strength of the ripple distortion |
| `decay` | `Float` | `10` | 0 … 20, step 0.1 | How quickly ripples fade (higher = faster) |
| `radius` | `Float` | `0.5` | 0.1 … 1, step 0.1 | Radius of cursor influence |
| `chromaticSplit` | `Float` | `1` | 0 … 3, step 0.1 | RGB channel separation along ripple edges |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "CursorRipples", props: ["intensity": .number(10), "decay": .number(10)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
