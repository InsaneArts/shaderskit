# Tint

Apply a color tint to the image

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Tint(color: "#ff8800", amount: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Tint(color: ShaderColor = "#ff8800", amount: Float = 0.5, preserveLuminosity: Bool = true, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ff8800"` | CSS color string | Tint color |
| `amount` | `Float` | `0.5` | 0 … 1, step 0.1 | Tint amount (0 = no tint, 1 = full tint) |
| `preserveLuminosity` | `Bool` | `true` | — | Preserve original brightness |

Dynamic form (same values): `ShaderNode(type: "Tint", props: ["color": .string("#ff8800"), "amount": .number(0.5)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
