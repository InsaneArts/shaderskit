# CompressionArtifacts

Simulates lossy JPEG compression — 8×8 DCT block quantization, blockiness, ringing and color bleed

- Category: Stylize · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    CompressionArtifacts(quality: 12) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
CompressionArtifacts(quality: Float = 12, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `quality` | `Float` | `12` | 1 … 100, step 1 | JPEG quality (1 = heavily destroyed, 100 = near lossless) |

Dynamic form (same values): `ShaderNode(type: "CompressionArtifacts", props: ["quality": .number(12)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
