# Flip

Mirror content horizontally, vertically, or both

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Flip() {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Flip(flipX: Bool = false, flipY: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `flipX` | `Bool` | `false` | — | Mirror the content horizontally (left ↔ right) |
| `flipY` | `Bool` | `false` | — | Mirror the content vertically (top ↔ bottom) |

Dynamic form (same values): `ShaderNode(type: "Flip", props: ["flipX": .bool(false), "flipY": .bool(false)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
