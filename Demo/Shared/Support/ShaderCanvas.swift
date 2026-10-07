import SwiftUI
import ShadersKit

enum MetalSupport {
    /// False on hardware without Metal (the only place the demo touches `ShaderDevice.shared`).
    static var isAvailable: Bool { ShaderDevice.shared != nil }

    /// Builds the shared device (compiles the compositor library) off the main thread.
    static func warmUp() {
        DispatchQueue.global(qos: .userInitiated).async { _ = ShaderDevice.shared }
    }
}

/// `ShaderView` with a friendly fallback when Metal is unavailable.
struct ShaderCanvas: View {
    var nodes: [ShaderNode]
    var isPaused = false
    var fps = 60
    var onFrame: ((FrameStats) -> Void)? = nil

    var body: some View {
        if MetalSupport.isAvailable {
            ShaderView(nodes: nodes, isPaused: isPaused, preferredFramesPerSecond: fps, onFrame: onFrame)
        } else {
            MetalUnavailableView()
        }
    }
}

struct MetalUnavailableView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.title)
                Text("Metal unavailable")
                    .font(.headline)
                Text("This device has no Metal GPU, so shaders cannot render.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}
