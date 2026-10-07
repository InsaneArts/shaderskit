import SwiftUI
import ShadersKit

/// Dim animated shader behind navigation surfaces, tuned for light and dark appearance.
struct AmbientBackground: View {
    enum Style { case aurora, flow }

    var style: Style = .aurora
    var isPaused = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            base
            ShaderCanvas(nodes: nodes, isPaused: isPaused, fps: 30, onFrame: PerfLog.onFrame("ambient"))
                .opacity(scheme == .dark ? 0.6 : 0.45)
            LinearGradient(colors: scrim, startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var base: Color {
        scheme == .dark ? Color(red: 0.03, green: 0.03, blue: 0.06) : Color(red: 0.96, green: 0.95, blue: 0.99)
    }

    private var scrim: [Color] {
        scheme == .dark
            ? [Color.black.opacity(0.0), Color.black.opacity(0.35), Color.black.opacity(0.6)]
            : [Color.white.opacity(0.0), Color.white.opacity(0.35), Color.white.opacity(0.6)]
    }

    private var nodes: [ShaderNode] {
        switch (style, scheme) {
        case (.aurora, .dark):
            return [Aurora(colorA: "#7b2ff7", colorB: "#1fd1a5", colorC: "#2b6cff", intensity: 70, speed: 2.5, height: 140).node]
        case (.aurora, _):
            return [FlowingGradient(colorA: "#f5ecff", colorB: "#c9b6ff", colorC: "#ffc4dd", colorD: "#b8e6ff", colorSpace: .linear, speed: 0.4, distortion: 0.6).node]
        case (.flow, .dark):
            return [FlowingGradient(colorA: "#05010d", colorB: "#3a0ca3", colorC: "#7209b7", colorD: "#0b4f6c", colorSpace: .linear, speed: 0.35, distortion: 0.7).node]
        case (.flow, _):
            return [FlowingGradient(colorA: "#fdfbff", colorB: "#d6ccff", colorC: "#ffd6e8", colorD: "#cdeeff", colorSpace: .linear, speed: 0.35, distortion: 0.7).node]
        }
    }
}
