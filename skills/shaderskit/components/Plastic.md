# Plastic

Glossy molded plastic with photorealistic studio reflections, driven in a custom shape

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Plastic(scale: 1, rotation: 0, colorA: "#f5f5f7")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Plastic(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, colorA: ShaderColor = "#f5f5f7", colorB: ShaderColor = "#d9dade", stops: [ColorStop]? = nil, gradientAngle: Float = 90, colorSpace: ColorSpace = .linear, thickness: Float = 0.5, roughness: Float = 0.12, reflectivity: Float = 1, crumple: Float = 0.25, crumpleScale: Float = 1, crumpleCoverage: Float = 1, seed: Float = 0, edgeSoftness: Float = 0.05, lightAngle: Float = 315, speed: Float = 1, shading: Float = 0.35, rim: Float = 0.25, rimColor: ShaderColor = "#ffffff", shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the plastic shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the plastic shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the plastic shape in degrees |
| `colorA` | `ShaderColor` | `"#f5f5f7"` | CSS color string | Body color at the start of the gradient |
| `colorB` | `ShaderColor` | `"#d9dade"` | CSS color string | Body color at the end of the gradient |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `gradientAngle` | `Float` | `90` | 0 … 360, step 1 | Direction of the body color gradient in degrees |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for gradient color interpolation |
| `thickness` | `Float` | `0.5` | 0.05 … 1, step 0.01 | Puffiness — how far the rounded bevel reaches inward from the edge before the surface flattens |
| `roughness` | `Float` | `0.12` | 0 … 1, step 0.01 | Surface roughness — 0 = polished gloss with crisp mirror reflections, 1 = matte satin |
| `reflectivity` | `Float` | `1` | 0 … 2, step 0.01 | Strength of the environment reflections and specular highlights |
| `crumple` | `Float` | `0.25` | 0 … 1, step 0.01 | Surface crumple — irregular dents that break reflections into hard organic shapes, like blown or vacuum-formed plastic |
| `crumpleScale` | `Float` | `1` | 0.5 … 10, step 0.1 | Size of the crumple dents — higher = smaller, denser dents |
| `crumpleCoverage` | `Float` | `1` | 0 … 1, step 0.01 | How much of the surface is crumpled — 0 = pristine, 0.5 = patches of crumple, 1 = fully crumpled |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — re-rolls the crumple pattern for reflection variety |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `lightAngle` | `Float` | `315` | 0 … 360, step 1 | Direction the studio key light comes from, in degrees |
| `speed` | `Float` | `1` | 0 … 4, step 0.01 | Speed of the environment drift — the studio reflections slowly orbit the surface. 0 pauses. |
| `shading` | `Float` | `0.35` | 0 … 1, step 0.01 | Diffuse shading contrast — how strongly the body darkens away from the light |
| `rim` | `Float` | `0.25` | 0 … 1, step 0.01 | Fresnel rim light intensity on grazing surfaces |
| `rimColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the fresnel rim light |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Plastic", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
