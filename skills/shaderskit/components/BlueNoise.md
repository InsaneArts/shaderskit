# BlueNoise

High-frequency blue noise — even, grainy speckle ideal for dithering

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BlueNoise(colorA: "#ffffff", colorB: "#000000", grain: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
BlueNoise(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#000000", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .linear, grain: Float = 1, contrast: Float = 0, balance: Float = 0, seed: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | First color |
| `colorB` | `ShaderColor` | `"#000000"` | CSS color string | Second color |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `grain` | `Float` | `1` | 1 … 32, step 1 | Grain size in pixels (1 = per-pixel, higher = chunkier speckle) |
| `contrast` | `Float` | `0` | -1 … 5, step 0.1 | Pattern contrast (higher = sharper transitions) |
| `balance` | `Float` | `0` | -1 … 1, step 0.05 | Balance between colors (negative = more colorB, positive = more colorA) |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for pattern variation |

Dynamic form (same values): `ShaderNode(type: "BlueNoise", props: ["colorA": .string("#ffffff"), "colorB": .string("#000000")])`
