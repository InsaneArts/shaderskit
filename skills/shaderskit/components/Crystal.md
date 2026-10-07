# Crystal

Diamond-like crystal lens with faceted refraction.

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Crystal(scale: 1, rotation: 0, refraction: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this shapeEffect applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Crystal(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, cutout: Bool = false, refraction: Float = 0.5, dispersion: Float = 0.5, facets: Float = 5, fresnel: Float = 0.05, fresnelSoftness: Float = 1, fresnelColor: ShaderColor = "#ffffff", edgeSoftness: Float = 0, innerZoom: Float = 1.5, lightAngle: Float = 270, highlights: Float = 0.5, shadows: Float = 0.3, brightness: Float = 1.2, tintColor: ShaderColor = "#e8e0ff", tintIntensity: Float = 0, tintPreserveLuminosity: Bool = true, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the crystal shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the crystal shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the crystal shape in degrees |
| `cutout` | `Bool` | `false` | — | Cut out alpha outside the crystal shape |
| `refraction` | `Float` | `0.5` | 0 … 3, step 0.01 | How strongly the crystal refracts content beneath |
| `dispersion` | `Float` | `0.5` | 0 … 2, step 0.01 | Prismatic rainbow dispersion — splits light into spectral colors |
| `facets` | `Float` | `5` | 3 … 24, step 1 | Symmetry order — how many times the facet pattern repeats around the center |
| `fresnel` | `Float` | `0.05` | 0 … 1, step 0.01 | Fresnel rim glow intensity around the crystal boundary |
| `fresnelSoftness` | `Float` | `1` | 0 … 2, step 0.01 | Fresnel rim width — higher values spread the glow further inward |
| `fresnelColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the fresnel rim glow |
| `edgeSoftness` | `Float` | `0` | 0 … 1, step 0.01 | Softness of the crystal boundary edge |
| `innerZoom` | `Float` | `1.5` | 0.5 … 3, step 0.01 | Magnification of content seen through the crystal |
| `lightAngle` | `Float` | `270` | 0 … 360, step 1 | Light direction angle in degrees |
| `highlights` | `Float` | `0.5` | 0 … 2, step 0.01 | Additive brightness on light-facing facets — never darkens |
| `shadows` | `Float` | `0.3` | 0 … 1, step 0.01 | Darkening on shadow-facing facets — never brightens |
| `brightness` | `Float` | `1.2` | 0.5 … 3, step 0.01 | Overall crystal brightness — higher values push facets toward brilliant white |
| `tintColor` | `ShaderColor` | `"#e8e0ff"` | CSS color string | Crystal body tint color |
| `tintIntensity` | `Float` | `0` | 0 … 1, step 0.01 | How much tint color is applied to the crystal interior |
| `tintPreserveLuminosity` | `Bool` | `true` | — | Preserve original brightness when tinting |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Crystal", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
