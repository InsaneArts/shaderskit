# Vibrance

Selective saturation adjustment protecting skin tones

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Vibrance(intensity: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Vibrance(intensity: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `0` | -2 … 2, step 0.1 | The intensity of the vibrance effect |

Dynamic form (same values): `ShaderNode(type: "Vibrance", props: ["intensity": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
