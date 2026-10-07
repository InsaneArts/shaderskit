# InkFlow

Drag to paint swirling ribbons of ink through a real fluid field — eddies keep evolving after you let go

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    InkFlow(colorSpeed: 1, color: "#ff2d7e", color1: "#4338ff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
InkFlow(colorMode: ColorMode = .rainbow, colorSpeed: Float = 1, color: ShaderColor = "#ff2d7e", color1: ShaderColor = "#4338ff", color2: ShaderColor = "#ff2d7e", color3: ShaderColor = "#19e3ff", colorSpace: ColorSpace = .oklab, radius: Float = 0.3, force: Float = 1, curl: Float = 0, decay: Float = 0.5, momentum: Float = 0.6, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `InkFlow.ColorMode`: .rainbow, .single, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorMode` | `ColorMode` | `"rainbow"` | `rainbow`, `single`, `custom` | How the brush color is chosen: an ever-cycling rainbow, a single fixed color, or a custom three-color cycle |
| `colorSpeed` | `Float` | `1` | 0 … 4, step 0.05 | How quickly the brush cycles through the rainbow or the custom colors as you paint |
| `color` | `ShaderColor` | `"#ff2d7e"` | CSS color string | Brush color used when Color Mode is Single |
| `color1` | `ShaderColor` | `"#4338ff"` | CSS color string | First color of the custom brush cycle |
| `color2` | `ShaderColor` | `"#ff2d7e"` | CSS color string | Second color of the custom brush cycle |
| `color3` | `ShaderColor` | `"#19e3ff"` | CSS color string | Third color of the custom brush cycle |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | color space the custom colors blend through as the brush cycles between them |
| `radius` | `Float` | `0.3` | 0.1 … 5, step 0.05 | Size of the ink splat painted under the cursor |
| `force` | `Float` | `1` | 0 … 3, step 0.05 | How hard the cursor's motion pushes the fluid — higher throws faster, more violent jets and curls |
| `curl` | `Float` | `0` | 0 … 60, step 1 | Vorticity confinement — swirl energy that spins the ink into persistent eddies and curls |
| `decay` | `Float` | `0.5` | 0.05 … 4, step 0.05 | How fast the ink fades away — low values leave long, lingering trails |
| `momentum` | `Float` | `0.6` | 0 … 1, step 0.01 | How long the fluid keeps flowing after a stroke — high momentum lets the motion carry on and on |

Dynamic form (same values): `ShaderNode(type: "InkFlow", props: ["colorMode": .string("rainbow"), "colorSpeed": .number(1)])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
