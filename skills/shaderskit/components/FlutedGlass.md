# FlutedGlass

Full-screen fluted glass effect — refracts content through repeating cylindrical bars

- Category: Distortions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    FlutedGlass(angle: 0, frequency: 10, softness: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
FlutedGlass(shape: Shape = .bars, angle: Float = 0, frequency: Float = 10, softness: Float = 0.5, waveAmplitude: Float = 0.06, waveFrequency: Float = 1.5, speed: Float = 0, refraction: Float = 1.5, aberration: Float = 0.2, lightAngle: Float = 30, highlight: Float = 0.2, highlightSoftness: Float = 0.3, highlightColor: ShaderColor = "#ffffff", edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `FlutedGlass.Shape`: .bars, .rounded, .waves

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `shape` | `Shape` | `"bars"` | `bars`, `rounded`, `waves` | Cross-section shape of each flute |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Direction of the flutes in degrees (0 = vertical bars) |
| `frequency` | `Float` | `10` | 1 … 20, step 1 | Number of flutes across the longest viewport axis |
| `softness` | `Float` | `0.5` | 0 … 1, step 0.01 | How smoothly distortion fades from each flute centre to its edge (0 = flat middle / sharp seams, 1 = gentle curve) |
| `waveAmplitude` | `Float` | `0.06` | 0 … 0.5, step 0.01 | How far each flute sways horizontally as it travels (Waves shape only) |
| `waveFrequency` | `Float` | `1.5` | 0.1 … 10, step 0.1 | How many sways fit along each flute (Waves shape only) |
| `speed` | `Float` | `0` | -1 … 1, step 0.01 | Animation speed — drifts the flute pattern over time and flows wave perturbations |
| `refraction` | `Float` | `1.5` | 0 … 4, step 0.01 | How aggressively each flute bends content beneath it |
| `aberration` | `Float` | `0.2` | 0 … 1, step 0.01 | Chromatic aberration — splits RGB along the refraction direction at flute seams |
| `lightAngle` | `Float` | `30` | -90 … 90, step 1 | Direction the light source is coming from (0 = head-on, 90 = grazing) |
| `highlight` | `Float` | `0.2` | 0 … 2, step 0.01 | Strength of the specular reflection on each flute |
| `highlightSoftness` | `Float` | `0.3` | 0 … 1, step 0.01 | Spread of the specular peak (0 = pin-tight, 1 = broad sheen) |
| `highlightColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the specular highlight |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion samples beyond the canvas |

Dynamic form (same values): `ShaderNode(type: "FlutedGlass", props: ["shape": .string("bars"), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
