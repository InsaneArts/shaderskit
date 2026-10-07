# Voxels

Rebuild any shape out of voxels — a flat shape becomes chunky pixel art, a 3D shape a lit voxel model with smooth ambient occlusion, cast shadows, a key light you can orbit or drive, and per-cube color

- Category: Shape Effects · Role: shapeEffect
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).

## Swift

```swift
import ShadersKit

ShaderView {
    Voxels(scale: 1, rotation: 0, voxelSize: 0.035)
}
```

Initializer (all parameters optional, defaults shown):

```swift
Voxels(origin: ShaderOrigin = .center, center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), scale: Float = 1, rotation: Float = 0, voxelSize: Float = 0.035, voxelShape: VoxelShape = .cube, voxelScale: Float = 1, fill: Float = 0, bevel: Float = 0.08, depth: Float = 0.12, gridSpace: GridSpace = .shape, colorA: ShaderColor = "#6ea8ff", colorB: ShaderColor = "#1d2b4f", colorMode: ColorMode = .height, colorVariation: Float = 0.25, colorSpace: ColorSpace = .oklab, lightAngle: Float = 225, lightElevation: Float = 42, lightColor: ShaderColor = "#fff2df", lightIntensity: Float = 1.1, ambientColor: ShaderColor = "#9fb4d8", ambient: Float = 0.55, shadows: Float = 0.85, shadowSoftness: Float = 0.35, ao: Float = 1, glossiness: Float = 0.35, specular: Float = 0.6, seams: Float = 0.2, shape: String = #"{"type":"sphere3D","radius":0.35}"#, shapeSdfUrl: String = "", shapeType: String = "", layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `Voxels.VoxelShape`: .cube, .rounded, .sphere
- `Voxels.GridSpace`: .shape, .view
- `Voxels.ColorMode`: .solid, .height, .depth, .random, .faces

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `origin` | `ShaderOrigin` | `"center"` | — | Reference edge the center position is measured from (center default). Lets you pin the shape relative to a corner or the canvas centre. |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | fraction or `.px(n)`, `ShaderPosition` (0…1, top-left origin) | Center position of the voxel model |
| `scale` | `Float` | `1` | 0.1 … 3, step 0.01 | Scale of the voxel model (1 = default size) |
| `rotation` | `Float` | `0` | 0 … 360, step 1 | Rotation of the voxel model in degrees |
| `voxelSize` | `Float` | `0.035` | 0.006 … 0.15, step 0.001 | Edge length of one voxel relative to the shape field — small for fine detail, large for chunky blocks |
| `voxelShape` | `VoxelShape` | `"cube"` | `cube`, `rounded`, `sphere` | What each cell is built from: hard cubes, rounded cubes (see Bevel) or spheres |
| `voxelScale` | `Float` | `1` | 0.3 … 1, step 0.01 | Size of each voxel inside its cell — 1 = touching neighbours, lower opens gaps between the blocks |
| `fill` | `Float` | `0` | -0.5 … 0.5, step 0.01 | How eagerly cells fill in along the surface — negative carves a thinner model, positive puffs it out |
| `bevel` | `Float` | `0.08` | 0 … 1, step 0.01 | Edge rounding of each voxel as a fraction of its size — a hairline chamfer catching light on cubes, the corner radius of rounded cubes |
| `depth` | `Float` | `0.12` | 0.01 … 0.6, step 0.005 | Thickness given to flat shapes (2D shapes and flat SVGs) so they become a slab of voxels — 3D shapes ignore it |
| `gridSpace` | `GridSpace` | `"shape"` | `shape`, `view` | Model: the grid rotates with the shape like a built voxel model. Screen: the grid is fixed to the canvas and the shape moves through it like a 3D pixelation |
| `colorA` | `ShaderColor` | `"#6ea8ff"` | CSS color string | Base color of the voxels (the first color of the palette mode) |
| `colorB` | `ShaderColor` | `"#1d2b4f"` | CSS color string | Second palette color — blended in by height, depth, per voxel or on the side faces |
| `colorMode` | `ColorMode` | `"height"` | `solid`, `height`, `depth`, `random`, `faces` | How the two colors are laid over the model: one solid color, a gradient by height or depth, a random pick per voxel, or Color A on top faces and Color B on the sides |
| `colorVariation` | `Float` | `0.25` | 0 … 1, step 0.01 | Per-voxel tonal jitter — the slightly-off shades that make blocks read as individual bricks |
| `colorSpace` | `ColorSpace` | `"oklab"` | `linear`, `oklch`, `oklab`, `hsl`, `hsv`, `lch` | Color space for color interpolation |
| `lightAngle` | `Float` | `225` | 0 … 360, step 1 | Direction the key light comes from, in degrees around the canvas — shadows fall away from it |
| `lightElevation` | `Float` | `42` | 5 … 85, step 1 | How high the key light sits above the canvas — low for long raking shadows, high for a flat top-down light |
| `lightColor` | `ShaderColor` | `"#fff2df"` | CSS color string | color of the key light |
| `lightIntensity` | `Float` | `1.1` | 0 … 3, step 0.01 | Strength of the key light |
| `ambientColor` | `ShaderColor` | `"#9fb4d8"` | CSS color string | Sky color of the ambient light — the fill on faces the key light misses |
| `ambient` | `Float` | `0.55` | 0 … 2, step 0.01 | Strength of the ambient sky/ground fill |
| `shadows` | `Float` | `0.85` | 0 … 1, step 0.01 | Darkness of the shadows voxels cast onto each other |
| `shadowSoftness` | `Float` | `0.35` | 0 … 1, step 0.01 | Penumbra of the cast shadows — 0 is razor sharp, higher spreads the light into a soft area source whose shadows sharpen at contact |
| `ao` | `Float` | `1` | 0 … 2, step 0.01 | Ambient occlusion in the creases between voxels — the soft contact darkening that sells the geometry |
| `glossiness` | `Float` | `0.35` | 0 … 1, step 0.01 | How tight the specular highlight is — satin plastic at 0, lacquered at 1 |
| `specular` | `Float` | `0.6` | 0 … 2, step 0.01 | Strength of the specular highlight and the fresnel rim on grazing faces |
| `seams` | `Float` | `0.2` | 0 … 1, step 0.01 | Dark seam lines along every voxel edge — 0 for seamless blocks, higher for a drawn-outline brick look |
| `shape` | `String` | `"{"type":"sphere3D","radius":0.35}"` | — | Serialized shape configuration (JSON) |
| `shapeSdfUrl` | `String` | `""` | — | URL to a pre-generated SDF .bin file |
| `shapeType` | `String` | `""` | — | Active SDF shape type |

Dynamic form (same values): `ShaderNode(type: "Voxels", props: ["origin": .string("center"), "center": .position(.xy(x: .number(0.5), y: .number(0.5)))])`

## Notes

- Only `voxelShape: cube` with `gridSpace: shape` is ported; other voxel shapes render as cubes.
