# Fog

Fog that fills the screen and interacts with the mouse

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Fog(colorA: "#e0e0e0", colorB: "#888888", speed: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Fog(colorA: ShaderColor = "#e0e0e0", colorB: ShaderColor = "#888888", seed: Float = 0, speed: Float = 1, turbulence: Float = 1, detail: Float = 15, blending: Float = 0.3, mouseInfluence: Float = 0.1, mouseRadius: Float = 0.1, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#e0e0e0"` | CSS color string | Primary fog color |
| `colorB` | `ShaderColor` | `"#888888"` | CSS color string | Secondary fog color — creates variation across the field |
| `seed` | `Float` | `0` | 0 … 999, step 1 | Deterministic starting pattern — different seeds produce different fog configurations |
| `speed` | `Float` | `1` | 0.1 … 3, step 0.1 | Simulation speed multiplier |
| `turbulence` | `Float` | `1` | 0 … 3, step 0.01 | Ambient motion strength |
| `detail` | `Float` | `15` | 0 … 50, step 1 | Fine-scale swirling structure — higher values produce more intricate wisps and vortices |
| `blending` | `Float` | `0.3` | 0 … 1, step 0.01 | How much the two colors blend together — 0 behaves like oil & water (colors stay distinct with sharp boundaries), 1 behaves like food coloring (colors fully mix) |
| `mouseInfluence` | `Float` | `0.1` | 0 … 2, step 0.01 | Strength of cursor influence — move the cursor to push fog |
| `mouseRadius` | `Float` | `0.1` | 0.02 … 0.5, step 0.01 | Radius of cursor influence area |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Fog", props: ["colorA": .string("#e0e0e0"), "colorB": .string("#888888")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
