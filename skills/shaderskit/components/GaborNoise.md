# GaborNoise

Oriented sine-grain noise with a fingerprint-like flow

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    GaborNoise(colorA: "#ffffff", colorB: "#000000", scale: 1.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
GaborNoise(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#000000", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .linear, scale: Float = 1.5, frequency: Float = 8, contrast: Float = 0, balance: Float = 0, seed: Float = 0, speed: Float = 1, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | First color |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Second color |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `scale` | `Float` | `1.5` | -2 … 5, step 0.1 | Pattern scale (higher = finer, more detailed patterns; each +1 roughly doubles the frequency) |
| `frequency` | `Float` | `8` | 1 … 24, step 0.5 | Frequency of the oriented waves within each cell |
| `contrast` | `Float` | `0` | -1 … 5, step 0.1 | Pattern contrast (higher = sharper transitions) |
| `balance` | `Float` | `0` | -1 … 1, step 0.05 | Balance between colors (negative = more colorB, positive = more colorA) |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |
| `speed` | `Float` | `1` | 0 … 5, step 0.1 | Animation speed |

Dynamic form (same values): `ShaderNode(type: "GaborNoise", props: ["colorA": .string("#ffffff"), "colorB": .string("#000000")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
