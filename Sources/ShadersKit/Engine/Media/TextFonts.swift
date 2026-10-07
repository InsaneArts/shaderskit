#if canImport(Metal)
import Foundation
import CoreText
import CoreGraphics
#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#endif

/// Resolves the Text shader's `fontFamily` / `fontWeight` / `italic` props to a CoreText font.
/// An installed family is used as is; upstream Google Fonts names map to the closest system font
/// (sans, serif, rounded, monospaced or condensed SF variants, or a few bundled Apple families);
/// anything else falls back to the system font. Missing italics are synthesized as an oblique
/// (the browser does the same for families without an italic face).
enum TextFonts {
    private enum Choice {
        case family(String)
        case system(Design)
    }

    private enum Design {
        case sans, serif, rounded, mono, condensed
    }

    private struct Resolved {
        var descriptor: CTFontDescriptor
        var oblique: Bool
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Resolved] = [:]

    static func font(family: String, weight: CGFloat, italic: Bool, size: CGFloat) -> CTFont {
        let key = "\(family.lowercased())|\(weight)|\(italic)"
        lock.lock()
        let cached = cache[key]
        lock.unlock()
        let resolved = cached ?? resolve(family: family, weight: weight, italic: italic)
        if cached == nil {
            lock.lock()
            cache[key] = resolved
            lock.unlock()
        }
        // Skia's synthetic oblique: x += y / 4.
        var skew = CGAffineTransform(a: 1, b: 0, c: 0.25, d: 1, tx: 0, ty: 0)
        return resolved.oblique ? CTFontCreateWithFontDescriptor(resolved.descriptor, size, &skew) : CTFontCreateWithFontDescriptor(resolved.descriptor, size, nil)
    }

    private static func resolve(family: String, weight: CGFloat, italic: Bool) -> Resolved {
        let w = weightTrait(weight)
        let name = family.trimmingCharacters(in: .whitespaces)
        var choices: [Choice] = [.family(name)]
        if let mapped = googleFontMap[name.lowercased()] { choices.append(mapped) }
        choices.append(.system(.sans))
        for choice in choices {
            let font: CTFont?
            switch choice {
            case .family(let f): font = namedFont(f, weight: w, italic: italic)
            case .system(let d): font = systemFont(d, weight: w, italic: italic)
            }
            if let font {
                let isItalic = CTFontGetSymbolicTraits(font).contains(.traitItalic)
                return Resolved(descriptor: CTFontCopyFontDescriptor(font), oblique: italic && !isItalic)
            }
        }
        let fallback = CTFontCreateUIFontForLanguage(.system, 100, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 100, nil)
        return Resolved(descriptor: CTFontCopyFontDescriptor(fallback), oblique: italic)
    }

    /// CSS font-weight (100…900) → CoreText weight trait (the `UIFont.Weight` / `NSFont.Weight` scale).
    static func weightTrait(_ css: CGFloat) -> CGFloat {
        let table: [CGFloat] = [-0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62]
        let x = min(max((css.isNaN ? 400 : css) / 100, 1), 9) - 1
        let i = min(Int(x), 7)
        return table[i] + (table[i + 1] - table[i]) * (x - CGFloat(i))
    }

    private static func namedFont(_ family: String, weight: CGFloat, italic: Bool) -> CTFont? {
        guard !family.isEmpty else { return nil }
        var traits: [CFString: Any] = [kCTFontWeightTrait: weight]
        if italic { traits[kCTFontSymbolicTrait] = CTFontSymbolicTraits.traitItalic.rawValue }
        let desc = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family, kCTFontTraitsAttribute: traits] as CFDictionary)
        guard let matched = CTFontDescriptorCreateMatchingFontDescriptor(desc, Set([kCTFontFamilyNameAttribute as String]) as CFSet) else { return nil }
        return CTFontCreateWithFontDescriptor(matched, 100, nil)
    }

    private static func systemFont(_ design: Design, weight: CGFloat, italic: Bool) -> CTFont? {
        let w = PlatformFont.Weight(rawValue: weight)
        var font: PlatformFont
        switch design {
        case .mono: font = PlatformFont.monospacedSystemFont(ofSize: 100, weight: w)
        case .condensed: font = PlatformFont.systemFont(ofSize: 100, weight: w, width: .condensed)
        case .serif, .rounded:
            let base = PlatformFont.systemFont(ofSize: 100, weight: w)
            let desc = base.fontDescriptor.withDesign(design == .serif ? .serif : .rounded)
            font = desc.flatMap { PlatformFont(descriptor: $0, size: 100) } ?? base
        case .sans: font = PlatformFont.systemFont(ofSize: 100, weight: w)
        }
        let ct = font as CTFont
        // CoreText keeps the weight when adding italic (the UIKit/AppKit descriptor call drops it).
        if italic, let it = CTFontCreateCopyWithSymbolicTraits(ct, 100, nil, .traitItalic, .traitItalic) { return it }
        return ct
    }

    /// Popular Google Fonts families (lower-cased) → closest font available on Apple platforms.
    private static let googleFontMap: [String: Choice] = {
        var m: [String: Choice] = [:]
        let serif = ["playfair display", "playfair", "merriweather", "lora", "pt serif", "noto serif", "noto serif display", "libre baskerville", "eb garamond", "cormorant", "cormorant garamond", "crimson text", "crimson pro", "dm serif display", "dm serif text", "source serif pro", "source serif 4", "roboto serif", "bitter", "arvo", "zilla slab", "roboto slab", "instrument serif", "fraunces", "spectral", "libre caslon text", "old standard tt", "abril fatface", "prata", "cinzel", "bodoni moda", "newsreader", "young serif", "gloock", "literata", "alegreya", "vollkorn", "domine", "frank ruhl libre", "ibm plex serif"]
        let mono = ["roboto mono", "jetbrains mono", "fira code", "fira mono", "source code pro", "ibm plex mono", "space mono", "inconsolata", "ubuntu mono", "dm mono", "geist mono", "courier prime", "overpass mono", "red hat mono", "martian mono", "azeret mono", "major mono display", "vt323", "share tech mono", "noto sans mono", "pt mono", "anonymous pro", "cousine", "space grotesk mono"]
        let rounded = ["nunito", "quicksand", "varela round", "m plus rounded 1c", "comfortaa", "fredoka", "fredoka one", "baloo 2", "mali", "sniglet"]
        let condensed = ["bebas neue", "oswald", "anton", "league gothic", "barlow condensed", "fjalla one", "teko", "big shoulders display", "archivo narrow", "roboto condensed", "pt sans narrow", "saira condensed", "antonio", "pathway gothic one", "six caps"]
        let script = ["pacifico", "dancing script", "great vibes", "sacramento", "allura", "satisfy", "parisienne", "lobster", "alex brush", "pinyon script", "tangerine", "kaushan script", "yellowtail"]
        let hand = ["caveat", "indie flower", "shadows into light", "permanent marker", "kalam", "patrick hand", "gochi hand", "architects daughter", "amatic sc", "covered by your grace", "rock salt", "reenie beanie"]
        let geometric = ["montserrat", "poppins", "outfit", "urbanist", "lexend", "raleway", "josefin sans", "questrial", "didact gothic", "red hat display", "sora", "plus jakarta sans", "manrope", "dm sans"]
        for f in serif { m[f] = .system(.serif) }
        for f in mono { m[f] = .system(.mono) }
        for f in rounded { m[f] = .system(.rounded) }
        for f in condensed { m[f] = .system(.condensed) }
        for f in script { m[f] = .family("Snell Roundhand") }
        for f in hand { m[f] = .family("Noteworthy") }
        for f in geometric { m[f] = .family("Avenir Next") }
        m["jost"] = .family("Futura")
        return m
    }()
}
#endif
