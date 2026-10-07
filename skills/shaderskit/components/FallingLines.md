# FallingLines

Directional falling lines with a leading-to-trailing color fade

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FallingLines(colorA: "#ffffff", colorB: "#ffffff00", angle: 90)
}
```

Initializer (all parameters optional, defaults shown):

```swift
FallingLines(colorA: ShaderColor = "#ffffff", colorB: ShaderColor = "#ffffff00", colorSpace: ColorSpace = .linear, angle: Float = 90, speed: Float = 0.5, speedVariance: Float = 0.3, density: Float = 15, trailLength: Float = 0.35, balance: Float = 0.5, strokeWidth: Float = 0.15, rounding: Float = 1, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#ffffff"` | CSS color string | Color at the leading edge of each line |
| `colorB` | `ShaderColor` | `"#ffffff00"` | CSS color string | Color at the trailing edge (transparent by default) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for interpolation between lead and trail colors |
| `angle` | `Float` | `90` | 0 … 360, step 1 | Direction of movement in degrees (90=down, 270=up, 0=right, 180=left) |
| `speed` | `Float` | `0.5` | 0 … 3, step 0.01 | Movement speed |
| `speedVariance` | `Float` | `0.3` | 0 … 1, step 0.01 | Per-line speed variance (0=uniform, 1=high variance) |
| `density` | `Float` | `15` | 1 … 60, step 1 | Number of line columns across the canvas |
| `trailLength` | `Float` | `0.35` | 0.01 … 1, step 0.01 | Streak length relative to spacing (0=point, 1=continuous) |
| `balance` | `Float` | `0.5` | 0 … 1, step 0.01 | Color mix midpoint (0.5=linear, 0=all trailing/colorB, 1=all leading/colorA) |
| `strokeWidth` | `Float` | `0.15` | 0.02 … 1, step 0.02 | Line thickness as fraction of column width (0=hairline, 1=full width) |
| `rounding` | `Float` | `1` | 0 … 1, step 0.01 | Rounds the leading edge (0=flat/square, 1=fully rounded cap) |

Dynamic form (same values): `ShaderNode(type: "FallingLines", props: ["colorA": .string("#ffffff"), "colorB": .string("#ffffff00")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
