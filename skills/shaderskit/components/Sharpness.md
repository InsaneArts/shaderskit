# Sharpness

Adjust image sharpness using a convolution kernel

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Sharpness(sharpness: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Sharpness(sharpness: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `sharpness` | `Float` | `0` | 0 … 5, step 0.1 | How sharp to make the underlying image |

Dynamic form (same values): `ShaderNode(type: "Sharpness", props: ["sharpness": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
