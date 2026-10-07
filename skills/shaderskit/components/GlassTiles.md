# GlassTiles

Refraction-like distortion in a tile grid pattern

- Category: Distortions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    GlassTiles(intensity: 2, tileCount: 20, rotation: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
GlassTiles(intensity: Float = 2, tileCount: Float = 20, rotation: Float = 0, roundness: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `2` | 0 … 10, step 0.1 | The intensity of the glass tiles effect |
| `tileCount` | `Float` | `20` | 5 … 50, step 1 | Number of tiles across the longest dimension |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation angle of the tile grid in degrees |
| `roundness` | `Float` | `0` | 0 … 1, step 0.1 | Makes tiles more circular instead of square |

Dynamic form (same values): `ShaderNode(type: "GlassTiles", props: ["intensity": .number(2), "tileCount": .number(20)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
