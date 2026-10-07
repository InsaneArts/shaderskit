# Blur

A simple Gaussian blur effect

- Category: Blurs · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Blur(intensity: 50) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Blur(intensity: Float = 50, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `50` | 0 … 200, step 1 | Intensity of the blur effect |

Dynamic form (same values): `ShaderNode(type: "Blur", props: ["intensity": .number(50)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
