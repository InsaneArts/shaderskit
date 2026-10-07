# ShadersKit API reference

## ShaderView

```swift
ShaderView(options: RenderOptions = RenderOptions(),
           isPaused: Bool = false,
           preferredFramesPerSecond: Int = 60,
           onFrame: ((FrameStats) -> Void)? = nil) { /* layers */ }

ShaderView(nodes: [ShaderNode], options: ..., isPaused: ..., preferredFramesPerSecond: ..., onFrame: ...)
```

- Renders continuously with Metal (iOS, iPadOS, macOS, tvOS, visionOS) or the CPU rasterizer
  (watchOS). The canvas is transparent where nothing is drawn: put your own background behind it
  or set `RenderOptions.backgroundColor`.
- `isPaused` stops rendering (use it for off-screen or hidden views).
- `onFrame` reports `FrameStats` (`passes`, `blendPasses`, `nodes`, `unsupportedNodes`,
  `compileErrors`, `pendingCompiles`). `unsupportedNodes` lists components that cannot render on
  this platform; `pendingCompiles` is nonzero while a shader library compiles in the background
  (the layer is skipped for those frames).
- The view tracks the mouse, trackpad hover and touches and feeds pointer-driven components.

`RenderOptions(colorSpace: .displayP3Linear | .sRGBLinear, toneMapping: .linear | .reinhard |
.cineon | .aces | .agx | .neutral | .hable | .unreal, premultiplyAlpha: Bool, backgroundColor:
SIMD4<Float>)`. Display P3 is the upstream default.

## Layers

Every component is a struct conforming to `ShaderLayer` (`var node: ShaderNode`). Filters,
distortions and containers take their content as a `@ShaderLayerBuilder` trailing closure:

```swift
Blur(intensity: 40) {
    Checkerboard()
    ShadersKit.Circle(color: "#ff0000", radius: 0.3).blendMode(.multiply)
}
```

Roles (from the component docs): generator, shape and media draw on their own; filter, warp,
shapeEffect-over-child and structural wrap content; simulation runs a GPU simulation.

### Modifiers (return a `ShaderNode`)

| Modifier | Effect |
|---|---|
| `.blendMode(_:)` | `normal`, `normalOklch`, `normalOklab`, `multiply`, `screen`, `linearDodge`, `overlay`, `difference`, `colorDodge`, `exclusion`, `color`, `luminosity`, `darken`, `lighten`, `colorBurn`, `linearBurn`, `softLight`, `hardLight`, `hue`, `saturation` |
| `.opacity(_:)` | 0…1 |
| `.visible(_:)` | hide without removing (hidden layers can still be mask sources) |
| `.layerID(_:)` | stable id (mask references, simulation state across edits) |
| `.mask("id", type:)` | mask with another layer by id; `type` = `alpha`, `alphaInverted`, `luminance`, `luminanceInverted` |
| `.mask(type:) { … }` | inline mask layer tree |
| `.layerTransform(LayerTransform(offsetX:offsetY:rotation:scale:anchorX:anchorY:edges:))` | move/rotate/scale the finished layer |
| `.prop("name", value)` | override a prop by name (`PropValue`) |

### Prop value types

| Swift type | Used for | Examples |
|---|---|---|
| `ShaderColor` | colors | `"#7c3aed"`, `.rgb(1, 0.5, 0, alpha: 0.5)`, `ShaderColor(Color.red)`, `.transparent` |
| `ShaderPosition` | positions | `ShaderPosition(x: 0.5, y: 0.5)`, `.px(40, 20)`, `.keyword("top left")`, `.center` |
| `DimensionalValue` | sizes with px support | `0.5` (fraction), `.px(24)` |
| `Float` | numbers, angles (degrees) | `45` |
| `[ColorStop]?` | gradient stops | `[ColorStop("#f00", at: 0), ColorStop("#00f", at: 1)]` |
| enums | selects | `EdgeMode.wrap`, `ColorSpace.oklch`, `StrokePosition.inside`, `ShaderOrigin.topLeft`, `ObjectFit.cover`, per-component enums such as `Repeater.Mode.radial` |
| `Bool`, `String` | toggles, text, JSON shape configs | |

## Dynamic trees and presets

```swift
let node = ShaderNode(type: "LinearGradient", props: ["angle": .number(90)], children: [], attributes: LayerAttributes(opacity: 0.5))
ShaderView(nodes: [node])
```

`PropValue` cases: `.number`, `.bool`, `.string`, `.position(PositionInput)`, `.dimensional`,
`.colorStops`, `.list`, `.null`. Unspecified props use the component defaults.

`ShaderPreset` is Codable and matches the upstream `createShader` JSON (`components`, `type`,
`props`, `children`, plus `blendMode`, `opacity`, `visible`, `id`, `mask`, `transform`):

```swift
let preset = try ShaderPreset(json: data)
ShaderView(nodes: preset.components, options: preset.renderOptions)
let swift = ShaderNode.swiftSource(for: preset.components)   // typed Swift code for the tree
```

`ShaderRegistry.index` lists all components (`name`, `category`, `description`, `role`,
`acceptsChildren`, `hasCompute`, `cpuSupported`); `ShaderRegistry.descriptor("Name")` gives the
full prop metadata (`props[].ui.min/max/step/options/group`, `defaultValue`, `transform`).

## Snapshots and offscreen rendering

```swift
let renderer = ShaderRenderer(device: ShaderDevice.shared!)
let image: CGImage? = renderer.renderImage(nodes, size: CGSize(width: 1024, height: 512), scale: 2, time: 1.0)
```

`ShaderDevice.shared?.precompileAll()` warms every shader library in the background (first use of
a component otherwise compiles its Metal library, cached by the OS afterwards).

## Media

- `ImageTexture(url:objectFit:)`: http(s), file path, `data:` URI, or a key registered with
  `ShaderMedia.registerImage(cgImage, for: "asset:hero")`.
- `VideoTexture(url:objectFit:…)`: AVPlayer, looping, muted.
- `WebcamTexture`: iOS and macOS front camera (needs `NSCameraUsageDescription`).
- `ShadersKit.Text(text:fontFamily:fontSize:…)`: CoreText raster.
- `HTMLInCanvas` renders a SwiftUI view: `ViewTextureRegistry.shared.register(id: "chart") { AnyView(MyChart()) }`
  and `HTMLInCanvas().prop("source", "chart")`.

## UIKit / AppKit

`ShaderMetalView` is an `MTKView` subclass: set `nodes`, `options`, `isPaused`,
`preferredFramesPerSecond`, read `lastStats`. Host it like any view.

## Performance

- One `ShaderView` = one Metal drawable per frame; each layer adds one or more fullscreen passes.
  Keep stacks small on iPhone (2–6 layers), pause views that are off screen.
- Compute-backed components (blurs, simulations, SDF materials) run extra kernels; prefer one per
  view.
- Lower `preferredFramesPerSecond` for ambient backgrounds (30 fps halves the GPU cost).
- For many thumbnails, render snapshots with `renderImage` instead of live views.
