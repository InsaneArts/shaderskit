# SineWave

Animated wave with thickness and softness

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    SineWave(color: "#ffffff", amplitude: 0.15, frequency: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
SineWave(color: ShaderColor = "#ffffff", amplitude: Float = 0.15, frequency: Float = 1, speed: Float = 1, angle: Float = 0, position: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), thickness: Float = 0.2, softness: Float = 0.4, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | The color of the sine wave |
| `amplitude` | `Float` | `0.15` | 0 … 1, step 0.1 | The height/amplitude of the sine wave |
| `frequency` | `Float` | `1` | 0.1 … 20, step 0.1 | The frequency/number of wave cycles |
| `speed` | `Float` | `1` | -5 … 5, step 0.1 | The animation speed of the wave |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | The rotation angle of the wave (in degrees) |
| `position` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center position of the wave |
| `thickness` | `Float` | `0.2` | 0 … 2, step 0.1 | The thickness of the wave line |
| `softness` | `Float` | `0.4` | 0 … 1, step 0.1 | Edge softness of the wave line |

Dynamic form (same values): `ShaderNode(type: "SineWave", props: ["color": .string("#ffffff"), "amplitude": .number(0.15)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
