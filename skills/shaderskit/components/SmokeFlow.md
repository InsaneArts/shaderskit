# SmokeFlow

Cursor-driven smoke that lingers, swirls, and dissipates with fluid dynamics

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    SmokeFlow(colorA: "#e29c8b", colorB: "#d517f9", intensity: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
SmokeFlow(colorA: ShaderColor = "#e29c8b", colorB: ShaderColor = "#d517f9", stops: [ColorStop]? = nil, intensity: Float = 1, emitRadius: Float = 0.07, momentum: Float = 20, dissipation: Float = 0.5, detail: Float = 10, gravity: Float = 2, colorDecay: Float = 0.5, colorSpace: ColorSpace = .oklab, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#e29c8b"` | CSS color string | Color of fresh smoke |
| `colorB` | `ShaderColor` | `"#d517f9"` | CSS color string | Color smoke transitions to as it ages |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `intensity` | `Float` | `1` | 0.1 … 2, step 0.05 | How much smoke is emitted as you move the cursor |
| `emitRadius` | `Float` | `0.07` | 0.01 … 0.3, step 0.01 | Size of smoke puff emitted at cursor |
| `momentum` | `Float` | `20` | 0 … 50, step 1 | How much cursor velocity is transferred into the smoke (higher = more directed flow) |
| `dissipation` | `Float` | `0.5` | 0.05 … 3, step 0.05 | How fast smoke fades over time |
| `detail` | `Float` | `10` | 0 … 60, step 1 | Fine-scale swirling detail driven by vorticity confinement |
| `gravity` | `Float` | `2` | -5 … 5, step 0.05 | Vertical drift — negative floats up, positive sinks down |
| `colorDecay` | `Float` | `0.5` | 0 … 3, step 0.1 | How quickly smoke shifts from fresh to aged color |
| `colorSpace` | `ColorSpace` | `"OKLAB"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "SmokeFlow", props: ["colorA": .string("#e29c8b"), "colorB": .string("#d517f9")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
