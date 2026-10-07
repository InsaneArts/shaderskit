# BarnDoors

Split the content along a center line and wipe outward in both directions

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BarnDoors(progress: 0.5, angle: 0, feather: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
BarnDoors(progress: Float = 0.5, angle: Float = 0, feather: Float = 0.1, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the doors have opened (0 = fully visible, 1 = fully wiped away) |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Direction the doors open in degrees (0 = apart horizontally) |
| `feather` | `Float` | `0.1` | 0 … 1, step 0.01 | Softness of the wipe edges |
| `invert` | `Bool` | `false` | — | Close in from both edges instead of opening from the center |

Dynamic form (same values): `ShaderNode(type: "BarnDoors", props: ["progress": .number(0.5), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
