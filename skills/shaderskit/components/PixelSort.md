# PixelSort

Pixels sort by brightness around the cursor and keep their sorted position, optionally decaying back over time

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    PixelSort(radius: 0.4, falloff: 1, strength: 0.1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
PixelSort(radius: Float = 0.4, falloff: Float = 1, strength: Float = 0.1, decay: Float = 0.1, axis: Axis = .vertical, direction: Direction = .descending, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `PixelSort.Axis`: .horizontal, .vertical
- `PixelSort.Direction`: .ascending, .descending

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `radius` | `Float` | `0.4` | 0.03 … 0.6, step 0.01 | Size of the cursor brush that sorts pixels |
| `falloff` | `Float` | `1` | 0 … 1, step 0.01 | Softness of the brush edge (0 = hard circle, 1 = very soft) |
| `strength` | `Float` | `0.1` | 0 … 1, step 0.01 | How fast pixels sort — runs more sorting passes per frame |
| `decay` | `Float` | `0.1` | 0 … 1, step 0.01 | How quickly sorted pixels melt back to their original position (0 = permanent) |
| `axis` | `Axis` | `"vertical"` | `horizontal`, `vertical` | Axis pixels are sorted along |
| `direction` | `Direction` | `"descending"` | `ascending`, `descending` | Sort order by brightness |

Dynamic form (same values): `ShaderNode(type: "PixelSort", props: ["radius": .number(0.4), "falloff": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
