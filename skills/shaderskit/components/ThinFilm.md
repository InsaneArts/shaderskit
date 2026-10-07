# ThinFilm

Iridescent thin-film edge

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ThinFilm(scale: 1, rotation: 0, intensity: 1)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ThinFilm(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, intensity: Float = 1, rimWidth: Float = 1, edgeSoftness: Float = 0.3, thickness: Float = 0.5, dispersion: Float = 0.5, saturation: Float = 1, hueShift: Float = 0, lightAngle: Float = 300, mode: Mode = .rainbow, colorA: ShaderColor = "#2b6fff", colorB: ShaderColor = "#ffffff", colorC: ShaderColor = "#ff7a21", colorSpace: ColorSpace = .oklch, speed: Float = 0.1, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `ThinFilm.Mode`: .rainbow, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the shape in degrees |
| `intensity` | `Float` | `1` | 0 … 4, step 0.01 | Rim brightness — values above 1 push the edge past white for HDR bloom |
| `rimWidth` | `Float` | `1` | 0 … 3, step 0.01 | How far inward from the edge the iridescence reaches |
| `edgeSoftness` | `Float` | `0.3` | 0 … 1, step 0.01 | Softness of the shape boundary |
| `thickness` | `Float` | `0.5` | 0 … 1, step 0.01 | Film thickness — higher values pack more spectral bands across the rim |
| `dispersion` | `Float` | `0.5` | 0 … 1, step 0.01 | How strongly color separates around the perimeter (warm vs cool sides) |
| `saturation` | `Float` | `1` | 0 … 1, step 0.01 | Spectral saturation — 0 = white rim, 1 = full iridescence |
| `hueShift` | `Float` | `0` | 0 … 1, step 0.01 | Rotate the spectrum to reposition the colors |
| `lightAngle` | `Float` | `300` | 0 … 360, step 1 | Light angle in degrees — sets which side of the rim runs warm vs cool |
| `mode` | `Mode` | `"rainbow"` | `rainbow`, `custom` | Rainbow uses the full iridescent spectrum; Custom cycles through your three chosen colors |
| `colorA` | `ShaderColor` | `"#2b6fff"` | CSS color string | First color in the rim cycle |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Second color in the rim cycle |
| `colorC` | `ShaderColor` | `"#ff7a21"` | CSS color string | Third color in the rim cycle |
| `colorSpace` | `ColorSpace` | `"oklch"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | color space used to blend between custom colors |
| `speed` | `Float` | `0.1` | -1 … 1, step 0.01 | Speed at which the colors rotate around the rim (0 = static) |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file — when non-empty, activates SVG mode and triggers a shader recompile |
| `shapeType` | `String` | `""` | — | Active SDF shape type — triggers recompile when shape is switched. When empty, derived from shape JSON at mount time. |

Dynamic form (same values): `ShaderNode(type: "ThinFilm", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
