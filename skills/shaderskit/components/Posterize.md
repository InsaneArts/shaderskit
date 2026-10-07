# Posterize

Reduce color depth to create a poster effect

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Posterize(intensity: 5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Posterize(intensity: Float = 5, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `5` | 2 … 20, step 1 | The intensity of the posterization effect (lower is more posterized) |

Dynamic form (same values): `ShaderNode(type: "Posterize", props: ["intensity": .number(5)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
