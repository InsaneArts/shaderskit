# Frost

Photoreal frozen ice — thickness-driven subsurface scattering that reads as a solid block, with fine frost crystals creeping in from the edges

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Frost(scale: 1, rotation: 0, iceColor: "#0597fc")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Frost(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, iceColor: ShaderColor = "#0597fc", ambient: Float = 0, edgeSoftness: Float = 0.05, density: Float = 5, absorption: Float = 1, scatter: Float = 0.5, frostAmount: Float = 0.8, frostDepth: Float = 0.4, frostScale: Float = 1, frostRoughness: Float = 3, sparkle: Float = 0.5, gloss: Float = 0.6, fresnel: Float = 0.02, lightAngle: Float = 300, speed: Float = 0.3, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the ice shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the ice shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the ice shape in degrees |
| `iceColor` | `ShaderColor` | `"#0597fc"` | CSS color string | Ice tint — the color deep ice saturates toward (thin edges stay near white) |
| `ambient` | `Float` | `0` | 0 … 1, step 0.01 | Cool ambient fill so shadowed ice never goes black |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `density` | `Float` | `5` | 0 … 10, step 0.01 | Optical depth multiplier — how thick and deep the ice reads |
| `absorption` | `Float` | `1` | 0 … 2, step 0.01 | Beer–Lambert absorption strength — higher drives a deeper blue-teal core |
| `scatter` | `Float` | `0.5` | 0 … 1, step 0.01 | Forward back-lit glow transmitted through thin ice |
| `frostAmount` | `Float` | `0.8` | 0 … 1, step 0.01 | Overall density of the rim frost crystals |
| `frostDepth` | `Float` | `0.4` | 0 … 1, step 0.01 | How far the frost creeps inward from the rim |
| `frostScale` | `Float` | `1` | 0.3 … 4, step 0.01 | Crystal size — higher = finer, busier frost |
| `frostRoughness` | `Float` | `3` | 1 … 5, step 0.01 | Feathery roughness of the frost crystal surface |
| `sparkle` | `Float` | `0.5` | 0 … 1, step 0.01 | Tiny bright crystal glints catching the light at the rim |
| `gloss` | `Float` | `0.6` | 0 … 1, step 0.01 | Surface sheen — the broad soft icy specular |
| `fresnel` | `Float` | `0.02` | 0 … 1, step 0.01 | Cold rim glow on grazing surfaces |
| `lightAngle` | `Float` | `300` | 0 … 360, step 1 | Key light direction in degrees |
| `speed` | `Float` | `0.3` | 0 … 2, step 0.01 | Sparkle twinkle speed. 0 freezes the sparkle. |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Frost", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
