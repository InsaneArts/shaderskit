# ProgressiveBlur

Blur that increases progressively in one direction

- Category: Blurs · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ProgressiveBlur(intensity: 50, angle: 0, falloff: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ProgressiveBlur(intensity: Float = 50, angle: Float = 0, center: ShaderPosition = ShaderPosition(x: 0, y: 0.5), falloff: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `50` | 0 … 100, step 1 | Maximum intensity of the blur effect |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Direction of the blur gradient (in degrees) |
| `center` | `ShaderPosition` | `(0, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point where blur begins |
| `falloff` | `Float` | `1` | 0 … 1, step 0.1 | Distance over which blur transitions to full strength |

Dynamic form (same values): `ShaderNode(type: "ProgressiveBlur", props: ["intensity": .number(50), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
