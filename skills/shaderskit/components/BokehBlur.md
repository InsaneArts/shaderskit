# BokehBlur

Photographic lens blur where bright highlights bloom into aperture-shaped discs

- Category: Blurs · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    BokehBlur(radius: 50, highlightGain: 4, highlightThreshold: 0.6) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
BokehBlur(radius: Float = 50, highlightGain: Float = 4, highlightThreshold: Float = 0.6, bladeShape: BladeShape = .blades, bladeCount: Float = 6, bladeRotation: Float = 0, chromaticFringe: Float = 0.2, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `BokehBlur.BladeShape`: .blades, .circle, .star, .heart, .flower, .cross, .ring

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `radius` | `Float` | `50` | 0 … 100, step 1 | Defocus amount — how far the lens blur spreads |
| `highlightGain` | `Float` | `4` | 0 … 10, step 0.1 | How strongly bright highlights bloom into discs |
| `highlightThreshold` | `Float` | `0.6` | 0 … 1, step 0.01 | Brightness above which a highlight forms a disc |
| `bladeShape` | `BladeShape` | `"blades"` | `blades`, `circle`, `star`, `heart`, `flower`, `cross`, `ring` | Aperture shape the highlights bloom into — bladed iris or a novelty cut-out (heart, star, …) |
| `bladeCount` | `Float` | `6` | 0 … 9, step 1 | Blade or point count for the Blades, Star and Flower shapes — 0–2 blades is a circular iris |
| `bladeRotation` | `Float` | `0` | 0 … 360, step 1, degrees | Rotation of the aperture shape (in degrees) |
| `chromaticFringe` | `Float` | `0.2` | 0 … 1, step 0.01 | Lens color fringing on the disc edges |

Dynamic form (same values): `ShaderNode(type: "BokehBlur", props: ["radius": .number(50), "highlightGain": .number(4)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
