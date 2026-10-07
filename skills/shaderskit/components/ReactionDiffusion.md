# ReactionDiffusion

A living Gray-Scott reaction-diffusion pattern that fills the layer and blooms wherever you drag the cursor

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ReactionDiffusion(feed: 0.0545, kill: 0.062, diffusionRatio: 0.5) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ReactionDiffusion(preset: Preset = .coral, feed: Float = 0.0545, kill: Float = 0.062, diffusionRatio: Float = 0.5, featureSize: Float = 3, speed: Float = 6, brushSize: Float = 0.04, brushStrength: Float = 0.6, colorA: ShaderColor = "transparent", colorC: ShaderColor = "#38bdf8", colorB: ShaderColor = "#e2f5ff", contrast: Float = 0.5, threshold: Float = 0.28, colorSpace: ColorSpace = .oklch, relief: Float = 0.4, lightAngle: Float = 135, childInfluence: Float = 0.6, childContrast: Float = 0.5, childThreshold: Float = 0.5, childInvert: Bool = false, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `ReactionDiffusion.Preset`: .coral, .mitosis, .spots, .maze, .worms, .fingerprints, .holes, .solitons, .bubbles, .waves, .flowers, .custom

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `preset` | `Preset` | `"coral"` | `coral`, `mitosis`, `spots`, `maze`, `worms`, `fingerprints`, `holes`, `solitons`, `bubbles`, `waves`, `flowers`, `custom` | Named Gray-Scott regime — drives the feed & kill rates for a whole family of patterns. Choose Custom to dial feed & kill by hand |
| `feed` | `Float` | `0.0545` | 0.01 … 0.1, step 0.001 | Feed rate — how fast chemical U is replenished (used when Pattern = Custom) |
| `kill` | `Float` | `0.062` | 0.03 … 0.07, step 0.001 | Kill rate — how fast chemical V is removed (used when Pattern = Custom) |
| `diffusionRatio` | `Float` | `0.5` | 0.2 … 0.9, step 0.01 | Ratio of the two chemicals' diffusion rates — shifts the pattern character (lower = tighter, more filament-like) |
| `featureSize` | `Float` | `3` | 1 … 6, step 0.1 | Size of the pattern features — lower shows finer, smaller cells; higher magnifies them into larger cells |
| `speed` | `Float` | `6` | 1 … 16, step 1 | Simulation steps per frame — higher evolves the pattern faster |
| `brushSize` | `Float` | `0.04` | 0.01 … 0.3, step 0.01 | Radius of the cursor brush that seeds new reagent as you drag |
| `brushStrength` | `Float` | `0.6` | 0 … 1, step 0.01 | How much reagent the cursor injects while dragging |
| `colorA` | `ShaderColor` | `"transparent"` | CSS color string | Background color (empty regions between cells) |
| `colorC` | `ShaderColor` | `"#38bdf8"` | CSS color string | Accent color at the cell walls (mid pattern values) |
| `colorB` | `ShaderColor` | `"#e2f5ff"` | CSS color string | Color of the dense cell interiors (high pattern values) |
| `contrast` | `Float` | `0.5` | 0 … 1, step 0.01 | Sharpness of the cell walls — higher gives crisper, more graphic edges |
| `threshold` | `Float` | `0.28` | 0.05 … 0.6, step 0.01 | Pattern level the colors are centered on — shifts the balance of background vs. cells |
| `colorSpace` | `ColorSpace` | `"oklch"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `relief` | `Float` | `0.4` | 0 … 1, step 0.01 | Treats the pattern as a raised surface and shades it with a light — higher gives a more sculpted, three-dimensional look (0 for a flat, graphic look) |
| `lightAngle` | `Float` | `135` | 0 … 360, step 1 | Direction the surface light comes from, in degrees |
| `childInfluence` | `Float` | `0.6` | 0 … 1, step 0.01 | When a child layer is nested, how strongly its brightness biases the pattern — the preset sets the character, the child steers where it grows dense vs. sparse (0 ignores the child) |
| `childContrast` | `Float` | `0.5` | 0 … 1, step 0.01 | Contrast applied to the child's brightness before it drives the pattern — higher pushes toward a crisp two-tone split (edges), lower keeps smooth tonal shading |
| `childThreshold` | `Float` | `0.5` | 0 … 1, step 0.01 | Brightness level of the child that reads as neutral — shifts which tones grow the pattern vs. clear it |
| `childInvert` | `Bool` | `false` | — | Flip which tones of the child grow the pattern (bright vs. dark areas) |

Dynamic form (same values): `ShaderNode(type: "ReactionDiffusion", props: ["preset": .string("coral"), "feed": .number(0.0545)])`

## Notes

- Optionally wraps layers in its trailing closure.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
- A nested child does not influence the simulation (upstream "drive" mode).
