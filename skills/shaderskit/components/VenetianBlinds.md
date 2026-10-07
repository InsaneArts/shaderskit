# VenetianBlinds

Wipe the content away behind a set of parallel closing strips

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    VenetianBlinds(progress: 0.5, angle: 0, stripCount: 5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
VenetianBlinds(progress: Float = 0.5, angle: Float = 0, stripCount: Float = 5, feather: Float = 0.15, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the blinds have closed (0 = fully visible, 1 = fully wiped away) |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Orientation of the strips in degrees |
| `stripCount` | `Float` | `5` | 2 … 60, step 1 | Number of strips across the frame |
| `feather` | `Float` | `0.15` | 0 … 1, step 0.01 | Softness of each closing strip edge |
| `invert` | `Bool` | `false` | — | Close each strip from the opposite edge |

Dynamic form (same values): `ShaderNode(type: "VenetianBlinds", props: ["progress": .number(0.5), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
