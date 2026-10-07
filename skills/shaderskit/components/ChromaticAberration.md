# ChromaticAberration

Separate RGB channels for a prismatic distortion effect

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ChromaticAberration(strength: 0.2, angle: 0, redOffset: -1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ChromaticAberration(strength: Float = 0.2, angle: Float = 0, redOffset: Float = -1, greenOffset: Float = 0, blueOffset: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `strength` | `Float` | `0.2` | 0 … 1, step 0.01 | Overall strength of the chromatic aberration effect |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Direction of the chromatic aberration in degrees |
| `redOffset` | `Float` | `-1` | -2 … 2, step 0.1 | Red channel offset multiplier |
| `greenOffset` | `Float` | `0` | -2 … 2, step 0.1 | Green channel offset multiplier |
| `blueOffset` | `Float` | `1` | -2 … 2, step 0.1 | Blue channel offset multiplier |

Dynamic form (same values): `ShaderNode(type: "ChromaticAberration", props: ["strength": .number(0.2), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
