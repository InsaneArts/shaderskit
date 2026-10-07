# Spherize

Map content onto a 3D sphere surface with depth distortion

- Category: Distortions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Spherize(radius: 1, depth: 1, lightIntensity: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Spherize(radius: Float = 1, depth: Float = 1, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), lightPosition: ShaderPosition = ShaderPosition(x: 0.3, y: 0.3), lightIntensity: Float = 0.5, lightSoftness: Float = 0.5, lightColor: ShaderColor = "#ffffff", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `radius` | `Float` | `1` | 0.1 … 3, step 0.1 | Radius of the sphere (1 = half viewport height) |
| `depth` | `Float` | `1` | 0 … 3, step 0.1 | How much the sphere bulges toward viewer (0 = flat, higher = more bulge) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The center point of the sphere |
| `lightPosition` | `ShaderPosition` | `(0.3, 0.3)` | `ShaderPosition` (0…1, top-left origin) | Position of the specular light source |
| `lightIntensity` | `Float` | `0.5` | 0 … 1, step 0.1 | Intensity of the rim light (0 = off) |
| `lightSoftness` | `Float` | `0.5` | 0 … 1, step 0.1 | Softness of the rim light falloff (0 = hard edge, 1 = soft glow) |
| `lightColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Color of the specular highlight |

Dynamic form (same values): `ShaderNode(type: "Spherize", props: ["radius": .number(1), "depth": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
