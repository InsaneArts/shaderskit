# HTMLInCanvas

Render live HTML/DOM content as a WebGPU texture layer via the html-in-canvas API. Requires Chrome Canary with chrome://flags/#canvas-draw-element enabled.

- Category: Textures · Role: media
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.

## Swift

```swift
import ShadersKit

ShaderView {
    HTMLInCanvas()
}
```

Initializer (all parameters optional, defaults shown):

```swift
HTMLInCanvas(, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|


Dynamic form (same values): `ShaderNode(type: "HTMLInCanvas", props: [])`

## Notes

- Upstream captured DOM content. Here it renders a SwiftUI view registered with `ViewTextureRegistry` under the `source` prop (`.prop("source", "myView")`).
