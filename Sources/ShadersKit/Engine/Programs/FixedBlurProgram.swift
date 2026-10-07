#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of the upstream `withFixedBlurCompute` hook (kit/blur.ts): a separable Gaussian with a
/// truncated 49-tap kernel at a fixed 1024×640 compute resolution. Serves `Blur` and `ChannelBlur`.
final class FixedBlurProgram: ComputeProgram {
    static let shaderNames = ["Blur", "ChannelBlur"]

    private static let computeWidth = 1024
    private static let computeHeight = 640
    private static let halfKernel = 24

    private let intermediate: MTLTexture
    private let output: MTLTexture
    private let weightsH: MTLBuffer
    private let weightsV: MTLBuffer
    private let paramsH: MTLBuffer
    private let paramsV: MTLBuffer
    private let kernelH: ComputeKernelDescriptor
    private let kernelV: ComputeKernelDescriptor
    private let layoutH: UniformLayout
    private let layoutV: UniformLayout

    private var lastRadius: Float = -1
    private var inputWidth: Float = 0
    private var inputHeight: Float = 0

    init(context ctx: ComputeContext) throws {
        guard let info = ctx.descriptor.compute, info.kernels.count >= 2 else { throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) kernels") }
        kernelH = info.kernels[0]
        kernelV = info.kernels[1]
        guard let lh = info.uniformLayouts[kernelH.buffer("params")?.name ?? "params"] ?? info.uniformLayouts.values.first(where: { $0.fields.count == 3 }),
              let lv = info.uniformLayouts[kernelV.buffers.first(where: { $0.space == "uniform" })?.name ?? "params_2"] ?? info.uniformLayouts.values.first(where: { $0.fields.count == 1 }) else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) kernel params layout")
        }
        layoutH = lh
        layoutV = lv
        guard let inter = ctx.makeTexture(width: Self.computeWidth, height: Self.computeHeight, label: "blur intermediate"),
              let out = ctx.makeTexture(width: Self.computeWidth, height: Self.computeHeight, label: "blur output"),
              let wh = ctx.makeBuffer(length: (Self.halfKernel * 2 + 1) * 4, label: "blur weightsH"),
              let wv = ctx.makeBuffer(length: (Self.halfKernel * 2 + 1) * 4, label: "blur weightsV"),
              let ph = ctx.makeBuffer(length: 16, label: "blur paramsH"),
              let pv = ctx.makeBuffer(length: 16, label: "blur paramsV") else {
            throw ShaderEngineError.noMetalDevice
        }
        intermediate = inter
        output = out
        weightsH = wh
        weightsV = wv
        paramsH = ph
        paramsV = pv
    }

    /// Upstream `buildTruncatedWeights`.
    static func truncatedWeights(halfKernel: Int, sigma: Float) -> (weights: [Float], activeHalf: Int) {
        let size = halfKernel * 2 + 1
        let activeHalf = max(1, min(halfKernel, Int((sigma * 3).rounded(.up))))
        var weights = [Float](repeating: 0, count: size)
        var total: Float = 0
        for i in -halfKernel...halfKernel where abs(i) <= activeHalf {
            let w = exp(-Float(i * i) / (2 * sigma * sigma))
            weights[i + halfKernel] = w
            total += w
        }
        if total > 0 { for i in 0..<size { weights[i] /= total } }
        return (weights, activeHalf)
    }

    private func radius(_ ctx: ComputeContext) -> Float {
        switch ctx.descriptor.name {
        case "ChannelBlur":
            let r = ctx.scalar("redIntensity") * 0.1
            let g = ctx.scalar("greenIntensity") * 0.1
            let b = ctx.scalar("blueIntensity") * 0.1
            return max(r, g, b, 0.01)
        default:
            return ctx.scalar("intensity") * 0.36
        }
    }

    private func updateWeights(_ ctx: ComputeContext) {
        let pixelRadius = lastRadius < 0 ? 4 : lastRadius
        let scaleY = inputHeight / Float(Self.computeHeight)
        let sigmaH = max(pixelRadius * 0.5, 0.001)
        let sigmaV = max(sigmaH / max(scaleY, 1e-6), 0.001)
        let h = Self.truncatedWeights(halfKernel: Self.halfKernel, sigma: sigmaH)
        let v = Self.truncatedWeights(halfKernel: Self.halfKernel, sigma: sigmaV)
        memcpy(weightsH.contents(), h.weights, h.weights.count * 4)
        memcpy(weightsV.contents(), v.weights, v.weights.count * 4)
        ctx.pack(layoutH, ["activeHalf": [Float(h.activeHalf)], "inputWidth": [inputWidth], "inputHeight": [inputHeight]], into: paramsH)
        ctx.pack(layoutV, ["activeHalf": [Float(v.activeHalf)]], into: paramsV)
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let input = ctx.rttTextures.values.first ?? ctx.childTexture else { return ComputeOutputs() }
        var dirty = false
        if inputWidth != Float(ctx.width) || inputHeight != Float(ctx.height) {
            inputWidth = Float(ctx.width)
            inputHeight = Float(ctx.height)
            dirty = true
        }
        let r = radius(ctx)
        if abs(r - lastRadius) >= 0.01 { lastRadius = r; dirty = true }
        if dirty { updateWeights(ctx) }

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        defer { enc.endEncoding() }
        enc.label = "\(ctx.descriptor.name) blur"
        let threads = SIMD3<UInt32>(UInt32(Self.computeWidth), UInt32(Self.computeHeight), 1)
        try ctx.dispatch(enc, kernelH, threads: threads) { e in
            if let s = kernelH.texture("input") { e.setTexture(input, index: s.slot) }
            if let s = kernelH.texture("intermediate") { e.setTexture(intermediate, index: s.slot) }
            if let s = kernelH.buffer("weights") { e.setBuffer(weightsH, offset: 0, index: s.slot) }
            if let s = kernelH.buffers.first(where: { $0.space == "uniform" }) { e.setBuffer(paramsH, offset: 0, index: s.slot) }
        }
        try ctx.dispatch(enc, kernelV, threads: threads) { e in
            if let s = kernelV.texture("src") { e.setTexture(intermediate, index: s.slot) }
            if let s = kernelV.texture("output") { e.setTexture(output, index: s.slot) }
            if let s = kernelV.buffer("weights") { e.setBuffer(weightsV, offset: 0, index: s.slot) }
            if let s = kernelV.buffers.first(where: { $0.space == "uniform" }) { e.setBuffer(paramsV, offset: 0, index: s.slot) }
        }
        return ComputeOutputs(textures: ["compute_0": output])
    }
}
#endif
