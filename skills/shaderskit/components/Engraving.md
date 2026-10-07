# Engraving

Copper-plate line engraving — the image is redrawn as flowing line work whose weight swells with darkness, lines displaced by the form like a banknote portrait: a single plate, cross-hatched shadow plates, or one continuous spiral cut

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Engraving(frequency: 90, angle: 8, relief: 0.6) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Engraving(style: Style = .crosshatch, frequency: Float = 90, angle: Float = 8, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), relief: Float = 0.6, waviness: Float = 0.35, contrast: Float = 1.15, inkColor: ShaderColor = "#1a1410", paperColor: ShaderColor = "#f4eee2", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Engraving.Style`: .line, .crosshatch, .spiral

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `style` | `Style` | `"crosshatch"` | `line`, `crosshatch`, `spiral` | The engraving cut: a single line plate, cross-hatched plates building up the shadows, or one continuous spiral |
| `frequency` | `Float` | `90` | 20 … 300, step 1 | Line density — how many engraved lines span the height of the canvas |
| `angle` | `Float` | `8` | 0 … 360, step 1, degrees | Direction of the base line work (in degrees) |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center the spiral coils outward from |
| `relief` | `Float` | `0.6` | 0 … 2, step 0.01 | How strongly the image brightness displaces the lines — the engraved 'lines climb over the form' effect |
| `waviness` | `Float` | `0.35` | 0 … 1, step 0.01 | Organic meander of the line work, like a hand-pulled burin stroke |
| `contrast` | `Float` | `1.15` | 0.25 … 3, step 0.01 | Tonal contrast applied before the lines are cut — higher pushes mid-tones toward pure line or pure paper |
| `inkColor` | `ShaderColor` | `"#1a1410"` | CSS color string | Color of the engraved ink |
| `paperColor` | `ShaderColor` | `"#f4eee2"` | CSS color string | Paper color shown between the lines |

Dynamic form (same values): `ShaderNode(type: "Engraving", props: ["style": .string("crosshatch"), "frequency": .number(90)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
