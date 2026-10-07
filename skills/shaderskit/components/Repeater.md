# Repeater

Repeat the child content in grid, radial or linear layouts with per-instance variation

- Category: Distortions · Role: structural
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Repeater(cropLeft: 0, cropRight: 0, cropTop: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this structural applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Repeater(mode: Mode = .grid, cropLeft: Float = 0, cropRight: Float = 0, cropTop: Float = 0, cropBottom: Float = 0, columns: Float = 3, rows: Float = 3, gapX: DimensionalValue = 0.05, gapY: DimensionalValue = 0.05, stagger: Float = 0, flip: Flip = .none, count: Float = 8, radius: DimensionalValue = 0.3, startAngle: Float = 0, sweep: Float = 360, faceCenter: Bool = false, direction: Float = 0, spacing: DimensionalValue = 0.2, instanceScale: Float = 1, instanceRotation: Float = 0, instanceOpacity: Float = 1, hueShift: Float = 0, phase: Float = 0, zOrder: ZOrder = .forward, jitterPosition: Float = 0, jitterRotation: Float = 0, jitterScale: Float = 0, jitterOpacity: Float = 0, seed: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `Repeater.Mode`: .grid, .radial, .linear
- `Repeater.Flip`: .none, .alternateFlipX, .alternateFlipY, .both
- `Repeater.ZOrder`: .forward, .backward

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `mode` | `Mode` | `"grid"` | `grid`, `radial`, `linear` | Layout used to place the repeated instances |
| `cropLeft` | `Float` | `0` | 0 … 0.49, step 0.005 | Crop inset from the left edge of the source element (fraction of its width) |
| `cropRight` | `Float` | `0` | 0 … 0.49, step 0.005 | Crop inset from the right edge of the source element (fraction of its width) |
| `cropTop` | `Float` | `0` | 0 … 0.49, step 0.005 | Crop inset from the top edge of the source element (fraction of its height) |
| `cropBottom` | `Float` | `0` | 0 … 0.49, step 0.005 | Crop inset from the bottom edge of the source element (fraction of its height) |
| `columns` | `Float` | `3` | 1 … 12, step 1 | Number of grid columns |
| `rows` | `Float` | `3` | 1 … 12, step 1 | Number of grid rows |
| `gapX` | `DimensionalValue` | `0.05` | 0 … 0.5, step 0.005 | Horizontal gap between grid cells |
| `gapY` | `DimensionalValue` | `0.05` | 0 … 0.5, step 0.005 | Vertical gap between grid cells |
| `stagger` | `Float` | `0` | 0 … 1, step 0.01 | Horizontal offset applied to every other row (brick layout) |
| `flip` | `Flip` | `"none"` | `none`, `alternate-flip-x`, `alternate-flip-y`, `both` | Mirror alternating columns/rows for seamless tiling patterns |
| `count` | `Float` | `8` | 1 … 64, step 1 | Number of repeated instances |
| `radius` | `DimensionalValue` | `0.3` | 0 … 1, step 0.005 | Orbit radius of the radial layout |
| `startAngle` | `Float` | `0` | 0 … 360, step 1 | Angle of the first instance on the orbit |
| `sweep` | `Float` | `360` | 0 … 360, step 1 | Angular span the instances are distributed across |
| `faceCenter` | `Bool` | `false` | — | Rotate each instance to face the orbit center |
| `direction` | `Float` | `0` | 0 … 360, step 1 | Direction of the linear layout in degrees (0 = rightward) |
| `spacing` | `DimensionalValue` | `0.2` | 0 … 1, step 0.005 | Distance between consecutive instances |
| `instanceScale` | `Float` | `1` | 0.5 … 2, step 0.005 | Progressive scale multiplier applied per instance (compounds with each copy) |
| `instanceRotation` | `Float` | `0` | -180 … 180, step 1 | Additional rotation in degrees applied per instance (accumulates with each copy) |
| `instanceOpacity` | `Float` | `1` | 0 … 1, step 0.005 | Progressive opacity falloff applied per instance (compounds with each copy) |
| `hueShift` | `Float` | `0` | 0 … 360, step 1 | Hue rotation in degrees added per instance |
| `phase` | `Float` | `0` | 0 … 1, step 0.001 | Seamless layout animation phase (0-1 wraps to the identical layout) |
| `zOrder` | `ZOrder` | `"forward"` | `forward`, `backward` | Stacking order of overlapping instances |
| `jitterPosition` | `Float` | `0` | 0 … 1, step 0.005 | Random per-instance position offset |
| `jitterRotation` | `Float` | `0` | 0 … 1, step 0.005 | Random per-instance rotation |
| `jitterScale` | `Float` | `0` | 0 … 1, step 0.005 | Random per-instance scale variation |
| `jitterOpacity` | `Float` | `0` | 0 … 1, step 0.005 | Random per-instance opacity variation |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Random seed for the jitter values |

Dynamic form (same values): `ShaderNode(type: "Repeater", props: ["mode": .string("grid"), "cropLeft": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
