# FractalNoise

Multi-octave fractal Brownian motion noise texture with true noise evolution

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FractalNoise(colorA: "#000000", colorB: "#ffffff", octaves: 4)
}
```

Initializer (all parameters optional, defaults shown):

```swift
FractalNoise(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", stops: [ColorStop]? = nil, octaves: Float = 4, detail: Float = 2, contrast: Float = 0.5, speed: Float = 0.15, angle: Float = 0, seed: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | First color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Second color |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `octaves` | `Float` | `4` | 1 … 8, step 1 | Number of noise octaves (more = more detail) |
| `detail` | `Float` | `2` | 1 … 4, step 0.1 | How much finer each successive octave becomes |
| `contrast` | `Float` | `0.5` | 0.1 … 1, step 0.01 | How strongly finer octaves contribute — higher values create more texture contrast |
| `speed` | `Float` | `0.15` | 0 … 1, step 0.01 | Speed at which the noise pattern evolves in place |
| `angle` | `Float` | `0` | -180 … 180, step 1, degrees | Rotation angle in degrees |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolation |

Dynamic form (same values): `ShaderNode(type: "FractalNoise", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
