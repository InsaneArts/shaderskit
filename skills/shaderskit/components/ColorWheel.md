# ColorWheel

A directional gradient that smoothly cycles through rainbow colors or a custom set of three colors

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ColorWheel(colorA: "#ff0000", colorB: "#00ff88", colorC: "#0066ff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
ColorWheel(mode: Mode = .rainbow, colorA: ShaderColor = "#ff0000", colorB: ShaderColor = "#00ff88", colorC: ShaderColor = "#0066ff", scale: Float = 1, angle: Float = 0, speed: Float = 0.05, colorSpace: ColorSpace = .oklch, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `ColorWheel.Mode`: .rainbow, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `mode` | `Mode` | `"rainbow"` | `rainbow`, `custom` | Rainbow cycles through the full spectrum; Custom loops through your three chosen colors |
| `colorA` | `ShaderColor` | `"#ff0000"` | CSS color string | First color in the cycle |
| `colorB` | `ShaderColor` | `"#00ff88"` | CSS color string | Second color in the cycle |
| `colorC` | `ShaderColor` | `"#0066ff"` | CSS color string | Third color in the cycle |
| `scale` | `Float` | `1` | 0.1 … 10, step 0.1 | Number of color cycles across the viewport |
| `angle` | `Float` | `0` | -180 … 180, step 1, degrees | Direction the gradient flows |
| `speed` | `Float` | `0.05` | -1 … 1, step 0.01 | Speed at which the gradient cycles |
| `colorSpace` | `ColorSpace` | `"oklch"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for blending between custom colors |

Dynamic form (same values): `ShaderNode(type: "ColorWheel", props: ["mode": .string("rainbow"), "colorA": .string("#ff0000")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
