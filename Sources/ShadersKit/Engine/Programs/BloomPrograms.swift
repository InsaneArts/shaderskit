#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream `withBloomCompute` (kit/blur.ts, static-size path): bright-extract the child
/// RTT into a compute-resolution bright buffer (the extract kernel also fills the radius map with
/// the uniform size), then blur the bright buffer with the jittered variable Gaussian.
///
/// Upstream sizes the grid to the canvas aspect at creation (`aspectAwareComputeRes`); the
/// generated kernels fix it at the recorded size (1024×768). The blur radius is converted to that
/// grid per axis (`radius` along x, `scaleY` along y) so the halo keeps upstream's round shape on
/// any canvas aspect. At a 4:3 canvas the values equal upstream's (`scaleY` 1, radius unchanged).
final class BloomCompute {
    private let blur: VariableGaussianBlur
    private let bright: MTLTexture
    private let extractKernel: ComputeKernelDescriptor
    private let extractLayout: UniformLayout
    private let extractParams: MTLBuffer

    var output: MTLTexture { blur.output }

    init(context ctx: ComputeContext) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute") }
        let size = BlurKit.computeSize(info, default: (1024, 768))
        blur = try VariableGaussianBlur(context: ctx, halfKernel: 24, computeWidth: size.width, computeHeight: size.height)
        bright = try BlurKit.makeTexture(ctx, size.width, size.height, .rgba16Float, "\(name) bright")
        extractKernel = try BlurKit.kernel(info, binding: "brightMap", shader: name)
        extractLayout = try BlurKit.uniformLayout(info, extractKernel, shader: name)
        extractParams = try BlurKit.makeBuffer(ctx, extractLayout.size, "\(name) extract params")
    }

    /// Encodes extract → H → V. `radius` is the bloom size in compute pixels (upstream units).
    func encode(_ ctx: ComputeContext, child: MTLTexture, threshold: Float, radius: Float) throws {
        let cw = blur.computeWidth, ch = blur.computeHeight
        let canvasW = Float(max(1, ctx.width)), canvasH = Float(max(1, ctx.height))
        let aspect = canvasW / canvasH
        // Upstream compute pixel = canvas long edge / 1024; ours = canvas width / cw along x.
        let radiusX = radius * Float(cw) / 1024 / min(aspect, 1)
        let scaleY = (Float(cw) / Float(ch)) / aspect
        // The blur's input is the bright buffer itself: input dims = compute dims.
        blur.setParams(ctx, inputWidth: Float(cw), inputHeight: Float(ch), scaleY: scaleY)
        ctx.pack(extractLayout, ["threshold": [threshold], "size": [radiusX], "inputWidth": [canvasW], "inputHeight": [canvasH]], into: extractParams)

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return }
        defer { enc.endEncoding() }
        enc.label = "\(ctx.descriptor.name) bloom"
        try ctx.dispatch(enc, extractKernel, threads: SIMD3(UInt32(cw), UInt32(ch), 1)) { e in
            if let s = extractKernel.texture("childTexture") { e.setTexture(child, index: s.slot) }
            if let s = extractKernel.texture("brightMap") { e.setTexture(bright, index: s.slot) }
            if let s = extractKernel.texture("blurMap_2") { e.setTexture(blur.blurMap, index: s.slot) }
            if let s = BlurKit.uniformSlot(extractKernel) { e.setBuffer(extractParams, offset: 0, index: s.slot) }
        }
        try blur.encode(ctx, enc, input: bright)
    }
}

/// Glow — upstream `bloom` (std/effects/blurs): size 0 skips compute and the fragment's
/// `glowCompose` against the zero placeholder is the sharp passthrough.
final class GlowProgram: ComputeProgram {
    static let shaderNames = ["Glow"]
    private let bloom: BloomCompute

    init(context ctx: ComputeContext) throws {
        bloom = try BloomCompute(context: ctx)
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        let size = ctx.scalar("size")
        guard size != 0, let child = BlurKit.childInput(ctx) else { return ComputeOutputs() }
        try bloom.encode(ctx, child: child, threshold: ctx.scalar("threshold"), radius: size)
        return ComputeOutputs(textures: ["compute_0": bloom.output])
    }
}

/// FilmStock — the CPU side of its three stages (shaders/FilmStock/index.ts):
/// * gate weave (`frameSway`): the `weaveTime` clock advances only while `weave` > 0;
/// * LUT grade (`lutAtlasGrade`): the stock's 17³ LUT decoded into an rgba8 slice atlas (`media_1`);
/// * halation (`screenedBloom`): a bloom at threshold 0.62, skipped while `halation` is 0.
final class FilmStockProgram: ComputeProgram {
    static let shaderNames = ["FilmStock"]
    private static let halationThreshold: Float = 0.62

    private let bloom: BloomCompute
    private var weaveTime: Float = 0
    private var lut: MTLTexture?
    private var lutKey = ""

    init(context ctx: ComputeContext) throws {
        bloom = try BloomCompute(context: ctx)
    }

    /// Upstream `decodeStockLut`: atlas texel (b·N + r, g) = LUT[r, g, b], alpha opaque.
    static func decodeStockLut(_ slug: String) -> [UInt8] {
        let n = FilmStockLuts.size
        let b64 = FilmStockLuts.blobs[slug] ?? FilmStockLuts.blobs["portrait400"] ?? ""
        let bin = [UInt8](Data(base64Encoded: b64) ?? Data())
        var out = [UInt8](repeating: 255, count: n * n * n * 4)
        guard bin.count >= n * n * n * 3 else { return out }
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let src = ((b * n + g) * n + r) * 3
                    let dst = (g * n * n + b * n + r) * 4
                    out[dst] = bin[src]
                    out[dst + 1] = bin[src + 1]
                    out[dst + 2] = bin[src + 2]
                }
            }
        }
        return out
    }

    private func lutTexture(_ ctx: ComputeContext) -> MTLTexture? {
        let key = ctx.string("stock") ?? "portrait400"
        if key == lutKey, let lut { return lut }
        let n = FilmStockLuts.size
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: n * n, height: n, mipmapped: false)
        d.usage = [.shaderRead]
        guard let t = ctx.device.device.makeTexture(descriptor: d) else { return nil }
        t.label = "filmstock-lut-\(key)"
        let bytes = Self.decodeStockLut(key)
        bytes.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, n * n, n), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: n * n * 4) }
        lut = t
        lutKey = key
        return t
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        // frameSway's onBeforeRender: the gated weave clock.
        weaveTime += ctx.frame.deltaTime * (ctx.scalar("weave") > 0 ? 1 : 0)
        var out = ComputeOutputs(extraFields: ["weaveTime": [weaveTime]])
        if let lut = lutTexture(ctx) { out.textures["media_1"] = lut }
        // screenedBloom: halation 0 → no compute; the screen reads a zero glow (placeholder).
        guard ctx.scalar("halation") != 0, let child = BlurKit.childInput(ctx) else { return out }
        try bloom.encode(ctx, child: child, threshold: Self.halationThreshold, radius: ctx.scalar("halationRadius"))
        out.textures["compute_0"] = bloom.output
        return out
    }
}
#endif
