# Ripples

Concentric animated ripples emanating from a point

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Ripples(colorA: "#ffffff", colorB: "#000000", speed: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Ripples(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#000000", speed: Float = 1, frequency: Float = 20, softness: Float = 0, thickness: Float = 0.5, phase: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point where ripples emanate from |
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the ripple waves |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Background color between ripples |
| `speed` | `Float` | `1` | -5 … 5, step 0.1 | Speed of ripple animation |
| `frequency` | `Float` | `20` | 1 … 80, step 0.1 | Number of ripples/spacing between them |
| `softness` | `Float` | `0` | 0 … 3, step 0.1 | Softness of ripple edges |
| `thickness` | `Float` | `0.5` | 0 … 1, step 0.1 | Thickness of each ripple band |
| `phase` | `Float` | `0` | 0 … 6.28, step 0.1 | Phase offset for ripple animation |

Dynamic form (same values): `ShaderNode(type: "Ripples", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "colorA": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
