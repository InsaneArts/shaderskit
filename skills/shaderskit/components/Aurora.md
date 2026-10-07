# Aurora

Mesmerizing aurora borealis with layered curtains, vertical rays, and flowing light.

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Aurora(colorA: "#a533f8", colorB: "#22ee88", colorC: "#1694e8")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Aurora(colorA: ShaderColor = "#a533f8", colorB: ShaderColor = "#22ee88", colorC: ShaderColor = "#1694e8", colorSpace: ColorSpace = .linear, balance: Float = 50, intensity: Float = 80, curtainCount: Float = 4, speed: Float = 5, waviness: Float = 50, rayDensity: Float = 20, height: Float = 120, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0), seed: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#a533f8"` | CSS color string | Edge color at the curtain base |
| `colorB` | `ShaderColor` | `"#22ee88"` | CSS color string | Core color in the bright center |
| `colorC` | `ShaderColor` | `"#1694e8"` | CSS color string | Tip color at the ray ends |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `balance` | `Float` | `50` | 0 … 100, step 1 | Shifts color distribution across the curtain height |
| `intensity` | `Float` | `80` | 0 … 100, step 1 | Overall aurora brightness |
| `curtainCount` | `Float` | `4` | 1 … 4, step 1 | Number of aurora curtain layers |
| `speed` | `Float` | `5` | -10 … 10, step 0.1 | Animation speed |
| `waviness` | `Float` | `50` | 0 … 200, step 1 | How much the curtains undulate |
| `rayDensity` | `Float` | `20` | 0 … 100, step 1 | Density of vertical ray structures |
| `height` | `Float` | `120` | 10 … 200, step 1 | How tall the aurora extends |
| `center` | `ShaderPosition` | `(0.5, 0)` | `ShaderPosition` (0…1, top-left origin) | Center position of the aurora |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for variation |

Dynamic form (same values): `ShaderNode(type: "Aurora", props: ["colorA": .string("#a533f8"), "colorB": .string("#22ee88")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
