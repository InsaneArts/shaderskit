# Sparkle

Twinkling star glints over the bright parts of the layer inside

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Sparkle(size: 100, intensity: 10, threshold: 0.2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Sparkle(size: Float = 100, intensity: Float = 10, threshold: Float = 0.2, expand: Float = 0, rayLength: Float = 5, colorize: Float = 0.45, speed: Float = 1, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `size` | `Float` | `100` | 10 … 200, step 1 | Spacing between glints, in CSS pixels (smaller means more glints) |
| `intensity` | `Float` | `10` | 0 … 20, step 0.1 | Brightness of the glints |
| `threshold` | `Float` | `0.2` | 0 … 1, step 0.01 | How bright the layer must be before glints appear: 0 allows all but black, 0.5 is mid-grey and up, 1 only pure white |
| `expand` | `Float` | `0` | 0 … 100, step 1 | Lets glints appear up to this many CSS pixels outside the bright areas |
| `rayLength` | `Float` | `5` | 0 … 20, step 0.1 | Length of the four rays around each glint (they fade out by half the spacing) |
| `colorize` | `Float` | `0.45` | 0 … 1, step 0.01 | How much each glint takes on the colour beneath it (0 is pure white) |
| `speed` | `Float` | `1` | 0 … 5, step 0.05 | How fast the glints twinkle |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Re-rolls where the glints sit and when they blink |

Dynamic form (same values): `ShaderNode(type: "Sparkle", props: ["size": .number(100), "intensity": .number(10)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
