#if canImport(Metal)
import Foundation
import Metal
import simd

/// Compute side of `GlassGlow` (hand-written, not an upstream port).
///
/// Each frame: a jump-flood distance field of the child's alpha, the glass and rim shading, a
/// three-radius bloom of the lit glass on its mip chain, and the composite the final pass reads.
final class GlassGlowProgram: ComputeProgram {
    static let shaderNames = ["GlassGlow"]

    private struct Params {
        var a: SIMD4<Float>
        var b: SIMD4<Float>
        var c: SIMD4<Float>
        var gamma: SIMD4<Float>
        var rimColour: SIMD4<Float>
        var band: SIMD4<Float>
        var info: SIMD4<UInt32>
    }

    private struct Blob {
        var pos: SIMD4<Float>
        var shape: SIMD4<Float>
        var colour: SIMD4<Float>
    }

    private let reset: MTLComputePipelineState
    private let seed: MTLComputePipelineState
    private let flood: MTLComputePipelineState
    private let distance: MTLComputePipelineState
    private let smooth: MTLComputePipelineState
    private let shade: MTLComputePipelineState
    private let blur: MTLComputePipelineState
    private let compose: MTLComputePipelineState
    private let box: MTLBuffer

    private var width = 0
    private var height = 0
    private var seedsA: MTLTexture?
    private var seedsB: MTLTexture?
    private var sdf: MTLTexture?
    private var sdfRaw: MTLTexture?
    private var glass: MTLTexture?
    private var base: MTLTexture?
    private var output: MTLTexture?
    private var blurTemp: [MTLTexture] = []
    private var blurOut: [MTLTexture] = []
    private var blurLevels: [Int] = []

    init(context ctx: ComputeContext) throws {
        func pipeline(_ name: String) throws -> MTLComputePipelineState {
            try ctx.device.computePipeline(library: ctx.library, name: name)
        }
        reset = try pipeline("gg_reset")
        seed = try pipeline("gg_seed")
        flood = try pipeline("gg_flood")
        distance = try pipeline("gg_distance")
        smooth = try pipeline("gg_smooth")
        shade = try pipeline("gg_shade")
        blur = try pipeline("gg_blur")
        compose = try pipeline("gg_compose")
        guard let b = ctx.device.device.makeBuffer(length: 16, options: [.storageModeShared]) else { throw ShaderEngineError.noMetalDevice }
        box = b
    }

    private func texture(_ ctx: ComputeContext, _ w: Int, _ h: Int, _ format: MTLPixelFormat, mipmapped: Bool = false, label: String) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: max(1, w), height: max(1, h), mipmapped: mipmapped)
        d.usage = [.shaderRead, .shaderWrite]
        d.storageMode = .private
        let t = ctx.device.device.makeTexture(descriptor: d)
        t?.label = label
        return t
    }

    /// The mip level each bloom radius runs on, chosen so the blur is about 4-16 texels wide there.
    /// The exact radius is computed on the GPU from the shape's box; this only picks the level.
    private func levels(boxHeight: Float, maxLevel: Int) -> [Int] {
        GlassGlowModel.bloom.map { b in
            let sigma = b.radius * boxHeight
            return min(maxLevel, max(0, Int(floor(log2(max(sigma, 1) / 4)))))
        }
    }

    private func estimatedBoxHeight() -> Float {
        let v = box.contents().bindMemory(to: UInt32.self, capacity: 4)
        guard v[3] > v[1], v[3] != 0, v[1] != .max else { return Float(height) * 0.8 }
        return Float(v[3] - v[1])
    }

    private func allocate(_ ctx: ComputeContext) {
        width = ctx.width
        height = ctx.height
        seedsA = texture(ctx, width, height, .rgba32Float, label: "GlassGlow seeds A")
        seedsB = texture(ctx, width, height, .rgba32Float, label: "GlassGlow seeds B")
        sdf = texture(ctx, width, height, .r32Float, label: "GlassGlow sdf")
        sdfRaw = texture(ctx, width, height, .r32Float, label: "GlassGlow sdf raw")
        glass = texture(ctx, width, height, .rgba16Float, mipmapped: true, label: "GlassGlow glass")
        base = texture(ctx, width, height, .rgba16Float, label: "GlassGlow base")
        output = texture(ctx, width, height, .rgba16Float, label: "GlassGlow output")
        blurLevels = []
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, _ pso: MTLComputePipelineState, _ w: Int, _ h: Int) {
        enc.setComputePipelineState(pso)
        let tw = pso.threadExecutionWidth
        let th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (w + tw - 1) / tw, height: (h + th - 1) / th, depth: 1), threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let child = ctx.childTexture else { return ComputeOutputs() }
        if ctx.width != width || ctx.height != height || output == nil { allocate(ctx) }
        guard let seedsA, let seedsB, let sdf, let sdfRaw, let glass, let base, let output else { return ComputeOutputs() }

        let wanted = levels(boxHeight: estimatedBoxHeight(), maxLevel: glass.mipmapLevelCount - 1)
        if wanted != blurLevels {
            blurLevels = wanted
            blurTemp = []
            blurOut = []
            for level in wanted {
                let w = max(1, width >> level), h = max(1, height >> level)
                guard let t = texture(ctx, w, h, .rgba16Float, label: "GlassGlow blur temp"),
                      let o = texture(ctx, w, h, .rgba16Float, label: "GlassGlow bloom") else { return ComputeOutputs() }
                blurTemp.append(t)
                blurOut.append(o)
            }
        }

        let time = ctx.state.animTime["_animTime"] ?? 0
        let blobs = GlassGlowModel.blobs(at: time).map {
            Blob(pos: SIMD4($0.x, $0.y, $0.z, $0.radius), shape: SIMD4($0.intensity, $0.aspect, cos($0.angle), sin($0.angle)), colour: SIMD4($0.colour, 0))
        }
        let m = GlassGlowModel.self
        var params = Params(
            a: SIMD4(m.height, m.contrast, m.edgeSoftness, m.dispersion * ctx.scalar("dispersion")),
            b: SIMD4(m.bevelWidth, m.bevelRefraction * ctx.scalar("refraction"), m.bevelExponent, m.rimWidth),
            c: SIMD4(m.rimAmbient, m.rimLight, m.rimInset, ctx.scalar("intensity")),
            gamma: SIMD4(m.gamma, 0),
            rimColour: SIMD4(m.rimColour, 0),
            band: SIMD4(m.bandInset, m.bandWidth, m.bandLight, m.bandBlur * m.bandBlur),
            info: SIMD4(UInt32(width), UInt32(height), UInt32(blobs.count), 0))
        var size = SIMD2<UInt32>(UInt32(width), UInt32(height))

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        enc.label = "GlassGlow shape + shade"
        enc.setBuffer(box, offset: 0, index: 0)
        enc.setComputePipelineState(reset)
        enc.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))

        enc.setTexture(child, index: 0)
        enc.setTexture(seedsA, index: 1)
        enc.setBuffer(box, offset: 0, index: 0)
        enc.setBytes(&size, length: MemoryLayout<SIMD2<UInt32>>.stride, index: 1)
        dispatch(enc, seed, width, height)

        // Jump flood from half the larger side down to 1, plus one extra 1-step pass.
        var steps: [Int] = []
        var s = 1
        while s < max(width, height) { s <<= 1 }
        s >>= 1
        while s >= 1 { steps.append(s); s >>= 1 }
        steps.append(1)
        var src = seedsA, dst = seedsB
        for step in steps {
            var sizeStep = SIMD3<Int32>(Int32(width), Int32(height), Int32(step))
            enc.setTexture(src, index: 0)
            enc.setTexture(dst, index: 1)
            enc.setBytes(&sizeStep, length: MemoryLayout<SIMD3<Int32>>.stride, index: 0)
            dispatch(enc, flood, width, height)
            swap(&src, &dst)
        }

        enc.setTexture(child, index: 0)
        enc.setTexture(src, index: 1)
        enc.setTexture(sdfRaw, index: 2)
        enc.setBytes(&size, length: MemoryLayout<SIMD2<UInt32>>.stride, index: 0)
        dispatch(enc, distance, width, height)

        enc.setTexture(sdfRaw, index: 0)
        enc.setTexture(sdf, index: 1)
        enc.setBytes(&size, length: MemoryLayout<SIMD2<UInt32>>.stride, index: 0)
        dispatch(enc, smooth, width, height)

        enc.setTexture(sdf, index: 0)
        enc.setTexture(glass, index: 1)
        enc.setTexture(base, index: 2)
        enc.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)
        enc.setBytes(blobs, length: MemoryLayout<Blob>.stride * blobs.count, index: 1)
        enc.setBuffer(box, offset: 0, index: 2)
        dispatch(enc, shade, width, height)
        enc.endEncoding()

        if let blit = ctx.commandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: glass)
            blit.endEncoding()
        }

        guard let enc2 = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        enc2.label = "GlassGlow bloom + compose"
        for (i, level) in blurLevels.enumerated() {
            guard let view = glass.makeTextureView(pixelFormat: glass.pixelFormat, textureType: .type2D, levels: level..<(level + 1), slices: 0..<1) else { continue }
            let w = blurOut[i].width, h = blurOut[i].height
            let scale = Float(w) / Float(width)
            for (input, out, dir) in [(view, blurTemp[i], SIMD2<Float>(1, 0)), (blurTemp[i], blurOut[i], SIMD2<Float>(0, 1))] {
                var p = SIMD4<Float>(dir.x, dir.y, m.bloom[i].radius, scale)
                enc2.setTexture(input, index: 0)
                enc2.setTexture(out, index: 1)
                enc2.setBytes(&p, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
                enc2.setBuffer(box, offset: 0, index: 1)
                dispatch(enc2, blur, w, h)
            }
        }
        let glow = ctx.scalar("glow")
        var gains = SIMD4<Float>(m.bloom[0].gain * glow, m.bloom[1].gain * glow, m.bloom[2].gain * glow, 0)
        enc2.setTexture(base, index: 0)
        for i in 0..<3 { enc2.setTexture(i < blurOut.count ? blurOut[i] : ctx.device.placeholderTexture, index: 1 + i) }
        enc2.setTexture(output, index: 4)
        enc2.setBytes(&gains, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        enc2.setBytes(&params, length: MemoryLayout<Params>.stride, index: 1)
        dispatch(enc2, compose, width, height)
        enc2.endEncoding()

        return ComputeOutputs(textures: ["compute_0": output], extraFields: ["_p3": [ctx.options.colorSpace == .displayP3Linear ? 1 : 0]])
    }
}
#endif
