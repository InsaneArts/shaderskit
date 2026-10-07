# RippleWipe

Wipe the content away in concentric rings pulsing out from a center point

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    RippleWipe(progress: 0.5, rings: 8, feather: 0.2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
RippleWipe(progress: Float = 0.5, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), rings: Float = 8, feather: Float = 0.2, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the ripple has expanded (0 = fully visible, 1 = fully wiped away) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Point the rings expand from |
| `rings` | `Float` | `8` | 2 … 40, step 1 | Number of concentric rings |
| `feather` | `Float` | `0.2` | 0 … 1, step 0.01 | How softly adjacent rings' timing overlaps (0 = discrete ring pops) |
| `invert` | `Bool` | `false` | — | Wipe from the outside inward instead |

Dynamic form (same values): `ShaderNode(type: "RippleWipe", props: ["progress": .number(0.5), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
