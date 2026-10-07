# Hologram

Volumetric sci-fi hologram — a translucent emissive projection of the shape with fresnel-lit edges, depth scan-lines that wrap 3D forms, CRT scanlines, flicker and beam wobble

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Hologram(scale: 1, rotation: 0, color: "#5ec8ff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Hologram(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, color: ShaderColor = "#5ec8ff", brightness: Float = 2.5, edgeSoftness: Float = 0.04, fill: Float = 0.45, edgeGlow: Float = 1, depthLines: Float = 0.5, depthScale: Float = 26, scanlines: Float = 0.55, scanlineScale: Float = 130, scanlineSpeed: Float = 1, sweep: Float = 0.1, flicker: Float = 0.3, distortion: Float = 0.1, grain: Float = 0.7, speed: Float = 1, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the hologram shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the hologram shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the hologram shape in degrees |
| `color` | `ShaderColor` | `"#5ec8ff"` | CSS color string | Projection tint — the color the whole hologram emits (classic sci-fi cyan by default) |
| `brightness` | `Float` | `2.5` | 0.2 … 3, step 0.01 | Overall emission gain. Bright edges blow out toward white for a hot, projected look. |
| `edgeSoftness` | `Float` | `0.04` | 0 … 1, step 0.01 | Softness of the shape boundary edge — keep low for crisp projection edges |
| `fill` | `Float` | `0.45` | 0 … 1, step 0.01 | Translucent interior glow. Driven by optical thickness, so thicker parts of a 3D form glow more — the core volumetric cue. |
| `edgeGlow` | `Float` | `1` | 0 … 2.5, step 0.01 | Fresnel rim intensity — bright glowing silhouette and, on 3D shapes, the grazing internal walls of extruded logos |
| `depthLines` | `Float` | `0.5` | 0 … 1, step 0.01 | Iso-depth scan-lines that hug the surface and reveal the 3D form like a volumetric scan. On flat shapes they become concentric contour rings. |
| `depthScale` | `Float` | `26` | 4 … 70, step 1 | Density of the depth scan-lines — higher packs more contour bands through the volume |
| `scanlines` | `Float` | `0.55` | 0 … 1, step 0.01 | CRT scanline contrast — how dark the gaps between horizontal projection lines get |
| `scanlineScale` | `Float` | `130` | 20 … 400, step 1 | Number of horizontal scanlines across the canvas height |
| `scanlineSpeed` | `Float` | `1` | 0 … 5, step 0.01 | How fast the scanlines drift upward — 0 holds them static |
| `sweep` | `Float` | `0.1` | 0 … 1, step 0.01 | Brightness of the refresh bar that sweeps vertically through the projection |
| `flicker` | `Float` | `0.3` | 0 … 1, step 0.01 | Unstable-projector flicker — a fast shimmer plus occasional brightness dropouts |
| `distortion` | `Float` | `0.1` | 0 … 1, step 0.01 | Continuous horizontal wobble and chromatic edge fringing — the wavering of an unstable beam |
| `grain` | `Float` | `0.7` | 0 … 1, step 0.01 | Fine projection static — animated per-pixel noise over the emission |
| `speed` | `Float` | `1` | 0 … 3, step 0.01 | Master animation speed for every animated layer. 0 freezes the projection. |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file — when non-empty, activates SVG mode and triggers a shader recompile |
| `shapeType` | `String` | `""` | — | Active SDF shape type — triggers recompile when shape is switched. When empty, derived from shape JSON at mount time. |

Dynamic form (same values): `ShaderNode(type: "Hologram", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
