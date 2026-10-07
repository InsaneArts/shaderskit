# TiltShift

Selective focus blur mimicking tilt-shift photography

- Category: Blurs · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    TiltShift(intensity: 50, width: 0.3, falloff: 0.3) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
TiltShift(intensity: Float = 50, width: Float = 0.3, falloff: Float = 0.3, angle: Float = 0, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `50` | 0 … 100, step 1 | Maximum blur intensity at edges |
| `width` | `Float` | `0.3` | 0 … 1, step 0.1 | Width of the sharp focus area |
| `falloff` | `Float` | `0.3` | 0 … 1, step 0.1 | Distance over which blur transitions to full strength |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation angle of the focus line (in degrees) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the focus line |

Dynamic form (same values): `ShaderNode(type: "TiltShift", props: ["intensity": .number(50), "width": .number(0.3)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
