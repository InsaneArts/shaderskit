#if canImport(Metal)
import Foundation
import Metal

/// `ImageTexture`: decodes the `url` prop (http(s), file path, data: URI or bundle resource) into a
/// linear-format texture the shader samples as `media_0` (the shader applies the sRGB EOTF itself).
final class ImageMediaProgram: MediaProgram {
    static let shaderNames = ["ImageTexture"]
    private let loader: MediaLoader

    init(context: MediaContext) throws {
        loader = MediaLoader.shared(for: context.device)
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        guard let source = ctx.string("url"), !source.isEmpty, let tex = loader.texture(forSource: source) else { return MediaOutputs() }
        return MediaOutputs(textures: ["media_0": tex])
    }
}
#endif
