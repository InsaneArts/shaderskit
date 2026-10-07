# VHS

Analog VHS tape with intermittent tape damage, chroma bleed, and per-scanline noise

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    VHS(wobble: 1, scanlineNoise: 0.6, smear: 0.2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
VHS(wobble: Float = 1, scanlineNoise: Float = 0.6, smear: Float = 0.2, speed: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `wobble` | `Float` | `1` | 0 … 5, step 0.01 | Overall amount of tape damage — waves, creases, and head-switching noise. Bursts on and off organically over time. |
| `scanlineNoise` | `Float` | `0.6` | 0 … 1, step 0.01 | Per-scanline fine chroma/luma jitter. Adds the classic horizontal-streak detail. |
| `smear` | `Float` | `0.2` | -2 … 2, step 0.01 | Horizontal chroma smear (color bleed) amount. Positive trails color to the right (classic VHS), negative trails it to the left. |
| `speed` | `Float` | `1` | 0.1 … 3, step 0.1 | Animation speed of the tape effects. |

Dynamic form (same values): `ShaderNode(type: "VHS", props: ["wobble": .number(1), "scanlineNoise": .number(0.6)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
