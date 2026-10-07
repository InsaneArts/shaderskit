#if canImport(Metal)
import Foundation
import Metal
import CoreVideo
import QuartzCore

/// Wraps `CVMetalTextureCache`: turns decoded BGRA pixel buffers (video, camera) into Metal
/// textures without a copy. Linear `bgra8Unorm` format: the shader applies the sRGB EOTF itself.
final class PixelBufferTextureCache {
    private let cache: CVMetalTextureCache

    init?(device: MTLDevice) {
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess, let cache else { return nil }
        self.cache = cache
    }

    func texture(from buffer: CVPixelBuffer) -> CVMetalTexture? {
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        var tex: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, nil, .bgra8Unorm, w, h, 0, &tex) == kCVReturnSuccess else { return nil }
        return tex
    }
}

extension MTLCommandBuffer {
    /// Keeps a `CVMetalTexture` (and its pixel buffer) alive until the GPU has finished with it.
    func keepAlive(_ texture: CVMetalTexture) {
        addCompletedHandler { _ in withExtendedLifetime(texture) {} }
    }
}

/// Calls `onIdle` once when `touch()` has not been called for `timeout` seconds. The media
/// programs use it to pause playback / capture when their node stops rendering.
final class IdleWatchdog {
    private let lock = NSLock()
    private var last = CACurrentMediaTime()
    private var idle = false
    private let timer: DispatchSourceTimer

    init(timeout: CFTimeInterval = 1, queue: DispatchQueue, onIdle: @escaping () -> Void) {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.25, repeating: 0.25)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let fire = !self.idle && CACurrentMediaTime() - self.last > timeout
            if fire { self.idle = true }
            self.lock.unlock()
            if fire { onIdle() }
        }
        timer.resume()
    }

    deinit {
        timer.cancel()
    }

    /// Records a rendered frame. Returns true when the program was idle (the caller resumes).
    func touch() -> Bool {
        lock.lock(); defer { lock.unlock() }
        last = CACurrentMediaTime()
        let wasIdle = idle
        idle = false
        return wasIdle
    }
}

/// A CPU-writable 2D texture (shared storage, managed on discrete-GPU Macs).
func makeUploadTexture(_ device: MTLDevice, format: MTLPixelFormat, width: Int, height: Int, label: String) -> MTLTexture? {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
    d.usage = .shaderRead
    #if os(macOS)
    d.storageMode = device.hasUnifiedMemory ? .shared : .managed
    #else
    d.storageMode = .shared
    #endif
    let t = device.makeTexture(descriptor: d)
    t?.label = label
    return t
}
#endif
