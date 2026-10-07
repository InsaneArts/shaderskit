# Holographic

Iridescent holographic foil sticker with animated rainbow sheen and glitter flakes

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Holographic(scale: 1, rotation: 0, hueShift: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Holographic(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, hueShift: Float = 0, foilScale: Float = 1.5, saturation: Float = 0.75, roughness: Float = 0.25, speed: Float = 1, crinkle: Float = 0.5, crinkleScale: Float = 1, sparkle: Float = 0.4, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the foil shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the foil shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the foil shape in degrees |
| `hueShift` | `Float` | `0` | 0 … 360, step 1 | Rotates the rainbow spectrum across the foil |
| `foilScale` | `Float` | `1.5` | 0.3 … 6, step 0.01 | Size of the iridescent color patches — higher = smaller, busier patches |
| `saturation` | `Float` | `0.75` | 0 … 1, step 0.01 | Rainbow saturation — 0 = plain silver foil, 1 = fully spectral |
| `roughness` | `Float` | `0.25` | 0 … 1, step 0.01 | Matte laminate grain — softens the gloss with fine paper-like noise |
| `speed` | `Float` | `1` | 0 … 2, step 0.01 | Animation speed — the spectrum drifts across the foil as if the sticker is tilting in your hand. 0 pauses. |
| `crinkle` | `Float` | `0.5` | 0 … 1, step 0.01 | Laminate wrinkles — perturbs the surface so the sheen and rainbow swirl locally instead of lying flat |
| `crinkleScale` | `Float` | `1` | 0.3 … 6, step 0.01 | Size of the laminate wrinkles — higher = smaller, denser wrinkles |
| `sparkle` | `Float` | `0.4` | 0 … 1, step 0.01 | Glitter flakes embedded in the foil — tiny facets that refract a shifted hue and twinkle as the spectrum drifts |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Holographic", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
