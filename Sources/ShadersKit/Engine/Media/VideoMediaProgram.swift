#if canImport(Metal)
import Foundation
import Metal
import AVFoundation
import QuartzCore

/// `VideoTexture`: plays the `url` prop (http(s) URL, file path / file URL or bundle resource name)
/// with `AVPlayer`, muted and looping (the `loop` prop), and hands the current frame to the shader
/// as `video_0` through `AVPlayerItemVideoOutput` → `CVMetalTextureCache` (linear bgra8Unorm).
/// Playback pauses when the node has not rendered for a second and resumes on the next frame.
final class VideoMediaProgram: MediaProgram {
    static let shaderNames = ["VideoTexture"]

    private let textures: PixelBufferTextureCache
    private let player: AVPlayer
    /// Serializes every `AVPlayer` call (render thread, end-of-item notifications, idle timer).
    private let queue = DispatchQueue(label: "ShadersKit.VideoMediaProgram")
    private let notificationQueue: OperationQueue
    private var watchdog: IdleWatchdog?

    private let lock = NSLock()
    private var output: AVPlayerItemVideoOutput? // guarded by `lock`
    private var loops = true // guarded by `lock`

    // Render-thread state.
    private var source: String?
    private var current: CVMetalTexture?

    // `queue` state.
    private var endObserver: NSObjectProtocol?

    init(context: MediaContext) throws {
        guard let cache = PixelBufferTextureCache(device: context.device.device) else { throw ShaderEngineError.noMetalDevice }
        textures = cache
        player = AVPlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        notificationQueue = OperationQueue()
        notificationQueue.underlyingQueue = queue
        let player = self.player
        watchdog = IdleWatchdog(queue: queue) { player.pause() }
    }

    deinit {
        let player = player
        let observer = endObserver
        queue.async {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let loop = ctx.props["loop"]?.boolValue ?? true
        lock.lock()
        let loopChanged = loop != loops
        loops = loop
        lock.unlock()
        if loopChanged {
            queue.async { [player] in player.actionAtItemEnd = loop ? .none : .pause }
        }

        let src = ctx.string("url").flatMap { $0.isEmpty ? nil : $0 }
        if src != source {
            source = src
            current = nil
            load(src.flatMap(Self.url(forSource:)))
        }
        if watchdog?.touch() == true {
            queue.async { [player] in player.play() }
        }

        lock.lock()
        let out = output
        lock.unlock()
        if let out {
            let itemTime = out.itemTime(forHostTime: CACurrentMediaTime())
            if out.hasNewPixelBuffer(forItemTime: itemTime), let buffer = out.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil), let tex = textures.texture(from: buffer) {
                current = tex
            }
        }
        guard let current, let mtl = CVMetalTextureGetTexture(current) else { return MediaOutputs() }
        ctx.commandBuffer.keepAlive(current)
        return MediaOutputs(textures: ["video_0": mtl])
    }

    /// Swaps the player item for a new source (nil stops playback).
    private func load(_ url: URL?) {
        var newOutput: AVPlayerItemVideoOutput?
        var item: AVPlayerItem?
        if let url {
            let o = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ])
            let i = AVPlayerItem(url: url)
            i.add(o)
            newOutput = o
            item = i
        }
        lock.lock()
        output = newOutput
        let loop = loops
        lock.unlock()
        queue.async { [weak self] in
            guard let self else { return }
            if let observer = self.endObserver {
                NotificationCenter.default.removeObserver(observer)
                self.endObserver = nil
            }
            let player = self.player
            player.replaceCurrentItem(with: item)
            guard let item else { return }
            player.actionAtItemEnd = loop ? .none : .pause
            self.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: self.notificationQueue) { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                let loop = self.loops
                self.lock.unlock()
                if loop { player.seek(to: .zero) }
            }
            player.play()
        }
    }

    /// Resolves the `url` prop: http(s) and file URLs, absolute or relative paths, bundle resources.
    static func url(forSource source: String) -> URL? {
        if source.hasPrefix("http://") || source.hasPrefix("https://") || source.hasPrefix("file://") {
            return URL(string: source)
        }
        if FileManager.default.fileExists(atPath: source) {
            return URL(fileURLWithPath: source)
        }
        return Bundle.main.url(forResource: source, withExtension: nil)
    }
}
#endif
