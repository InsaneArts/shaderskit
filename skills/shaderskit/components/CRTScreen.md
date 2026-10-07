# CRTScreen

Retro CRT monitor simulation with scanlines

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    CRTScreen(pixelSize: 128, colorShift: 1, scanlineIntensity: 0.3) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
CRTScreen(pixelSize: Float = 128, colorShift: Float = 1, scanlineIntensity: Float = 0.3, scanlineFrequency: Float = 200, brightness: Float = 1, contrast: Float = 1, vignetteIntensity: Float = 1, vignetteRadius: Float = 0.5, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `pixelSize` | `Float` | `128` | 8 … 128, step 1 | Density of the RGB phosphor stripes — about half this many across the canvas width (higher = smaller, finer pixels) |
| `colorShift` | `Float` | `1` | 0 … 10, step 0.1 | Chromatic aberration amount |
| `scanlineIntensity` | `Float` | `0.3` | 0 … 1, step 0.1 | Strength of horizontal scanlines |
| `scanlineFrequency` | `Float` | `200` | 100 … 800, step 10 | Number of scanlines across screen |
| `brightness` | `Float` | `1` | 0.5 … 2, step 0.1 | Screen brightness boost |
| `contrast` | `Float` | `1` | 0.5 … 2, step 0.1 | Screen contrast enhancement |
| `vignetteIntensity` | `Float` | `1` | 0 … 1, step 0.1 | Strength of corner darkening effect (0 = off) |
| `vignetteRadius` | `Float` | `0.5` | 0 … 1, step 0.01 | How far the vignette extends inward (0 = edges only, 1 = reaches center) |

Dynamic form (same values): `ShaderNode(type: "CRTScreen", props: ["pixelSize": .number(128), "colorShift": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
