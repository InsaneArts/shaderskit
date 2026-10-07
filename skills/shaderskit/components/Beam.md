# Beam

A beam of light from one point to another.

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Beam(startThickness: 0.2, endThickness: 0.2, startSoftness: 0.5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Beam(startPosition: ShaderPosition = ShaderPosition(x: 0.2, y: 0.5), endPosition: ShaderPosition = ShaderPosition(x: 0.8, y: 0.5), startThickness: Float = 0.2, endThickness: Float = 0.2, startSoftness: Float = 0.5, endSoftness: Float = 0.5, insideColor: ShaderColor = "#FF0000", outsideColor: ShaderColor = "#0000FF", colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `startPosition` | `ShaderPosition` | `(0.2, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Starting point of the beam |
| `endPosition` | `ShaderPosition` | `(0.8, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Ending point of the beam |
| `startThickness` | `Float` | `0.2` | 0 … 2, step 0.1 | Thickness at the start of the beam |
| `endThickness` | `Float` | `0.2` | 0 … 2, step 0.1 | Thickness at the end of the beam |
| `startSoftness` | `Float` | `0.5` | 0 … 50, step 0.1 | Edge softness at the start of the beam |
| `endSoftness` | `Float` | `0.5` | 0 … 20, step 0.1 | Edge softness at the end of the beam |
| `insideColor` | `ShaderColor` | `"#FF0000"` | CSS color string | Color at the center of the beam |
| `outsideColor` | `ShaderColor` | `"#0000FF"` | CSS color string | Color at the edges of the beam |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "Beam", props: ["startPosition": .position(.xy(x: .number(0.2), y: .number(0.5))), "endPosition": .position(.xy(x: .number(0.8), y: .number(0.5)))])`
