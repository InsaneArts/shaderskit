# Surface3D

Drapes child content over a 3D wave surface with perspective and lighting

- Category: Distortions · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Surface3D(amplitude: 0.3, frequency: 1.5, octaves: 2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this shapeEffect applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Surface3D(amplitude: Float = 0.3, waveType: WaveType = .fractal, frequency: Float = 1.5, octaves: Float = 2, seed: Float = 0, speed: Float = 0.5, tilt: Float = 35, roll: Float = 0, height: Float = 0, zoom: Float = 1, nearCutoff: Float = 0, farCutoff: Float = 1, edgePinning: Float = 0, edges: EdgeMode = .mirror, lighting: Float = 30, glossiness: Float = 0, highlights: Float = 15, lightX: Float = 0.4, lightY: Float = -0.6, lightZ: Float = 0.7, lightColor: ShaderColor = "#ffffff", cursorIntensity: Float = 1, cursorSpeed: Float = 0.5, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Surface3D.WaveType`: .fractal, .sine, .ridge

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `amplitude` | `Float` | `0.3` | 0 … 1, step 0.01 | Wave height |
| `waveType` | `WaveType` | `"fractal"` | `fractal`, `sine`, `ridge` | Wave pattern type |
| `frequency` | `Float` | `1.5` | 0.1 … 5, step 0.1 | Wave frequency |
| `octaves` | `Float` | `2` | 1 … 5, step 1 | Detail octaves |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed offset |
| `speed` | `Float` | `0.5` | 0 … 3, step 0.1 | Animation speed |
| `tilt` | `Float` | `35` | 0 … 85, step 1 | Camera tilt in degrees |
| `roll` | `Float` | `0` | -45 … 45, step 1 | Camera roll in degrees |
| `height` | `Float` | `0` | -1 … 2, step 0.01 | Camera height |
| `zoom` | `Float` | `1` | 0.3 … 3, step 0.01 | Camera zoom |
| `nearCutoff` | `Float` | `0` | 0 … 1, step 0.01 | Near fade distance |
| `farCutoff` | `Float` | `1` | 0 … 1, step 0.01 | Far fade distance |
| `edgePinning` | `Float` | `0` | 0 … 1, step 0.01 | Smoothly flatten the surface at its edges (orthogonal to edge mode) |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle content beyond the surface bounds |
| `lighting` | `Float` | `30` | 0 … 100, step 1 | Intensity of lighting and shading |
| `glossiness` | `Float` | `0` | 0 … 100, step 1 | Surface glossiness |
| `highlights` | `Float` | `15` | 0 … 100, step 1 | Specular highlight intensity |
| `lightX` | `Float` | `0.4` | -1 … 1, step 0.01 | Light direction X |
| `lightY` | `Float` | `-0.6` | -1 … 1, step 0.01 | Light direction Y |
| `lightZ` | `Float` | `0.7` | -1 … 1, step 0.01 | Light direction Z |
| `lightColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Light color |
| `cursorIntensity` | `Float` | `1` | 0 … 2, step 0.01 | Strength of cursor ripples |
| `cursorSpeed` | `Float` | `0.5` | 0 … 1, step 0.01 | Speed of cursor ripple propagation |

Dynamic form (same values): `ShaderNode(type: "Surface3D", props: ["amplitude": .number(0.3), "waveType": .string("fractal")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
