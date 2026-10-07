# FilmStock

Real analog film color from measured film-emulation LUTs — ten classic stock looks with emulsion halation and projector gate weave

- Category: Adjustments · Role: filter
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    FilmStock(strength: 1, halation: 0.4, halationRadius: 28) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
FilmStock(stock: Stock = .portrait400, strength: Float = 1, halation: Float = 0.4, halationRadius: Float = 28, weave: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `FilmStock.Stock`: .portrait400, .vivid100, .chrome64, .slide100, .velvet50, .everyday400, .pastel400, .warm200, .instant, .mono400

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `stock` | `Stock` | `"portrait400"` | `portrait400`, `vivid100`, `chrome64`, `slide100`, `velvet50`, `everyday400`, `pastel400`, `warm200`, `instant`, `mono400` | Film stock — each look is a real measured film-emulation color LUT |
| `strength` | `Float` | `1` | 0 … 1, step 0.01 | How strongly the stock's color grade is applied |
| `halation` | `Float` | `0.4` | 0 … 1, step 0.01 | Strength of the red-orange highlight glow (film emulsion backscatter) |
| `halationRadius` | `Float` | `28` | 0 … 100, step 1 | Spread of the halation glow in pixels |
| `weave` | `Float` | `0` | 0 … 1, step 0.01 | Gate weave — subtle projector-like frame jitter and rotation |

Dynamic form (same values): `ShaderNode(type: "FilmStock", props: ["stock": .string("portrait400"), "strength": .number(1)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
