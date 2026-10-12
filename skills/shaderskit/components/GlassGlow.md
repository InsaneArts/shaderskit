# GlassGlow

Light sweeping through a glass shape, with a refracting edge and a soft halo

- Category: Shape Effects · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    GlassGlow(speed: 1, intensity: 1, glow: 1) {
        ImageTexture(url: "logo.png", objectFit: .contain)   // the shape: this content's alpha
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
GlassGlow(speed: Float = 1, intensity: Float = 1, glow: Float = 1, refraction: Float = 1, dispersion: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `speed` | `Float` | `1` | 0 … 3, step 0.01 | Animation speed (1 = one 6 second loop) |
| `intensity` | `Float` | `1` | 0 … 2, step 0.01 | Brightness of the light inside the glass |
| `glow` | `Float` | `1` | 0 … 3, step 0.01 | Strength of the halo around the shape |
| `refraction` | `Float` | `1` | 0 … 3, step 0.01 | How far the glass edge bends the light inward |
| `dispersion` | `Float` | `1` | 0 … 3, step 0.01 | Colour split along the glass edge |

Dynamic form (same values): `ShaderNode(type: "GlassGlow", props: ["speed": .number(1), "intensity": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
- Not an upstream port: written for ShadersKit. The shape is the alpha of the wrapped content (an image, `Text`, a captured SwiftUI view); the light loops every 6 seconds at `speed` 1.
