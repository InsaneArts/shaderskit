# ZoomBlur

Radial zoom blur expanding from a center point

- Category: Blurs · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ZoomBlur(intensity: 30) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ZoomBlur(intensity: Float = 30, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `30` | 0 … 100, step 1 | Intensity of the zoom blur effect |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the zoom blur |

Dynamic form (same values): `ShaderNode(type: "ZoomBlur", props: ["intensity": .number(30), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
