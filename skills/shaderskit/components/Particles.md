# Particles

A swarm of simulated particles that settles into the shape, filling it evenly — flat, SVG or true 3D volumes — scattering from the cursor (or chasing it), tumbling when the shape moves, and always drifting back home

- Category: Shape Effects · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Particles(scale: 1, rotation: 0, colorA: "#8ec5ff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Particles(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, colorA: ShaderColor = "#8ec5ff", colorB: ShaderColor = "#ff7ad9", count: Float = 4000, size: Float = 1.5, particleShape: ParticleShape = .dot, spread: Float = 1, agitation: Float = 0.12, damping: Float = 0.4, gravity: Float = 0, mouseInfluence: Float = 2, mouseRadius: Float = 0.2, exposure: Float = 1, softness: Float = 0.1, depth: Float = 0.18, colorSpace: ColorSpace = .oklab, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Particles.ParticleShape`: .dot, .square, .glow

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the shape in degrees |
| `colorA` | `ShaderColor` | `"#8ec5ff"` | CSS color string | Color of particles at rest |
| `colorB` | `ShaderColor` | `"#ff7ad9"` | CSS color string | Color particles shift toward when agitated — scattering from the cursor or catching up to a moving shape |
| `count` | `Float` | `4000` | 1000 … 16000, step 1000 | Number of simulated particles |
| `size` | `Float` | `1.5` | 0.6 … 6, step 0.1 | Base particle size (each particle also varies slightly, and grows as it drifts toward the viewer) |
| `particleShape` | `ParticleShape` | `"dot"` | `dot`, `square`, `glow` | What each particle is drawn as — a crisp dot or square (softness still feathers them), or a soft glow puff |
| `spread` | `Float` | `1` | 0.1 … 3, step 0.01 | The pressure pushing particles apart — how strongly they insist on even spacing inside the shape |
| `agitation` | `Float` | `0.12` | 0 … 1, step 0.01 | Idle thermal motion of the swarm — 0 freezes it crystal-still once settled |
| `damping` | `Float` | `0.4` | 0 … 1, step 0.01 | How quickly disturbed particles calm back down and settle into place |
| `gravity` | `Float` | `0` | -2 … 2, step 0.01 | Downward pull on the swarm — negative floats the particles upward |
| `mouseInfluence` | `Float` | `2` | -5 … 5, step 0.01 | Strength of the cursor field. Positive scatters particles away; negative pulls the swarm toward the cursor |
| `mouseRadius` | `Float` | `0.2` | 0.05 … 0.8, step 0.01 | Reach of the cursor field, in shape-local units |
| `exposure` | `Float` | `1` | 0.2 … 3, step 0.01 | Brightness of the additive particle glow |
| `softness` | `Float` | `0.1` | 0 … 1, step 0.01 | Edge softness of each particle — 0 is a crisp disc, 1 a soft glow puff |
| `depth` | `Float` | `0.18` | 0.02 … 0.6, step 0.01 | Thickness of the particle volume behind flat shapes (3D shapes use their own true depth) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the rest→excited color ramp |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Particles", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
