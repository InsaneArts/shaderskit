# Blob

Organic animated blob with 3D lighting and gradients

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Blob(colorA: "#ff6b35", colorB: "#e91e63", size: 0.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Blob(origin: ShaderOrigin = .center, colorA: ShaderColor = "#ff6b35", colorB: ShaderColor = "#e91e63", stops: [ColorStop]? = nil, size: Float = 0.5, deformation: Float = 0.5, softness: Float = 0.5, highlightIntensity: Float = 0.5, highlightX: Float = 0.3, highlightY: Float = -0.3, highlightZ: Float = 0.4, highlightColor: ShaderColor = "#ffe11a", speed: Float = 0.5, seed: Float = 1, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `colorA` | `ShaderColor` | `"#ff6b35"` | CSS color string | Primary color of the blob |
| `colorB` | `ShaderColor` | `"#e91e63"` | CSS color string | Secondary color of the blob |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `size` | `Float` | `0.5` | 0 … 2, step 0.01 | Size of the blob |
| `deformation` | `Float` | `0.5` | 0 … 1, step 0.1 | How organic and blobby the shape is (0 = circle, 1 = very blobby) |
| `softness` | `Float` | `0.5` | 0 … 1, step 0.1 | Softness of the blob edges (combines edge width and transition curve) |
| `highlightIntensity` | `Float` | `0.5` | 0 … 1, step 0.1 | Intensity of specular highlight effect |
| `highlightX` | `Float` | `0.3` | -1 … 1, step 0.1 | Light direction X component |
| `highlightY` | `Float` | `-0.3` | -1 … 1, step 0.1 | Light direction Y component |
| `highlightZ` | `Float` | `0.4` | -1 … 1, step 0.1 | Light direction Z component |
| `highlightColor` | `ShaderColor` | `"#ffe11a"` | CSS color string | Color of the specular highlight |
| `speed` | `Float` | `0.5` | 0 … 2, step 0.1 | Animation speed |
| `seed` | `Float` | `1` | 0 … 100, step 1 | Adjusts the starting state, useful for variation |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | The center point of the blob |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Blob", props: ["origin": .string("center"), "colorA": .string("#ff6b35")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
