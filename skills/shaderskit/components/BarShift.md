# BarShift

Slices content into parallel bars, each offset independently for a fractured or glitch-like effect

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BarShift(count: 6, angle: 0, intensity: 0.15) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
BarShift(count: Float = 6, angle: Float = 0, intensity: Float = 0.15, seed: Float = 0, speed: Float = 0, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `count` | `Float` | `6` | 1 … 30, step 1 | Number of bars across the longest viewport dimension |
| `angle` | `Float` | `0` | -180 … 180, step 1, degrees | Angle of bar orientation in degrees (0 = vertical bars, 90 = horizontal bars) |
| `intensity` | `Float` | `0.15` | 0 … 1, step 0.01 | Maximum displacement per bar |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Randomization seed for per-bar offset variation |
| `speed` | `Float` | `0` | -2 … 2, step 0.1 | Animation speed — each bar drifts at its own rate and direction |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "BarShift", props: ["count": .number(6), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
