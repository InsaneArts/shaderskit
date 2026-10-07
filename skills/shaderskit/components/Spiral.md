# Spiral

Rotating spiral pattern with animated movement

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Spiral(colorA: "#000000", colorB: "#ffffff", strokeWidth: 0.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Spiral(colorA: ShaderColor = "#000000", colorB: ShaderColor = "#ffffff", strokeWidth: Float = 0.5, strokeFalloff: Float = 0, softness: Float = 0, speed: Float = 1, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#000000"` | CSS color string | Background color |
| `colorB` | `ShaderColor` | `"#ffffff"` | CSS color string | Spiral stroke color |
| `strokeWidth` | `Float` | `0.5` | 0 … 2, step 0.1 | Thickness of spiral stroke |
| `strokeFalloff` | `Float` | `0` | 0 … 1, step 0.1 | Stroke losing width further from center |
| `softness` | `Float` | `0` | 0 … 1, step 0.1 | Color transition sharpness (0 = hard edge, 1 = smooth fade) |
| `speed` | `Float` | `1` | -3 … 3, step 0.1 | Animation speed (negative values reverse direction) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the spiral |
| `scale` | `Float` | `1` | 0.1 … 5, step 0.1 | Scale factor for spiral bands (higher = more bands, lower = fewer bands) |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Spiral", props: ["colorA": .string("#000000"), "colorB": .string("#ffffff")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
