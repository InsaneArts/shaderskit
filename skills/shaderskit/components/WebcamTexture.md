# WebcamTexture

Display a live webcam feed with customizable object-fit modes

- Category: Textures · Role: media
- Platforms: Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.

## Swift

```swift
import ShadersKit

ShaderView {
    WebcamTexture()
}
```

Initializer (all parameters optional, defaults shown):

```swift
WebcamTexture(objectFit: ObjectFit = .cover, mirror: Bool = true, layer: LayerAttributes = LayerAttributes())
```

Option enums:
- `WebcamTexture.ObjectFit`: .cover, .contain, .fill, .scaleDown, .none

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `objectFit` | `ObjectFit` | `"cover"` | `cover`, `contain`, `fill`, `scale-down`, `none` | How the webcam feed should be sized within the viewport |
| `mirror` | `Bool` | `true` | — | Mirror the webcam feed horizontally (selfie mode) |

Dynamic form (same values): `ShaderNode(type: "WebcamTexture", props: ["objectFit": .string("cover"), "mirror": .bool(true)])`

## Notes

- iOS and macOS only (camera permission required); renders nothing elsewhere.
