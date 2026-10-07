# MeshGradient

Flowing mesh gradient of soft drifting color swaths whose seams wrap through the palette

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.MeshGradient(colorA: "#1a0533", colorB: "#ffdf8e", count: 5)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.MeshGradient(colorA: ShaderColor = "#1a0533", colorB: ShaderColor = "#ffdf8e", stops: [ColorStop]? = nil, colorSpace: ColorSpace = .oklab, count: Float = 5, smoothness: Float = 2, variation: Float = 0.35, swirl: Float = 0.3, drift: Float = 0.5, wrapping: Float = 0, speed: Float = 1, seed: Float = 0, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#1a0533"` | CSS color string | First gradient color (two-color fallback when stops are cleared) |
| `colorB` | `ShaderColor` | `"#ffdf8e"` | CSS color string | Second gradient color (two-color fallback when stops are cleared) |
| `stops` | `[ColorStop]?` | `[{"color":"#1a0533","position":0},{"color":"#6d2fd1","position":0.26},{"color":"#e04b9e","position":0.52},{"color":"#ff8c42","position":0.76},{"color":"#ffdf8e","position":1}]` | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `count` | `Float` | `5` | 2 … 8, step 1 | Number of color points scattered across the canvas |
| `smoothness` | `Float` | `2` | 0 … 5, step 0.01 | How smoothly the color points blend into each other |
| `variation` | `Float` | `0.35` | 0 … 1, step 0.01 | Varies edge softness across the canvas — some color boundaries crisp, others diffuse |
| `swirl` | `Float` | `0.3` | -1 … 1, step 0.01 | Vortex rotation that spirals the field around the frame centre — negative values spin the other way |
| `drift` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the color points wander from their home positions |
| `wrapping` | `Float` | `0` | 0 … 1, step 0.01 | Wraps the palette back through itself where colors meet — banded seams where the field pinches, smooth elsewhere |
| `speed` | `Float` | `1` | 0 … 10, step 0.1 | Animation speed |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for the point layout and palette assignment |

Dynamic form (same values): `ShaderNode(type: "MeshGradient", props: ["colorA": .string("#1a0533"), "colorB": .string("#ffdf8e")])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
- `MeshGradient` also exists in SwiftUI or the standard library: write `ShadersKit.MeshGradient` in files that import SwiftUI.
