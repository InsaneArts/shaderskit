# CheckerWipe

Wipe the content away as a checkerboard of fading squares

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    CheckerWipe(progress: 0.5, blockSize: 0.1, softness: 0.15) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
CheckerWipe(progress: Float = 0.5, blockSize: Float = 0.1, softness: Float = 0.15, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the wipe has progressed (0 = fully visible, 1 = fully wiped away) |
| `blockSize` | `Float` | `0.1` | 0.02 … 0.5, step 0.01 | Size of each square as a fraction of the frame width |
| `softness` | `Float` | `0.15` | 0 … 1, step 0.01 | How softly each square fades out (0 = hard-edged squares) |
| `invert` | `Bool` | `false` | — | Reverse the order the squares wipe in |

Dynamic form (same values): `ShaderNode(type: "CheckerWipe", props: ["progress": .number(0.5), "blockSize": .number(0.1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
