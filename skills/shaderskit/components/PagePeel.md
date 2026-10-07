# PagePeel

Curl the content up from a corner like a peeling page

- Category: Transitions · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    PagePeel(amount: 0.2, radius: 0.2, shading: 0.55) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
PagePeel(corner: Corner = .bottomRight, amount: Float = 0.2, radius: Float = 0.2, shading: Float = 0.55, highlight: Float = 0.4, highlightSoftness: Float = 0.2, shadow: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `PagePeel.Corner`: .topLeft, .topRight, .bottomLeft, .bottomRight

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `corner` | `Corner` | `"bottom-right"` | `top-left`, `top-right`, `bottom-left`, `bottom-right` | Which corner the page peels from |
| `amount` | `Float` | `0.2` | 0 … 1, step 0.01 | How far the peel has progressed across the page (0 = flat, 1 = fully peeled) |
| `radius` | `Float` | `0.2` | 0.02 … 0.4, step 0.01 | Tightness of the curl (fraction of the page diagonal) |
| `shading` | `Float` | `0.55` | 0 … 1, step 0.01 | How much the underside of the curl is shaded for depth |
| `highlight` | `Float` | `0.4` | 0 … 1, step 0.01 | Strength of the specular sheen running along the curl |
| `highlightSoftness` | `Float` | `0.2` | 0 … 1, step 0.01 | Width of the specular highlight band (low = tight gloss, high = broad satin) |
| `shadow` | `Float` | `1` | 0 … 1, step 0.01 | Strength of the contact shadow the curl casts on the page |

Dynamic form (same values): `ShaderNode(type: "PagePeel", props: ["corner": .string("bottom-right"), "amount": .number(0.2)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
