# SliceWipe

Slice the content into strips that slide away in alternating directions

- Category: Transitions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    SliceWipe(progress: 0.5, angle: 0, sliceCount: 8) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
SliceWipe(progress: Float = 0.5, angle: Float = 0, sliceCount: Float = 8, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the strips have slid (0 = fully visible, 1 = fully wiped away) |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Orientation of the strips in degrees (0 = vertical strips sliding up and down) |
| `sliceCount` | `Float` | `8` | 2 … 60, step 1 | Number of strips across the frame |

Dynamic form (same values): `ShaderNode(type: "SliceWipe", props: ["progress": .number(0.5), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
