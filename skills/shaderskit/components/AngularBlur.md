# AngularBlur

Radial motion blur rotating around a center point

- Category: Blurs · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    AngularBlur(intensity: 20) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
AngularBlur(intensity: Float = 20, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `20` | 0 … 100, step 1 | Intensity of the angular blur effect |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the rotation |

Dynamic form (same values): `ShaderNode(type: "AngularBlur", props: ["intensity": .number(20), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
