# DisplacementMap

Distorts child content using another layer's pixels as a displacement map

- Category: Distortions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    DisplacementMap(amount: 0.3, angle: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
DisplacementMap(source: String = "", amount: Float = 0.3, channelMode: ChannelMode = .twoAxis, angle: Float = 0, edges: EdgeMode = .mirror, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `DisplacementMap.ChannelMode`: .twoAxis, .directional

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `source` | `String` | `""` | — | The layer whose pixels drive the displacement — its red/green (or luminance) push the content around |
| `amount` | `Float` | `0.3` | 0 … 1, step 0.01 | Overall displacement strength |
| `channelMode` | `ChannelMode` | `"twoAxis"` | `twoAxis`, `directional` | How the source drives the push — red→X / green→Y, or luminance along a fixed angle |
| `angle` | `Float` | `0` | 0 … 360, step 1 | Push direction in degrees (used by the Luminance channel mode) |
| `edges` | `EdgeMode` | `"mirror"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle edges when distortion pushes content out of bounds |

Dynamic form (same values): `ShaderNode(type: "DisplacementMap", props: ["source": .string(""), "amount": .number(0.3)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
