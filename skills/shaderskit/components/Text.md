# Text

Text with any Google font — multi-line with wrapping, alignment and line height — rendered crisp via a glyph texture

- Category: Textures · Role: media
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Text(fontWeight: 400, fontSize: 0.07, letterSpacing: 0)
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Text(text: String = "Hello World", fontFamily: String = "Inter", fontWeight: Float = 400, italic: Bool = false, textTransform: TextTransform = .none, fontSize: DimensionalValue = 0.07, letterSpacing: Float = 0, lineHeight: Float = 1.2, textAlign: TextAlign = .center, width: DimensionalValue = 0, color: ShaderColor = "#ffffff", origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), rotation: Float = 0, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Text.TextTransform`: .none, .uppercase, .lowercase, .capitalize
- `Text.TextAlign`: .left, .center, .right

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `text` | `String` | `"Hello World"` | — | The text to display (single line) |
| `fontFamily` | `String` | `"Inter"` | — | Google Fonts family name |
| `fontWeight` | `Float` | `400` | — | Font weight (only weights published for the family render true; others are synthesized) |
| `italic` | `Bool` | `false` | — | Italic style |
| `textTransform` | `TextTransform` | `"none"` | `none`, `uppercase`, `lowercase`, `capitalize` | Case transformation applied to the text |
| `fontSize` | `DimensionalValue` | `0.07` | 0.01 … 0.5, step 0.005 | Font size as a fraction of canvas height |
| `letterSpacing` | `Float` | `0` | -0.1 … 0.5, step 0.005 | Letter spacing in em units |
| `lineHeight` | `Float` | `1.2` | 0.8 … 2.5, step 0.05 | Line height as a multiple of font size (multi-line text) |
| `textAlign` | `TextAlign` | `"center"` | `left`, `center`, `right` | Horizontal alignment of lines within the text block |
| `width` | `DimensionalValue` | `0` | 0 … 1, step 0.005, fraction or `.px(n)` | Wrap width — text wraps to fit; 0 = auto (hug contents, single line per explicit break). Edited via the Typography panel's Auto/Fixed width toggle and the side drag handles, not a slider. |
| `color` | `ShaderColor` | `"#ffffff"` | CSS color string | Text color |
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the text relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the text |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation in degrees |

Dynamic form (same values): `ShaderNode(type: "Text", props: ["text": .string("Hello World"), "fontFamily": .string("Inter")])`

## Notes

- `Text` also exists in SwiftUI or the standard library: write `ShadersKit.Text` in files that import SwiftUI.
- Rasterized with CoreText; Google font names map to the closest installed font.
