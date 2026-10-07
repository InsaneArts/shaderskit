# SmokeFill

Fill a shape with swirling fluid smoke that interacts with the shape boundary

- Category: Shape Effects · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    SmokeFill(colorA: "#8cf3ff", colorB: "#04a0d6", scale: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
SmokeFill(colorA: ShaderColor = "#8cf3ff", colorB: ShaderColor = "#04a0d6", origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, emitFrom: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), direction: Float = 0, speed: Float = 10, spread: Float = 60, emitRadius: Float = 0.03, intensity: Float = 1, dissipation: Float = 0.3, detail: Float = 25, gravity: Float = 0.5, colorDecay: Float = 0.4, mouseInfluence: Float = 0.1, mouseRadius: Float = 0.1, colorSpace: ColorSpace = .linear, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#8cf3ff"` | CSS color string | Color of fresh smoke |
| `colorB` | `ShaderColor` | `"#04a0d6"` | CSS color string | Color smoke transitions to as it ages |
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the shape in degrees |
| `emitFrom` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Emission source point within the shape |
| `direction` | `Float` | `0` | 0 … 360, step 1 | Emission direction (0 = up, 90 = right, 180 = down, 270 = left) |
| `speed` | `Float` | `10` | 0.1 … 30, step 0.1 | Emission velocity strength |
| `spread` | `Float` | `60` | 0 … 180, step 1 | Emission cone angle in degrees |
| `emitRadius` | `Float` | `0.03` | 0.01 … 0.3, step 0.01 | Size of the emission area |
| `intensity` | `Float` | `1` | 0.1 … 1, step 0.01 | Smoke emission density |
| `dissipation` | `Float` | `0.3` | 0.1 … 5, step 0.1 | How fast smoke fades over time |
| `detail` | `Float` | `25` | 0 … 50, step 1 | Fine-scale swirling detail |
| `gravity` | `Float` | `0.5` | -2 … 2, step 0.1 | Downward gravitational pull on smoke — 0 = weightless, negative values = smoke rises |
| `colorDecay` | `Float` | `0.4` | 0 … 3, step 0.1 | How quickly smoke shifts from Color A to Color B |
| `mouseInfluence` | `Float` | `0.1` | 0 … 2, step 0.01 | Strength of cursor influence |
| `mouseRadius` | `Float` | `0.1` | 0.02 … 0.5, step 0.01 | Radius of cursor influence area |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "SmokeFill", props: ["colorA": .string("#8cf3ff"), "colorB": .string("#04a0d6")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
