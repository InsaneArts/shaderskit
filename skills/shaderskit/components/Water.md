# Water

Translucent water — a refractive, light-absorbing body that deepens to its color with thickness, wrapped in a wind-driven wave surface that reflects a procedural sky, with Fresnel-bright grazing edges and foam breaking on the crests and shoreline

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Water(scale: 1, rotation: 0, waterColor: "#00bfeb")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Water(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, waterColor: ShaderColor = "#00bfeb", clarity: Float = 0.4, depth: Float = 5, shallows: Float = 0.5, caustics: Float = 0.15, causticScale: Float = 6, choppiness: Float = 0.8, waveScale: Float = 3.5, swirl: Float = 0.6, speed: Float = 0.5, reflection: Float = 2, envRotation: Float = 0, sharpness: Float = 0.1, lightAngle: Float = 30, foam: Float = 0.3, edgeSoftness: Float = 0.05, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the water shape |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the water shape (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the water shape in degrees |
| `waterColor` | `ShaderColor` | `"#00bfeb"` | CSS color string | The color the water saturates toward with depth |
| `clarity` | `Float` | `0.4` | 0 … 1, step 0.01 | How much of the reflected sky transmits through the body |
| `depth` | `Float` | `5` | 0 … 8, step 0.01 | How quickly the water darkens and saturates toward its color with thickness |
| `shallows` | `Float` | `0.5` | 0 … 1, step 0.01 | Brightness of the thin shallow water at the edges — high fades the rim to light translucent water, low keeps the edges close to the deep water color |
| `caustics` | `Float` | `0.15` | 0 … 2, step 0.01 | Intensity of the light caustics bubbling up through the body — bright veins of focused light churning inside the water |
| `causticScale` | `Float` | `6` | 1 … 20, step 0.1 | Size of the caustic veins — higher = finer, busier light patterns inside the body |
| `choppiness` | `Float` | `0.8` | 0 … 1.5, step 0.01 | Height of the wind-driven waves — the depth of the folds that bend the reflection |
| `waveScale` | `Float` | `3.5` | 0.5 … 8, step 0.01 | Scale of the wave fronts — higher = smaller, busier ripples |
| `swirl` | `Float` | `0.6` | 0 … 1.5, step 0.01 | Swirl of the flow — domain-warps the wave fronts into curling eddies |
| `speed` | `Float` | `0.5` | 0 … 4, step 0.01 | Speed of the rolling waves. 0 pauses the surface. |
| `reflection` | `Float` | `2` | 0 … 2, step 0.01 | Strength of the reflected sky across the surface |
| `envRotation` | `Float` | `0` | 0 … 360, step 1 | Rotates the reflected sky — spins where the bright sky and sun fall |
| `sharpness` | `Float` | `0.1` | 0 … 1, step 0.01 | Tightness of the sun glint and reflected sun |
| `lightAngle` | `Float` | `30` | 0 … 360, step 1 | Direction of the sun, in degrees — drives the glint and where the sun reflects |
| `foam` | `Float` | `0.3` | 0 … 1, step 0.01 | White foam breaking on the wave crests and along the shoreline edge |
| `edgeSoftness` | `Float` | `0.05` | 0 … 1, step 0.01 | Softness of the shape boundary edge |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Water", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
