import Testing
import Foundation
import simd
@testable import ShadersKit

#if canImport(Metal) && !os(watchOS)
import Metal
import AVFoundation
import SwiftUI
import ImageIO

/// Reads a bgra8Unorm texture into (r, g, b, a) pixels in 0...1, row-major from the top.
private func pixels(_ tex: MTLTexture) -> [SIMD4<Float>] {
    var bytes = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
    tex.getBytes(&bytes, bytesPerRow: tex.width * 4, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
    return stride(from: 0, to: bytes.count, by: 4).map { (i: Int) -> SIMD4<Float> in
        let v = SIMD4<Float>(Float(bytes[i + 2]), Float(bytes[i + 1]), Float(bytes[i]), Float(bytes[i + 3]))
        return v / 255
    }
}

private func centerPixel(_ tex: MTLTexture) -> SIMD4<Float> {
    pixels(tex)[(tex.height / 2) * tex.width + tex.width / 2]
}

/// Renders `node` until the center pixel is visible (media loads asynchronously) or the attempts run out.
private func renderUntilVisible(_ renderer: ShaderRenderer, _ node: ShaderNode, size: SIMD2<Float> = SIMD2(64, 64), attempts: Int = 100) async throws -> MTLTexture {
    var tex: MTLTexture? = nil
    for _ in 0..<attempts {
        tex = renderer.renderOffscreen([node], frame: FrameInput(pixelSize: size))
        if let t = tex, centerPixel(t).w > 0.5 { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    return try #require(tex)
}

@Suite("Media programs", .serialized)
struct MediaTests {
    let device = ShaderDevice.shared

    // MARK: Text

    private func textOutputs(_ props: [String: PropValue], size: SIMD2<Float> = SIMD2(256, 128)) throws -> MediaOutputs {
        let device = try #require(device)
        let desc = try #require(ShaderRegistry.descriptor("Text"))
        var merged = desc.defaultProps
        for (k, v) in props { merged[k] = v }
        let cb = try #require(device.queue.makeCommandBuffer())
        let ctx = MediaContext(device: device, descriptor: desc, frame: FrameInput(pixelSize: size), props: merged, commandBuffer: cb, width: Int(size.x), height: Int(size.y), state: NodeState(), options: RenderOptions())
        return try TextMediaProgram(context: ctx).encode(ctx)
    }

    @Test("Text rasterizes glyphs and reports the padded box half-extents")
    func textRaster() throws {
        let out = try textOutputs(["text": "Hello", "fontSize": 0.2])
        let tex = try #require(out.textures["media_0"])
        var alpha = [UInt8](repeating: 0, count: tex.width * tex.height)
        tex.getBytes(&alpha, bytesPerRow: tex.width, from: MTLRegionMake2D(0, 0, tex.width, tex.height), mipmapLevel: 0)
        #expect(alpha.filter { $0 > 128 }.count > 100)
        #expect(alpha[0] == 0) // padding around the block stays empty

        let halfW = try #require(out.extraFields["halfW"]?.first)
        let halfH = try #require(out.extraFields["halfH"]?.first)
        // One line: (lineHeight 1.2 + 2 × 0.25 padding) × fontSize / 2, in canvas-height units.
        #expect(abs(halfH - 1.7 * 0.2 / 2) < 0.01, "halfH \(halfH)")
        #expect(halfW > halfH && halfW < 0.6, "halfW \(halfW)")
        // The raster is supersampled 3× over the canvas density.
        #expect(abs(Float(tex.height) - halfH * 2 * 128 * 3) <= 1)

        func half(_ props: [String: PropValue]) throws -> SIMD2<Float> {
            let o = try textOutputs(props)
            return SIMD2(try #require(o.extraFields["halfW"]?.first), try #require(o.extraFields["halfH"]?.first))
        }
        #expect(try half(["text": "Hello\nWorld", "fontSize": 0.2]).y > halfH * 1.5)
        let wrapped = try half(["text": "Hello Hello Hello", "fontSize": 0.2, "width": 0.3])
        let unwrapped = try half(["text": "Hello Hello Hello", "fontSize": 0.2])
        #expect(wrapped.y > unwrapped.y * 1.5)
        #expect(wrapped.x < unwrapped.x)
        #expect(try half(["text": "hello", "fontSize": 0.2, "textTransform": "uppercase"]).x > halfW)
        let px = try half(["text": "Hello", "fontSize": .dimensional(DimensionalValue(value: 25.6, unit: .px))])
        #expect(abs(px.y - halfH) < 1e-4)
    }

    @Test("Text renders white glyphs at the center of the canvas")
    func textRender() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false))
        let node = ShaderNode(type: "Text", props: ["text": "Hello", "fontSize": 0.3, "color": "#ffffff"])
        let tex = try #require(renderer.renderOffscreen([node], frame: FrameInput(pixelSize: SIMD2(256, 128))))
        #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
        #expect(!renderer.stats.unsupportedNodes.contains("Text"))
        let px = pixels(tex)
        let inked = px.filter { $0.w > 0.9 }
        #expect(inked.count > 200)
        #expect(inked.allSatisfy { $0.x > 0.9 && $0.y > 0.9 && $0.z > 0.9 })
        #expect(px[0].w == 0)
        #expect(px[255].w == 0)
    }

    @Test("TEMP dump text")
    func tempDump() throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear, premultiplyAlpha: false, backgroundColor: SIMD4(0, 0, 0, 1)))
        let dir = "/private/tmp/claude-501/-Users-tgomareli-Development-shaders/34781fec-54ba-4a48-872d-8ead05d949c1/scratchpad/textdump"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cases: [(String, [String: PropValue])] = [
            ("default", ["text": "Hello World g"]),
            ("bold-italic", ["text": "Bold Italic gjy", "fontWeight": 800, "italic": true, "fontSize": 0.12]),
            ("serif-wrap-left", ["text": "The quick brown fox jumps over the lazy dog", "fontFamily": "Playfair Display", "width": 0.5, "textAlign": "left", "fontSize": 0.08]),
            ("mono-spaced-rot", ["text": "MONO 123", "fontFamily": "JetBrains Mono", "letterSpacing": 0.2, "rotation": 15, "fontSize": 0.1]),
            ("georgia-italic-right", ["text": "Georgia\nright aligned", "fontFamily": "Georgia", "italic": true, "textAlign": "right", "fontSize": 0.1, "center": .position(.xy(x: .number(0.3), y: .number(0.3)))]),
            ("script-capitalize", ["text": "hello script world", "fontFamily": "Pacifico", "textTransform": "capitalize", "fontSize": 0.1]),
        ]
        for (name, props) in cases {
            let tex = try #require(renderer.renderOffscreen([ShaderNode(type: "Text", props: props)], frame: FrameInput(pixelSize: SIMD2(512, 256))))
            var bytes = [UInt8](repeating: 0, count: 512 * 256 * 4)
            tex.getBytes(&bytes, bytesPerRow: 512 * 4, from: MTLRegionMake2D(0, 0, 512, 256), mipmapLevel: 0)
            let ctx = CGContext(data: &bytes, width: 512, height: 256, bitsPerComponent: 8, bytesPerRow: 512 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            let img = ctx.makeImage()!
            let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(dir)/\(name).png") as CFURL, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, img, nil)
            CGImageDestinationFinalize(dest)
        }
    }

    // MARK: Image

    @Test("ImageTexture shows a data: URL image once it has loaded")
    func imageDataURL() async throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        let red = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII="
        let tex = try await renderUntilVisible(renderer, ShaderNode(type: "ImageTexture", props: ["url": .string(red)]))
        let p = centerPixel(tex)
        #expect(p.w > 0.99)
        #expect(p.x > 0.98 && p.y < 0.02 && p.z < 0.02, "\(p)")
        #expect(renderer.stats.compileErrors.isEmpty)
    }

    // MARK: Video

    @Test("VideoTexture plays a local file")
    func videoPlays() async throws {
        let device = try #require(device)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shaderskit-red-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        try await writeSplitVideo(to: url)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        let tex = try await renderUntilVisible(renderer, ShaderNode(type: "VideoTexture", props: ["url": .string(url.path)]))
        let px = pixels(tex)
        let top = px[8 * 64 + 32], bottom = px[56 * 64 + 32]
        #expect(top.w > 0.99 && bottom.w > 0.99)
        #expect(top.x > 0.85 && top.y < 0.15 && top.z < 0.15, "top \(top)")
        #expect(bottom.z > 0.85 && bottom.x < 0.15 && bottom.y < 0.15, "bottom \(bottom)")
        #expect(renderer.stats.compileErrors.isEmpty)
        #expect(!renderer.stats.unsupportedNodes.contains("VideoTexture"))
    }

    @Test("VideoTexture with a missing file renders nothing and reports no error")
    func videoMissingFile() async throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device)
        let node = ShaderNode(type: "VideoTexture", props: ["url": "/nonexistent/missing.mp4"])
        for _ in 0..<5 {
            let tex = try #require(renderer.renderOffscreen([node], frame: FrameInput(pixelSize: SIMD2(32, 32))))
            #expect(centerPixel(tex).w == 0)
            #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        renderer.resetState()
    }

    // MARK: Webcam

    @Test("WebcamTexture without camera access renders nothing and reports no error")
    func webcamWithoutPermission() async throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device)
        for _ in 0..<5 {
            _ = renderer.renderOffscreen([ShaderNode(type: "WebcamTexture")], frame: FrameInput(pixelSize: SIMD2(32, 32)))
            #expect(renderer.stats.compileErrors.isEmpty, "\(renderer.stats.compileErrors)")
            #expect(!renderer.stats.unsupportedNodes.contains("WebcamTexture"))
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        renderer.resetState()
    }

    // MARK: View texture

    @MainActor
    @Test("HTMLInCanvas samples a registered SwiftUI view")
    func viewTexture() async throws {
        let device = try #require(device)
        let renderer = ShaderRenderer(device: device, options: RenderOptions(colorSpace: .sRGBLinear))
        ViewTextureRegistry.shared.register(id: "media-test") {
            VStack(spacing: 0) {
                Color(red: 1, green: 0, blue: 0)
                Color(red: 0, green: 0, blue: 1)
            }
        }
        defer { ViewTextureRegistry.shared.unregister(id: "media-test") }
        let node = ShaderNode(type: "HTMLInCanvas").prop("source", "media-test")
        let tex = try await renderUntilVisible(renderer, node)
        let px = pixels(tex)
        let top = px[8 * 64 + 32], bottom = px[56 * 64 + 32]
        #expect(top.w > 0.99 && bottom.w > 0.99)
        #expect(top.x > 0.95 && top.y < 0.05 && top.z < 0.05, "top \(top)")
        #expect(bottom.z > 0.95 && bottom.x < 0.05 && bottom.y < 0.05, "bottom \(bottom)")
        #expect(renderer.stats.compileErrors.isEmpty)

        let missing = try #require(renderer.renderOffscreen([ShaderNode(type: "HTMLInCanvas").prop("source", "not-registered")], frame: FrameInput(pixelSize: SIMD2(64, 64))))
        #expect(centerPixel(missing).w == 0)
    }
}

/// Writes a one-second 64×64 H.264 movie: top half red, bottom half blue.
private func writeSplitVideo(to url: URL) async throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 64,
        kCVPixelBufferHeightKey as String: 64,
    ])
    writer.add(input)
    #expect(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<30 {
        while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pb = try #require(buffer)
        CVPixelBufferLockBaseAddress(pb, [])
        let base = try #require(CVPixelBufferGetBaseAddress(pb)).assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(pb)
        for y in 0..<64 {
            for x in 0..<64 {
                let o = y * rowBytes + x * 4
                let red = y < 32
                base[o] = red ? 0 : 255; base[o + 1] = 0; base[o + 2] = red ? 255 : 0; base[o + 3] = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])
        #expect(adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)))
    }
    input.markAsFinished()
    await writer.finishWriting()
    #expect(writer.status == .completed, "\(String(describing: writer.error))")
}
#endif
