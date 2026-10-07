# BrushedMetal

Photorealistic brushed metal — a satin anodised surface combed with fine directional grain that smears the reflected studio and key light into the long anisotropic streaks of real brushed aluminium, steel, gold or copper

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    BrushedMetal(scale: 1, rotation: 0, lightColor: "#e9ebef")
}
```

Initializer (all parameters optional, defaults shown):

```swift
BrushedMetal(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, lightColor: ShaderColor = "#e9ebef", darkColor: ShaderColor = "#26282d", brushAngle: Float = 0, anisotropy: Float = 0.4, grain: Float = 0.4, grainScale: Float = 2, roughness: Float = 0.5, environment: Float = 1.4, envRotation: Float = 0, lightAngle: Float = 215, speed: Float = 0.4, bevelWidth: Float = 0.05, bevelShape: Float = 0, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the metal shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the metal shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the metal shape in degrees |
| `lightColor` | `ShaderColor` | `"#e9ebef"` | CSS color string | The bright tone of the polished grain — recolor for gold (#ffe8b0), copper (#ffc8a0) or steel |
| `darkColor` | `ShaderColor` | `"#26282d"` | CSS color string | The dark tone the brushed grain falls to in shadow. Tint it warm for gold/bronze, cool for steel. |
| `brushAngle` | `Float` | `0` | 0 … 360, step 1 | Direction the surface is brushed, in degrees — the grain and every reflection streak run along this axis |
| `anisotropy` | `Float` | `0.4` | 0 … 1, step 0.01 | How directional the brushing is — 1 = long smeared streaks along the grain, 0 = isotropic satin with no direction |
| `grain` | `Float` | `0.4` | 0 … 1, step 0.01 | Depth of the individual brush scratches — the fine satin texture combed into the metal |
| `grainScale` | `Float` | `2` | 0.25 … 4, step 0.01 | Density of the brush lines — higher = finer, tighter scratches |
| `roughness` | `Float` | `0.5` | 0 … 1, step 0.01 | Overall satin softness — 0 = near-polished with crisp reflections, 1 = soft matte brushed finish |
| `environment` | `Float` | `1.4` | 0 … 2, step 0.01 | Strength of the reflected studio lighting — the softboxes seen smeared across the metal |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the reflected studio — spins where the bright reflections fall |
| `lightAngle` | `Float` | `215` | 0 … 360, step 1 | Direction of the key light for the anisotropic specular streak, in degrees |
| `speed` | `Float` | `0.4` | 0 … 4, step 0.01 | Speed of the slowly drifting reflection — the studio gently orbits the surface. 0 pauses. |
| `bevelWidth` | `Float` | `0.05` | 0.005 … 0.2, step 0.001 | Width of the edge bevel, relative to the shape — thin for machined jewellery edges, wide for soft pillowed metal |
| `bevelShape` | `Float` | `0` | 0 … 1, step 0.01 | Bevel profile — 0 = one smooth round fillet, 1 = machined: a steep outer fillet, a chamfer plateau and an inner knee, each catching its own line of light |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "BrushedMetal", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
