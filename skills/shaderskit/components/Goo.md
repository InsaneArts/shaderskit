# Goo

Photoreal wet liquid — animated 3D metaball blobs that merge and bulge to loosely form the shape, with sliding wet highlights, a clearcoat rim and a translucent body

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Goo(scale: 1, rotation: 0, gooColor: "#37c95a")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Goo(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, gooColor: ShaderColor = "#37c95a", translucency: Float = 0.6, absorb: Float = 2, containment: Float = 0.9, edgeSoftness: Float = 0.06, blobScale: Float = 0.3, spread: Float = 1, merge: Float = 0.6, bulge: Float = 1, threshold: Float = 0.5, lightAngle: Float = 300, wetness: Float = 2, fresnel: Float = 0.25, specColor: ShaderColor = "#ffffff", ambient: Float = 0.25, speed: Float = 0.5, wobble: Float = 0.5, breathe: Float = 0.3, seed: Float = 1, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the goo |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the goo (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the goo in degrees |
| `gooColor` | `ShaderColor` | `"#37c95a"` | CSS color string | Base liquid color (a glossy slime green by default) |
| `translucency` | `Float` | `0.6` | 0 … 1, step 0.01 | Subsurface glow strength — deep lobes transmit more color |
| `absorb` | `Float` | `2` | 0 … 6, step 0.01 | How fast thin areas clear and thick areas saturate (Beer–Lambert) |
| `containment` | `Float` | `0.9` | 0 … 1, step 0.01 | 0 = free blobs that ignore the shape, 1 = goo fills the shape and its surface conforms to the 3D form (highlights track the faces as it rotates) |
| `edgeSoftness` | `Float` | `0.06` | 0 … 0.3, step 0.005 | Softness of the blob coverage edge |
| `blobScale` | `Float` | `0.3` | 0.1 … 1, step 0.01 | Base radius of each liquid lobe |
| `spread` | `Float` | `1` | 0 … 2, step 0.01 | How far the lobes scatter across the shape |
| `merge` | `Float` | `0.6` | 0 … 1, step 0.01 | How much the lobes fuse together — low = distinct beads, high = one fused mass |
| `bulge` | `Float` | `1` | 0 … 1.5, step 0.01 | How 3D-rounded each lobe reads — dome height of the wet surface |
| `threshold` | `Float` | `0.5` | 0.2 … 0.9, step 0.01 | Iso-surface level — lower makes fatter, fuller blobs |
| `lightAngle` | `Float` | `300` | 0 … 360, step 1 | Light direction in degrees |
| `wetness` | `Float` | `2` | 0 … 5, step 0.01 | Master scale on the sharp specular highlight and clearcoat rim |
| `fresnel` | `Float` | `0.25` | 0 … 1, step 0.01 | Clearcoat fresnel rim strength wrapping each lobe |
| `specColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Highlight / rim color (white reads as a clear wet coat) |
| `ambient` | `Float` | `0.25` | 0 … 1, step 0.01 | Base fill so shadowed goo isn't black |
| `speed` | `Float` | `0.5` | 0 … 2, step 0.01 | Drift and breathe speed of the blobs. 0 pauses. |
| `wobble` | `Float` | `0.5` | 0 … 1, step 0.01 | Drift amplitude — how far the lobe centers wander |
| `breathe` | `Float` | `0.3` | 0 … 1, step 0.01 | Radius pulsing amplitude — lobes swell and shrink |
| `seed` | `Float` | `1` | 0 … 100, step 1 | Variation offset — shifts the blob arrangement |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Goo", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
