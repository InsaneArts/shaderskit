# LinearWipe

Wipe the content away along a straight edge with a soft feathered transition

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    LinearWipe(progress: 0.5, angle: 0, feather: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
LinearWipe(progress: Float = 0.5, angle: Float = 0, feather: Float = 0.1, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the wipe has travelled (0 = fully visible, 1 = fully wiped away) |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Direction of the wipe in degrees (0 = left to right) |
| `feather` | `Float` | `0.1` | 0 … 1, step 0.01 | Softness of the wipe edge |
| `invert` | `Bool` | `false` | — | Reverse the direction the wipe travels |

Dynamic form (same values): `ShaderNode(type: "LinearWipe", props: ["progress": .number(0.5), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
