# KeyFrames

Motion-tracking overlay — trackers hunt and follow features in the content, dropping keyframe diamonds behind them along their motion paths, like a compositor mid-track

- Category: Stylize · Role: overlay
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    KeyFrames(trackers: 12, threshold: 0.15, variance: 0.8) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this overlay applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
KeyFrames(trackers: Float = 12, detect: Detect = .bright, threshold: Float = 0.15, variance: Float = 0.8, agility: Float = 0.5, lifespan: Float = 6, trail: Float = 1, markerSize: Float = 28, lineWidth: Float = 1.5, markerColor: ShaderColor = "#54d66b", keyframeColor: ShaderColor = "#ffcf33", pathColor: ShaderColor = "#ffffffb8", layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `KeyFrames.Detect`: .bright, .dark, .alpha, .red, .green, .blue

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `trackers` | `Float` | `12` | 1 … 64, step 1 | Number of simultaneous trackers. |
| `detect` | `Detect` | `"bright"` | `bright`, `dark`, `alpha`, `red`, `green`, `blue` | What the trackers hunt for. |
| `threshold` | `Float` | `0.15` | 0 … 0.9, step 0.01 | Feature floor — content scoring below this doesn't count as trackable at all. |
| `variance` | `Float` | `0.8` | 0 … 1, step 0.01 | Spread of tracker preferences — 0 hunts only the strongest features, 1 distributes trackers across the whole brightness range. |
| `agility` | `Float` | `0.5` | 0 … 1, step 0.01 | How fast trackers travel and how wide they search. |
| `lifespan` | `Float` | `6` | 0 … 20, step 0.5 | Seconds a tracker follows its target before retiring and reacquiring elsewhere. 0 = track forever. |
| `trail` | `Float` | `1` | 0 … 1, step 0.01 | Visibility of the keyframe trail each tracker leaves behind. |
| `markerSize` | `Float` | `28` | 8 … 80, step 1 | Tracker gizmo size in pixels. |
| `lineWidth` | `Float` | `1.5` | 0.5 … 6, step 0.25 | Stroke width in pixels. |
| `markerColor` | `ShaderColor` | `"#54d66b"` | CSS color string | Tracker gizmo color. |
| `keyframeColor` | `ShaderColor` | `"#ffcf33"` | CSS color string | Keyframe diamond color. |
| `pathColor` | `ShaderColor` | `"#ffffffb8"` | CSS color string | Motion path color. |

Dynamic form (same values): `ShaderNode(type: "KeyFrames", props: ["trackers": .number(12), "detect": .string("bright")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
