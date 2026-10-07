# MagneticFilings

Thousands of tiny iron filings scattered on paper that swing to align with a magnetic field around the cursor, tracing out the field lines — a dipole whose axis follows the cursor's motion draws the classic two-lobed swirl, and every sweep of the magnet sends a glowing wave of filings flipping and settling

- Category: Interactive · Role: simulation
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    MagneticFilings(colorA: "#be1ef9", colorB: "#6326ff", count: 8000)
}
```

Initializer (all parameters optional, defaults shown):

```swift
MagneticFilings(colorA: ShaderColor = "#be1ef9", colorB: ShaderColor = "#6326ff", colorSpace: ColorSpace = .oklab, shape: Shape = .dot, count: Float = 8000, size: Float = 1, restOrientation: RestOrientation = .random, fieldType: FieldType = .dipole, strength: Float = 1.7, reach: Float = 0.6, response: Float = 0.5, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `MagneticFilings.Shape`: .arrow, .streak, .dot, .square, .glow
- `MagneticFilings.RestOrientation`: .random, .horizontal, .vertical
- `MagneticFilings.FieldType`: .dipole, .radial

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `colorA` | `ShaderColor` | `"#be1ef9"` | CSS color string | Color of filings resting quietly, aligned and still |
| `colorB` | `ShaderColor` | `"#6326ff"` | CSS color string | Color filings flash toward as they swing and settle — a wave of it follows the moving magnet |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for the rest→excited color ramp |
| `shape` | `Shape` | `"dot"` | `arrow`, `streak`, `dot`, `square`, `glow` | How each filing is drawn — a slim streak or arrow reads as a compass needle, a box as a chunky filing, a dot or soft glow for a finer grain |
| `count` | `Float` | `8000` | 500 … 12000, step 500 | Number of iron filings |
| `size` | `Float` | `1` | 0.5 … 3, step 0.05 | Size of each filing |
| `restOrientation` | `RestOrientation` | `"random"` | `random`, `horizontal`, `vertical` | Which way filings point where the field can't reach them — randomly, all horizontal, or all vertical |
| `fieldType` | `FieldType` | `"dipole"` | `dipole`, `radial` | The magnetic field the filings reveal — a dipole (bar-magnet lobes that follow the cursor's motion) or a radial monopole (spokes out from the cursor) |
| `strength` | `Float` | `1.7` | 0 … 3, step 0.01 | How strongly the magnet grips the filings — higher snaps more of them into sharp alignment |
| `reach` | `Float` | `0.6` | 0.1 … 1, step 0.01 | How far the magnet's influence spreads (in screen heights) — larger reveals more of the field at once |
| `response` | `Float` | `0.5` | 0 … 1, step 0.01 | How briskly filings swing and settle — low is loose and floppy with a long wobble, high snaps into place quickly |

Dynamic form (same values): `ShaderNode(type: "MagneticFilings", props: ["colorA": .string("#be1ef9"), "colorB": .string("#6326ff")])`

## Notes

- Reacts to the pointer / touch position (`ShaderView` feeds it automatically).
