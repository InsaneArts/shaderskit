# ObjectTracker

Computer-vision style object detection overlay — draws bounding boxes and labels around detected regions of the content below, with grid, quadtree and mosaic layouts.

- Category: Stylize · Role: overlay
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    ObjectTracker(threshold: 0.25, cellSize: 400, maxDepth: 2) {
        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this overlay applies to
    }
}
```

Initializer (all parameters optional, defaults shown):

```swift
ObjectTracker(detectionMode: DetectionMode = .bright, threshold: Float = 0.25, layout: Layout = .mosaic, cellSize: Float = 400, maxDepth: Float = 2, boxStyle: BoxStyle = .corners, lineWidth: Float = 1.5, cornerRadius: Float = 0, strokeColor: ShaderColor = "#ffffff", fillColor: ShaderColor = "#5a79911a", labelColor: ShaderColor = "#000000", labelBackgroundColor: ShaderColor = "#ffffff", labelMode: LabelMode = .none, labelPosition: LabelPosition = .bottomRight, labelRadius: Float = 0, labelInset: Bool = true, fontFamily: String = "Inter", fontWeight: Float = 500, fontSize: DimensionalValue = 0.015, letterSpacing: Float = 0, layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }
```

Option enums:
- `ObjectTracker.DetectionMode`: .alpha, .bright, .dark, .red, .green, .blue
- `ObjectTracker.Layout`: .grid, .quadtree, .mosaic
- `ObjectTracker.BoxStyle`: .full, .corners
- `ObjectTracker.LabelMode`: .none, .dimensions, .percentage
- `ObjectTracker.LabelPosition`: .bottomLeft, .bottomRight, .topLeft, .topRight

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `detectionMode` | `DetectionMode` | `"bright"` | `alpha`, `bright`, `dark`, `red`, `green`, `blue` | What counts as a detectable object. |
| `threshold` | `Float` | `0.25` | 0 … 1, step 0.01 | Detection cut-off. |
| `layout` | `Layout` | `"mosaic"` | `grid`, `quadtree`, `mosaic` | How the canvas is partitioned into detection cells. |
| `cellSize` | `Float` | `400` | 24 … 800, step 1 | Base cell size in pixels |
| `maxDepth` | `Float` | `2` | 1 … 5, step 1 | Maximum subdivision levels for Quadtree/Mosaic layouts (each level can quarter a cell). |
| `boxStyle` | `BoxStyle` | `"corners"` | `full`, `corners` | Bounding box outline style |
| `lineWidth` | `Float` | `1.5` | 0.5 … 12, step 0.5 | Thickness of the box outline in pixels. |
| `cornerRadius` | `Float` | `0` | 0 … 40, step 1 | Corner radius of the box outline in pixels |
| `strokeColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Bounding box outline color. |
| `fillColor` | `ShaderColor` | `"#5a79911a"` | CSS color string | Bounding box fill color. |
| `labelColor` | `ShaderColor` | `"#000000"` | CSS color string | Label text color. |
| `labelBackgroundColor` | `ShaderColor` | `"#ffffff"` | CSS color string | Label pill background color. |
| `labelMode` | `LabelMode` | `"none"` | `none`, `dimensions`, `percentage` | What each label shows. |
| `labelPosition` | `LabelPosition` | `"bottom-right"` | `bottom-left`, `bottom-right`, `top-left`, `top-right` | Which corner of the box the label anchors to. |
| `labelRadius` | `Float` | `0` | 0 … 30, step 1 | Corner radius of the label pill in pixels. |
| `labelInset` | `Bool` | `true` | — | Place the label inside or outside the box. |
| `fontFamily` | `String` | `"Inter"` | — | Google Fonts family used for label text. |
| `fontWeight` | `Float` | `500` | — | Font weight for label text. |
| `fontSize` | `DimensionalValue` | `0.015` | 0.01 … 0.5, step 0.005 | Label text size as a fraction of canvas height. |
| `letterSpacing` | `Float` | `0` | -0.1 … 0.5, step 0.005 | Letter spacing for label text, in em units. |

Dynamic form (same values): `ShaderNode(type: "ObjectTracker", props: ["detectionMode": .string("bright"), "threshold": .number(0.25)])`

## Notes

- Wraps the layers in its trailing closure; draws nothing without content.
