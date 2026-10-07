# Marble

Classic marble swirl and vein texture using noise-warped sine waves

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Marble(colorA: "#ffffff", colorB: "#3a2d54", colorC: "#0f0f0f")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Marble(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#3a2d54", colorC: ShaderColor = "#0f0f0f", scale: Float = 2, turbulence: Float = 10, speed: Float = 0.05, seed: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | Base background color of the marble |
| `colorB` | `ShaderColor` | `"#3a2d54"` | CSS color string | Secondary marble tone |
| `colorC` | `ShaderColor` | `"#0f0f0f"` | CSS color string | Deepest marble color |
| `scale` | `Float` | `2` | 0.1 … 10, step 0.1 | Scale and density of the marble vein pattern |
| `turbulence` | `Float` | `10` | 0 … 50, step 0.5 | Amount of noise-driven distortion applied to the veins |
| `speed` | `Float` | `0.05` | 0 … 0.25, step 0.005 | Animation speed |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Marble", props: ["colorA": .string("#ffffff"), "colorB": .string("#3a2d54")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
