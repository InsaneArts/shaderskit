# DataMosh

Corrupted-codec motion smearing — macroblocks lock in place and drag their pixels across the frame in liquid trails, each recovering on its own clock, like a video stream that lost its keyframes

- Category: Stylize · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    DataMosh(intensity: 0.7, blockSize: 48, drift: 0.35) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
DataMosh(intensity: Float = 0.7, blockSize: Float = 48, drift: Float = 0.35, churn: Float = 0.4, blend: Float = 1, speed: Float = 1, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `0.7` | 0 … 1, step 0.01 | How much of the image locks and smears — the fraction of corrupted macroblocks |
| `blockSize` | `Float` | `48` | 30 … 150, step 1 | Macroblock size — the granularity of the corruption |
| `drift` | `Float` | `0.35` | 0 … 1, step 0.01 | Motion vector strength — how fast corrupted areas drag their pixels away |
| `churn` | `Float` | `0.4` | 0 … 1, step 0.01 | How often each block re-rolls its fate — low values let corrupted regions melt for a long time before recovering |
| `blend` | `Float` | `1` | 0 … 1, step 0.01 | Blend between the live image and the moshed stream |
| `speed` | `Float` | `1` | 0 … 4, step 0.1 | Simulation speed. 0 freezes the decay in place. |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for the corruption layout |

Dynamic form (same values): `ShaderNode(type: "DataMosh", props: ["intensity": .number(0.7), "blockSize": .number(48)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
