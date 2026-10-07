# FloatingParticles

Drifting, twinkling motes — thousands of real simulated particles floating in a shared heading with per-particle wander and variance, and a cursor that stirs the field with a gust that settles back into the drift

- Category: Textures · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    FloatingParticles(particleColor: "#ffffff", count: 1200, particleSize: 1.2)
}
```

Initializer (all parameters optional, defaults shown):

```swift
FloatingParticles(particleColor: ShaderColor = "#ffffff", shape: Shape = .dot, count: Float = 1200, particleSize: Float = 1.2, softness: Float = 0.1, speed: Float = 0.25, angle: Float = 90, speedVariance: Float = 0.3, angleVariance: Float = 30, randomness: Float = 0.25, twinkle: Float = 0.5, cursorStrength: Float = 0, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `FloatingParticles.Shape`: .dot, .square, .glow

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `particleColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the particles |
| `shape` | `Shape` | `"dot"` | `dot`, `square`, `glow` | What each particle is drawn as — a crisp dot or square (softness still feathers them), or a soft glow puff |
| `count` | `Float` | `1200` | 100 … 8192, step 100 | Number of particles |
| `particleSize` | `Float` | `1.2` | 0.3 … 4, step 0.05 | Size of the particles (each also varies slightly for depth) |
| `softness` | `Float` | `0.1` | 0 … 1, step 0.01 | Edge softness of each particle — 0 is a crisp shape, 1 a soft glow puff |
| `speed` | `Float` | `0.25` | 0 … 1, step 0.01 | Speed of the shared drift |
| `angle` | `Float` | `90` | 0 … 360, step 1 | Drift heading in degrees (0 = left, 90 = up, 180 = right, 270 = down — the classic default floats upward) |
| `speedVariance` | `Float` | `0.3` | 0 … 1, step 0.05 | Per-particle speed variance around the shared drift (0 = everything moves in lockstep) |
| `angleVariance` | `Float` | `30` | 0 … 180, step 1 | Per-particle heading variance in degrees (0 = one shared direction, 180 = every which way) |
| `randomness` | `Float` | `0.25` | 0 … 1, step 0.05 | Orbital wander — each particle circles lazily around its drift path instead of gliding straight |
| `twinkle` | `Float` | `0.5` | 0 … 1, step 0.05 | Intensity of the twinkle (0 = steady, 1 = full shimmer) |
| `cursorStrength` | `Float` | `0` | 0 … 1, step 0.01 | How strongly the cursor stirs the field — 0 (default) leaves the drift undisturbed |

Dynamic form (same values): `ShaderNode(type: "FloatingParticles", props: ["particleColor": .string("#ffffff"), "shape": .string("dot")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
