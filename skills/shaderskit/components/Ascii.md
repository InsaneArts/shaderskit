# Ascii

Convert imagery to ASCII character art

- Category: Stylize · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Ascii(cellSize: 30, spacing: 1, gamma: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Ascii(characters: String = "@%#*+=-:.", cellSize: Float = 30, fontFamily: FontFamily = .jetBrainsMono, spacing: Float = 1, gamma: Float = 1, alphaThreshold: Float = 0, preserveAlpha: Bool = true, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Ascii.FontFamily`: .azeretMono, .courierPrime, .cutiveMono, .firaCode, .geistMono, .ibmPlexMono, .jetBrainsMono, .majorMonoDisplay, .martianMono, .novaMono, .pressStart2P, .robotoMono, .shareTechMono, .silkscreen, .sourceCodePro, .spaceMono, .syneMono, .vt323, .xanhMono

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `characters` | `String` | `"@%#*+=-:."` | — | Characters ordered from dense to sparse. First character is used for bright areas, last for dark areas. |
| `cellSize` | `Float` | `30` | 8 … 100, step 1 | Size of each ASCII character cell (normalized to 1080p reference, scales proportionally at other resolutions) |
| `fontFamily` | `FontFamily` | `"JetBrains Mono"` | `Azeret Mono`, `Courier Prime`, `Cutive Mono`, `Fira Code`, `Geist Mono`, `IBM Plex Mono`, `JetBrains Mono`, `Major Mono Display`, `Martian Mono`, `Nova Mono`, `Press Start 2P`, `Roboto Mono`, `Share Tech Mono`, `Silkscreen`, `Source Code Pro`, `Space Mono`, `Syne Mono`, `VT323`, `Xanh Mono` | Font family for characters |
| `spacing` | `Float` | `1` | 0 … 1, step 0.01 | Character size within each cell (1.0 = optimal size, 0.0 = smallest) |
| `gamma` | `Float` | `1` | 0.25 … 3, step 0.01 | Brightness curve adjustment. <1 brightens darks (more light characters), >1 darkens midtones (more dark characters). Use to better fit characters to image brightness range. |
| `alphaThreshold` | `Float` | `0` | 0 … 1, step 0.01 | Pixels with alpha below this threshold become fully transparent. |
| `preserveAlpha` | `Bool` | `true` | — | When enabled, output alpha matches input alpha. When disabled, pixels above the alpha threshold become fully opaque. |

Dynamic form (same values): `ShaderNode(type: "Ascii", props: ["characters": .string("@%#*+=-:."), "cellSize": .number(30)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
