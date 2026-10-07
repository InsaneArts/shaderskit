#if canImport(Metal) && !os(watchOS)
import Foundation
import Metal
import CoreGraphics

public extension ShaderRenderer {
    /// Renders the layer stack once into a `CGImage` (sRGB, premultiplied alpha). Useful for
    /// thumbnails, exports and tests. Blocks until the GPU finishes.
    func renderImage(_ nodes: [ShaderNode], size: CGSize, scale: CGFloat = 1, time: Float = 0, pointer: SIMD2<Float> = SIMD2(0.5, 0.5)) -> CGImage? {
        let w = max(1, Int(size.width * scale))
        let h = max(1, Int(size.height * scale))
        let frame = FrameInput(time: time, deltaTime: 1.0 / 60.0, pixelSize: SIMD2(Float(w), Float(h)), logicalSize: SIMD2(Float(size.width), Float(size.height)), pointer: pointer, pointerActive: false)
        guard let tex = renderOffscreen(nodes, frame: frame) else { return nil }
        return ShaderRenderer.cgImage(from: tex, colorSpace: options.colorSpace)
    }

    /// Converts a bgra8Unorm shared texture into a CGImage.
    static func cgImage(from tex: MTLTexture, colorSpace: ColorSpaceMode) -> CGImage? {
        let w = tex.width
        let h = tex.height
        let bytesPerRow = w * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * h)
        tex.getBytes(&bytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        let cs = colorSpace == .displayP3Linear ? (CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()) : CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: cs, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
#endif
