# Changelog

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
- Multi-platform demo app (`Demo/`).
