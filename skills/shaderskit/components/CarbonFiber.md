# CarbonFiber

Photorealistic woven carbon fibre — interlaced tows whose anisotropic sheen flips ninety degrees cell to cell, raised into a quilted weave and finished with a glossy clearcoat that mirrors the studio. Plain or twill, in any shape.

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    CarbonFiber(scale: 1, rotation: 0, lightColor: "#b9bdc6")
}
```

Initializer (all parameters optional, defaults shown):

```swift
CarbonFiber(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, lightColor: ShaderColor = "#b9bdc6", darkColor: ShaderColor = "#0b0c0e", weaveStyle: WeaveStyle = .twill, weaveScale: Float = 30, weaveAngle: Float = 0, relief: Float = 0.5, fiberSheen: Float = 1.2, roughness: Float = 0.5, clearcoat: Float = 1.2, environment: Float = 2, envRotation: Float = 0, lightAngle: Float = 215, bevelWidth: Float = 0.05, bevelShape: Float = 0, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `CarbonFiber.WeaveStyle`: .twill, .plain

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the carbon shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the carbon shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the carbon shape in degrees |
| `lightColor` | `ShaderColor` | `"#b9bdc6"` | CSS color string | The bright tone of the fibre sheen — recolor for forged/colored carbon (red, blue, bronze) |
| `darkColor` | `ShaderColor` | `"#0b0c0e"` | CSS color string | The deep resin tone the weave falls to in shadow — near-black for classic carbon |
| `weaveStyle` | `WeaveStyle` | `"twill"` | `twill`, `plain` | Weave pattern — plain (checkerboard) or 2×2 twill (the diagonal supercar weave) |
| `weaveScale` | `Float` | `30` | 2 … 50, step 0.5 | Number of woven tows across the shape — higher = finer, denser weave |
| `weaveAngle` | `Float` | `0` | 0 … 360, step 1 | Rotates the whole weave grid in degrees |
| `relief` | `Float` | `0.5` | 0 … 1, step 0.01 | Depth of the quilted weave — how far each tow bulges, catching light on its crown and shadowing the valleys between |
| `fiberSheen` | `Float` | `1.2` | 0 … 1.5, step 0.01 | Strength of the anisotropic fibre sheen — the directional satin glint running along each tow |
| `roughness` | `Float` | `0.5` | 0 … 1, step 0.01 | Softness of the fibre sheen — 0 = tight crisp glints, 1 = soft matte satin |
| `clearcoat` | `Float` | `1.2` | 0 … 2, step 0.01 | Strength of the glossy lacquer coat — the sharp studio reflections of the wet clearcoat over the weave |
| `environment` | `Float` | `2` | 0 … 2, step 0.01 | Strength of the reflected studio lighting seen in the clearcoat |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the reflected studio — spins where the bright reflections fall |
| `lightAngle` | `Float` | `215` | 0 … 360, step 1 | Direction of the key light for the fibre sheen, in degrees |
| `bevelWidth` | `Float` | `0.05` | 0.005 … 0.2, step 0.001 | Width of the edge bevel, relative to the shape — thin for machined jewellery edges, wide for soft pillowed metal |
| `bevelShape` | `Float` | `0` | 0 … 1, step 0.01 | Bevel profile — 0 = one smooth round fillet, 1 = machined: a steep outer fillet, a chamfer plateau and an inner knee, each catching its own line of light |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "CarbonFiber", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`
