# Halftone

Halftone dot pattern effect for printing aesthetics

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Halftone(frequency: 100, angle: 45, cyanAngle: 15) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Halftone(style: Style = .classic, frequency: Float = 100, angle: Float = 45, cyanAngle: Float = 15, magentaAngle: Float = 75, yellowAngle: Float = 0, blackAngle: Float = 45, misprint: Float = 0, misprintAngle: Float = 0, paperColor: ShaderColor = "#ffffff", cyanColor: ShaderColor = "#00ffff", magentaColor: ShaderColor = "#ff00ff", yellowColor: ShaderColor = "#ffff00", blackColor: ShaderColor = "#000000", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Halftone.Style`: .classic, .cmyk

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `style` | `Style` | `"classic"` | `classic`, `cmyk` | Halftone rendering style |
| `frequency` | `Float` | `100` | 10 … 300, step 1 | Frequency of the halftone dots |
| `angle` | `Float` | `45` | 0 … 360, step 1, degrees | Rotation angle of the pattern (in degrees) |
| `cyanAngle` | `Float` | `15` | 0 … 360, step 1, degrees | Screen angle for the cyan plate (in degrees) |
| `magentaAngle` | `Float` | `75` | 0 … 360, step 1, degrees | Screen angle for the magenta plate (in degrees) |
| `yellowAngle` | `Float` | `0` | 0 … 360, step 1, degrees | Screen angle for the yellow plate (in degrees) |
| `blackAngle` | `Float` | `45` | 0 … 360, step 1, degrees | Screen angle for the black plate (in degrees) |
| `misprint` | `Float` | `0` | 0 … 0.01, step 0.0005 | Simulated mis-registration between plates. Plates are offset around the misprint angle, producing color fringing at the edges of inked regions. |
| `misprintAngle` | `Float` | `0` | 0 … 360, step 1, degrees | Direction the plates drift apart. Rotating this rotates the color-fringing pattern. |
| `paperColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Paper/substrate color shown where no ink lands |
| `cyanColor` | `ShaderColor` | `"#00ffff"` | CSS color string | Cyan ink color |
| `magentaColor` | `ShaderColor` | `"#ff00ff"` | CSS color string | Magenta ink color |
| `yellowColor` | `ShaderColor` | `"#ffff00"` | CSS color string | Yellow ink color |
| `blackColor` | `ShaderColor` | `"#000000"` | CSS color string | Black (key) ink color |

Dynamic form (same values): `ShaderNode(type: "Halftone", props: ["style": .string("classic"), "frequency": .number(100)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
