# DiamondWipe

Wipe the content away through a lattice of growing diamonds

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DiamondWipe(progress: 0.5, size: 0.15, feather: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
DiamondWipe(progress: Float = 0.5, size: Float = 0.15, feather: Float = 0.1, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the diamonds have grown (0 = fully visible, 1 = fully wiped away) |
| `size` | `Float` | `0.15` | 0.02 … 0.5, step 0.01 | Size of each diamond cell as a fraction of the frame width |
| `feather` | `Float` | `0.1` | 0 … 1, step 0.01 | Softness of each diamond edge |
| `invert` | `Bool` | `false` | — | Wipe from the cell corners inward instead |

Dynamic form (same values): `ShaderNode(type: "DiamondWipe", props: ["progress": .number(0.5), "size": .number(0.15)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
