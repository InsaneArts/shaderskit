# DropShadow

Adds a soft shadow behind the child content based on its alpha silhouette

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DropShadow(color: "#000000", distance: 0.1, angle: 135) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
DropShadow(color: ShaderColor = "#000000", distance: Float = 0.1, angle: Float = 135, blur: Float = 5, intensity: Float = 0.5, cutout: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#000000"` | CSS color string | Shadow color |
| `distance` | `Float` | `0.1` | 0 … 1, step 0.005 | How far the shadow is offset from the content |
| `angle` | `Float` | `135` | 0 … 360, step 1 | Direction the shadow is cast (compass degrees: 0=up, 90=right, 135=lower-right, 180=down) |
| `blur` | `Float` | `5` | 0 … 20, step 0.5 | Shadow softness (blur radius in pixels) |
| `intensity` | `Float` | `0.5` | 0 … 1, step 0.01 | Shadow intensity — how strong/visible the shadow is |
| `cutout` | `Bool` | `false` | — | Hide the original layer and show only the shadow |

Dynamic form (same values): `ShaderNode(type: "DropShadow", props: ["color": .string("#000000"), "distance": .number(0.1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
