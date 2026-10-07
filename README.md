# ShadersKit

A Swift port of the [shaders.com](https://shaders.com) WebGPU component library for Apple platforms.
All 199 upstream components are available as typed Swift layers, rendered with Metal on iOS,
iPadOS, macOS, tvOS and visionOS, and with a CPU rasterizer on watchOS (which has no Metal).

```swift
import ShadersKit

ShaderView {
    LinearGradient(colorA: "#0f172a", colorB: "#7c3aed", angle: 45)
    Blur(intensity: 40) {
        ShadersKit.Circle(radius: 0.5, color: "#ff2b6e")
    }
    .blendMode(.screen)
    .opacity(0.8)
}
```

Layers are composited top-to-bottom exactly like the upstream `<Shader>` element: the first layer
is the bottom-most, later layers blend over it, filters and distortions wrap the content nested
inside them, and every layer carries a blend mode, opacity, optional mask and transform.

## Contents

- [Status](#status)
- [Installation](#installation)
- [Usage](#usage)
- [Architecture](#architecture)
- [Regenerating from upstream](#regenerating-from-upstream)
- [Demo app](#demo-app)
- [License](#license)

## Status

| Area | State |
|---|---|
| Fragment shaders (generators, shapes, filters, warps) — 148 components | Ported. Every variant is transpiled from the upstream WGSL and verified with the Metal compiler and runtime renders. |
| Compute-backed shaders (blurs, simulations, SDF materials) — 51 components | All 51 have a `ComputeProgram` (see `Engine/Programs`). Known gaps: SVG-derived and flat 2D shapes in the SDF materials render nothing; `Glass` frosted (`blur > 0`) prepass, `Voxels` non-cube voxel shapes, `TimeTrail` rainbow tint and `ReactionDiffusion` child-driven mode are not ported; `Irradiance` shadows cannot be disabled. |
| CPU-side per-frame hooks (`FlowingGradient`, `MeshGradient`, `Beam`, `Blob`, `StudioBackground`, `FilmGrain`, `Form3D`, `Ascii`, `ChromaFlow`, `CursorTrail`) | Ported (`Engine/HostFieldsHook.swift`, shared with watchOS; the three texture-producing ones are `MediaProgram`s under `Engine/Media`). |
| Media sources | `ImageTexture` (URL/file/data URI), `VideoTexture` (AVPlayer), `WebcamTexture` (iOS/macOS), `Text` (CoreText; Google fonts map to system fonts), and `HTMLInCanvas` replaced by a SwiftUI view capture (`ViewTextureRegistry`, prop `source`). |
| watchOS | CPU rasterizer for 146 shader programs (no compute or video). Screen-space derivatives (`fwidth`) are approximated, so hairline anti-aliasing differs from the GPU. |
| Prop maps / mouse / auto drivers (design-editor features) | Not ported. Pointer input reaches shaders through the system uniforms; animate props from Swift instead. |
| Flow layout, bounding-box editor metadata | Not ported (shapes position themselves through their own props). |

## Installation

Add the package to your project:

```swift
dependencies: [
    .package(url: "<this repository>", from: "0.1.0"),
]
```

Platforms: iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1. Swift 5.10 / Xcode 16 or newer.

## Usage

### SwiftUI

`ShaderView` renders continuously (60 fps by default) and tracks the pointer or touches so
interactive components react:

```swift
ShaderView(options: RenderOptions(colorSpace: .displayP3Linear, toneMapping: .linear)) {
    MeshGradient()
    FilmGrain { }          // filters wrap content; an empty filter draws nothing
    Vignette { Plasma() }
}
.frame(height: 300)
```

Every component is a struct named after the upstream component with the same props and defaults
(`Sources/ShadersKit/Generated/Layers`). Select-style props are enums, colors accept CSS strings
(`"#7c3aed"`, `"rgb(255 0 0 / 50%)"`, named colors), positions are `ShaderPosition`, lengths that
accept `px` are `DimensionalValue` (`0.5` means a fraction of the canvas, `.px(24)` pixels).

Names that collide with SwiftUI or the standard library (`Circle`, `Ellipse`, `Text`, `Group`,
`Grid`, `Glass`, `Mirror`, `LinearGradient`, `RadialGradient`, `MeshGradient`, and the `BlendMode`
enum) must be qualified as `ShadersKit.Circle` in files that also import SwiftUI.

### Layer modifiers

```swift
Halftone { RadialGradient() }
    .blendMode(.multiply)
    .opacity(0.7)
    .mask("logo", type: .luminance)        // another layer's `.layerID("logo")`
    .layerTransform(LayerTransform(rotation: 15, scale: 1.2))
```

### Dynamic trees and presets

The renderer consumes `ShaderNode` trees, so compositions can be built at runtime or loaded from
JSON (upstream `createShader` presets use the same component names and prop values):

```swift
let node = ShaderNode(type: "LinearGradient", props: ["angle": .number(90)])
ShaderView(nodes: [node])
```

`ShaderRegistry.index` lists every component with its category, role and description;
`ShaderRegistry.descriptor(_:)` exposes the full prop metadata (ranges, options, groups), which is
what the demo app's inspector is generated from.

### Bundled images

```swift
ShaderMedia.registerImage(cgImage, for: "asset:hero")
ImageTexture(url: "asset:hero", objectFit: .cover)
```

### Snapshots

```swift
let renderer = ShaderRenderer(device: ShaderDevice.shared!)
let image = renderer.renderImage([LinearGradient().node], size: CGSize(width: 512, height: 512))
```

### UIKit / AppKit

`ShaderMetalView` is an `MTKView` subclass; set `nodes` and `options` and it renders.

### watchOS

`ShaderView` has the same API and renders through `CPURenderer` at a reduced resolution
(`CPURenderer.renderScale(for:)`). Prefer generators and simple filters there.

## Architecture

```
Tools/upstream-dump     vitest files that compose every upstream shader GPU-free and dump its WGSL
Tools/wgsl2x            WGSL parser/type-checker + Metal and Swift emitters + Swift codegen
Sources/ShadersKit
  Model/                ShaderNode tree, PropValue, LayerAttributes, descriptors, registry
  Props/                CSS color parsing and the upstream prop transforms (ports of utilities/)
  Generated/Layers/     199 typed layer structs (generated)
  Generated/CPU/        146 CPU shader programs in Swift (generated)
  Resources/MSL/        One .metal file per component with every compile-time variant (generated)
  Resources/Descriptors Component metadata JSON (generated)
  Engine/               Metal renderer: uniform packing, per-node passes, blend/mask compositor,
                        compute and media program frameworks (Engine/Programs, Engine/Media)
  CPU/                  CPU rasterizer runtime and renderer (watchOS)
  SwiftUI/              ShaderView and the platform views
Demo/                   Multi-platform demo and test app (XcodeGen project)
```

How a frame is rendered:

1. Each node's props are transformed (colors → linear Display P3, positions, angles, selects…)
   and packed into the exact WGSL uniform layout the upstream composer emitted.
2. The compile-time variant matching the node's select props is picked; its passes run as
   fullscreen fragment passes into rgba16Float textures. Filters receive their composited children
   as a texture; gather filters use the upstream RTT pass.
3. Compute-backed nodes run their `ComputeProgram` between the RTT and final passes.
4. Siblings are composited with the upstream blend / mask functions (transpiled from the same
   WGSL), then a present pass applies tone mapping, the sRGB transfer function and premultiplies
   alpha for the drawable.

## Regenerating from upstream

The whole `Generated/` + `Resources/` set is produced from an upstream checkout:

```bash
git clone https://github.com/shader-effects-inc/shaders upstream && cd upstream && pnpm install
cp ../Tools/upstream-dump/zz-dump*.test.ts packages/core/src/__tests__/gpu/
cd packages/core && DUMP_OUT=/tmp/dump pnpm vitest run zz-dump
cd ../../../Tools/wgsl2x && npm install && npx tsx src/main.ts /tmp/dump .. --validate
```

`--validate` compiles every generated `.metal` file with the Metal toolchain. The dump needs no
GPU: it mocks the TypeGPU root and resolves each pass to WGSL exactly like the upstream test suite.

## Agent skill

`skills/shaderskit` is a skill for coding agents (Claude Code, Codex, …): quick start, workflow,
per-component reference (`skills/shaderskit/components/*.md`, generated from the descriptors),
platform notes and recipes. The demo app's "Copy agent prompt" button emits prompts that use it.
Install it with the [skills CLI](https://skills.sh):

```bash
npx skills add tornikegomareli/shaderskit --skill shaderskit -y
```

## Demo app

`Demo/` contains an XcodeGen project (`cd Demo && xcodegen generate`) with iOS, macOS, tvOS and
watchOS targets: a gallery of all components with live previews, an inspector generated from the
prop metadata, a layer playground with Swift code export, curated showcases and a performance HUD.

## License

The upstream engine and components are MIT licensed by Shader Effects Inc.; this port keeps the
same license for the generated and hand-written code in this repository.
