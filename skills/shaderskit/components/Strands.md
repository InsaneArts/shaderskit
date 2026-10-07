# Strands

Flowing ribbons of light with a multi-color gradient

- Category: Textures · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Strands(speed: 0.5, amplitude: 2, frequency: 0.3)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Strands(speed: Float = 0.5, amplitude: Float = 2, frequency: Float = 0.3, lineCount: Float = 8, lineWidth: Float = 0.05, softness: Float = 0.05, spread: Float = 0.2, pinEdges: Bool = false, stops: [ColorStop]? = nil, colorSpace: ColorSpace = .oklab, colorScale: Float = 1, colorVariance: Float = 1, colorSpeed: Float = 1, start: ShaderPosition = ShaderPosition(x: 0, y: 0.5), end: ShaderPosition = ShaderPosition(x: 1, y: 0.5), layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `speed` | `Float` | `0.5` | 0 … 2, step 0.1 | Overall animation speed |
| `amplitude` | `Float` | `2` | 0 … 5, step 0.1 | How far the strands wave away from their resting line |
| `frequency` | `Float` | `0.3` | 0 … 5, step 0.1 | How many waves run along each strand |
| `lineCount` | `Float` | `8` | 1 … 16, step 1 | Number of strands |
| `lineWidth` | `Float` | `0.05` | 0 … 1, step 0.05 | Thickness of each strand’s solid core |
| `softness` | `Float` | `0.05` | 0 … 1, step 0.05 | Softness of each strand’s edge (0 is crisp, higher is feathered) |
| `spread` | `Float` | `0.2` | 0 … 1, step 0.05 | How far the strands fan out across the field |
| `pinEdges` | `Bool` | `false` | — | Pin the strands so they converge to the start and end points |
| `stops` | `[ColorStop]?` | `[{"color":"#00e5ff","position":0},{"color":"#5b8cff","position":0.34},{"color":"#b06bff","position":0.67},{"color":"#ff5fa2","position":1}]` | `[ColorStop]`, overrides the two-colour props when set | Multi-stop gradient colors (overrides Color A / Color B when set) |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space used to blend the gradient |
| `colorScale` | `Float` | `1` | 1 … 6, step 1 | How many times the gradient repeats along the strands |
| `colorVariance` | `Float` | `1` | 0 … 1, step 0.05 | At 0 every strand shares the same color; at 1 the strands spread across the full gradient |
| `colorSpeed` | `Float` | `1` | 0 … 2, step 0.05 | Speed at which the colors flow along the strands (loops) |
| `start` | `ShaderPosition` | `(0, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Starting point of the strands |
| `end` | `ShaderPosition` | `(1, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Ending point of the strands |

Dynamic form (same values): `ShaderNode(type: "Strands", props: ["speed": .number(0.5), "amplitude": .number(2)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
