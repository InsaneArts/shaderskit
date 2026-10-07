# HueShift

Rotate hue around the color wheel

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    HueShift(shift: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
HueShift(shift: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `shift` | `Float` | `0` | -180 … 180, step 1 | The amount to shift the hue by |

Dynamic form (same values): `ShaderNode(type: "HueShift", props: ["shift": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
