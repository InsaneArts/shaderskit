import SwiftUI
import QuartzCore
import ShadersKit

/// Measures frames per second from `ShaderView.onFrame` and republishes stats twice a second,
/// so the HUD does not invalidate SwiftUI on every frame.
@Observable
final class FrameMeter {
    private(set) var fps: Double = 0
    private(set) var stats = FrameStats()

    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var windowStart: CFTimeInterval = 0

    func record(_ stats: FrameStats) {
        let now = CACurrentMediaTime()
        if windowStart == 0 { windowStart = now }
        frames += 1
        let elapsed = now - windowStart
        if elapsed >= 0.5 {
            fps = Double(frames) / elapsed
            if self.stats != stats { self.stats = stats }
            frames = 0
            windowStart = now
        }
    }
}
