#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream CompressionArtifacts `jpegCompress` compute hook: one thread per 4×4
/// device-pixel cell runs the DCT block quantizer and writes the block colour into a fixed
/// 1024×1024 cell texture (`compute_0`). Only the active cell grid is dispatched.
///
/// Upstream runs this compute before the RTT passes and reads the previous frame's child (a
/// one-frame lag); ShadersKit runs it after `rtt_0`, so the cells match the current frame.
final class CompressionArtifactsProgram: ComputeProgram {
    static let shaderNames = ["CompressionArtifacts"]
    private static let stride = 4
    private static let maxCells = 1024

    private let kernel: ComputeKernelDescriptor
    private let layout: UniformLayout
    private let params: MTLBuffer
    private let cells: MTLTexture

    init(context ctx: ComputeContext) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute") }
        kernel = try BlurKit.kernel(info, binding: "cellTex", shader: name)
        layout = try BlurKit.uniformLayout(info, kernel, shader: name)
        params = try BlurKit.makeBuffer(ctx, layout.size, "\(name) params")
        cells = try BlurKit.makeTexture(ctx, Self.maxCells, Self.maxCells, .rgba16Float, "\(name) cells")
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let input = BlurKit.childInput(ctx) else { return ComputeOutputs() }
        let w = max(1, ctx.width), h = max(1, ctx.height)
        let cellsX = min((w + Self.stride - 1) / Self.stride, Self.maxCells)
        let cellsY = min((h + Self.stride - 1) / Self.stride, Self.maxCells)
        ctx.pack(layout, ["inputWidth": [Float(w)], "inputHeight": [Float(h)], "quality": [ctx.scalar("quality")]], into: params)

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        defer { enc.endEncoding() }
        enc.label = "CompressionArtifacts cells"
        try ctx.dispatch(enc, kernel, threads: SIMD3(UInt32(cellsX), UInt32(cellsY), 1)) { e in
            if let s = kernel.texture("input") { e.setTexture(input, index: s.slot) }
            if let s = kernel.texture("cellTex") { e.setTexture(cells, index: s.slot) }
            if let s = BlurKit.uniformSlot(kernel) { e.setBuffer(params, offset: 0, index: s.slot) }
        }
        return ComputeOutputs(textures: ["compute_0": cells])
    }
}
#endif
