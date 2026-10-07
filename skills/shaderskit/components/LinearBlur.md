# LinearBlur

Directional motion blur in a specific angle

- Category: Blurs · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    LinearBlur(intensity: 30, angle: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
LinearBlur(intensity: Float = 30, angle: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `30` | 0 … 100, step 1 | Intensity of the linear blur effect |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Direction of the linear blur (in degrees) |

Dynamic form (same values): `ShaderNode(type: "LinearBlur", props: ["intensity": .number(30), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
