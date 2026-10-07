#if canImport(Metal)
import Foundation
import Metal
import MetalKit
import CoreGraphics
import ImageIO

/// Loads image media for `ImageTexture`-style layers into Metal textures (asynchronously for
/// remote URLs) and caches them by source string.
final class MediaLoader {
    private let device: ShaderDevice
    private let loader: MTKTextureLoader
    private var textures: [String: MTLTexture] = [:]
    private var pending: Set<String> = []
    private let lock = NSLock()

    init(device: ShaderDevice) {
        self.device = device
        loader = MTKTextureLoader(device: device.device)
    }

    nonisolated(unsafe) private static var shared: [ObjectIdentifier: MediaLoader] = [:]
    private static let sharedLock = NSLock()

    /// One loader (and texture cache) per device.
    static func shared(for device: ShaderDevice) -> MediaLoader {
        sharedLock.lock(); defer { sharedLock.unlock() }
        if let l = shared[ObjectIdentifier(device)] { return l }
        let l = MediaLoader(device: device)
        shared[ObjectIdentifier(device)] = l
        return l
    }

    /// Texture for a source string, or nil while loading / when missing.
    func texture(forSource source: String) -> MTLTexture? {
        lock.lock()
        if let t = textures[source] {
            lock.unlock()
            return t
        }
        let alreadyPending = pending.contains(source)
        if !alreadyPending { pending.insert(source) }
        lock.unlock()
        if !alreadyPending { load(source) }
        return nil
    }

    /// Registers an already-decoded image under a source key (used by the demo for bundled assets).
    func register(_ texture: MTLTexture, for source: String) {
        lock.lock()
        textures[source] = texture
        lock.unlock()
    }

    private func load(_ source: String) {
        let finish: (CGImage?) -> Void = { [weak self] image in
            guard let self else { return }
            var tex: MTLTexture? = nil
            if let image {
                // Linear (non-sRGB) format: the shader applies the sRGB EOTF itself (upstream decode mode).
                tex = try? self.loader.newTexture(cgImage: image, options: [.SRGB: false, .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue), .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue), .origin: MTKTextureLoader.Origin.topLeft.rawValue])
            }
            self.lock.lock()
            if let tex { self.textures[source] = tex }
            self.pending.remove(source)
            self.lock.unlock()
        }
        if source.hasPrefix("http://") || source.hasPrefix("https://"), let url = URL(string: source) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                finish(data.flatMap(MediaLoader.decode))
            }.resume()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var data: Data? = nil
            if source.hasPrefix("data:") {
                if let comma = source.firstIndex(of: ",") {
                    data = Data(base64Encoded: String(source[source.index(after: comma)...]))
                }
            } else if let url = URL(string: source), url.isFileURL {
                data = try? Data(contentsOf: url)
            } else {
                data = try? Data(contentsOf: URL(fileURLWithPath: source))
                if data == nil, let url = Bundle.main.url(forResource: source, withExtension: nil) {
                    data = try? Data(contentsOf: url)
                }
            }
            finish(data.flatMap(MediaLoader.decode))
        }
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: false] as CFDictionary)
    }
}

/// Public media helpers.
public enum ShaderMedia {
    /// Makes `image` available to `ImageTexture` layers whose `url` prop equals `source`
    /// (any string, e.g. `"asset:hero"`). The image is treated as sRGB-encoded like a decoded file.
    public static func registerImage(_ image: CGImage, for source: String, device: ShaderDevice? = ShaderDevice.shared) {
        guard let device else { return }
        let loader = MediaLoader.shared(for: device)
        let mtk = MTKTextureLoader(device: device.device)
        guard let tex = try? mtk.newTexture(cgImage: image, options: [.SRGB: false, .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue), .origin: MTKTextureLoader.Origin.topLeft.rawValue]) else { return }
        loader.register(tex, for: source)
    }
}
#endif
