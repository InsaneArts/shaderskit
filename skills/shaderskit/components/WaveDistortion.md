# WaveDistortion

Wave-based distortion with multiple waveform types

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    WaveDistortion(strength: 0.3, frequency: 1, speed: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
WaveDistortion(strength: Float = 0.3, frequency: Float = 1, speed: Float = 1, angle: Float = 0, waveType: WaveType = .sine, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `WaveDistortion.WaveType`: .sine, .triangle, .square, .sawtooth, .bounce

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `strength` | `Float` | `0.3` | 0 … 1, step 0.01 | Distortion intensity |
| `frequency` | `Float` | `1` | 0.1 … 10, step 0.1 | Number of bends/waves |
| `speed` | `Float` | `1` | 0 … 5, step 0.1 | Animation speed |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Direction of wave distortion in degrees |
| `waveType` | `WaveType` | `"sine"` | `sine`, `triangle`, `square`, `sawtooth`, `bounce` | Shape of the distortion wave |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "WaveDistortion", props: ["strength": .number(0.3), "frequency": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
