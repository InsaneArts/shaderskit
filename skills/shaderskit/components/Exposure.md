# Exposure

Multiplicative exposure (gain) on the child. Unlike additive brightness, it scales values around black — blacks stay black while highlights can be pushed past 1.0 to feed HDR bloom and tone-mapping roll-off. Pointwise, so no extra render pass is needed.

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Exposure(exposure: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Exposure(exposure: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `exposure` | `Float` | `1` | 0 … 8, step 0.1 | Brightness multiplier (gain). 1 = unchanged, >1 pushes highlights past white for HDR bloom, <1 darkens. |

Dynamic form (same values): `ShaderNode(type: "Exposure", props: ["exposure": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
