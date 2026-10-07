# ParticleField

Explodes the child content into a breathing 3D field of particles — bright areas float toward you and dark areas recede, the whole relief can be orbited with the camera rotations, and the cursor physically throws particles that spring back home

- Category: Stylize · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    ParticleField(count: 15000, depth: 0.7, particleSize: 0.75) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this simulation applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ParticleField(count: Float = 15000, depthSource: DepthSource = .luminance, depth: Float = 0.7, particleShape: ParticleShape = .dot, particleSize: Float = 0.75, depthShading: Float = 0.6, wobble: Float = 0.35, zoom: Float = 1, rotationX: Float = 0, rotationY: Float = 0, rotationZ: Float = 0, offsetX: Float = 0, offsetY: Float = 0, cursorMode: CursorMode = .push, cursorStrength: Float = 0.8, cursorRadius: Float = 0.2, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `ParticleField.DepthSource`: .luminance, .luminanceInverted, .red, .green, .blue, .saturation, .alpha
- `ParticleField.ParticleShape`: .dot, .square, .glow
- `ParticleField.CursorMode`: .none, .push, .pull

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `count` | `Float` | `15000` | 1000 … 40000, step 500 | Number of particles — how finely the child is sampled into the field |
| `depthSource` | `DepthSource` | `"luminance"` | `luminance`, `luminanceInverted`, `red`, `green`, `blue`, `saturation`, `alpha` | Which channel of the child drives each particle's depth toward or away from the camera |
| `depth` | `Float` | `0.7` | 0 … 2, step 0.01 | Depth of the relief — how far bright and dark areas rise toward and sink away from the camera |
| `particleShape` | `ParticleShape` | `"dot"` | `dot`, `square`, `glow` | What each particle is drawn as — a crisp dot or square, or a soft glow puff |
| `particleSize` | `Float` | `0.75` | 0.3 … 3, step 0.01 | Size of each particle relative to the grid spacing |
| `depthShading` | `Float` | `0.6` | 0 … 1, step 0.01 | How much far particles dim into the distance — the main cue that sells the 3D relief |
| `wobble` | `Float` | `0.35` | 0 … 1, step 0.01 | Gentle idle drift that keeps the field breathing even on a still image |
| `zoom` | `Float` | `1` | 0.3 … 2.5, step 0.01 | Camera distance — dolly the whole field closer or further away |
| `rotationX` | `Float` | `0` | -180 … 180, step 1 | Camera orbit around the horizontal axis — tilt the relief toward or away from you |
| `rotationY` | `Float` | `0` | -180 … 180, step 1 | Camera orbit around the vertical axis — view the particle extrusion from the side |
| `rotationZ` | `Float` | `0` | -180 … 180, step 1 | Camera roll around the view axis |
| `offsetX` | `Float` | `0` | -1 … 1, step 0.01 | Shift the whole field horizontally across the frame (in screen widths) |
| `offsetY` | `Float` | `0` | -1 … 1, step 0.01 | Shift the whole field vertically across the frame (in screen heights) — tilt it flat, then sink it toward the bottom like a ground plane |
| `cursorMode` | `CursorMode` | `"push"` | `none`, `push`, `pull` | How the cursor disturbs the field — push throws particles away and toward you, pull gathers them in |
| `cursorStrength` | `Float` | `0.8` | 0 … 2, step 0.01 | Strength of the cursor force — how hard particles get thrown before springing back |
| `cursorRadius` | `Float` | `0.2` | 0.05 … 1, step 0.01 | Reach of the cursor field, in screen units |

Dynamic form (same values): `ShaderNode(type: "ParticleField", props: ["count": .number(15000), "depthSource": .string("luminance")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
