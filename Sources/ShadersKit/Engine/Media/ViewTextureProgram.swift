#if canImport(Metal)
import Foundation
import Metal
import SwiftUI
import Accelerate
import QuartzCore

/// SwiftUI views for `HTMLInCanvas` layers (the native stand-in for upstream's DOM capture).
/// Register a view under a source name and point a layer at it with `.prop("source", "<name>")`:
///
///     ViewTextureRegistry.shared.register(id: "badge") { BadgeView() }
///     ShaderNode(type: "HTMLInCanvas").prop("source", "badge")
///
/// The view is rendered with `ImageRenderer` at the layer's size about 10 times a second, and
/// right away after `register` or `invalidate`.
public final class ViewTextureRegistry: @unchecked Sendable {
    public static let shared = ViewTextureRegistry()

    private struct Entry {
        var content: @MainActor () -> AnyView
        var version: Int
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var nextVersion = 0

    public init() {}

    /// Registers (or replaces) the view rendered by `HTMLInCanvas` layers whose `source` prop is `id`.
    public func register<Content: View>(id: String, @ViewBuilder content: @escaping @MainActor () -> Content) {
        lock.lock(); defer { lock.unlock() }
        nextVersion += 1
        entries[id] = Entry(content: { AnyView(content()) }, version: nextVersion)
    }

    public func unregister(id: String) {
        lock.lock(); defer { lock.unlock() }
        entries[id] = nil
    }

    /// Re-renders the view on the next frame instead of waiting for the periodic refresh.
    public func invalidate(id: String) {
        lock.lock(); defer { lock.unlock() }
        guard entries[id] != nil else { return }
        nextVersion += 1
        entries[id]?.version = nextVersion
    }

    func version(of id: String) -> Int? {
        lock.lock(); defer { lock.unlock() }
        return entries[id]?.version
    }

    func content(of id: String) -> (@MainActor () -> AnyView)? {
        lock.lock(); defer { lock.unlock() }
        return entries[id]?.content
    }
}

/// `HTMLInCanvas`: samples a SwiftUI view from `ViewTextureRegistry` (looked up by the layer's
/// `source` prop) as `media_0`. The view is rendered on the main actor without blocking the render
/// thread, then uploaded as straight-alpha sRGB-encoded bgra8Unorm (the shader decodes sRGB).
final class ViewTextureProgram: MediaProgram {
    static let shaderNames = ["HTMLInCanvas"]
    static let refreshInterval: CFTimeInterval = 0.1

    private let device: MTLDevice
    private let registry: ViewTextureRegistry
    private let workQueue = DispatchQueue(label: "ShadersKit.ViewTextureProgram")

    private let lock = NSLock()
    private var texture: MTLTexture? // guarded by `lock`
    private var inFlight = false // guarded by `lock`

    // Render-thread state.
    private var requestedKey: String?
    private var lastRequest: CFTimeInterval = 0

    init(context: MediaContext) throws {
        device = context.device.device
        registry = .shared
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        guard let source = ctx.string("source"), let version = registry.version(of: source) else {
            requestedKey = nil
            lock.lock(); texture = nil; lock.unlock()
            return MediaOutputs()
        }
        let width = ctx.width, height = ctx.height
        let key = "\(source)|\(version)|\(width)x\(height)"
        let now = CACurrentMediaTime()
        lock.lock()
        let due = !inFlight && (key != requestedKey || now - lastRequest >= Self.refreshInterval)
        if due { inFlight = true }
        let current = texture
        lock.unlock()
        if due {
            requestedKey = key
            lastRequest = now
            let logical = CGSize(width: CGFloat(ctx.frame.logicalSize.x), height: CGFloat(ctx.frame.logicalSize.y))
            request(source: source, width: width, height: height, logical: logical)
        }
        // After a resize the previous raster stays bound (stretched) until the new one lands.
        guard let current else { return MediaOutputs() }
        return MediaOutputs(textures: ["media_0": current])
    }

    /// Renders on the main actor, converts and uploads on a background queue.
    private func request(source: String, width: Int, height: Int, logical: CGSize) {
        let registry = registry
        DispatchQueue.main.async { [weak self] in
            let image: CGImage? = MainActor.assumeIsolated {
                guard let content = registry.content(of: source) else { return nil }
                let points = logical.width > 0 && logical.height > 0 ? logical : CGSize(width: width, height: height)
                let renderer = ImageRenderer(content: content().frame(width: points.width, height: points.height))
                renderer.proposedSize = ProposedViewSize(points)
                renderer.scale = CGFloat(width) / points.width
                renderer.isOpaque = false
                return renderer.cgImage
            }
            guard let self else { return }
            self.workQueue.async {
                let tex = image.flatMap { self.upload($0, width: width, height: height) }
                self.lock.lock()
                if let tex { self.texture = tex }
                self.inFlight = false
                self.lock.unlock()
            }
        }
    }

    /// Draws the image at exactly width×height in sRGB and un-premultiplies it (the shader expects
    /// straight alpha, like upstream's element capture).
    private func upload(_ image: CGImage, width: Int, height: Int) -> MTLTexture? {
        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buf in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let cg = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
            cg.interpolationQuality = .high
            cg.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var v = vImage_Buffer(data: buf.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            // Alpha is the last byte (BGRA), so the RGBA routine applies unchanged.
            vImageUnpremultiplyData_RGBA8888(&v, &v, vImage_Flags(kvImageNoFlags))
            return true
        }
        guard drawn, let tex = makeUploadTexture(device, format: .bgra8Unorm, width: width, height: height, label: "HTMLInCanvas:view") else { return nil }
        pixels.withUnsafeBytes { tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes) }
        return tex
    }
}
#endif
