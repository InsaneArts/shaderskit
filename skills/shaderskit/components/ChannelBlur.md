# ChannelBlur

Independent blur for red, green, and blue channels

- Category: Blurs · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ChannelBlur(redIntensity: 0, greenIntensity: 20, blueIntensity: 40) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ChannelBlur(redIntensity: Float = 0, greenIntensity: Float = 20, blueIntensity: Float = 40, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `redIntensity` | `Float` | `0` | 0 … 100, step 1 | Blur intensity for red channel |
| `greenIntensity` | `Float` | `20` | 0 … 100, step 1 | Blur intensity for green channel |
| `blueIntensity` | `Float` | `40` | 0 … 100, step 1 | Blur intensity for blue channel |

Dynamic form (same values): `ShaderNode(type: "ChannelBlur", props: ["redIntensity": .number(0), "greenIntensity": .number(20)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
