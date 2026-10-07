# Heatmap

Thermal-camera heat flowing through any 2D, SVG, or 3D shape. Powered by Paper Shaders.

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Heatmap(scale: 1, rotation: 0, colorA: "#02010f")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Heatmap(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, colorA: ShaderColor = "#02010f", colorB: ShaderColor = "#f9e25f", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .oklab, innerGlow: Float = 0.4, outerGlow: Float = 0.2, contour: Float = 0.5, angle: Float = 90, speed: Float = 1, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the heatmap shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the heatmap shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the heatmap shape in degrees |
| `colorA` | `ShaderColor` | `"#02010f"` | CSS color string | Cold color (used when no gradient stops are set) |
| `colorB` | `ShaderColor` | `"#f9e25f"` | CSS color string | Hot color (used when no gradient stops are set) |
| `stops` | `[ColorStop]?` | `[{"color":"#02010f","position":0},{"color":"#2a0a8a","position":0.2},{"color":"#a41c9b","position":0.45},{"color":"#e8632b","position":0.7},{"color":"#f9e25f","position":0.9},{"color":"#ffffff","position":1}]` | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the heat ramp interpolation |
| `innerGlow` | `Float` | `0.4` | 0 … 1, step 0.01 | Heat filling the inside of the shape |
| `outerGlow` | `Float` | `0.2` | 0 … 1, step 0.01 | Heat radiating beyond the silhouette |
| `contour` | `Float` | `0.5` | 0 … 1, step 0.01 | Heat concentrated along the shape boundary |
| `angle` | `Float` | `90` | 0 … 360, step 1 | Direction the heat waves travel, in degrees |
| `speed` | `Float` | `1` | 0 … 4, step 0.01 | Speed of the flowing heat. 0 pauses. |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Heatmap", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
