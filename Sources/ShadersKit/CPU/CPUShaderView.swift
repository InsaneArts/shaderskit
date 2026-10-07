#if os(watchOS)
import SwiftUI

/// watchOS host view: drives the CPU rasterizer on a timer and displays the resulting image.
struct CPUShaderView: View {
    var nodes: [ShaderNode]
    var options: RenderOptions
    var isPaused: Bool
    var fps: Int
    var onFrame: ((FrameStats) -> Void)?

    @State private var renderer = CPURenderer()
    @State private var start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, fps)), paused: isPaused)) { context in
                let size = geo.size
                let scale = CPURenderer.renderScale(for: size)
                let px = SIMD2<Float>(Float(size.width * scale), Float(size.height * scale))
                let frame = FrameInput(
                    time: Float(context.date.timeIntervalSince(start)),
                    deltaTime: Float(1.0 / Double(max(1, fps))),
                    pixelSize: px,
                    logicalSize: SIMD2(Float(size.width), Float(size.height)),
                    pointer: SIMD2(0.5, 0.5),
                    pointerActive: false
                )
                if let image = renderer.renderImage(nodes, frame: frame, options: options) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: size.width, height: size.height)
                        .onAppear { onFrame?(renderer.stats) }
                } else {
                    Color.clear
                }
            }
        }
    }
}
#endif
