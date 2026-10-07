# BlockDissolve

Dissolve the content away as a grid of blocks vanishing in random order

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BlockDissolve(progress: 0.5, blockSize: 0.08, softness: 0.15) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
BlockDissolve(progress: Float = 0.5, blockSize: Float = 0.08, softness: Float = 0.15, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the dissolve has progressed (0 = fully visible, 1 = fully wiped away) |
| `blockSize` | `Float` | `0.08` | 0.01 … 0.5, step 0.01 | Size of each block as a fraction of the frame width |
| `softness` | `Float` | `0.15` | 0 … 1, step 0.01 | How softly each block fades out (0 = hard-edged blocks) |
| `invert` | `Bool` | `false` | — | Reverse the order blocks dissolve in |

Dynamic form (same values): `ShaderNode(type: "BlockDissolve", props: ["progress": .number(0.5), "blockSize": .number(0.08)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
