# RadialWipe

Sweep the content away in a clock-hand arc around a center point

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    RadialWipe(progress: 0.5, startAngle: 0, feather: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
RadialWipe(progress: Float = 0.5, startAngle: Float = 0, direction: Direction = .cw, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), feather: Float = 0.1, invert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `RadialWipe.Direction`: .cw, .ccw, .both

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `progress` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the sweep has travelled (0 = fully visible, 1 = fully wiped away) |
| `startAngle` | `Float` | `0` | 0 … 360, step 1 | Angle in degrees where the sweep begins |
| `direction` | `Direction` | `"cw"` | `cw`, `ccw`, `both` | Which way the sweep rotates |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Point the sweep rotates around |
| `feather` | `Float` | `0.1` | 0 … 1, step 0.01 | Softness of the sweeping edge |
| `invert` | `Bool` | `false` | — | Reverse which side of the sweep is wiped |

Dynamic form (same values): `ShaderNode(type: "RadialWipe", props: ["progress": .number(0.5), "startAngle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
