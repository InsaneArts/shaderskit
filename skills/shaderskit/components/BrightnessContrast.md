# BrightnessContrast

Adjust brightness and contrast of the image

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    BrightnessContrast(brightness: 0, contrast: 0) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
BrightnessContrast(brightness: Float = 0, contrast: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `brightness` | `Float` | `0` | -1 … 1, step 0.01 | Brightness adjustment (-1 to 1) |
| `contrast` | `Float` | `0` | -1 … 1, step 0.01 | Contrast adjustment (-1 to 1) |

Dynamic form (same values): `ShaderNode(type: "BrightnessContrast", props: ["brightness": .number(0), "contrast": .number(0)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
