# VideoTexture

Display a video with customizable playback and object-fit modes

- Category: Textures · Role: media
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.

## Swift

```swift
import ShadersKit

ShaderView {
    VideoTexture()
}
```

Initializer (all parameters optional, defaults shown):

```swift
VideoTexture(url: String = "https://shaders.com/sample.mp4", objectFit: ObjectFit = .fill, loop: Bool = true, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `url` | `String` | `"https://shaders.com/sample.mp4"` | — | Upload a video or provide a URL |
| `objectFit` | `ObjectFit` | `"fill"` | `cover`, `contain`, `fill`, `scale-down` | How the video should be sized within the viewport |
| `loop` | `Bool` | `true` | — | Loop the video playback |

Dynamic form (same values): `ShaderNode(type: "VideoTexture", props: ["url": .string("https://shaders.com/sample.mp4"), "objectFit": .string("fill")])`

## Notes

- `url` accepts http(s) or file URLs; playback loops and is muted.
