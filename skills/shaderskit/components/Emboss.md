# Emboss

Embossed / debossed relief shading on top of child content, driven by a custom shape

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Emboss(scale: 1, rotation: 0, depth: -0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this shapeEffect applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Emboss(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, depth: Float = -0.5, lightAngle: Float = 260, lightIntensity: Float = 0.6, shadowIntensity: Float = 0.3, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the embossed shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the embossed shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the embossed shape in degrees |
| `depth` | `Float` | `-0.5` | -1 … 1, step 0.01 | Relief depth — negative = inset (debossed), positive = raised (embossed) |
| `lightAngle` | `Float` | `260` | 0 … 360, step 1 | Directional light angle in degrees — controls highlight and shadow direction |
| `lightIntensity` | `Float` | `0.6` | 0 … 2, step 0.01 | Strength of the directional edge highlights and shadows |
| `shadowIntensity` | `Float` | `0.3` | 0 … 1, step 0.01 | Darkness of the relief shadow |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file — when non-empty, activates SVG mode and triggers a shader recompile |
| `shapeType` | `String` | `""` | — | Active SDF shape type — triggers recompile when shape is switched. When empty, derived from shape JSON at mount time. |

Dynamic form (same values): `ShaderNode(type: "Emboss", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
