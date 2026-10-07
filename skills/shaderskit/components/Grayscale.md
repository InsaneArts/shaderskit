# Grayscale

Convert colors to black and white

- Category: Adjustments · Role: filter
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Grayscale() {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this filter applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Grayscale(, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|


Dynamic form (same values): `ShaderNode(type: "Grayscale", props: [])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
