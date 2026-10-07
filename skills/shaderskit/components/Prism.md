# Prism

A beam of light that fans out and splits into a slowly-rotating rainbow past a controllable point. Transparent background — composite over a dark layer.

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Prism(beamWidth: 0.04, intensity: 1.6, beamColor: "#ffffff")
}
```

Initializer (all parameters optional, defaults shown):

```swift
Prism(position: ShaderPosition = ShaderPosition(x: 0.18, y: 0.18), beamWidth: Float = 0.04, intensity: Float = 1.6, beamColor: ShaderColor = "#ffffff", startFalloff: Float = 0.15, endFalloff: Float = 0.6, splitPosition: ShaderPosition = ShaderPosition(x: 0.5, y: 0.42), spread: Float = 0.7, softness: Float = 0.12, saturation: Float = 0.95, speed: Float = 0.1, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `position` | `ShaderPosition` | `(0.18, 0.18)` | `ShaderPosition` (0…1, top-left origin) | Where the beam originates |
| `beamWidth` | `Float` | `0.04` | 0.002 … 0.3, step 0.002 | Thickness of the white beam |
| `intensity` | `Float` | `1.6` | 0 … 4, step 0.01 | Brightness (above 1 blows the core to white) |
| `beamColor` | `ShaderColor` | `"#ffffff"` | CSS color string | color of the beam before it splits |
| `startFalloff` | `Float` | `0.15` | 0 … 1, step 0.01 | How softly the beam fades in at its source |
| `endFalloff` | `Float` | `0.6` | 0.02 … 2, step 0.01 | How quickly the rainbow fades out with distance |
| `splitPosition` | `ShaderPosition` | `(0.5, 0.42)` | `ShaderPosition` (0…1, top-left origin) | Where the beam starts to fan out and split (projected onto the beam axis) |
| `spread` | `Float` | `0.7` | 0 … 3, step 0.01 | How widely the rainbow diffuses as it travels past the split point |
| `softness` | `Float` | `0.12` | 0.001 … 1, step 0.005 | How quickly the white beam transitions into the rainbow |
| `saturation` | `Float` | `0.95` | 0 … 1, step 0.01 | Rainbow saturation — 0 = white, 1 = full color |
| `speed` | `Float` | `0.1` | -1 … 1, step 0.01 | Speed the hue slowly rotates through the rainbow (0 = static) |

Dynamic form (same values): `ShaderNode(type: "Prism", props: ["position": .position(.xy(x: .number(0.18), y: .number(0.18))), "beamWidth": .number(0.04)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
