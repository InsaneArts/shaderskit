# Glass

Optically realistic glass lens driven in a custom shape

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Glass(scale: 1, rotation: 0, refraction: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this shapeEffect applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Glass(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, cutout: Bool = false, refraction: Float = 1, edgeSoftness: Float = 0.1, blur: Float = 0, thickness: Float = 0.2, aberration: Float = 0.5, innerZoom: Float = 1, lightAngle: Float = 300, highlight: Float = 0.05, highlightColor: ShaderColor = "#ffffff", highlightSoftness: Float = 0.5, fresnel: Float = 0.1, fresnelSoftness: Float = 0.1, fresnelColor: ShaderColor = "#ffffff", tintColor: ShaderColor = "#ffffff", tintIntensity: Float = 0, tintPreserveLuminosity: Bool = true, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the glass shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the glass shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the glass shape in degrees |
| `cutout` | `Bool` | `false` | — | Cut out the alpha outside the glass shape |
| `refraction` | `Float` | `1` | 0 … 2, step 0.01 | Lens refraction — how aggressively the edges warp content beneath (0 = none, 1 = max) |
| `edgeSoftness` | `Float` | `0.1` | 0 … 1, step 0.01 | Edge softness — higher values give a wider, softer fade at the glass boundary |
| `blur` | `Float` | `0` | 0 … 20, step 0.1 | Frosted blur amount — 0 = clear glass, higher = frosted/diffuse |
| `thickness` | `Float` | `0.2` | 0 … 1, step 0.01 | Glass depth — how far inward from the edge the refraction extends |
| `aberration` | `Float` | `0.5` | 0 … 1, step 0.01 | Chromatic aberration — splits RGB channels along the refraction vector |
| `innerZoom` | `Float` | `1` | 0.5 … 3, step 0.01 | Inner zoom level — magnifies content seen through the glass |
| `lightAngle` | `Float` | `300` | 0 … 360, step 1 | Light angle in degrees |
| `highlight` | `Float` | `0.05` | 0 … 2, step 0.01 | Directional edge highlight — bright rim on the light-facing boundary |
| `highlightColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the directional edge highlight and specular glint |
| `highlightSoftness` | `Float` | `0.5` | 0 … 1, step 0.01 | Specular highlight softness |
| `fresnel` | `Float` | `0.1` | 0 … 1, step 0.01 | Fresnel rim glow — a soft luminous halo around the glass boundary |
| `fresnelSoftness` | `Float` | `0.1` | 0 … 1, step 0.01 | Fresnel rim width — higher values spread the glow further inward |
| `fresnelColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the fresnel rim glow |
| `tintColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color tint applied to the internal directional gradient |
| `tintIntensity` | `Float` | `0` | 0 … 1, step 0.01 | Intensity of the color tint applied to the glass interior |
| `tintPreserveLuminosity` | `Bool` | `true` | — | Preserve original brightness when tinting |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file — when non-empty, activates SVG mode and triggers a shader recompile |
| `shapeType` | `String` | `""` | — | Active SDF shape type — triggers recompile when shape is switched. When empty, derived from shape JSON at mount time. |

Dynamic form (same values): `ShaderNode(type: "Glass", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- `Glass` also exists in SwiftUI or the standard library: write `ShadersKit.Glass` in files that import SwiftUI.
- The frosted (`blur > 0`) prepass is not ported; clear glass works.
