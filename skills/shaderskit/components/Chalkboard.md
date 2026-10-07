# Chalkboard

Renders content as a chalk drawing on a blackboard, with edge strokes and cross-hatch shading

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Chalkboard(boardColor: "#000000", chalkColor: "#eceadb", edgeSensitivity: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Chalkboard(boardColor: ShaderColor = "#000000", chalkColor: ShaderColor = "#eceadb", edgeSensitivity: Float = 0.5, edgeThickness: Float = 1.5, shading: Float = 0.05, hatchScale: Float = 16, grain: Float = 0.45, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `boardColor` | `ShaderColor` | `"#000000"` | CSS color string | Background board color |
| `chalkColor` | `ShaderColor` | `"#eceadb"` | CSS color string | Chalk stroke color |
| `edgeSensitivity` | `Float` | `0.5` | 0 … 1, step 0.01 | How readily edges are detected and drawn as chalk strokes |
| `edgeThickness` | `Float` | `1.5` | 0.5 … 4, step 0.1 | Thickness of the chalk outline strokes |
| `shading` | `Float` | `0.05` | 0 … 1, step 0.01 | Amount of cross-hatch shading filling darker regions |
| `hatchScale` | `Float` | `16` | 3 … 24, step 0.5 | Spacing of the cross-hatch lines in pixels |
| `grain` | `Float` | `0.45` | 0 … 1, step 0.01 | Chalk dustiness / grain that breaks up the strokes |

Dynamic form (same values): `ShaderNode(type: "Chalkboard", props: ["boardColor": .string("#000000"), "chalkColor": .string("#eceadb")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
