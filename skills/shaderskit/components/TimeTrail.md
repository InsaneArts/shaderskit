# TimeTrail

An Echo-style temporal trail — whatever moves sheds a smooth, decaying long-exposure ghost trail (frame-difference Motion mode works on opaque images and video; Alpha mode trails a shape's coverage), with optional zoom-feedback tunnels and rainbow light-painting

- Category: Stylize · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    TimeTrail(motionThreshold: 0.06, trailLength: 0.6, diffusion: 1) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
TimeTrail(trailSource: TrailSource = .motion, motionThreshold: Float = 0.06, trailLength: Float = 0.6, diffusion: Float = 1, trailOpacity: Float = 1, trailBlend: TrailBlend = .normal, driftX: Float = 0, driftY: Float = 0, zoom: Float = 1, tintMode: TintMode = .none, tint: ShaderColor = "#33aaff", speed: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `TimeTrail.TrailSource`: .motion, .alpha
- `TimeTrail.TrailBlend`: .normal, .add, .screen, .multiply, .overlay, .softLight, .hardLight, .darken, .lighten, .colorDodge, .colorBurn, .linearBurn, .difference, .exclusion, .hue, .saturation, .color, .luminosity
- `TimeTrail.TintMode`: .none, .color, .rainbow

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `trailSource` | `TrailSource` | `"motion"` | `motion`, `alpha` | What sheds the trail — Motion trails whatever changes frame-to-frame (works on opaque images and video), Alpha trails the child's transparency coverage (best for a clean shape over empty canvas) |
| `motionThreshold` | `Float` | `0.06` | 0.01 … 0.5, step 0.01 | How much a pixel must change between frames to shed a trail (Motion source only) — lower catches subtle movement, higher only fast motion |
| `trailLength` | `Float` | `0.6` | 0.05 … 4, step 0.01 | How long the trail lingers, in seconds — the time constant of the fade (the star control) |
| `diffusion` | `Float` | `1` | 0 … 1, step 0.01 | How much the trail smears and softens as it fades — 0 keeps crisp ghost frames, higher melts them together |
| `trailOpacity` | `Float` | `1` | 0 … 1, step 0.01 | Overall strength of the trail behind the live frame |
| `trailBlend` | `TrailBlend` | `"normal"` | `normal`, `add`, `screen`, `multiply`, `overlay`, `softLight`, `hardLight`, `darken`, `lighten`, `colorDodge`, `colorBurn`, `linearBurn`, `difference`, `exclusion`, `hue`, `saturation`, `color`, `luminosity` | How the trail combines with the frame — Add / Screen build glowing light-painting trails, Multiply lays down dark ink ghosts, plus the full standard blend set |
| `driftX` | `Float` | `0` | -1 … 1, step 0.01 | Sideways drift of the trail per second — smears the trail in a direction |
| `driftY` | `Float` | `0` | -1 … 1, step 0.01 | Vertical drift of the trail per second |
| `zoom` | `Float` | `1` | 0.9 … 1.1, step 0.001 | Per-frame zoom of the trail around the centre — above 1 pulls the trail into an outward tunnel, below 1 sucks it inward |
| `tintMode` | `TintMode` | `"none"` | `none`, `color`, `rainbow` | color the trail — Color tints it a single hue, Rainbow cycles hue as the trail ages |
| `tint` | `ShaderColor` | `"#33aaff"` | CSS color string | Trail tint color (used in Color mode) |
| `speed` | `Float` | `1` | 0 … 4, step 0.1 | Simulation speed. 0 freezes the trail in place. |

Dynamic form (same values): `ShaderNode(type: "TimeTrail", props: ["trailSource": .string("motion"), "motionThreshold": .number(0.06)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Rainbow tint runs untinted.
