# ChromaFlow

Interactive liquid flow effect that follows your cursor

- Category: Interactive · Role: simulation
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ChromaFlow(baseColor: "#0066ff", upColor: "#00ff00", downColor: "#ff0000")
}
```

Initializer (all parameters optional, defaults shown):

```swift
ChromaFlow(baseColor: ShaderColor = "#0066ff", upColor: ShaderColor = "#00ff00", downColor: ShaderColor = "#ff0000", leftColor: ShaderColor = "#0000ff", rightColor: ShaderColor = "#ffff00", intensity: Float = 1, radius: Float = 3, momentum: Float = 30, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `baseColor` | `ShaderColor` | `"#0066ff"` | CSS color string | Base liquid color |
| `upColor` | `ShaderColor` | `"#00ff00"` | CSS color string | Color for upward movement |
| `downColor` | `ShaderColor` | `"#ff0000"` | CSS color string | Color for downward movement |
| `leftColor` | `ShaderColor` | `"#0000ff"` | CSS color string | Color for leftward movement |
| `rightColor` | `ShaderColor` | `"#ffff00"` | CSS color string | Color for rightward movement |
| `intensity` | `Float` | `1` | 0.5 … 1.5, step 0.1 | Strength of the liquid effect |
| `radius` | `Float` | `3` | 0 … 5, step 0.1 | Radius of the liquid effect |
| `momentum` | `Float` | `30` | 10 … 60, step 1 | How much momentum colors retain in their flow direction |

Dynamic form (same values): `ShaderNode(type: "ChromaFlow", props: ["baseColor": .string("#0066ff"), "upColor": .string("#00ff00")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
