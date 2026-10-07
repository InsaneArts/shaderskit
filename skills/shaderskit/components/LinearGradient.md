# LinearGradient

Create smooth linear color gradients

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.LinearGradient(colorA: "#1aff00", colorB: "#0000ff", angle: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.LinearGradient(colorA: ShaderColor = "#1aff00", colorB: ShaderColor = "#0000ff", stops: [ColorStop]? = nil, start: ShaderPosition = ShaderPosition(x: 0, y: 0.5), end: ShaderPosition = ShaderPosition(x: 1, y: 0.5), angle: Float = 0, edges: EdgeMode = .stretch, colorSpace: ColorSpace = .linear, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#1aff00"` | CSS color string | The starting color of the gradient |
| `colorB` | `ShaderColor` | `"#0000ff"` | CSS color string | The ending color of the gradient |
| `stops` | `[ColorStop]?` | — | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `start` | `ShaderPosition` | `(0, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The starting point of the gradient |
| `end` | `ShaderPosition` | `(1, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The ending point of the gradient |
| `angle` | `Float` | `0` | 0 … 360, step 1, degrees | Additional rotation angle of the gradient (in degrees) |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle areas beyond the gradient endpoints |
| `colorSpace` | `ColorSpace` | `"linear"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |

Dynamic form (same values): `ShaderNode(type: "LinearGradient", props: ["colorA": .string("#1aff00"), "colorB": .string("#0000ff")])`

## Notes

- `LinearGradient` also exists in SwiftUI or the standard library: write `ShadersKit.LinearGradient` in files that import SwiftUI.
