# Paper

Applies realistic paper grain and surface roughness to child content

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Paper(roughness: 0.3, grainScale: 1, displacement: 0.15) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Paper(roughness: Float = 0.3, grainScale: Float = 1, displacement: Float = 0.15, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `roughness` | `Float` | `0.3` | 0 … 1, step 0.01 | Surface roughness — higher values create more pronounced brightness variation |
| `grainScale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the paper grain — lower = coarser, higher = finer |
| `displacement` | `Float` | `0.15` | 0 … 1, step 0.01 | Surface micro-roughness — shifts pixels at grain scale like real paper fiber bumps |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |

Dynamic form (same values): `ShaderNode(type: "Paper", props: ["roughness": .number(0.3), "grainScale": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
