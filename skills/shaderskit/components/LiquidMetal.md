# LiquidMetal

Flowing liquid chrome — a molten reflective surface that wraps the shape, sweeping a procedural studio reflection across animated folds with crisp speculars and prismatic edges

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    LiquidMetal(scale: 1, rotation: 0, lightColor: "#eef0f6")
}
```

Initializer (all parameters optional, defaults shown):

```swift
LiquidMetal(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, lightColor: ShaderColor = "#eef0f6", darkColor: ShaderColor = "#141414", turbulence: Float = 1, ripple: Float = 4, warp: Float = 1.5, speed: Float = 0.5, environment: Float = 1.5, envRotation: Float = 0, sharpness: Float = 0.6, dispersion: Float = 0.25, lightAngle: Float = 265, bevelWidth: Float = 0.05, bevelShape: Float = 0, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the metal shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the metal shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the metal shape in degrees |
| `lightColor` | `ShaderColor` | `"#eef0f6"` | CSS color string | The bright tone of the chrome highlights |
| `darkColor` | `ShaderColor` | `"#141414"` | CSS color string | The dark tone the reflection falls to in shadow — recolor for tinted metal (gold, steel, copper…) |
| `turbulence` | `Float` | `1` | 0 … 1.5, step 0.01 | How molten the surface is — the depth of the flowing folds that bend the reflection |
| `ripple` | `Float` | `4` | 0.5 … 8, step 0.01 | Scale of the molten folds — higher = smaller, busier ripples |
| `warp` | `Float` | `1.5` | 0 … 1.5, step 0.01 | Swirl of the flow — domain-warps the folds into liquid curls |
| `speed` | `Float` | `0.5` | 0 … 4, step 0.01 | Speed of the molten flow and the slowly drifting reflection. 0 pauses. |
| `environment` | `Float` | `1.5` | 0 … 2, step 0.01 | Strength of the reflected studio lighting — the softboxes seen across the metal |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the reflected studio — spins where the bright reflections fall |
| `sharpness` | `Float` | `0.6` | 0 … 1, step 0.01 | Tightness of the specular highlights — 1 = razor chrome glints, 0 = soft satin |
| `dispersion` | `Float` | `0.25` | 0 … 1, step 0.01 | Prismatic color fringing along the reflection edges |
| `lightAngle` | `Float` | `265` | 0 … 360, step 1 | Direction of the key light for the specular glints, in degrees |
| `bevelWidth` | `Float` | `0.05` | 0.005 … 0.2, step 0.001 | Width of the edge bevel, relative to the shape — thin for machined jewellery edges, wide for soft pillowed metal |
| `bevelShape` | `Float` | `0` | 0 … 1, step 0.01 | Bevel profile — 0 = one smooth round fillet, 1 = machined: a steep outer fillet, a chamfer plateau and an inner knee, each catching its own line of light |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "LiquidMetal", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
