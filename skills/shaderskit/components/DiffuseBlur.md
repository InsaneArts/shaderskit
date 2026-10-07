# DiffuseBlur

Grain-like pixel displacement at random

- Category: Blurs · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DiffuseBlur(intensity: 30) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
DiffuseBlur(intensity: Float = 30, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `30` | 0 … 100, step 1 | Intensity of the diffuse blur effect |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "DiffuseBlur", props: ["intensity": .number(30), "edges": .string("stretch")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
