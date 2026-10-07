# LightEdge

Glowing, pulsing light racing around the edge of any 2D, SVG, or 3D shape. Powered by Paper Shaders.

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    LightEdge(scale: 1, rotation: 0, colorA: "#7b2ff7")
}
```

Initializer (all parameters optional, defaults shown):

```swift
LightEdge(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, colorA: ShaderColor = "#7b2ff7", colorB: ShaderColor = "#00e0ff", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .linear, thickness: Float = 0.25, softness: Float = 0.5, intensity: Float = 0.6, bloom: Float = 0.3, spots: Float = 3, spotSize: Float = 0.5, pulse: Float = 0, smoke: Float = 0.3, smokeSize: Float = 0.5, speed: Float = 1, seed: Float = 0, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the shape in degrees |
| `colorA` | `ShaderColor` | `"#7b2ff7"` | CSS color string | First border light color (used when no gradient stops are set) |
| `colorB` | `ShaderColor` | `"#00e0ff"` | CSS color string | Second border light color (used when no gradient stops are set) |
| `stops` | `[ColorStop]?` | `[{"color":"#7b2ff7","position":0},{"color":"#00e0ff","position":0.5},{"color":"#ff3d81","position":1}]` | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space overlapping lights blend in |
| `thickness` | `Float` | `0.25` | 0.01 … 1, step 0.01 | Width of the border band |
| `softness` | `Float` | `0.5` | 0 … 1, step 0.01 | Edge softness — 0 = crisp band, 1 = wide smooth gradient |
| `intensity` | `Float` | `0.6` | 0 … 1, step 0.01 | Brightness of the individual light spots |
| `bloom` | `Float` | `0.3` | 0 … 1, step 0.01 | How additively overlapping lights pile up — high values overdrive to white |
| `spots` | `Float` | `3` | 1 … 5, step 1 | Number of light spots orbiting per color |
| `spotSize` | `Float` | `0.5` | 0 … 1, step 0.01 | Angular size of each light spot |
| `pulse` | `Float` | `0` | 0 … 1, step 0.01 | Heartbeat pulsing — synchronizes the lights to a double-beat rhythm |
| `smoke` | `Float` | `0.3` | 0 … 1, step 0.01 | Noisy luminous smoke drifting along the border |
| `smokeSize` | `Float` | `0.5` | 0 … 1, step 0.01 | Scale of the smoke billows |
| `speed` | `Float` | `1` | 0 … 4, step 0.1 | Animation speed. 0 pauses. |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — re-rolls spot speeds, directions and phases |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "LightEdge", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
