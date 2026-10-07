# Boids

A living murmuration of hundreds of flocking agents drawn as crisp arrows, streaks, dots or glowing comets — separation, alignment and cohesion drive fluid, splitting-and-merging ribbons, agents flash toward an excited color when scattered, and the cursor acts as an attractor or a predator

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Boids(colorA: "#8ec5ff", colorB: "#ff7ad9", count: 2000)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Boids(colorA: ShaderColor = "#8ec5ff", colorB: ShaderColor = "#ff7ad9", colorSpace: ColorSpace = .oklab, agentShape: AgentShape = .arrow, count: Float = 2000, speed: Float = 2, seed: Float = 0, size: Float = 1.5, trails: Float = 0, separation: Float = 1.7, alignment: Float = 1.5, cohesion: Float = 1, perception: Float = 0.12, cursorMode: CursorMode = .repel, cursorStrength: Float = 1.5, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Boids.AgentShape`: .arrow, .streak, .dot, .square, .glow
- `Boids.CursorMode`: .none, .attract, .repel

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#8ec5ff"` | CSS color string | Color of agents cruising calmly with the flock |
| `colorB` | `ShaderColor` | `"#ff7ad9"` | CSS color string | Color agents flash toward when agitated — scattering from the predator cursor or banking through a hard turn |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the rest→excited color ramp |
| `agentShape` | `AgentShape` | `"arrow"` | `arrow`, `streak`, `dot`, `square`, `glow` | What each agent is drawn as — a hard-edged arrow, streak or square pointing along its heading, a plain dot, or a soft glowing comet |
| `count` | `Float` | `2000` | 100 … 4000, step 100 | Number of flocking agents |
| `speed` | `Float` | `2` | 0.2 … 5, step 0.1 | Overall cruising speed of the flock |
| `seed` | `Float` | `0` | 0 … 100, step 1 | Re-rolls the flock's starting formation — each value spawns the murmuration in a different arrangement |
| `size` | `Float` | `1.5` | 0.5 … 3, step 0.05 | Size of each agent |
| `trails` | `Float` | `0` | 0 … 1, step 0.01 | How long each agent's motion trail persists — 0 draws crisp agents, 1 leaves long ribbons |
| `separation` | `Float` | `1.7` | 0 … 3, step 0.01 | How strongly agents steer away from crowding their neighbours |
| `alignment` | `Float` | `1.5` | 0 … 3, step 0.01 | How strongly agents match their neighbours' heading — the driver of coherent murmuration ribbons |
| `cohesion` | `Float` | `1` | 0 … 3, step 0.01 | How strongly agents steer toward the local center of the flock |
| `perception` | `Float` | `0.12` | 0.05 … 0.35, step 0.01 | How far each agent can sense its neighbours (in screen heights) — larger sees bigger, smoother flocks |
| `cursorMode` | `CursorMode` | `"repel"` | `none`, `attract`, `repel` | How the flock reacts to the cursor |
| `cursorStrength` | `Float` | `1.5` | 0 … 3, step 0.01 | Strength of the cursor's pull or push on the flock |

Dynamic form (same values): `ShaderNode(type: "Boids", props: ["colorA": .string("#8ec5ff"), "colorB": .string("#ff7ad9")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
