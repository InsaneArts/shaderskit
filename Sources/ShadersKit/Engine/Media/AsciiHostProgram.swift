#if canImport(Metal)
import Foundation
import Metal
import CoreText
import CoreGraphics

/// Ascii (shaders/Ascii `setupGlyphAtlas`): rasterizes the `characters` string into a fixed
/// 2048² RGBA glyph atlas (white glyphs centred in an `atlasSize`² grid of cells) bound as
/// `media_1`, and publishes `_charCount`, `_atlasScale` and `_atlasSize`. Re-rasters only when
/// `characters`, `fontFamily` or `spacing` change. `media_0` (the child) is left to the renderer.
///
/// Upstream loads the Google font named by `fontFamily`; here an installed family of that name is
/// used, otherwise the system monospaced font.
final class AsciiHostProgram: MediaProgram {
    static let shaderNames = ["Ascii"]
    static let atlasTextureSize = 2048

    private struct Key: Equatable { var characters: String, fontFamily: String, spacing: Float }

    private let device: MTLDevice
    private var key: Key?
    private var atlas: MTLTexture?
    private var fields: [String: [Float]] = [:]

    init(context: MediaContext) throws {
        device = context.device.device
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let k = Key(characters: ctx.string("characters") ?? "@%#*+=-:.",
                    fontFamily: ctx.string("fontFamily") ?? "JetBrains Mono",
                    spacing: ctx.scalar("spacing"))
        if k != key {
            key = k
            build(k)
        }
        guard let atlas else { return MediaOutputs(extraFields: fields) }
        return MediaOutputs(textures: ["media_1": atlas], extraFields: fields)
    }

    /// A monospaced font for the family: the installed family itself when it is monospaced,
    /// otherwise the system monospaced font.
    static func font(family: String, size: CGFloat) -> CTFont {
        let named = TextFonts.font(family: family, weight: 400, italic: false, size: size)
        if CTFontGetSymbolicTraits(named).contains(.traitMonoSpace) { return named }
        return TextFonts.font(family: "JetBrains Mono", weight: 400, italic: false, size: size)
    }

    private func build(_ k: Key) {
        // Upstream returns early on an empty string and keeps the previous atlas and fields.
        let chars = k.characters.map(String.init)
        guard !chars.isEmpty else { return }
        let S = Self.atlasTextureSize
        let charCount = chars.count
        let atlasSize = max(2, Int(Double(charCount).squareRoot().rounded(.up)))
        let baseAtlasCellSize: Double = 128
        let spacingMultiplier = max(1, 2 / Double(k.spacing))
        let actualCellSize = min(baseAtlasCellSize * spacingMultiplier, Double(S) / Double(atlasSize))
        let fontSize = actualCellSize * 0.75

        var pixels = [UInt8](repeating: 0, count: S * S * 4)
        pixels.withUnsafeMutableBytes { buf in
            guard let cg = CGContext(data: buf.baseAddress, width: S, height: S, bitsPerComponent: 8, bytesPerRow: S * 4,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            cg.setShouldAntialias(true)
            cg.setAllowsFontSmoothing(false)
            cg.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            cg.textMatrix = .identity
            let font = Self.font(family: k.fontFamily, size: CGFloat(fontSize))
            // Canvas `textBaseline = 'middle'`: the em box's middle sits on the cell centre.
            let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
            let middleToBaseline = (ascent - descent) / 2
            for (i, ch) in chars.enumerated() {
                let row = i / atlasSize
                let col = i % atlasSize
                let cx = CGFloat(Double(col) * actualCellSize + actualCellSize / 2)
                let cy = CGFloat(Double(row) * actualCellSize + actualCellSize / 2)
                let line = TextMeasure.line(ch, font: font, kern: 0)
                let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                // CG origin is bottom-left; row 0 of the buffer is the top of the atlas.
                cg.textPosition = CGPoint(x: cx - w / 2, y: CGFloat(S) - (cy + middleToBaseline))
                CTLineDraw(line, cg)
            }
        }
        guard let tex = makeUploadTexture(device, format: .rgba8Unorm, width: S, height: S, label: "Ascii:atlas") else { return }
        pixels.withUnsafeBytes { tex.replace(region: MTLRegionMake2D(0, 0, S, S), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: S * 4) }
        // A fresh texture per raster: the previous one may still be in flight.
        atlas = tex
        let uvScale = (Double(atlasSize) * actualCellSize) / Double(S)
        fields = ["_charCount": [Float(charCount)], "_atlasScale": [Float(uvScale)], "_atlasSize": [Float(atlasSize)]]
    }
}
#endif
