# ImageTexture

Display an image with customizable object-fit modes

- Category: Textures · Role: media
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.

## Swift

```swift
import ShadersKit

ShaderView {
    ImageTexture()
}
```

Initializer (all parameters optional, defaults shown):

```swift
ImageTexture(url: String = "https://shaders.com/sample.jpg", objectFit: ObjectFit = .fill, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `url` | `String` | `"https://shaders.com/sample.jpg"` | — | Upload an image or provide a URL |
| `objectFit` | `ObjectFit` | `"fill"` | `cover`, `contain`, `fill`, `scale-down` | How the image should be sized within the viewport |

Dynamic form (same values): `ShaderNode(type: "ImageTexture", props: ["url": .string("https://shaders.com/sample.jpg"), "objectFit": .string("fill")])`

## Notes

- `url` accepts http(s) URLs, file paths, `data:` URIs, or a key registered with `ShaderMedia.registerImage(_:for:)`.
