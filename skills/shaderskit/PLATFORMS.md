# Platforms

## Adding the package

SwiftPM (`Package.swift`):

```swift
dependencies: [
    .package(path: "/path/to/ShadersKit"),            // local checkout, or
    .package(url: "https://github.com/<org>/ShadersKit", from: "0.1.0"),
],
targets: [ .target(name: "App", dependencies: [.product(name: "ShadersKit", package: "ShadersKit")]) ]
```

Xcode project: File → Add Package Dependencies… → enter the URL or "Add Local…" and pick the
checkout; add the `ShadersKit` product to the app target. XcodeGen: `packages: { ShadersKit: { path: ../ShadersKit } }`
and `dependencies: [{ package: ShadersKit }]`.

Minimums: iOS 17, iPadOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1. No extra Info.plist keys
unless `WebcamTexture` is used (`NSCameraUsageDescription`).

The package compiles its Metal shaders from source at first use (per component, cached by the
system afterwards); nothing to configure in the build.

## iOS / iPadOS

- SwiftUI: `ShaderView { … }` anywhere. Full-screen background:
  `ZStack { ShaderView { … }.ignoresSafeArea(); content }`.
- UIKit: `let v = ShaderMetalView(); v.nodes = [MeshGradient().node]; view.addSubview(v)`.
- Touches and iPad pointer hover drive pointer-based components automatically.
- Display P3 output by default (`RenderOptions.colorSpace`).
- Memory: intermediate textures are rgba16Float at the view's pixel size; avoid dozens of
  simultaneous live views.

## macOS

- Same SwiftUI API; mouse movement over the view drives pointer input (no click needed).
- `ShaderMetalView` is an `NSView` (`MTKView`) for AppKit hosts.
- Windows at Retina scale render at 2× pixels; lower `preferredFramesPerSecond` for large
  ambient windows if needed.

## tvOS

- Same API. No `Slider`/`ColorPicker` in SwiftUI on tvOS: drive props with buttons or focus
  state.
- The Siri Remote touch surface reaches the view as indirect touches; pointer-driven components
  respond while a finger is on the surface.

## watchOS

- No Metal. `ShaderView` renders with `CPURenderer` at a reduced resolution
  (`CPURenderer.renderScale(for:)`, about 24k pixels per frame) and 30 fps by default.
- Only fragment-only components work (146 of 199; `components/<Name>.md` → Platforms says
  "All platforms"). Compute-backed components, video and camera render nothing.
- Prefer generators and simple filters (gradients, noise, shapes, Pixelate, Grayscale, Vignette).
  Heavy raymarchers (Strands, Waveform, Voronoi, MeshGradient) run but at low frame rates.
- Screen-space derivatives (`fwidth`) are approximated: hairline anti-aliasing on grid-style
  components differs from the GPU.
- Keep stacks to 1–2 layers; bind a prop to the Digital Crown for interaction.

## visionOS

- Metal path like iOS; `ShaderView` works in windows. Not verified on device.

## Color management

Colors are converted to linear Display P3 (default) and the drawable is tagged Display P3, so
`"#ff0000"` is a P3 red. Pass `RenderOptions(colorSpace: .sRGBLinear)` to match sRGB assets.
