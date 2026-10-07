# StudioBackground

Multi-light studio background with ambient motion.

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    StudioBackground(color: "#d8dbec", keyColor: "#d5e4ea", keyIntensity: 40)
}
```

Initializer (all parameters optional, defaults shown):

```swift
StudioBackground(color: ShaderColor = "#d8dbec", keyColor: ShaderColor = "#d5e4ea", keyIntensity: Float = 40, keySoftness: Float = 50, fillColor: ShaderColor = "#d5e4ea", fillIntensity: Float = 10, fillSoftness: Float = 70, fillAngle: Float = 70, backColor: ShaderColor = "#c8d4e8", backIntensity: Float = 20, backSoftness: Float = 80, brightness: Float = 20, vignette: Float = 0, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.8), lightTarget: Float = 100, wallCurvature: Float = 10, ambientIntensity: Float = 50, ambientSpeed: Float = 2, seed: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#d8dbec"` | CSS color string | Base studio surface color |
| `keyColor` | `ShaderColor` | `"#d5e4ea"` | CSS color string | Color of the overhead key light |
| `keyIntensity` | `Float` | `40` | 0 … 100, step 1 | Intensity of the key light |
| `keySoftness` | `Float` | `50` | 0 … 100, step 1 | How diffuse the key light is |
| `fillColor` | `ShaderColor` | `"#d5e4ea"` | CSS color string | Color of the side fill lights |
| `fillIntensity` | `Float` | `10` | 0 … 100, step 1 | Intensity of the fill lights |
| `fillSoftness` | `Float` | `70` | 0 … 100, step 1 | How diffuse the fill lights are |
| `fillAngle` | `Float` | `70` | 0 … 100, step 1 | How far apart the fill lights are from center |
| `backColor` | `ShaderColor` | `"#c8d4e8"` | CSS color string | Color of the upward back wash |
| `backIntensity` | `Float` | `20` | 0 … 100, step 1 | Intensity of the back wash |
| `backSoftness` | `Float` | `80` | 0 … 100, step 1 | How diffuse the back wash is |
| `brightness` | `Float` | `20` | 0 … 100, step 1 | Overall ambient light level |
| `vignette` | `Float` | `0` | 0 … 100, step 1 | Edge darkening |
| `center` | `ShaderPosition` | `(0.5, 0.8)` | `ShaderPosition` (0…1, top-left origin) | Where the spotlight meets the floor |
| `lightTarget` | `Float` | `100` | 0 … 100, step 1 | How far toward the floor vs wall the spotlights aim |
| `wallCurvature` | `Float` | `10` | 0 … 100, step 1 | How rounded the cove is |
| `ambientIntensity` | `Float` | `50` | 0 … 100, step 1 | Intensity of drifting ambient lights |
| `ambientSpeed` | `Float` | `2` | -5 … 5, step 0.1 | Drift speed |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Seed for ambient pattern |

Dynamic form (same values): `ShaderNode(type: "StudioBackground", props: ["color": .string("#d8dbec"), "keyColor": .string("#d5e4ea")])`
