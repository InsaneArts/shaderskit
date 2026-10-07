# PixelThrow

Throws pixels along the cursor's path like a fluid — brighter (or redder/greener/bluer) pixels are flung farther, then settle back with friction

- Category: Interactive · Role: simulation
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    PixelThrow(strength: 0.25, keyInfluence: 0.8, radius: 0.2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
PixelThrow(throwKey: ThrowKey = .luminance, strength: Float = 0.25, keyInfluence: Float = 0.8, radius: Float = 0.2, friction: Float = 0.3, momentum: Float = 0.5, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `PixelThrow.ThrowKey`: .luminance, .darkness, .red, .green, .blue

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `throwKey` | `ThrowKey` | `"luminance"` | `luminance`, `darkness`, `red`, `green`, `blue` | Which pixel value decides how far a pixel is thrown |
| `strength` | `Float` | `0.25` | 0 … 1, step 0.01 | Maximum distance pixels can be thrown |
| `keyInfluence` | `Float` | `0.8` | 0 … 1, step 0.01 | How much the chosen value modulates throw distance (0 = all pixels thrown equally, 1 = only high-value pixels move) |
| `radius` | `Float` | `0.2` | 0.02 … 0.6, step 0.01 | Size of the cursor's throw brush |
| `friction` | `Float` | `0.3` | 0 … 1, step 0.01 | How quickly thrown pixels settle back to their origin (0 = float almost forever, 1 = snap back fast) |
| `momentum` | `Float` | `0.5` | 0 … 1, step 0.01 | How much the thrown flow keeps drifting and swirling after the cursor passes (fluidity) |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle pixels thrown beyond the canvas edges |

Dynamic form (same values): `ShaderNode(type: "PixelThrow", props: ["throwKey": .string("luminance"), "strength": .number(0.25)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
