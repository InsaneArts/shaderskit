# Chrome

Studio-lit mirror chrome — a precision-machined shape with a controllable polished bevel, softly convex faces and a photographic studio reflected in them: one huge frontal softbox, black flags, and thin warm/cool strip lights that fringe amber and ice-blue exactly where the reflections break

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Chrome(scale: 1, rotation: 0, tint: "#ffffff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Chrome(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, tint: ShaderColor = "#ffffff", warmColor: ShaderColor = "#ffa94d", coolColor: ShaderColor = "#82a7e6", bevelWidth: Float = 0.028, bevelShape: Float = 0.55, curvature: Float = 0.5, waviness: Float = 0.15, environment: Float = 1, envRotation: Float = 0, softness: Float = 0.3, spectral: Float = 0.9, dispersion: Float = 0.3, shadows: Float = 0.7, speed: Float = 0.5, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the chrome shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the chrome shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the chrome shape in degrees |
| `tint` | `ShaderColor` | `"#ffffff"` | CSS color string | Metal tint multiplied into the reflection — white for silver chrome, warm ivory for gold, dusky rose for copper |
| `warmColor` | `ShaderColor` | `"#ffa94d"` | CSS color string | Color of the warm strip light hugging the studio horizon — the amber band that fringes the reflections |
| `coolColor` | `ShaderColor` | `"#82a7e6"` | CSS color string | Color of the cool wash below the horizon — the steel-blue zone the darker reflections fall into |
| `bevelWidth` | `Float` | `0.028` | 0.005 … 0.2, step 0.001 | Width of the polished edge bevel, relative to the shape — thin for machined jewellery edges, wide for soft pillowed metal |
| `bevelShape` | `Float` | `0.55` | 0 … 1, step 0.01 | Bevel profile — 0 = one smooth round fillet, 1 = machined: a steep outer fillet, a chamfer plateau and an inner knee, each catching its own line of light |
| `curvature` | `Float` | `0.5` | 0 … 1, step 0.01 | Convex doming of the faces — sweeps the big soft studio gradients across otherwise flat metal |
| `waviness` | `Float` | `0.15` | 0 … 1, step 0.01 | Pressed-metal imperfection — gently bends the face reflections and wobbles the bevel light lines so the surface reads as real |
| `environment` | `Float` | `1` | 0 … 2, step 0.01 | Exposure of the reflected studio — the overall brilliance of the chrome |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the whole reflected studio — spins where the softbox, flags and strips fall |
| `softness` | `Float` | `0.3` | 0 … 1, step 0.01 | Softness of the studio edges — 0 = razor polished reflections, 1 = satin diffusion |
| `spectral` | `Float` | `0.9` | 0 … 2, step 0.01 | The colored accent lights: an amber glow hugging the softbox edge and an ice-blue wash below it. 0 = a fully achromatic black-and-white studio. |
| `dispersion` | `Float` | `0.3` | 0 … 1, step 0.01 | Prismatic RGB splitting concentrated on the fast-curving bevel — thin rainbow micro-fringes along the edge highlights, distinct from the broad accent lights |
| `shadows` | `Float` | `0.7` | 0 … 1, step 0.01 | Depth of the dark studio reflections — how hard the black side flags and floor crush toward graphite. 0 lifts them to a soft gray studio. |
| `speed` | `Float` | `0.5` | 0 … 4, step 0.01 | Speed of the studio orbit — the whole lighting environment slowly wanders around the piece, sliding the reflections across faces and edges. 0 freezes it. |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Chrome", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
