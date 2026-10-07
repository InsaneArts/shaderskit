# CornerPin

Pin each corner of the content to an arbitrary position for a free perspective warp

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    CornerPin(amount: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
CornerPin(topLeft: ShaderPosition = ShaderPosition(x: 0, y: 0), topRight: ShaderPosition = ShaderPosition(x: 1, y: 0), bottomLeft: ShaderPosition = ShaderPosition(x: 0, y: 1), bottomRight: ShaderPosition = ShaderPosition(x: 1, y: 1), amount: Float = 1, edges: EdgeMode = .transparent, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `topLeft` | `ShaderPosition` | `(0, 0)` | `ShaderPosition` (0…1, top-left origin) | Position of the top-left corner |
| `topRight` | `ShaderPosition` | `(1, 0)` | `ShaderPosition` (0…1, top-left origin) | Position of the top-right corner |
| `bottomLeft` | `ShaderPosition` | `(0, 1)` | `ShaderPosition` (0…1, top-left origin) | Position of the bottom-left corner |
| `bottomRight` | `ShaderPosition` | `(1, 1)` | `ShaderPosition` (0…1, top-left origin) | Position of the bottom-right corner |
| `amount` | `Float` | `1` | 0 … 1, step 0.01 | Blends the warp in and out — 0 returns the content to its original rectangle, 1 fully pins the corners |
| `edges` | `EdgeMode` | `"transparent"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle areas outside the pinned quad |

Dynamic form (same values): `ShaderNode(type: "CornerPin", props: ["topLeft": .position(.xy(x: .number(0), y: .number(0))), "topRight": .position(.xy(x: .number(1), y: .number(0)))])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
