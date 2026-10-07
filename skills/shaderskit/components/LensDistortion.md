# LensDistortion

Split content into shifting chromatic layers with barrel or pincushion lens warp. Powered by Paper Shaders.

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    LensDistortion(spread: 0.6, angle: 0, perspective: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
LensDistortion(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), spread: Float = 0.6, angle: Float = 0, perspective: Float = 0.1, bias: Float = 1, count: Float = 35, dispersion: Float = 1, dispersionShift: Float = 0, dispersionColor: Float = 0.6, focusCenter: Float = 0.8, focusEdges: Float = 1, lensBulge: Float = 0, lensCircle: Float = 0, swirl: Float = 0.35, noise: Float = 0, noiseFrequency: Float = 0.25, noiseOffset: Float = 0, grainMixer: Float = 0, grainOverlay: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the lens effect — the focus zone, lens warp, circle crop and swirl all pivot around it |
| `spread` | `Float` | `0.6` | 0 … 1, step 0.01 | Strength of the color split; how far the color layers are pushed apart (0 is off) |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Direction of the spread in degrees |
| `perspective` | `Float` | `0.1` | 0 … 1, step 0.01 | Shapes the spread direction from a straight line (0) to a radial burst out from the centre (1) |
| `bias` | `Float` | `1` | -1 … 1, step 0.01 | Shifts the colors toward one end of the spread; 0 spaces them evenly |
| `count` | `Float` | `35` | 2 … 50, step 1 | Number of sampled color layers along the spread; higher is smoother and costlier |
| `dispersion` | `Float` | `1` | 0 … 1, step 0.01 | Overall amount of color dispersion; 1 gives each layer its own color from the spectrum, 0 keeps the original color |
| `dispersionShift` | `Float` | `0` | -1 … 1, step 0.01 | Balance of the dispersion between a soft circular zone at the centre and the rest; -1 keeps it in the centre only, 1 at the edges only |
| `dispersionColor` | `Float` | `0.6` | 0 … 1, step 0.01 | Rotates the dispersion colors around the hue wheel, 0 to 1 for a full turn |
| `focusCenter` | `Float` | `0.8` | 0 … 1, step 0.01 | Reduces the spread in a circular zone at the centre; 0 keeps it full to the centre |
| `focusEdges` | `Float` | `1` | 0 … 1, step 0.01 | Reduces the spread toward the edges; 1 restores the original image there |
| `lensBulge` | `Float` | `0` | -1 … 1, step 0.01 | Radial lens warp; positive bulges out like a fisheye, negative pinches in like a pincushion |
| `lensCircle` | `Float` | `0` | 0 … 1, step 0.01 | Squeezes pixels outside the inscribed circle inward so the outline becomes a circle |
| `swirl` | `Float` | `0.35` | -1 … 1, step 0.01 | Rotates the color layers around the centre by an angle growing along the spread; 0 is off |
| `noise` | `Float` | `0` | 0 … 1, step 0.01 | Scatters the spread direction with noise; 0 is off |
| `noiseFrequency` | `Float` | `0.25` | 0 … 1, step 0.01 | Frequency of the direction noise; higher is finer (no effect with noise at 0) |
| `noiseOffset` | `Float` | `0` | 0 … 1, step 0.01 | Offsets the noise pattern for a different seed (no effect with noise at 0) |
| `grainMixer` | `Float` | `0` | 0 … 1, step 0.01 | Scatters the spread with grain noise, breaking up the edges of the color layers |
| `grainOverlay` | `Float` | `0` | 0 … 1, step 0.01 | Post-processing black/white grain overlay |

Dynamic form (same values): `ShaderNode(type: "LensDistortion", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "spread": .number(0.6)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
