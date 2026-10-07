# Recipes

All snippets assume `import ShadersKit` and, where SwiftUI is also imported, qualified names
(`ShadersKit.Circle`, `ShadersKit.MeshGradient`, …).

## Ambient app background

```swift
ZStack {
    ShaderView(preferredFramesPerSecond: 30) {
        ShadersKit.MeshGradient(colorA: "#1a0533", colorB: "#ffdf8e", speed: 0.4)
        FilmGrain(strength: 0.25) { }       // empty filter draws nothing; put FilmGrain around content instead:
    }
    .ignoresSafeArea()
    content
}
```

Correct grain over the gradient (filters wrap what they affect):

```swift
ShaderView(preferredFramesPerSecond: 30) {
    Vignette(intensity: 0.5) {
        FilmGrain(strength: 0.25) {
            ShadersKit.MeshGradient(speed: 0.4)
        }
    }
}
```

## Hero card with a glass material

```swift
ShaderView {
    Aurora()
    Glass(scale: 0.8) { Aurora() }     // SDF glass sphere refracting the aurora
}
.frame(width: 320, height: 420)
.clipShape(RoundedRectangle(cornerRadius: 28))
```

## Shape with glow, masked logo

```swift
ShaderView {
    Glow(intensity: 3, size: 60) {
        Star(color: "#ffffff", radius: 0.3)
    }
    ShadersKit.LinearGradient(colorA: "#ff2b6e", colorB: "#7c3aed", angle: 45)
        .mask("logo", type: .alpha)
    Heart(color: "#ffffff", radius: 0.5).layerID("logo").visible(false)
}
```

## Pointer-driven interaction

```swift
ShaderView {
    Liquify(intensity: 1.2) { Checkerboard(cells: 8) }      // bends under the finger / mouse
}
```

Other pointer components: CursorRipples, CursorTrail, GridDistortion, Boids (`cursorMode`),
Smoke/SmokeFlow/InkFlow, MagneticFilings, ParticleFlow.

## Animating props from Swift

```swift
@State private var angle: Float = 0

ShaderView {
    ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed", angle: angle)
}
.onAppear { withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { angle = 360 } }
```

`ShaderView` is a plain SwiftUI view: any state change re-renders with the new props without
recompiling (select-type props switch shader variants, also without a stall after first use).

## Transition between two images

```swift
@State private var progress: Float = 0
ShaderView {
    IrisWipe(progress: progress) {
        ImageTexture(url: "asset:after", objectFit: .cover)
    }
    // the layer below shows through where the wipe is transparent
}
```

Put the "before" layer first (bottom), the wipe-wrapped "after" layer second.

## Still image / thumbnail

```swift
let renderer = ShaderRenderer(device: ShaderDevice.shared!)
let cg = renderer.renderImage([Plasma().node], size: CGSize(width: 512, height: 512), scale: 2)
```

## Loading a design-editor preset

Export JSON from shaders.com (or the demo's Playground) and load it:

```swift
let preset = try ShaderPreset(json: data)
ShaderView(nodes: preset.components, options: preset.renderOptions)
```
