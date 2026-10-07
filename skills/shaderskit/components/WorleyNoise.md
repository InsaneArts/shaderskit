# WorleyNoise

Cellular noise field — distance-based, with selectable feature combinations and fractal octaves

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    WorleyNoise(colorA: "#ffffff", colorB: "#000000", scale: 6)
}
```

Initializer (all parameters optional, defaults shown):

```swift
WorleyNoise(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#000000", colorSpace: ColorSpace = .linear, scale: Float = 6, mode: Mode = .f1, distance: Distance = .euclidean, octaves: Float = 1, lacunarity: Float = 2, persistence: Float = 0.5, jitter: Float = 1, contrast: Float = 1, balance: Float = 0, seed: Float = 0, speed: Float = 0.5, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `WorleyNoise.Mode`: .f1, .f2, .f2MinusF1, .f1PlusF2, .f1TimesF2
- `WorleyNoise.Distance`: .euclidean, .manhattan, .chebyshev

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | Color where the noise field is low (typically near cell centers) |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Color where the noise field is high (typically near cell boundaries) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `scale` | `Float` | `6` | 1 … 30, step 0.5 | Number of cells across the canvas at the base octave |
| `mode` | `Mode` | `"f1"` | `f1`, `f2`, `f2MinusF1`, `f1PlusF2`, `f1TimesF2` | Field type. F1 = distance to nearest point. F2 = distance to second-nearest. F2 − F1 emphasises cell boundaries. |
| `distance` | `Distance` | `"euclidean"` | `euclidean`, `manhattan`, `chebyshev` | Distance metric. Euclidean = round cells. Manhattan = diamond. Chebyshev = square. |
| `octaves` | `Float` | `1` | 1 … 4, step 1 | Number of fractal layers stacked at progressively finer scales |
| `lacunarity` | `Float` | `2` | 1.5 … 4, step 0.1 | Scale multiplier between octaves (only active when Octaves > 1) |
| `persistence` | `Float` | `0.5` | 0 … 1, step 0.01 | Amplitude multiplier between octaves (only active when Octaves > 1) |
| `jitter` | `Float` | `1` | 0 … 1, step 0.01 | How much each cell's point drifts inside its cell. 0 = rigid grid (banded look), 1 = fully random. |
| `contrast` | `Float` | `1` | 0.25 … 4, step 0.01 | Steepness of the gradient between low and high regions |
| `balance` | `Float` | `0` | -1 … 1, step 0.01 | Shifts the gradient midpoint. Negative pulls the field toward Color A, positive toward Color B. |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — shifts the cell pattern without changing its overall structure |
| `speed` | `Float` | `0.5` | 0 … 5, step 0.1 | Animation speed — how fast each cell's point drifts |

Dynamic form (same values): `ShaderNode(type: "WorleyNoise", props: ["colorA": .string("#ffffff"), "colorB": .string("#000000")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
