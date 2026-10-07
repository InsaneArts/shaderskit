# SolidColor

Fill the canvas with a single solid color

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    SolidColor(color: "#5b18ca")
}
```

Initializer (all parameters optional, defaults shown):

```swift
SolidColor(color: ShaderColor = "#5b18ca", layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `color` | `ShaderColor` | `"#5b18ca"` | CSS color string | The solid color to display |

Dynamic form (same values): `ShaderNode(type: "SolidColor", props: ["color": .string("#5b18ca")])`
