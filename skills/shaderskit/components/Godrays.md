# Godrays

Volumetric light rays emanating from a point

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Godrays(density: 0.3, intensity: 0.8, spotty: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Godrays(center: ShaderPosition = ShaderPosition(x: 0, y: 0), density: Float = 0.3, intensity: Float = 0.8, spotty: Float = 1, speed: Float = 0.5, rayColor: ShaderColor = "#4283fb", backgroundColor: ShaderColor = "transparent", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0, 0)` | `ShaderPosition` (0…1, top-left origin) | The center point of the god rays |
| `density` | `Float` | `0.3` | 0 … 1, step 0.1 | Frequency of ray sectors |
| `intensity` | `Float` | `0.8` | 0 … 1, step 0.1 | Ray visibility within sectors |
| `spotty` | `Float` | `1` | 0 … 1, step 0.1 | Density of spots on rays (higher = more spots) |
| `speed` | `Float` | `0.5` | 0 … 2, step 0.1 | Animation speed of the rays |
| `rayColor` | `ShaderColor` | `"#4283fb"` | CSS color string | Color of the light rays |
| `backgroundColor` | `ShaderColor` | `"transparent"` | CSS color string | Background color |

Dynamic form (same values): `ShaderNode(type: "Godrays", props: ["center": .position(.xy(x: .number(0), y: .number(0))), "density": .number(0.3)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
