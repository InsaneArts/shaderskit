# Saturation

Adjust color saturation intensity

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Saturation(intensity: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Saturation(intensity: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `1` | 0 … 3, step 0.1 | The intensity of the saturation effect (1 being no change) |

Dynamic form (same values): `ShaderNode(type: "Saturation", props: ["intensity": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
