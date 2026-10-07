# Solarize

Inverts tones above a luminance threshold — a classic darkroom and photo effect

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Solarize(threshold: 0.5, strength: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Solarize(threshold: Float = 0.5, strength: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `threshold` | `Float` | `0.5` | 0 … 1, step 0.01 | Luminance level above which colors are inverted. Pixels brighter than this threshold get flipped. |
| `strength` | `Float` | `1` | 0 … 1, step 0.01 | Blend between original (0) and fully solarized (1) |

Dynamic form (same values): `ShaderNode(type: "Solarize", props: ["threshold": .number(0.5), "strength": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
