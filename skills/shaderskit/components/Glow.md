# Glow

Soft glow effect with adjustable intensity

- Category: Stylize · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Glow(intensity: 1, threshold: 0.5, size: 25) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Glow(intensity: Float = 1, threshold: Float = 0.5, size: Float = 25, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `1` | 0 … 50, step 0.5 | Glow intensity (brightness of the glow effect) |
| `threshold` | `Float` | `0.5` | 0 … 1, step 0.01 | Brightness threshold for glow extraction (lower = more glow) |
| `size` | `Float` | `25` | 0 … 100, step 1 | Glow spread in pixels (clean up to ~72px, mild banding above) |

Dynamic form (same values): `ShaderNode(type: "Glow", props: ["intensity": .number(1), "threshold": .number(0.5)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
