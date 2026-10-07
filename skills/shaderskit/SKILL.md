---
name: shaderskit
description: Adds GPU shader effects to Apple apps with the ShadersKit Swift package (a Metal port of the 199 shaders.com components — gradients, noise, shapes, glass and metal materials, blurs, distortions, particle and fluid simulations, transitions). Use when asked to add, implement, edit, animate or compose a shader, "shader background", gradient/noise/blur/glass effect, or any ShadersKit/shaders.com component name (SunBurst, MeshGradient, Blur, Chrome, Boids, …) in a SwiftUI, UIKit or AppKit app on iOS, iPadOS, macOS, tvOS, watchOS or visionOS, or when a prompt says "use the shaderskit skill".
---

# ShadersKit

ShadersKit renders a stack of shader layers in a `ShaderView`. Every upstream component is a Swift
struct with the same props and defaults; filters and distortions wrap the layers nested in their
trailing closure. Layers composite top to bottom: the first is the bottom-most.

## Quick start

```swift
import ShadersKit

ShaderView {
    MeshGradient()                                   // generator (draws on its own)
    Vignette(intensity: 0.6) {                       // filter: wraps content
        ShadersKit.Circle(color: "#ff2b6e", radius: 0.4)
    }
    .blendMode(.screen)
    .opacity(0.8)
}
.frame(height: 320)
```

Colors are CSS strings (`"#7c3aed"`, `"rgb(255 0 0 / 50%)"`, named colors). Positions are
`ShaderPosition(x:y:)` in 0…1 with the top-left origin. Lengths that accept pixels are
`DimensionalValue` (`0.5` = fraction of the canvas, `.px(24)` = pixels). Select props are enums.

## Workflow: "add shader X to my app"

1. Open `components/<X>.md` for the initializer, prop ranges and platform notes
   (index: [COMPONENTS.md](COMPONENTS.md)). Never guess prop names.
2. Add the package: see [PLATFORMS.md](PLATFORMS.md) → "Adding the package" (SwiftPM or Xcode).
3. Put a `ShaderView` where the effect belongs (background: `.ignoresSafeArea()` behind
   content; card: give it a frame and `clipShape`). See [RECIPES.md](RECIPES.md).
4. Use the typed struct exactly as documented; qualify names that clash with SwiftUI as
   `ShadersKit.Circle`, `ShadersKit.Text`, `ShadersKit.LinearGradient`, `ShadersKit.MeshGradient`,
   `ShadersKit.Group`, `ShadersKit.Grid`, `ShadersKit.Glass`, `ShadersKit.Mirror`,
   `ShadersKit.Ellipse`, `ShadersKit.RadialGradient`, and `ShadersKit.BlendMode`.
5. Animate from Swift: change props with `@State` + `withAnimation`, or use `TimelineView`;
   most components already animate on their own clock (`speed` prop, `0` pauses).
6. Build for the target platform and run. Check `components/<X>.md` → Platforms before promising
   watchOS support (compute-backed components are Metal-only).

Checklist before finishing:
- [ ] Props come from the component doc (names, types, ranges).
- [ ] Clashing names are qualified.
- [ ] `ShaderView` has a size (frame, or it fills its container).
- [ ] Platform supports the component (watchOS = CPU rasterizer, simple components only).
- [ ] Built and ran on the requested platform.

## Core API

[REFERENCE.md](REFERENCE.md): `ShaderView`, layer modifiers (`blendMode`, `opacity`, `mask`,
`layerTransform`, `layerID`), `RenderOptions`, dynamic `ShaderNode` trees, JSON presets, Swift
code export, snapshots (`ShaderRenderer.renderImage`), media sources, performance.

## Platforms

[PLATFORMS.md](PLATFORMS.md): package setup, SwiftUI/UIKit/AppKit hosting, tvOS focus and
remote, watchOS CPU limits, visionOS, pointer input, color management.

## Installing this skill

```bash
npx skills add tornikegomareli/shaderskit --skill shaderskit -y            # all detected agents
npx skills add tornikegomareli/shaderskit --skill shaderskit -y -a claude-code   # one agent
```

## Prompts from the demo app

The demo's "Copy agent prompt" button produces a prompt that names this skill, the component,
the target platform and an exact Swift snippet. Treat the snippet as the required configuration:
reproduce it verbatim, then place it where the prompt says. The template is in
[PROMPT.md](PROMPT.md).

## Scripts

`node scripts/component.js <Name>` prints a component's props, defaults and ranges straight from
the package's descriptor JSON (run from the ShadersKit repository root).
