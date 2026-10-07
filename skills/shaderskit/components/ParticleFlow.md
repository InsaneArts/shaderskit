# ParticleFlow

Thousands of drifting dust particles carried by a real incompressible fluid field the cursor stirs — drag to plow a wake and the particles ride the eddies and vortices it leaves behind, while a gentle ambient breeze keeps the whole scene breathing on its own

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ParticleFlow(colorA: "#8ec5ff", colorB: "#ffd98e", count: 6000)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ParticleFlow(colorA: ShaderColor = "#8ec5ff", colorB: ShaderColor = "#ffd98e", colorSpace: ColorSpace = .oklab, shape: Shape = .streak, count: Float = 6000, size: Float = 1.2, trails: Float = 0, speed: Float = 1, force: Float = 1, swirl: Float = 25, momentum: Float = 0.6, ambient: Float = 0.15, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `ParticleFlow.Shape`: .arrow, .streak, .dot, .square, .glow

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#8ec5ff"` | CSS color string | Color of particles drifting slowly with the flow |
| `colorB` | `ShaderColor` | `"#ffd98e"` | CSS color string | Color particles flash toward as they speed up in the fast jets and wakes |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the rest→excited color ramp |
| `shape` | `Shape` | `"streak"` | `arrow`, `streak`, `dot`, `square`, `glow` | What each particle is drawn as — a streak or arrow that stretches along the flow, a plain dot, a square, or a soft glowing comet |
| `count` | `Float` | `6000` | 1000 … 16000, step 500 | Number of drifting particles |
| `size` | `Float` | `1.2` | 0.3 … 3, step 0.05 | Size of each particle |
| `trails` | `Float` | `0` | 0 … 1, step 0.01 | How long each particle's motion trail persists — 0 draws crisp dust, 1 leaves long flowing ribbons |
| `speed` | `Float` | `1` | 0.2 … 3, step 0.05 | How strongly the fluid carries the particles — higher makes the dust ride the flow faster |
| `force` | `Float` | `1` | 0 … 3, step 0.05 | How hard the cursor's motion pushes the fluid — higher plows faster, more violent wakes and jets |
| `swirl` | `Float` | `25` | 0 … 60, step 1 | Vorticity confinement — swirl energy that spins the flow into persistent eddies and vortices the dust orbits |
| `momentum` | `Float` | `0.6` | 0 … 1, step 0.01 | How long the fluid keeps flowing after you stop dragging — high momentum lets the eddies carry the dust on and on |
| `ambient` | `Float` | `0.15` | 0 … 1, step 0.01 | A gentle, ever-evolving breeze that keeps the dust drifting even without the cursor — set to 0 for a field that only moves when you stir it |

Dynamic form (same values): `ShaderNode(type: "ParticleFlow", props: ["colorA": .string("#8ec5ff"), "colorB": .string("#ffd98e")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
