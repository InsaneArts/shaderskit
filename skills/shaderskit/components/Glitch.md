# Glitch

Digital glitch that melts pixels and distorts colors

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Glitch(intensity: 0.5, speed: 1, rgbShift: 5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Glitch(intensity: Float = 0.5, speed: Float = 1, rgbShift: Float = 5, blockDensity: Float = 10, colorBarIntensity: Float = 0.2, mirrorAmount: Float = 0.3, scanlineIntensity: Float = 0.2, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `intensity` | `Float` | `0.5` | 0 … 1, step 0.01 | Overall glitch strength and frequency of glitch bursts |
| `speed` | `Float` | `1` | 0.1 … 5, step 0.1 | How fast the glitch pattern evolves |
| `rgbShift` | `Float` | `5` | 0 … 20, step 0.5 | Amount of chromatic aberration (RGB channel splitting) |
| `blockDensity` | `Float` | `10` | 2 … 50, step 1 | Base number of horizontal glitch bands |
| `colorBarIntensity` | `Float` | `0.2` | 0 … 1, step 0.01 | Intensity of vivid neon color bar overlay in glitch regions |
| `mirrorAmount` | `Float` | `0.3` | 0 … 1, step 0.01 | Chance of glitch blocks showing mirrored/flipped content |
| `scanlineIntensity` | `Float` | `0.2` | 0 … 1, step 0.01 | Visibility of CRT-style horizontal scanlines in distorted areas |

Dynamic form (same values): `ShaderNode(type: "Glitch", props: ["intensity": .number(0.5), "speed": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
