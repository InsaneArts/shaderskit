# Form3D

Wraps child content onto a 3D raymarched shape with lighting.

- Category: Distortions · Role: shapeEffect
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    Form3D(zoom: 50, glossiness: 50, lighting: 50) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this shapeEffect applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
Form3D(shape3d: String = #"{"type":"ribbon","angle":0,"twist":50,"width":40,"thickness":20,"seed":0}"#, shape3dType: String = "ribbon", center: ShaderPosition = ShaderPosition(x: 0.5, y: 0.5), zoom: Float = 50, glossiness: Float = 50, lighting: Float = 50, uvMode: EdgeMode = .stretch, speed: Float = 1, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `shape3d` | `String` | `"{"type":"ribbon","angle":0,"twist":50,"width":40,"thickness":20,"seed":0}"` | — | 3D shape and its parameters |
| `shape3dType` | `String` | `"ribbon"` | — | Active shape type — triggers recompile when shape is switched |
| `center` | `ShaderPosition` | `(0.5, 0.5)` | `ShaderPosition` (0…1, top-left origin) | Center position of the shape on screen |
| `zoom` | `Float` | `50` | 10 … 200, step 1 | Camera zoom level |
| `glossiness` | `Float` | `50` | 0 … 200, step 1 | Specular highlight intensity and sharpness |
| `lighting` | `Float` | `50` | 0 … 200, step 1 | Overall intensity of lighting effects |
| `uvMode` | `EdgeMode` | `"stretch"` | `stretch`, `mirror`, `wrap` | How to handle UV coordinates at shape boundaries |
| `speed` | `Float` | `1` | -10 … 10, step 0.1 | Animation speed — scales all spin rates |

Dynamic form (same values): `ShaderNode(type: "Form3D", props: ["shape3d": .string("{"type":"ribbon","angle":0,"twist":50,"width":40,"thickness":20,"seed":0}"), "shape3dType": .string("ribbon")])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
- Animates on its own clock; `speed` scales the speed (0 pauses).
