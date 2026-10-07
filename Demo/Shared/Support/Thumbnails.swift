import SwiftUI
import ShadersKit
import CoreGraphics

/// A rendered still of a node tree.
final class Thumbnail {
    let image: CGImage
    /// True when nothing visible was drawn (compute-backed, pointer-driven or media components).
    let isBlank: Bool

    init(image: CGImage, isBlank: Bool) {
        self.image = image
        self.isBlank = isBlank
    }
}

/// Renders snapshots off the main thread with `ShaderRenderer.renderImage`. Rendering a
/// component also compiles its Metal library, so a card's live view starts without a hitch
/// once its snapshot exists.
final class ThumbnailRenderer: @unchecked Sendable {
    static let shared = ThumbnailRenderer()

    private let cache = NSCache<NSString, Thumbnail>()
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var idle: [ShaderRenderer] = []

    private init() {
        cache.countLimit = 500
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        queue.name = "ShadersDemo.thumbnails"
    }

    func cached(_ key: String) -> Thumbnail? {
        cache.object(forKey: key as NSString)
    }

    /// Returns the cached snapshot or renders one. Cancelled requests are skipped, so fast
    /// scrolling does not queue work for cards that already left the screen.
    func thumbnail(key: String, nodes: [ShaderNode], size: CGSize, scale: CGFloat = 2, time: Float = 2.5) async -> Thumbnail? {
        if let hit = cached(key) { return hit }
        let flag = CancelFlag()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Thumbnail?, Never>) in
                queue.addOperation { [self] in
                    if flag.isCancelled {
                        continuation.resume(returning: nil)
                        return
                    }
                    if let hit = cached(key) {
                        continuation.resume(returning: hit)
                        return
                    }
                    let result = render(nodes, size: size, scale: scale, time: time)
                    if let result { cache.setObject(result, forKey: key as NSString) }
                    continuation.resume(returning: result)
                }
            }
        } onCancel: {
            flag.cancel()
        }
    }

    /// Synchronous render on the caller's thread (exports).
    func renderNow(_ nodes: [ShaderNode], size: CGSize, scale: CGFloat, time: Float) -> CGImage? {
        render(nodes, size: size, scale: scale, time: time)?.image
    }

    private func render(_ nodes: [ShaderNode], size: CGSize, scale: CGFloat, time: Float) -> Thumbnail? {
        guard let device = ShaderDevice.shared else { return nil }
        lock.lock()
        let renderer = idle.popLast() ?? ShaderRenderer(device: device)
        lock.unlock()
        defer {
            lock.lock()
            idle.append(renderer)
            lock.unlock()
        }
        renderer.resetState()
        guard let image = renderer.renderImage(nodes, size: size, scale: scale, time: time) else { return nil }
        return Thumbnail(image: image, isBlank: Self.isBlank(image))
    }

    /// Samples the image: blank when almost every pixel is transparent or black.
    static func isBlank(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return false }
        let length = CFDataGetLength(data)
        let bpr = image.bytesPerRow
        let step = max(1, image.height / 24)
        let xStep = max(1, image.width / 24)
        var lit = 0
        var samples = 0
        var y = 0
        while y < image.height {
            var x = 0
            while x < image.width {
                let i = y * bpr + x * 4
                if i + 3 < length {
                    samples += 1
                    // BGRA premultiplied: any channel above ~3% counts as drawn
                    if max(bytes[i], bytes[i + 1], bytes[i + 2]) > 8 { lit += 1 }
                }
                x += xStep
            }
            y += step
        }
        return samples == 0 || Double(lit) / Double(samples) < 0.01
    }
}

private final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// Shows a cached snapshot of a node tree, rendering it on demand.
struct SnapshotImage: View {
    let key: String
    let nodes: [ShaderNode]
    var size = CGSize(width: 240, height: 180)
    /// Renders again after a delay when the first result is blank (remote media loading).
    var retryIfBlank = false
    @State private var thumbnail: Thumbnail?

    var body: some View {
        ZStack {
            if let thumbnail, !thumbnail.isBlank {
                Image(decorative: thumbnail.image, scale: 2)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            thumbnail = await ThumbnailRenderer.shared.thumbnail(key: key, nodes: nodes, size: size)
            if retryIfBlank, thumbnail?.isBlank == true {
                try? await Task.sleep(for: .seconds(2.5))
                if Task.isCancelled { return }
                thumbnail = await ThumbnailRenderer.shared.thumbnail(key: key + ":retry", nodes: nodes, size: size)
            }
        }
    }
}
