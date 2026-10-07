# Neon

Photorealistic neon tube / 3D pipe effect driven by a custom shape

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Neon(scale: 1, rotation: 0, color: "#00ddff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Neon(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, color: ShaderColor = "#00ddff", secondaryColor: ShaderColor = "#ff00aa", secondaryBlend: Float = 0.5, glowColor: ShaderColor = "#00ddff", tubeThickness: Float = 0.2, intensity: Float = 1.5, hotCoreIntensity: Float = 0.6, glowIntensity: Float = 0.6, glowRadius: Float = 0.25, lightAngle: Float = 300, specularIntensity: Float = 0.5, specularSize: Float = 0.5, cornerSmoothing: Float = 0.15, flickerSpeed: Float = 0, flickerAmount: Float = 0.2, flowSpeed: Float = 0, flowAmount: Float = 0.3, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the neon shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the neon shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the neon shape in degrees |
| `color` | `ShaderColor` | `"#00ddff"` | CSS color string | Primary neon tube color |
| `secondaryColor` | `ShaderColor` | `"#ff00aa"` | CSS color string | Shadow-side color for a two-tone / dual-lit pipe look |
| `secondaryBlend` | `Float` | `0.5` | 0 … 1, step 0.01 | Blend between mono (0) and two-tone (1) tube coloring |
| `glowColor` | `ShaderColor` | `"#00ddff"` | CSS color string | Color of the outer glow / bloom |
| `tubeThickness` | `Float` | `0.2` | 0 … 1, step 0.01 | How far inward from the boundary the tube extends. Low = thin neon outline, high = thick 3D pipe |
| `intensity` | `Float` | `1.5` | 0.5 … 4, step 0.01 | Overall brightness multiplier |
| `hotCoreIntensity` | `Float` | `0.6` | 0 … 1, step 0.01 | Bright white-hot center line — the gas discharge glow inside the tube |
| `glowIntensity` | `Float` | `0.6` | 0 … 2, step 0.01 | Outer glow / bloom strength |
| `glowRadius` | `Float` | `0.25` | 0.01 … 1, step 0.01 | How far the glow extends beyond the tube |
| `lightAngle` | `Float` | `300` | 0 … 360, step 1 | Directional light angle in degrees — controls 3D shading on the tube |
| `specularIntensity` | `Float` | `0.5` | 0 … 2, step 0.01 | Specular highlight brightness on the tube surface |
| `specularSize` | `Float` | `0.5` | 0 … 1, step 0.01 | Specular highlight size — 0 = tight pinpoint, 1 = broad sheen |
| `cornerSmoothing` | `Float` | `0.15` | 0 … 1, step 0.01 | Rounds sharp corners to mimic how real glass tubes curve at bends |
| `flickerSpeed` | `Float` | `0` | 0 … 5, step 0.1 | Flicker animation speed — 0 = off, higher = faster sporadic on/off |
| `flickerAmount` | `Float` | `0.2` | 0 … 1, step 0.01 | How often the neon flickers off — 0 = always on, 1 = frequent outages |
| `flowSpeed` | `Float` | `0` | 0 … 5, step 0.1 | Flow animation speed — 0 = off, light rotates through the tube |
| `flowAmount` | `Float` | `0.3` | 0 … 1, step 0.01 | Strength of the flowing brightness variation — 0 = uniform, 1 = dramatic |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file — when non-empty, activates SVG mode and triggers a shader recompile |
| `shapeType` | `String` | `""` | — | Active SDF shape type — triggers recompile when shape is switched. When empty, derived from shape JSON at mount time. |

Dynamic form (same values): `ShaderNode(type: "Neon", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`
