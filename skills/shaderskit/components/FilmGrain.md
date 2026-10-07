# FilmGrain

Analog film grain texture overlay, weighted toward darker areas

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FilmGrain(strength: 0.5, bias: 2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
FilmGrain(strength: Float = 0.5, bias: Float = 2, animated: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `strength` | `Float` | `0.5` | 0 … 1, step 0.025 | Intensity of the film grain noise |
| `bias` | `Float` | `2` | 0 … 10, step 0.1 | Concentrates grain in darker areas. Higher values focus grain more heavily on shadows; 0 applies grain uniformly. |
| `animated` | `Bool` | `false` | — | When enabled, the grain pattern changes each frame for a dynamic film effect |

Dynamic form (same values): `ShaderNode(type: "FilmGrain", props: ["strength": .number(0.5), "bias": .number(2)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
