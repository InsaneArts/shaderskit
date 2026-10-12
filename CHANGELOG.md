# Changelog

## Unreleased

- `GlassGlow`, the first component written for ShadersKit rather than ported: light sweeping through
  a glass shape (the alpha of its content), with a refracting, colour-split edge and a three-radius
  halo. Props: `speed`, `intensity`, `glow`, `refraction`, `dispersion`. Metal only.
- Hand-written components live in `Sources/ShadersKit/Custom` and `Resources/Custom`, which
  `Tools/regenerate.sh` does not touch; the registry, the index and the skill docs include them.

## 0.1.0

Initial port of the shaders.com library (upstream `shaders` 1.7.0, 199 components).

- WGSL → Metal transpiler and codegen pipeline (`Tools/`), 1,171 compiled variants.
- Metal renderer with the upstream blend / mask / tone-mapping compositor, pointer input,
  layer transforms and masks, Display P3 output.
- Typed SwiftUI layer API (`ShaderView`, one struct per component), dynamic `ShaderNode` trees,
  JSON presets compatible with upstream `createShader` documents, Swift code export.
- CPU rasterizer for watchOS (146 fragment-only components).
- Compute program framework with ported shader families (see `Engine/Programs`).
- Media programs for images, video, camera, text and SwiftUI view capture (see `Engine/Media`).
- Multi-platform demo app (`Demo/`): every component with its Swift code, its props, and a ready prompt
  for a coding agent; the Aurora app icon on iOS, macOS, tvOS and watchOS.
- Agent skill (`skills/shaderskit`): a doc for each of the 199 components. Install it with
  `npx skills add InsaneArts/shaderskit --skill shaderskit -y`.
