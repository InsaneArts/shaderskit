# Line

Draw a straight line between two points with color, thickness, and solid, dashed, or dotted styles

- Category: Shapes · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Line(color: "#ffffff", thickness: 0.01, dashLength: 0.05)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Line(color: ShaderColor = "#ffffff", pointA: ShaderPosition = ShaderPosition(x: 0.2, y: 0.5), pointB: ShaderPosition = ShaderPosition(x: 0.8, y: 0.5), thickness: DimensionalValue = 0.01, style: Style = .solid, dashLength: DimensionalValue = 0.05, gapLength: DimensionalValue = 0.025, capStart: CapStart = .rounded, capEnd: CapEnd = .rounded, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Line.Style`: .solid, .dashed, .dotted
- `Line.CapStart`: .square, .rounded
- `Line.CapEnd`: .square, .rounded

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | The color of the line |
| `pointA` | `ShaderPosition` | `(0.2, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | The start point of the line |
| `pointB` | `ShaderPosition` | `(0.8, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | The end point of the line |
| `thickness` | `DimensionalValue` | `0.01` | 0 … 0.25, step 0.001 | The thickness of the line. A value of one (1) matches the canvas height. |
| `style` | `Style` | `"solid"` | `solid`, `dashed`, `dotted` | The line style: solid, dashed, or dotted. Dashes and dots are spaced to land exactly on both endpoints. |
| `dashLength` | `DimensionalValue` | `0.05` | 0 … 0.5, step 0.001 | The length of each dash, including its caps |
| `gapLength` | `DimensionalValue` | `0.025` | 0 … 0.5, step 0.001 | The gap between dashes, or the spacing between dots |
| `capStart` | `CapStart` | `"rounded"` | `square`, `rounded` | Cap shape at the start of the line (point A). Rounded caps center on the endpoint; square caps end flat exactly at it. Also shapes the A-facing end of each dash and dot. |
| `capEnd` | `CapEnd` | `"rounded"` | `square`, `rounded` | Cap shape at the end of the line (point B). Rounded caps center on the endpoint; square caps end flat exactly at it. Also shapes the B-facing end of each dash and dot. |

Dynamic form (same values): `ShaderNode(type: "Line", props: ["color": .string("#ffffff"), "pointA": .position(.xy(x: .number(0.2), y: .number(0.5)))])`
