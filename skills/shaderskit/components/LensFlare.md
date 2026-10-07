# LensFlare

Realistic camera lens flare with artifacts.

- Category: Stylize · Role: generator
- Platforms: All platforms, including watchOS (CPU rasterizer).

## Swift

```swift
import ShadersKit

ShaderView {
    LensFlare(intensity: 0.5, ghostIntensity: 0.4, ghostSpread: 0.7)
}
```

Initializer (all parameters optional, defaults shown):

```swift
LensFlare(lightPosition: ShaderPosition = ShaderPosition(x: 0.3, y: 0.3), intensity: Float = 0.5, ghostIntensity: Float = 0.4, ghostSpread: Float = 0.7, ghostChroma: Float = 0.3, haloIntensity: Float = 0.4, haloRadius: Float = 0.6, haloChroma: Float = 0.6, haloSoftness: Float = 0.8, starburstIntensity: Float = 0.3, starburstPoints: Float = 6, streakIntensity: Float = 0.15, streakLength: Float = 0.5, glareIntensity: Float = 0.2, glareSize: Float = 0.5, edgeFade: Float = 0.2, speed: Float = 0.5, layer: LayerAttributes = LayerAttributes())
```

## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
| `lightPosition` | `ShaderPosition` | `(0.3, 0.3)` | `ShaderPosition` (0…1, top-left origin) | Position of the light source |
| `intensity` | `Float` | `0.5` | 0 … 2, step 0.01 | Master brightness of the entire lens flare effect |
| `ghostIntensity` | `Float` | `0.4` | 0 … 1, step 0.01 | Brightness of internal reflection ghost discs along the flare axis |
| `ghostSpread` | `Float` | `0.7` | 0.1 … 2, step 0.01 | Spacing between ghost reflections along the flare axis |
| `ghostChroma` | `Float` | `0.3` | 0 … 1, step 0.01 | Rainbow chromatic fringing around ghost element edges |
| `haloIntensity` | `Float` | `0.4` | 0 … 1, step 0.01 | Brightness of the circular halo ring from internal reflection |
| `haloRadius` | `Float` | `0.6` | 0.1 … 1, step 0.01 | Radius of the halo ring |
| `haloChroma` | `Float` | `0.6` | 0 … 1, step 0.01 | Spectral dispersion on the halo creating rainbow color separation |
| `haloSoftness` | `Float` | `0.8` | 0.01 … 3, step 0.01 | Thickness and softness of the halo ring |
| `starburstIntensity` | `Float` | `0.3` | 0 … 1, step 0.01 | Brightness of diffraction spikes radiating from the light source |
| `starburstPoints` | `Float` | `6` | 4 … 16, step 1 | Number of starburst spikes (simulates aperture blade count) |
| `streakIntensity` | `Float` | `0.15` | 0 … 1, step 0.01 | Brightness of horizontal anamorphic light streak |
| `streakLength` | `Float` | `0.5` | 0.1 … 1, step 0.01 | Horizontal extent of the anamorphic streak |
| `glareIntensity` | `Float` | `0.2` | 0 … 1, step 0.01 | Soft veiling glare that washes out contrast around the light |
| `glareSize` | `Float` | `0.5` | 0.1 … 1, step 0.01 | Size of the soft glare glow |
| `edgeFade` | `Float` | `0.2` | 0 … 1, step 0.01 | How much the flare fades when the light source is near the screen edge (0 = no fade, 1 = heavy fade) |
| `speed` | `Float` | `0.5` | 0 … 3, step 0.1 | Speed of subtle flare shimmer and starburst rotation |

Dynamic form (same values): `ShaderNode(type: "LensFlare", props: ["lightPosition": .position(.xy(x: .number(0.3), y: .number(0.3))), "intensity": .number(0.5)])`

## Notes

- Animates on its own clock; `speed` scales the speed (0 pauses).
