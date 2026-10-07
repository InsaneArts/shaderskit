# NoiseDissolve

Dissolve the content away through an organic noise pattern

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    NoiseDissolve(progress: 0.5, scale: 3, softness: 0.25) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
NoiseDissolve(progress: Float = 0.5, scale: Float = 3, softness: Float = 0.25, seed: Float = 0, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the dissolve has progressed (0 = fully visible, 1 = fully wiped away) |
| `scale` | `Float` | `3` | 0.5 … 20, step 0.1 | Frequency of the dissolve pattern (higher = smaller blobs) |
| `softness` | `Float` | `0.25` | 0 … 1, step 0.01 | How softly the erosion edge fades out (0 = hard-edged blobs) |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |
| `invert` | `Bool` | `false` | — | Reverse the order the pattern dissolves in |

Dynamic form (same values): `ShaderNode(type: "NoiseDissolve", props: ["progress": .number(0.5), "scale": .number(3)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
