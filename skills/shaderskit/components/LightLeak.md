# LightLeak

Photorealistic film light leak — warm overexposed light bleeding in from a draggable anchor point, with streak bands, chromatic fringing, and slow breathing that evolves over time

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    LightLeak(spread: 0.55, intensity: 0.15, streaks: 0.6) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
LightLeak(position: ShaderPosition = ShaderPosition(x: 0.95, y: 0.4), spread: Float = 0.55, intensity: Float = 0.15, streaks: Float = 0.6, colorHot: ShaderColor = "#fff3c4", colorMid: ShaderColor = "#ff7a2f", colorFringe: ShaderColor = "#a63d8f", flicker: Float = 0.35, speed: Float = 1, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `position` | `ShaderPosition` | `(0.95, 0.4)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Anchor point of the leak — the light beams from here toward the canvas centre |
| `spread` | `Float` | `0.55` | 0.1 … 1.5, step 0.01 | How far the light bleeds into the frame |
| `intensity` | `Float` | `0.15` | 0 … 1, step 0.01 | Exposure strength of the leak |
| `streaks` | `Float` | `0.6` | 0 … 1, step 0.01 | Strength of the parallel streak bands further into the frame |
| `colorHot` | `ShaderColor` | `"#fff3c4"` | CSS color string | Core color where the leak is fully overexposed |
| `colorMid` | `ShaderColor` | `"#ff7a2f"` | CSS color string | Main body color of the leak |
| `colorFringe` | `ShaderColor` | `"#a63d8f"` | CSS color string | Outer fringe color where the light fades out |
| `flicker` | `Float` | `0.35` | 0 … 1, step 0.01 | Breathing of the leak intensity |
| `speed` | `Float` | `1` | 0 … 4, step 0.1 | Speed of the breathing, drift and evolution. 0 freezes the leak. |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed — re-rolls the drift and breathing pattern |

Dynamic form (same values): `ShaderNode(type: "LightLeak", props: ["position": .position(.xy(x: .number(0.95), y: .number(0.4))), "spread": .number(0.55)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
