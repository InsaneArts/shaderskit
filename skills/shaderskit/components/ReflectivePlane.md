# ReflectivePlane

Reflective floor that mirrors the content above it

- Category: Stylize · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ReflectivePlane(height: 0.7, distance: 0.5, falloff: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ReflectivePlane(height: Float = 0.7, distance: Float = 0.5, falloff: Float = 0.5, blur: Float = 3, blurDistance: Float = 0.3, edges: EdgeMode = .stretch, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `height` | `Float` | `0.7` | 0 … 1, step 0.01 | Vertical position of the reflective surface |
| `distance` | `Float` | `0.5` | 0.01 … 1, step 0.01 | How far below the floor the reflection remains visible before fully fading to transparent. |
| `falloff` | `Float` | `0.5` | 0 … 3, step 0.01 | Width of the fade zone, as a fraction of reflection distance. |
| `blur` | `Float` | `3` | 0 … 5, step 0.01 | Maximum blur applied to the reflection far from the surface. |
| `blurDistance` | `Float` | `0.3` | 0.01 … 1, step 0.01 | How far below the surface the blur takes to ramp from sharp to maximum. |
| `edges` | `EdgeMode` | `"stretch"` | `stretch`, `transparent`, `mirror`, `wrap` | How to handle reflected samples that fall outside the source content. |

Dynamic form (same values): `ShaderNode(type: "ReflectivePlane", props: ["height": .number(0.7), "distance": .number(0.5)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
