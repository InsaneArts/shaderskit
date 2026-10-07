# CursorTrail

Animated trail effect that tracks cursor movement

- Category: Interactive · Role: simulation
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    CursorTrail(colorA: "#00aaff", colorB: "#ff00aa", radius: 0.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
CursorTrail(colorA: ShaderColor = "#00aaff", colorB: ShaderColor = "#ff00aa", stops: [ColorStop]? = nil, radius: Float = 0.5, length: Float = 0.5, shrink: Float = 1, softness: Float = 0, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#00aaff"` | CSS color string | Color of fresh trails |
| `colorB` | `ShaderColor` | `"#ff00aa"` | CSS color string | Color trails transition to as they fade |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `radius` | `Float` | `0.5` | 0.5 … 2, step 0.1 | Base radius of the trail stroke |
| `length` | `Float` | `0.5` | 0.1 … 2, step 0.1 | How long the trail persists (in seconds) |
| `shrink` | `Float` | `1` | 0 … 1, step 0.1 | How much the stroke tapers as it fades out (0 = no taper, 1 = full taper) |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Edge softness of the trail (0 = crisp paint edge, 1 = very soft) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "CursorTrail", props: ["colorA": .string("#00aaff"), "colorB": .string("#ff00aa")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
