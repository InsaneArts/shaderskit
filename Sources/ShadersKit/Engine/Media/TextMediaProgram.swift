#if canImport(Metal)
import Foundation
import Metal
import CoreText
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// `Text`: lays the `text` prop out with CoreText (port of upstream `measureTextBlock` and the
/// Text glyph raster host), rasterizes white glyphs at 3× supersampling (capped at 4096 texels per
/// axis) into an alpha texture bound as `media_0`, and publishes the padded raster box
/// half-extents as the `halfW` / `halfH` extraFields. Re-rasterizes only when a glyph-affecting
/// prop or the canvas size changes; color, center and rotation are pure uniforms.
final class TextMediaProgram: MediaProgram {
    static let shaderNames = ["Text"]
    static let maxTextureAxis: CGFloat = 4096
    static let supersample: CGFloat = 3

    private let device: MTLDevice
    private var key: TextRasterSpec?
    private var outputs = MediaOutputs()

    init(context: MediaContext) throws {
        device = context.device.device
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let spec = TextRasterSpec(ctx)
        if spec != key {
            key = spec
            outputs = raster(spec)
        }
        return outputs
    }

    private func raster(_ p: TextRasterSpec) -> MediaOutputs {
        let fontSizePx = p.fontSizePx
        let wrapWidthPx = p.wrapWidthPx
        guard !p.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, fontSizePx > 0 else {
            return output(texture: upload(nil, width: 2, height: 2), halfW: 0.001, halfH: 0.001)
        }
        let font100 = TextFonts.font(family: p.fontFamily, weight: p.fontWeight, italic: p.italic, size: 100)
        let m = TextMeasure.block(text: p.text, transform: p.textTransform, font: font100, letterSpacingEm: p.letterSpacing, lineHeightEm: p.lineHeight, maxWidthPer100: wrapWidthPx > 0 ? wrapWidthPx * 100 / fontSizePx : 0)

        let f = fontSizePx / 100
        let contentWPx = max(1, (wrapWidthPx > 0 ? max(wrapWidthPx * 100 / fontSizePx, m.widthPer100) : m.widthPer100) * f)
        let pitchPx = m.pitchPer100 * f
        let lineBoxPx = max(1, fontSizePx * p.lineHeight)
        // Font-box block height: ascent + (n−1)·pitch + descent, min one line box.
        let blockHPx = max(lineBoxPx, m.blockHeightPer100 * f)
        let ascentPx = m.ascentPer100 * f
        let descentPx = m.descentPer100 * f
        // Padding for italic overhangs and ascenders/descenders that escape a tight line box.
        let padPx = max(0.25 * fontSizePx, (ascentPx + descentPx - lineBoxPx) / 2 + 0.25 * fontSizePx)
        let cssW = contentWPx + padPx * 2
        let cssH = blockHPx + padPx * 2

        // Supersampled raster; degrade the density instead of failing past the per-axis cap.
        let scale = min(p.devicePixelRatio * Self.supersample, Self.maxTextureAxis / cssW, Self.maxTextureAxis / cssH)
        let texW = max(2, Int((cssW * scale).rounded()))
        let texH = max(2, Int((cssH * scale).rounded()))

        var pixels = [UInt8](repeating: 0, count: texW * texH)
        pixels.withUnsafeMutableBytes { buf in
            guard let cg = CGContext(data: buf.baseAddress, width: texW, height: texH, bitsPerComponent: 8, bytesPerRow: texW, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return }
            cg.setShouldAntialias(true)
            cg.setAllowsFontSmoothing(false)
            cg.setShouldSubpixelPositionFonts(true)
            cg.setShouldSubpixelQuantizeFonts(false)
            cg.setFillColor(gray: 1, alpha: 1)
            cg.textMatrix = .identity
            let font = TextFonts.font(family: p.fontFamily, weight: p.fontWeight, italic: p.italic, size: fontSizePx * scale)
            let kern = p.letterSpacing * fontSizePx * scale
            // Centre the font-box block on the raster, baselines at `lineHeight` pitch; each line is
            // placed by textAlign within the content width. CG's origin is bottom-left.
            let blockTopY = CGFloat(texH) / 2 - (blockHPx / 2) * scale
            let contentLeftX = (CGFloat(texW) - contentWPx * scale) / 2
            for (i, line) in m.lines.enumerated() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lineWPx = m.lineWidthsPer100[i] * f
                let drawX: CGFloat
                switch p.textAlign {
                case "left": drawX = contentLeftX
                case "right": drawX = contentLeftX + (contentWPx - lineWPx) * scale
                default: drawX = contentLeftX + ((contentWPx - lineWPx) / 2) * scale
                }
                let baselineY = blockTopY + (ascentPx + CGFloat(i) * pitchPx) * scale
                cg.textPosition = CGPoint(x: drawX, y: CGFloat(texH) - baselineY)
                CTLineDraw(TextMeasure.line(line, font: font, kern: kern), cg)
            }
        }
        let tex = upload(pixels, width: texW, height: texH)
        return output(texture: tex, halfW: max(1e-4, (cssW / 2) / p.canvasHeight), halfH: max(1e-4, (cssH / 2) / p.canvasHeight))
    }

    private func upload(_ pixels: [UInt8]?, width: Int, height: Int) -> MTLTexture? {
        guard let tex = makeUploadTexture(device, format: .a8Unorm, width: width, height: height, label: "Text:glyph") else { return nil }
        let bytes = pixels ?? [UInt8](repeating: 0, count: width * height)
        bytes.withUnsafeBytes { tex.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width) }
        return tex
    }

    private func output(texture: MTLTexture?, halfW: CGFloat, halfH: CGFloat) -> MediaOutputs {
        MediaOutputs(textures: texture.map { ["media_0": $0] } ?? [:], extraFields: ["halfW": [Float(halfW)], "halfH": [Float(halfH)]])
    }
}

/// Every input the glyph raster depends on (the re-raster key).
struct TextRasterSpec: Equatable {
    var text: String
    var fontFamily: String
    var fontWeight: CGFloat
    var italic: Bool
    var fontSizePx: CGFloat
    var letterSpacing: CGFloat
    var lineHeight: CGFloat
    var textAlign: String
    var wrapWidthPx: CGFloat
    var textTransform: String
    /// Logical canvas size (upstream `dimensions`, CSS px ≙ points).
    var canvasHeight: CGFloat
    var devicePixelRatio: CGFloat

    init(_ ctx: MediaContext) {
        let props = ctx.props
        let dimW = CGFloat(ctx.frame.logicalSize.x > 0 ? ctx.frame.logicalSize.x : 1)
        let dimH = CGFloat(ctx.frame.logicalSize.y > 0 ? ctx.frame.logicalSize.y : 1)
        text = ctx.string("text") ?? "Hello World"
        fontFamily = ctx.string("fontFamily") ?? "Inter"
        fontWeight = CGFloat(props["fontWeight"]?.numberValue ?? 400)
        italic = props["italic"]?.boolValue ?? false
        fontSizePx = Self.fontSizePx(props["fontSize"], canvasHeight: dimH)
        letterSpacing = CGFloat(props["letterSpacing"]?.numberValue ?? 0)
        let lh = CGFloat(props["lineHeight"]?.numberValue ?? 1.2)
        lineHeight = lh != 0 && !lh.isNaN ? lh : 1.2
        textAlign = ctx.string("textAlign") ?? "center"
        wrapWidthPx = Self.wrapWidthPx(props["width"], canvasWidth: dimW)
        textTransform = ctx.string("textTransform") ?? "none"
        canvasHeight = dimH
        devicePixelRatio = max(0.1, CGFloat(ctx.width) / dimW)
    }

    /// Upstream `fontSizePxOf`: a number is a fraction of the canvas height, `{value, unit: px}` is pixels.
    static func fontSizePx(_ v: PropValue?, canvasHeight: CGFloat) -> CGFloat {
        switch v {
        case .dimensional(let d)?: return d.unit == .px ? CGFloat(d.value) : CGFloat(d.value) * canvasHeight
        case .number(let n)?: return CGFloat(n) * canvasHeight
        default: return 0.1 * canvasHeight
        }
    }

    /// Upstream `wrapWidthPxOf`: a number is a fraction of the canvas width; 0 = no wrapping.
    static func wrapWidthPx(_ v: PropValue?, canvasWidth: CGFloat) -> CGFloat {
        switch v {
        case .dimensional(let d)?: return d.unit == .px ? CGFloat(d.value) : CGFloat(d.value) * canvasWidth
        case .number(let n)?: return CGFloat(n) * canvasWidth
        default: return 0
        }
    }
}

/// Port of upstream `utilities/textMeasure.ts` on CoreText. Everything is measured at a 100 px
/// reference size so the block scales linearly with font size.
enum TextMeasure {
    struct Block {
        var lines: [String]
        var lineWidthsPer100: [CGFloat]
        var widthPer100: CGFloat
        var ascentPer100: CGFloat
        var descentPer100: CGFloat
        var pitchPer100: CGFloat
        var blockHeightPer100: CGFloat
    }

    static func applyTextTransform(_ text: String, _ mode: String) -> String {
        switch mode {
        case "uppercase": return text.uppercased()
        case "lowercase": return text.lowercased()
        case "capitalize":
            // `/(^|\s)(\S)/g` → upper-case the first character after the start or whitespace.
            var out = ""
            var atWordStart = true
            for ch in text {
                out += atWordStart && !ch.isWhitespace ? ch.uppercased() : String(ch)
                atWordStart = ch.isWhitespace
            }
            return out
        default: return text
        }
    }

    /// A single-line CTLine with letter spacing applied after every character (like canvas `letterSpacing`).
    static func line(_ text: String, font: CTFont, kern: CGFloat) -> CTLine {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTKernAttributeName as String): kern,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    }

    /// Advance width at 100 px, without the trailing letter-spacing unit (the box hugs the last glyph).
    static func widthPer100(_ text: String, font: CTFont, letterSpacingEm: CGFloat) -> CGFloat {
        let w = CGFloat(CTLineGetTypographicBounds(line(text, font: font, kern: letterSpacingEm * 100), nil, nil, nil))
        return text.isEmpty ? w : max(0, w - letterSpacingEm * 100)
    }

    /// Greedy word wrap: explicit lines wrap independently, a word longer than the max overflows
    /// on its own line (no mid-word breaks). `maxWidthPer100 <= 0` disables wrapping.
    static func wrapLines(_ text: String, maxWidthPer100: CGFloat, measure: (String) -> CGFloat) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let explicit = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard maxWidthPer100 > 0 else { return explicit }
        var out: [String] = []
        for line in explicit {
            var current = ""
            for word in line.split(separator: " ", omittingEmptySubsequences: false) {
                let candidate = current.isEmpty ? String(word) : "\(current) \(word)"
                if !current.isEmpty && measure(candidate) > maxWidthPer100 {
                    out.append(current)
                    current = String(word)
                } else {
                    current = candidate
                }
            }
            out.append(current)
        }
        return out
    }

    /// Upstream `measureTextBlock` (font-box metrics only; the ink extents feed the editor's
    /// bounding box, which this port does not have).
    static func block(text: String, transform: String, font: CTFont, letterSpacingEm: CGFloat, lineHeightEm: CGFloat, maxWidthPer100: CGFloat) -> Block {
        let transformed = applyTextTransform(text, transform)
        let lines = wrapLines(transformed, maxWidthPer100: maxWidthPer100) { widthPer100($0, font: font, letterSpacingEm: letterSpacingEm) }
        let widths = lines.map { widthPer100($0, font: font, letterSpacingEm: letterSpacingEm) }
        let n = CGFloat(max(1, lines.count))
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let pitch = max(1, lineHeightEm * 100)
        return Block(lines: lines, lineWidthsPer100: widths, widthPer100: widths.max() ?? 0, ascentPer100: ascent, descentPer100: descent, pitchPer100: pitch, blockHeightPer100: ascent + (n - 1) * pitch + descent)
    }
}
#endif
