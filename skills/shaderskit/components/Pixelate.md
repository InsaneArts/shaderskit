# Pixelate

Pixelation effect with adjustable cell size

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Pixelate(scale: 50, gap: 0, roundness: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Pixelate(scale: Float = 50, gap: Float = 0, roundness: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `scale` | `Float` | `50` | 1 … 200, step 1 | Number of pixels along the longest edge (higher = smaller pixels) |
| `gap` | `Float` | `0` | 0 … 0.95, step 0.01 | Space between pixels as a fraction of cell size (0 = no gap, 1 = fully invisible) |
| `roundness` | `Float` | `0` | 0 … 1, step 0.01 | Roundness of each pixel's corners (0 = square, 1 = circle) |

Dynamic form (same values): `ShaderNode(type: "Pixelate", props: ["scale": .number(50), "gap": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
