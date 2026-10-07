# Nebula

A volumetric gas nebula sealed inside polished glass; billowing emission clouds with hollow dark cavities and hot glowing cores, star fields drifting at real depth behind the gas, all refracted through the curved walls of the shape and dressed with studio reflections

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Nebula(scale: 1, rotation: 0, coreColor: "#ffd9b0")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Nebula(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, coreColor: ShaderColor = "#ffd9b0", gasColor: ShaderColor = "#ff5e7a", veilColor: ShaderColor = "#3a5bdb", colorSpace: ColorSpace = .oklab, density: Float = 1, cavity: Float = 0, dust: Float = 0.55, gasScale: Float = 0.4, billow: Float = 0.6, glow: Float = 0, seed: Float = 0, stars: Float = 0.07, starScale: Float = 1, twinkle: Float = 0.35, refraction: Float = 0.5, environment: Float = 0.7, highlight: Float = 1.15, highlightSoftness: Float = 0.5, lightAngle: Float = 315, edgeSoftness: Float = 0.05, speed: Float = 0.3, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the nebula shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the nebula shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the nebula shape in degrees |
| `coreColor` | `ShaderColor` | `"#ffd9b0"` | CSS color string | The hot color the densest gas cores glow with — the embedded newborn stars |
| `gasColor` | `ShaderColor` | `"#ff5e7a"` | CSS color string | The main emission color of the gas body — H-alpha rose by default |
| `veilColor` | `ShaderColor` | `"#3a5bdb"` | CSS color string | The color of the thin outer veils and the deep-space background behind the gas |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space the veil → gas → core ramps blend in |
| `density` | `Float` | `1` | 0 … 1, step 0.01 | Optical density of the gas — how strongly clouds occlude the stars and gas behind them |
| `cavity` | `Float` | `0` | 0 … 1, step 0.01 | How hollowed-out the nebula is — 0 fills the volume with cloud banks, high carves large dark voids between them |
| `dust` | `Float` | `0.55` | 0 … 1, step 0.01 | Cold dark dust lanes threading the gas — absorb-only tendrils that redden the clouds and stars behind them |
| `gasScale` | `Float` | `0.4` | 0.1 … 1, step 0.01 | Feature size of the gas — higher = finer, busier cloud detail |
| `billow` | `Float` | `0.6` | 0 … 1, step 0.01 | Turbulent folding of the clouds — 0 = smooth drifting banks, 1 = heavily churned billows |
| `glow` | `Float` | `0` | 0 … 2, step 0.01 | Hot emission bloom of the dense cores |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — pans the gas field to a different region of noise space for a new cloud composition |
| `stars` | `Float` | `0.07` | 0 … 1, step 0.01 | Brightness of the star fields drifting at depth behind and inside the gas |
| `starScale` | `Float` | `1` | 0.25 … 3, step 0.01 | Density of the star fields — higher = smaller, busier stars |
| `twinkle` | `Float` | `0.35` | 0 … 1, step 0.01 | Intensity of the star twinkle (0 = steady stars, 1 = full shimmer) |
| `refraction` | `Float` | `0.5` | 0 … 1, step 0.01 | How strongly the curved glass walls bend the interior seen near the edges |
| `environment` | `Float` | `0.7` | 0 … 2, step 0.01 | Strength of the studio softboxes reflected in the polished glass surface |
| `highlight` | `Float` | `1.15` | 0 … 2, step 0.01 | Sharp key-light glint on the glass |
| `highlightSoftness` | `Float` | `0.5` | 0 … 1, step 0.01 | Specular highlight softness — lower is a tighter, sharper glint |
| `lightAngle` | `Float` | `315` | 0 … 360, step 1 | Direction of the key light and reflected studio, in degrees |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `speed` | `Float` | `0.3` | 0 … 4, step 0.01 | Speed of the slowly churning gas and twinkling stars. 0 freezes the nebula. |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Nebula", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
