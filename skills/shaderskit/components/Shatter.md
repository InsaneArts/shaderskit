# Shatter

Broken glass effect with tectonic plate displacement

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Shatter(crackWidth: 1, intensity: 4, radius: 0.4) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Shatter(crackWidth: Float = 1, intensity: Float = 4, radius: Float = 0.4, decay: Float = 1, seed: Float = 2, chromaticSplit: Float = 1, refractionStrength: Float = 5, shardLighting: Float = 0.1, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `crackWidth` | `Float` | `1` | 0.5 … 5, step 0.1 | Thickness of crack lines |
| `intensity` | `Float` | `4` | 0 … 20, step 1 | How much shards shift |
| `radius` | `Float` | `0.4` | 0.1 … 1, step 0.1 | Cursor influence radius |
| `decay` | `Float` | `1` | 0.1 … 10, step 0.1 | How fast shards return to rest |
| `seed` | `Float` | `2` | 0 … 50, step 1 | Random seed for pattern |
| `chromaticSplit` | `Float` | `1` | 0 … 5, step 0.1 | RGB separation for prismatic glass effect |
| `refractionStrength` | `Float` | `5` | 0 … 10, step 0.1 | How much cracks bend/distort the underlying image |
| `shardLighting` | `Float` | `0.1` | 0 … 0.5, step 0.1 | Subtle lighting on tilted shards for 3D depth |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when displacement pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Shatter", props: ["crackWidth": .number(1), "intensity": .number(4)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
