# Irradiance

Photorealistic light spilling around the edge of any 2D, SVG, or 3D shape — any number of movable colored point lights strike the silhouette and the lit edges irradiate their surroundings, gathered in a compute pass with real cast shadows, mixing where they meet and burning to white at the rim

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Irradiance(scale: 1, rotation: 0, lightHeight: 0.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Irradiance(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, lights: [Light] = [Light(position: ShaderPosition(x: 0.3, y: 0.3), color: "#ffb347", intensity: 3), Light(position: ShaderPosition(x: 0.72, y: 0.7), color: "#7a5cff", intensity: 2)], lightHeight: Float = 0.5, lightRange: Float = 1.2, reach: Float = 3, core: Float = 1, wrap: Float = 0.1, shadows: Bool = true, shadowSoftness: Float = 0.15, bodyColor: ShaderColor = "#000000", bodyLight: Float = 0.6, bevelWidth: Float = 0.01, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

List item types:
- `Irradiance.Light(position: ShaderPosition, color: ShaderColor, intensity: Float)`

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the shape in degrees |
| `lights` | `[Light]` | `[{"position":{"x":0.3,"y":0.3},"color":"#ffb347","intensity":3},{"position":{"x":0.72,"y":0.7},"color":"#7a5cff","intensity":2}]` | — | The point lights striking the shape — each with its own position, color and brightness |
| `lightHeight` | `Float` | `0.5` | 0.05 … 3, step 0.01 | Height of the lights above the shape plane, relative to the shape — low lights graze the body, high lights flood it evenly |
| `lightRange` | `Float` | `1.2` | 0.1 … 4, step 0.01 | Reach of each light — the distance at which it has fallen to half strength, relative to the shape |
| `reach` | `Float` | `3` | 0.5 … 8, step 0.01 | How far from the shape the spilled light is gathered, relative to the shape — the glow fades out toward this distance |
| `core` | `Float` | `1` | 0 … 2, step 0.01 | The lit edge seen directly — the white-hot line along the rim where the lights strike |
| `wrap` | `Float` | `0.1` | 0 … 1, step 0.01 | How far light wraps around edges that face away from it — 0 leaves the far side dark |
| `shadows` | `Bool` | `true` | — | Cast shadows — the body blocks each light from edges it stands in front of (keeps holes and concave pockets dark) |
| `shadowSoftness` | `Float` | `0.15` | 0 … 1, step 0.01 | Penumbra width of the cast shadows — 0 is razor sharp |
| `bodyColor` | `ShaderColor` | `"#000000"` | CSS color string | Color of the shape itself — black for a pure occluder, lighter to see the lights land on its form |
| `bodyLight` | `Float` | `0.6` | 0 … 2, step 0.01 | How much the lights illuminate the body — the bevel of a flat shape or the form of a 3D one |
| `bevelWidth` | `Float` | `0.01` | 0.005 … 0.2, step 0.001 | Width of the rounded edge a flat shape catches the light on, relative to the shape |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Irradiance", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Shadows cannot be disabled (`shadows: false` only affects the rim).
