# Bend

Bends the ends of the frame toward you like a curved display — content at the edges swells closer under real perspective, or curls away when the strength goes negative

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Bend(strength: 0.5, falloff: 0, angle: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Bend(strength: Float = 0.5, falloff: Float = 0, angle: Float = 0, edges: EdgeMode = .transparent, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `strength` | `Float` | `0.5` | -1 … 1, step 0.01 | How hard the ends bend — positive curls them toward you (edges magnify), negative curls them away (edges recede into the frame) |
| `falloff` | `Float` | `0` | 0 … 1, step 0.01 | Concentrates the bend toward the ends — 0 curves the whole frame, higher keeps the middle flat and bends only near the edges |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Direction of the bend axis in degrees — 0 bends the left/right ends, 90 bends the top/bottom |
| `edges` | `EdgeMode` | `"transparent"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when the bend pulls content away from the frame border |

Dynamic form (same values): `ShaderNode(type: "Bend", props: ["strength": .number(0.5), "falloff": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
