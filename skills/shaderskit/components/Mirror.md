# Mirror

Mirror content across a line defined by center point and angle

- Category: Distortions · Role: warp
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Mirror(angle: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this warp applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Mirror(center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), angle: Float = 0, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | The point the mirror line passes through |
| `angle` | `Float` | `0` | 0 … 360, step 1 | The angle of the mirror line in degrees |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "Mirror", props: ["center": .position(.xy(x: .number(0.5), y: .number(0.5))), "angle": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- `Mirror` also exists in SwiftUI or the standard library: write `ShadersKit.Mirror` in files that import SwiftUI.
