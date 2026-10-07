# RandomBars

Wipe the content away as parallel bars vanishing in random order

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    RandomBars(progress: 0.5, angle: 0, barCount: 12) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
RandomBars(progress: Float = 0.5, angle: Float = 0, barCount: Float = 12, softness: Float = 0.15, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the wipe has progressed (0 = fully visible, 1 = fully wiped away) |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Orientation of the bars in degrees (0 = vertical bars) |
| `barCount` | `Float` | `12` | 2 … 100, step 1 | Number of bars across the frame |
| `softness` | `Float` | `0.15` | 0 … 1, step 0.01 | How softly each bar fades out (0 = hard-edged bars) |
| `invert` | `Bool` | `false` | — | Reverse the order the bars vanish in |

Dynamic form (same values): `ShaderNode(type: "RandomBars", props: ["progress": .number(0.5), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
