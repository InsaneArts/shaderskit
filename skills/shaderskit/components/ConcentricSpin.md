# ConcentricSpin

Concentric rings that each rotate the underlying image by different amounts

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ConcentricSpin(intensity: 20, rings: 8, smoothness: 0.03) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ConcentricSpin(intensity: Float = 20, rings: Float = 8, smoothness: Float = 0.03, seed: Float = 0, speed: Float = 0.1, speedRandomness: Float = 0.5, edges: EdgeMode = .mirror, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `20` | 0 … 100, step 1 | Maximum rotation angle per ring |
| `rings` | `Float` | `8` | 1 … 30, step 1 | Number of concentric rings |
| `smoothness` | `Float` | `0.03` | 0 … 1, step 0.01 | Softness of transitions between rings |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Randomization seed for per-ring rotation variation |
| `speed` | `Float` | `0.1` | -5 … 5, step 0.1 | Speed of continuous ring rotation |
| `speedRandomness` | `Float` | `0.5` | 0 … 1, step 0.01 | How much each ring varies in rotation speed and direction |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center point of the concentric rings |

Dynamic form (same values): `ShaderNode(type: "ConcentricSpin", props: ["intensity": .number(20), "rings": .number(8)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
