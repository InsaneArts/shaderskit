# IrisWipe

Reveal through an expanding circle growing from a center point

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    IrisWipe(progress: 0.5, feather: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
IrisWipe(progress: Float = 0.5, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), feather: Float = 0.1, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the iris has expanded (0 = fully visible, 1 = fully wiped away) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Point the iris expands from |
| `feather` | `Float` | `0.1` | 0 … 1, step 0.01 | Softness of the iris edge |
| `invert` | `Bool` | `false` | — | Wipe from the outside inward instead |

Dynamic form (same values): `ShaderNode(type: "IrisWipe", props: ["progress": .number(0.5), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
