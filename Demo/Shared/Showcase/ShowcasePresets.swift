import SwiftUI
import ShadersKit

/// A curated composition built only from components that render today (no compute).
struct ShowcasePreset: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let layers: [ShaderNode]
}

enum ShowcasePresets {
    static let all: [ShowcasePreset] = [
        ShowcasePreset(id: "velvet", title: "Velvet Dusk", subtitle: "Swirl · FilmGrain · Vignette", symbol: "moon.stars", layers: [
            Vignette(radius: 0.75, falloff: 0.9, intensity: 0.8) {
                FilmGrain(strength: 0.22, animated: true) {
                    Swirl(stops: [
                        ColorStop("#0b0221", at: 0),
                        ColorStop("#3a0ca3", at: 0.3),
                        ColorStop("#f72585", at: 0.62),
                        ColorStop("#ffb703", at: 1),
                    ], speed: 0.6, detail: 1.6, colorSpace: .oklch)
                }
            }.node,
        ]),
        ShowcasePreset(id: "aurora", title: "Northern Lights", subtitle: "Aurora through Twirl over a star field", symbol: "sparkles", layers: [
            ShadersKit.LinearGradient(colorA: "#01030f", colorB: "#0b1d3a", start: ShaderPosition(x: 0.5, y: 1), end: ShaderPosition(x: 0.5, y: 0)).node,
            DotGrid(color: "#ffffff", density: 90, dotSize: 0.06, speed: 0.4, twinkle: 0.9).opacity(0.55),
            Twirl(intensity: 0.8) {
                Aurora(colorA: "#9d4edd", colorB: "#2ef2a0", colorC: "#3a86ff", intensity: 90, speed: 3, waviness: 80, height: 150)
            }.blendMode(.screen),
        ]),
        ShowcasePreset(id: "halftone", title: "Print Cells", subtitle: "Voronoi through a CMYK Halftone", symbol: "circle.grid.3x3.fill", layers: [
            Halftone(style: .cmyk, frequency: 60, angle: 30) {
                Voronoi(colorA: "#00b4d8", colorB: "#ff006e", colorBorder: "#1a1a2e", scale: 4, speed: 0.6, edgeIntensity: 0.7, colorSpace: .oklch)
            }.node,
        ]),
        ShowcasePreset(id: "mandala", title: "Plasma Mandala", subtitle: "Plasma through Kaleidoscope", symbol: "seal", layers: [
            Vignette(radius: 0.65, intensity: 0.9) {
                Kaleidoscope(segments: 10) {
                    Plasma(density: 2.6, speed: 1.4, intensity: 1.8, warp: 0.6, stops: [
                        ColorStop("#10002b", at: 0),
                        ColorStop("#7b2cbf", at: 0.35),
                        ColorStop("#ff4d6d", at: 0.7),
                        ColorStop("#ffd166", at: 1),
                    ], colorSpace: .oklch)
                }
            }.node,
        ]),
        ShowcasePreset(id: "chroma", title: "Chromatic Flow", subtitle: "FlowingGradient with ChromaticAberration and grain", symbol: "camera.aperture", layers: [
            FilmGrain(strength: 0.18) {
                ChromaticAberration(strength: 0.6, angle: 35) {
                    FlowingGradient(colorA: "#03001c", colorB: "#5b21b6", colorC: "#06b6d4", colorD: "#f472b6", colorSpace: .linear, speed: 1.2, distortion: 0.9)
                }
            }.node,
        ]),
        ShowcasePreset(id: "bulge", title: "Lens Board", subtitle: "Checkerboard under a Bulge warp", symbol: "circle.circle", layers: [
            Vignette(color: "#05040a", radius: 0.7, falloff: 0.6, intensity: 0.7) {
                Bulge(strength: 0.85, radius: 0.9, falloff: 0.7) {
                    Checkerboard(colorA: "#ff3d7f", colorB: "#1b1035", cells: 14)
                }
            }.node,
        ]),
        ShowcasePreset(id: "shapes", title: "Love & Stars", subtitle: "Circle, Heart and Star with Screen and Difference", symbol: "heart.circle", layers: [
            ShadersKit.RadialGradient(colorA: "#2b1055", colorB: "#05040a", radius: 1.1).node,
            ShadersKit.Circle(color: "#4dd6ff", radius: 0.62, softness: 0.25, center: ShaderPosition(x: 0.38, y: 0.46)).blendMode(.screen),
            Heart(color: "#ff4d8d", center: ShaderPosition(x: 0.6, y: 0.48), radius: 0.3, softness: 0.01).blendMode(.screen),
            Star(color: "#ffd166", center: ShaderPosition(x: 0.5, y: 0.5), radius: 0.2, rotation: 18).blendMode(.difference),
        ]),
        ShowcasePreset(id: "liquid", title: "Liquid", subtitle: "Ripples over a RadialGradient, through WaveDistortion", symbol: "drop", layers: [
            WaveDistortion(strength: 0.12, frequency: 2.2, speed: 0.8) {
                ShadersKit.RadialGradient(colorA: "#00f5d4", colorB: "#240046", radius: 1.15, colorSpace: .oklch)
                Ripples(colorA: "#ffffff", colorB: "#000000", speed: 1.2, frequency: 22, softness: 2.2, thickness: 0.4)
                    .blendMode(.overlay)
            }.node,
        ]),
        ShowcasePreset(id: "crt", title: "Signal Lost", subtitle: "Swirl through CRTScreen and Glitch", symbol: "tv", layers: [
            Glitch(intensity: 0.35, speed: 0.8, rgbShift: 4) {
                CRTScreen(pixelSize: 96, scanlineIntensity: 0.45, vignetteIntensity: 0.8) {
                    Swirl(colorA: "#00ff9c", colorB: "#020d08", speed: 0.8, detail: 2.4)
                }
            }.node,
        ]),
        ShowcasePreset(id: "prism", title: "Prism", subtitle: "Prism with a LensFlare in Screen mode", symbol: "rays", layers: [
            ShadersKit.LinearGradient(colorA: "#02010a", colorB: "#0f0c29", angle: 90).node,
            Prism(intensity: 2, spread: 0.9, speed: 0.15).node,
            LensFlare(lightPosition: ShaderPosition(x: 0.18, y: 0.18), intensity: 0.7).blendMode(.screen),
        ]),
        ShowcasePreset(id: "marble", title: "Fluted Marble", subtitle: "Marble behind FlutedGlass", symbol: "square.split.bottomrightquarter", layers: [
            FlutedGlass(frequency: 12, refraction: 2, aberration: 0.35, highlight: 0.35) {
                Marble(colorA: "#f8f9fa", colorB: "#7b2cbf", colorC: "#10002b", scale: 2.5, turbulence: 14, speed: 0.08)
            }.node,
        ]),
        ShowcasePreset(id: "strands", title: "Light Strands", subtitle: "Strands with a warm LightLeak", symbol: "waveform.path", layers: [
            SolidColor(color: "#05030f").node,
            LightLeak(intensity: 0.35, streaks: 0.8) {
                Strands(amplitude: 2.4, lineCount: 12, lineWidth: 0.04, spread: 0.3)
            }.node,
        ]),
        ShowcasePreset(id: "sunburst", title: "Sunburst Pop", subtitle: "SunBurst and Spiral in Soft Light", symbol: "sun.max", layers: [
            Vignette(radius: 0.8, intensity: 0.6) {
                SunBurst(color: "#ffe066", background: "#ff006e", rayCount: 20, softness: 0.4, radius: 1, speed: 0.25)
                Spiral(colorA: "#000000", colorB: "#ffffff", strokeWidth: 0.6, softness: 0.6, speed: 0.6, scale: 1.4)
                    .blendMode(.softLight)
                    .opacity(0.6)
            }.node,
        ]),
        ShowcasePreset(id: "cubes", title: "Isometric Dream", subtitle: "IsometricCubes recolored by GradientMap", symbol: "cube", layers: [
            GradientMap(palette: .sunset, speed: 0.3) {
                IsometricCubes(cells: 7, thickness: 1.5, colorVariation: 1)
            }.node,
        ]),
    ]
}
