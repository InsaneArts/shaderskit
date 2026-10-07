# Smoke

Realistic fluid smoke simulation with vorticity dynamics

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Smoke(colorA: "#fc83f9", colorB: "#c21c79", direction: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Smoke(colorA: ShaderColor = "#fc83f9", colorB: ShaderColor = "#c21c79", stops: [ColorStop]? = nil, emitFrom: ShaderPosition = ShaderPosition(x: 0.5, y: 1), direction: Float = 0, speed: Float = 20, spread: Float = 60, emitRadius: Float = 0.08, intensity: Float = 1, dissipation: Float = 0.2, detail: Float = 25, gravity: Float = 0.5, colorDecay: Float = 0.4, mouseInfluence: Float = 0.1, mouseRadius: Float = 0.1, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#fc83f9"` | CSS color string | Color of fresh smoke |
| `colorB` | `ShaderColor` | `"#c21c79"` | CSS color string | Color smoke transitions to as it ages |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `emitFrom` | `ShaderPosition` | `(0.5, 1)` | `ShaderPosition` (0…1, top-left origin) | The emission source point |
| `direction` | `Float` | `0` | 0 … 360, step 1 | Emission direction (0 = up, 90 = right, 180 = down, 270 = left) |
| `speed` | `Float` | `20` | 0.1 … 50, step 0.1 | Emission velocity strength |
| `spread` | `Float` | `60` | 0 … 180, step 1 | Emission cone angle in degrees |
| `emitRadius` | `Float` | `0.08` | 0.01 … 0.3, step 0.01 | Size of the emission area |
| `intensity` | `Float` | `1` | 0.1 … 1, step 0.01 | Smoke emission density |
| `dissipation` | `Float` | `0.2` | 0.1 … 3, step 0.1 | How fast smoke fades over time |
| `detail` | `Float` | `25` | 0 … 50, step 1 | Fine-scale swirling detail |
| `gravity` | `Float` | `0.5` | -2 … 2, step 0.1 | Downward gravitational pull on smoke |
| `colorDecay` | `Float` | `0.4` | 0 … 3, step 0.1 | How quickly smoke shifts from Color A to Color B |
| `mouseInfluence` | `Float` | `0.1` | 0 … 2, step 0.01 | Strength of cursor influence |
| `mouseRadius` | `Float` | `0.1` | 0.02 … 0.5, step 0.01 | Radius of cursor influence area |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Smoke", props: ["colorA": .string("#fc83f9"), "colorB": .string("#c21c79")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
