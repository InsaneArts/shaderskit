# Stone

Applies a marbled stone relief and surface distortion to child content

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Stone(intensity: 0.5, scale: 1, contrast: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Stone(intensity: Float = 0.5, scale: Float = 1, contrast: Float = 0, distortion: Float = 0.15, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `0.5` | 0 … 1, step 0.01 | Strength of the relief shading applied to the child content |
| `scale` | `Float` | `1` | 0.1 … 8, step 0.05 | Scale of the pattern — lower = larger features, higher = finer grain |
| `contrast` | `Float` | `0` | -1 … 2, step 0.05 | Contrast of the texture — negative flattens it into a subtle overlay |
| `distortion` | `Float` | `0.15` | 0 … 1, step 0.01 | Surface distortion — warps the child along the texture like carved relief |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |

Dynamic form (same values): `ShaderNode(type: "Stone", props: ["intensity": .number(0.5), "scale": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
