# Waveform

Audio-visualizer waveform — equalizer bars, a filled wave, an oscilloscope line, or a dot matrix — driven by a simulated signal whose amplitude you can map to your own audio level

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Waveform(colorA: "#3b5bff", colorB: "#ff3bd4", amplitude: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Waveform(style: Style = .bars, colorA: ShaderColor = "#3b5bff", colorB: ShaderColor = "#ff3bd4", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .oklab, from: ShaderPosition = ShaderPosition(x: 0, y: 0.5), to: ShaderPosition = ShaderPosition(x: 1, y: 0.5), amplitude: Float = 1, frequency: Float = 1, height: Float = 0.6, align: Align = .mirrored, count: Float = 32, barWidth: Float = 0.6, rounding: Float = 1, dotSize: Float = 0.7, lineWidth: DimensionalValue = 0.006, softness: Float = 0, speed: Float = 1, seed: Float = 1, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Waveform.Style`: .bars, .wave, .line, .dots
- `Waveform.Align`: .mirrored, .top, .bottom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `style` | `Style` | `"bars"` | `bars`, `wave`, `line`, `dots` | Visualizer style: equalizer bars, a filled wave envelope, an oscilloscope line, or a dot matrix |
| `colorA` | `ShaderColor` | `"#3b5bff"` | CSS color string | Color at the start |
| `colorB` | `ShaderColor` | `"#ff3bd4"` | CSS color string | Color at the end |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the start→end gradient |
| `from` | `ShaderPosition` | `(0, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Where the waveform starts (Color A end) |
| `to` | `ShaderPosition` | `(1, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Where the waveform ends (Color B end) |
| `amplitude` | `Float` | `1` | 0 … 2, step 0.01 | Overall signal level (0 = silence). Map this to your own audio level to make the waveform react to real sound. |
| `frequency` | `Float` | `1` | 0.2 … 3, step 0.01 | How busy the signal is across the width (higher = more peaks) |
| `height` | `Float` | `0.6` | 0.05 … 1, step 0.01 | Maximum vertical extent of the waveform as a fraction of the canvas height |
| `align` | `Align` | `"mirrored"` | `mirrored`, `top`, `bottom` | Which side of the start→end baseline the waveform grows on: mirrored around it, above it (top), or below it (bottom) |
| `count` | `Float` | `32` | 4 … 128, step 1 | Number of bars (or dot columns) across the width |
| `barWidth` | `Float` | `0.6` | 0.1 … 1, step 0.01 | Bar thickness as a fraction of its column (1 = bars touch) |
| `rounding` | `Float` | `1` | 0 … 1, step 0.01 | Rounds the bar ends (0 = square, 1 = fully rounded caps) |
| `dotSize` | `Float` | `0.7` | 0.2 … 1, step 0.01 | Dot diameter as a fraction of its cell |
| `lineWidth` | `DimensionalValue` | `0.006` | 0.001 … 0.05, step 0.001 | Stroke thickness of the line. A value of one (1) matches the canvas height. |
| `softness` | `Float` | `0` | 0 … 1, step 0.01 | Feathers the wave's edge into a glow |
| `speed` | `Float` | `1` | 0 … 3, step 0.01 | Animation speed of the simulated signal |
| `seed` | `Float` | `1` | 0 … 100, step 1 | Adjusts the starting state, useful for variation |

Dynamic form (same values): `ShaderNode(type: "Waveform", props: ["style": .string("bars"), "colorA": .string("#3b5bff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
