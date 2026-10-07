import Foundation
import QuartzCore
import ShadersKit

/// `-perfLog YES`: counts frames delivered by every live gallery card and the ambient
/// background, and prints per-view frame rates every 3 seconds.
final class PerfLog {
    static let shared: PerfLog? = UserDefaults.standard.bool(forKey: "perfLog") ? PerfLog() : nil

    private var counts: [String: Int] = [:]
    private var start = CACurrentMediaTime()

    func tick(_ id: String) {
        counts[id, default: 0] += 1
        let now = CACurrentMediaTime()
        let elapsed = now - start
        guard elapsed >= 3 else { return }
        let rates = counts.map { ($0.key, Double($0.value) / elapsed) }.sorted { $0.0 < $1.0 }
        let avg = rates.isEmpty ? 0 : rates.map(\.1).reduce(0, +) / Double(rates.count)
        let summary = rates.map { "\($0.0)=\(Int($0.1.rounded()))" }.joined(separator: " ")
        print("[ShadersDemo perf] views=\(rates.count) avgFPS=\(String(format: "%.1f", avg)) \(summary)")
        counts.removeAll()
        start = now
    }

    /// `onFrame` closure for a view, or nil when logging is off (no per-frame overhead).
    static func onFrame(_ id: String) -> ((FrameStats) -> Void)? {
        guard let log = shared else { return nil }
        return { _ in log.tick(id) }
    }
}
