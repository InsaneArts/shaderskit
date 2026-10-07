# FlowField

Fluid-like distortion with constant smooth motion

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FlowField(strength: 0.15, detail: 2, speed: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
FlowField(strength: Float = 0.15, detail: Float = 2, speed: Float = 0, evolutionSpeed: Float = 0, seed: Float = 0, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `strength` | `Float` | `0.15` | 0 … 0.5, step 0.01 | Intensity of the flow distortion |
| `detail` | `Float` | `2` | 0.5 … 5, step 0.1 | Scale of the flow patterns |
| `speed` | `Float` | `0` | 0 … 20, step 0.1 | Speed of the flow |
| `evolutionSpeed` | `Float` | `0` | 0 … 20, step 0.1 | How fast the flow field pattern reshapes over time |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for flow pattern variation |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "FlowField", props: ["strength": .number(0.15), "detail": .number(2)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
