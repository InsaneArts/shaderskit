# Obsidian

Dark tinted glass whose faces stay near-black while every surface turning away from the viewer ignites with a flowing iridescent gradient — vivid color living only on the oblique walls and bevels

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Obsidian(scale: 1, rotation: 0, bodyColor: "#06071a")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Obsidian(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, bodyColor: ShaderColor = "#06071a", colorA: ShaderColor = "#ff2f7a", colorB: ShaderColor = "#5fe6ff", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .oklab, iridescence: Float = 1, rimWidth: Float = 0.55, rimSoftness: Float = 0.25, flowAngle: Float = 30, flowScale: Float = 1, speed: Float = 0.5, gloss: Float = 0.35, envRotation: Float = 0, bevelWidth: Float = 0.08, bevelShape: Float = 0, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the glass shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the glass shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the glass shape in degrees |
| `bodyColor` | `ShaderColor` | `"#06071a"` | CSS color string | The dark body of the glass — what the faces looking straight at you show. Keep it deep for the iridescence to pop. |
| `colorA` | `ShaderColor` | `"#ff2f7a"` | CSS color string | First iridescent color (two-color fallback when stops are cleared) |
| `colorB` | `ShaderColor` | `"#5fe6ff"` | CSS color string | Second iridescent color (two-color fallback when stops are cleared) |
| `stops` | `[ColorStop]?` | `[{"color":"#ff2f7a","position":0},{"color":"#2a2cff","position":0.3},{"color":"#5fe6ff","position":0.55},{"color":"#a6ffd8","position":0.75},{"color":"#ffb3e6","position":1}]` | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `iridescence` | `Float` | `1` | 0 … 1.5, step 0.01 | Strength of the color on the oblique surfaces — 0 = plain dark glass, above 1 = saturated neon walls |
| `rimWidth` | `Float` | `0.55` | 0 … 1, step 0.01 | How far in from edge-on the color reaches — small keeps it to the steepest walls, large lets it creep across gently turning faces |
| `rimSoftness` | `Float` | `0.25` | 0.02 … 0.6, step 0.01 | Softness of the transition from dark face to colored wall |
| `flowAngle` | `Float` | `30` | 0 … 360, step 1 | Direction the gradient flows across the surface, in degrees |
| `flowScale` | `Float` | `1` | 0.2 … 4, step 0.01 | How many times the palette cycles across the shape — higher = tighter color bands |
| `speed` | `Float` | `0.5` | 0 … 4, step 0.01 | Speed the gradient flows along the walls. 0 pauses. |
| `gloss` | `Float` | `0.35` | 0 … 2, step 0.01 | Strength of the studio softboxes reflected in the glass — the pale highlights riding the top edges |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the reflected studio — spins where the bright reflections fall |
| `bevelWidth` | `Float` | `0.08` | 0.005 … 0.3, step 0.001 | Width of the edge bevel on flat shapes — the band that turns away from the viewer and catches the color |
| `bevelShape` | `Float` | `0` | 0 … 1, step 0.01 | Bevel profile — 0 = one smooth round fillet, 1 = machined: a steep outer fillet, a chamfer plateau and an inner knee |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Obsidian", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
