# Group

Container for organizing and composing child effects — supports flex-like flow layout (column/row stacking via the flow prop)

- Category: Utilities · Role: structural
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ShadersKit.Group() {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this structural applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ShadersKit.Group(, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|


Dynamic form (same values): `ShaderNode(type: "Group", props: [])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- `Group` also exists in SwiftUI or the standard library: write `ShadersKit.Group` in files that import SwiftUI.
