#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream `irradianceField(...).compute` (std/paint/radiance.ts + gpu/scaffolds/radiance.ts)
/// as Irradiance configures it: the shape's volumetric field pre-march (`compute_0`), a jump-flooded
/// silhouette distance field over the marched domain, a progressive Monte-Carlo irradiance gather into a
/// res×res texture, its running mean, and a Gaussian denoise whose output the fragment reads (`compute_1`).
final class SDFIrradianceProgram: ComputeProgram {
    static let shaderNames = ["Irradiance"]

    // Irradiance/index.ts look constants.
    private static let rays = (burst: 128, motion: 64, refine: 32, refineFrames: 12)
    private static let mobileRayDivisor = 2
    private static let fieldRes = 512
    private static let fieldResMobile = 320
    // std/paint/radiance.ts constants.
    private static let denoiseRadius = 3.0
    private static let denoiseHalfKernel = 6
    private static let warmupFrames = 3
    private static let maxLights = 8

    private let field: SDFVolumetricField
    private let res: Int
    private let outTex: MTLTexture
    private let meanTex: MTLTexture
    private let prevTex: MTLTexture
    private let jfaA: MTLTexture
    private let jfaB: MTLTexture
    private let blurIntermediate: MTLTexture
    private let blurOutput: MTLTexture
    private let weightsH: MTLBuffer
    private let weightsV: MTLBuffer
    private let blurParamsH: [UInt8]
    private let blurParamsV: [UInt8]
    private let kBlurH: ComputeKernelDescriptor
    private let kBlurV: ComputeKernelDescriptor
    private let kAccumulate: ComputeKernelDescriptor
    private let kCopy: ComputeKernelDescriptor
    private let kSeed: ComputeKernelDescriptor
    private let kStepAB: ComputeKernelDescriptor
    private let kStepBA: ComputeKernelDescriptor
    private let kGather: ComputeKernelDescriptor
    private let accumulateLayout: UniformLayout
    private let silhouetteLayout: UniformLayout
    private let gatherLayout: UniformLayout
    private let jumps: [Int]
    private let finalSilhouette: MTLTexture
    private let raySchedule: (burst: Int, motion: Int, refine: Int, refineFrames: Int)

    private var lastKey: [Float]? = nil
    private var silhouetteReady = false
    private var frame = 0
    private var warmup = SDFIrradianceProgram.warmupFrames
    private var samples = 0
    private var changedLastFrame = false

    init(context ctx: ComputeContext) throws {
        guard let info = ctx.descriptor.compute, info.kernels.count >= 9 else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) radiance kernels")
        }
        field = try SDFVolumetricField(context: ctx, kernelIndex: 0)
        func kernel(_ i: Int) throws -> ComputeKernelDescriptor {
            guard let k = info.kernel(i) else { throw ShaderEngineError.missingFunction("\(ctx.descriptor.name)_k\(i)") }
            return k
        }
        func layout(_ k: ComputeKernelDescriptor) throws -> UniformLayout {
            guard let b = k.buffers.first(where: { $0.space == "uniform" }), let l = info.uniformLayouts[b.name] else {
                throw ShaderEngineError.missingFunction("\(k.entry) uniform layout")
            }
            return l
        }
        kBlurH = try kernel(1)
        kBlurV = try kernel(2)
        kAccumulate = try kernel(3)
        kCopy = try kernel(4)
        kSeed = try kernel(5)
        kStepAB = try kernel(6)
        kStepBA = try kernel(7)
        kGather = try kernel(8)
        accumulateLayout = try layout(kAccumulate)
        silhouetteLayout = try layout(kSeed)
        gatherLayout = try layout(kGather)

        let mobile = SDFKit.isMobileGpuViewport
        let res = mobile ? Self.fieldResMobile : Self.fieldRes
        self.res = res
        let div = mobile ? Self.mobileRayDivisor : 1
        raySchedule = (Self.rays.burst / div, Self.rays.motion / div, Self.rays.refine / div, Self.rays.refineFrames)

        func tex(_ label: String) throws -> MTLTexture {
            guard let t = ctx.makeTexture(width: res, height: res, format: .rgba16Float, label: "Irradiance \(label)") else { throw ShaderEngineError.noMetalDevice }
            return t
        }
        outTex = try tex("gather")
        meanTex = try tex("mean")
        prevTex = try tex("prev")
        blurIntermediate = try tex("denoise intermediate")
        blurOutput = try tex("denoise output")
        jfaA = try tex("silhouette A")
        jfaB = try tex("silhouette B")

        // Halving jump-flood steps down to 1 texel; the final texture's parity follows the pass count.
        var j: [Int] = []
        var step = Int((Double(res) / 2).rounded(.up))
        while step >= 1 {
            j.append(step)
            if step == 1 { break }
            step /= 2
        }
        jumps = j
        finalSilhouette = jumps.count % 2 == 1 ? jfaB : jfaA

        // Denoise (kit/blur createGaussianBlurCompute at res×res, input res×res): updateRadius(4) at
        // creation, then updateRadius(DENOISE_RADIUS). scaleY = 1, so H and V share one sigma.
        let size = (Self.denoiseHalfKernel * 2 + 1) * 4
        guard let wh = ctx.makeBuffer(length: size, label: "Irradiance denoise weightsH"),
              let wv = ctx.makeBuffer(length: size, label: "Irradiance denoise weightsV") else { throw ShaderEngineError.noMetalDevice }
        weightsH = wh
        weightsV = wv
        let sigmaH = max(Self.denoiseRadius * 0.5, 0.001)
        let sigmaV = max(sigmaH / (Double(res) / Double(res)), 0.001)
        let h = SDFKit.truncatedWeights(halfKernel: Self.denoiseHalfKernel, sigma: sigmaH)
        let v = SDFKit.truncatedWeights(halfKernel: Self.denoiseHalfKernel, sigma: sigmaV)
        memcpy(wh.contents(), h.weights, h.weights.count * 4)
        memcpy(wv.contents(), v.weights, v.weights.count * 4)
        blurParamsH = SDFKit.pack(try layout(kBlurH), ["activeHalf": [Float(h.activeHalf)], "inputWidth": [Float(res)], "inputHeight": [Float(res)]])
        blurParamsV = SDFKit.pack(try layout(kBlurV), ["activeHalf": [Float(v.activeHalf)]])
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        // The pre-march first (false when the shape is static), then read its domain.
        let pre = try field.prepare(ctx)
        let runSilhouette = pre || !silhouetteReady
        if runSilhouette { silhouetteReady = true }
        let dom = field.domain

        let center = SDFKit.uniform(ctx, "n_x.center") ?? [0.5, 0.5]
        let scale = SDFKit.number(ctx, "scale", 1)
        let rotation = SDFKit.number(ctx, "rotation", 0)
        let aspect = Double(max(1, ctx.width)) / Double(max(1, ctx.height))
        let lights = lightLanes(ctx, center: SIMD2(Double(center[0]), Double(center[1])), scale: scale, rotation: rotation, aspect: aspect)
        let sa = SDFKit.analyticSubPropValues(SDFKit.parseShapeConfig(ctx.string("shape")))
        var values: [String: [Float]] = [
            "center": [center[0], center[1]],
            "lightPos": lights.pos,
            "lightColor": lights.color,
            "lightCount": [Float(lights.count)],
            "scale": [Float(scale)],
            "rotation": [Float(rotation)],
            "aspect": [Float(aspect)],
            "reach": [Float(SDFKit.number(ctx, "reach", 3))],
            "wrap": [Float(SDFKit.number(ctx, "wrap", 0))],
            "lightRange": [Float(SDFKit.number(ctx, "lightRange", 1))],
            "shadowSoftness": [Float(SDFKit.number(ctx, "shadowSoftness", 0))],
            // Hit threshold + minimum step at field-texel scale.
            "eps": [Float((1 / Double(res)) / max(scale, 0.001))],
            "res": [Float(res)],
            "saRadius": [sa[0]], "saSides": [sa[1]], "saRounding": [sa[2]], "saInnerRatio": [sa[3]],
            "saRotation": [sa[4]], "saHeight": [sa[5]], "saOffset": [sa[6]], "saAperture": [sa[7]],
            "vfOriginX": [Float(dom.originX)], "vfOriginY": [Float(dom.originY)],
            "vfSpanX": [Float(dom.spanX)], "vfSpanY": [Float(dom.spanY)],
            "vfActiveRes": [Float(dom.activeRes)], "vfRBound": [Float(dom.rBound)],
        ]
        let key = values.keys.sorted().flatMap { values[$0]! }

        // A change (or a pre-march) restarts the progressive estimate with a burst; a still scene
        // refines for `refineFrames`, then idles.
        let warming = warmup > 0
        if warming { warmup -= 1 }
        let changed = key != lastKey || pre || runSilhouette || warming
        let rays: Int
        if changed {
            lastKey = key
            frame = 0
            samples = 0
            rays = changedLastFrame ? raySchedule.motion : raySchedule.burst
        } else if frame > raySchedule.refineFrames {
            changedLastFrame = false
            return outputs()
        } else {
            rays = raySchedule.refine
        }
        changedLastFrame = changed
        let sampleIndex = frame
        frame += 1
        let weight = Double(rays) / Double(samples + rays)
        samples += rays
        values["frame"] = [Float(sampleIndex)]
        values["rays"] = [Float(rays)]
        let gatherParams = SDFKit.pack(gatherLayout, values)
        let accumulateParams = SDFKit.pack(accumulateLayout, ["weight": [Float(weight)]])

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return outputs() }
        defer { enc.endEncoding() }
        enc.label = "Irradiance gather"
        let grid = SIMD3<UInt32>(UInt32(res), UInt32(res), 1)
        let lib = ctx.library
        if pre { try field.encode(enc, ctx) }
        if runSilhouette {
            var base: [String: [Float]] = [
                "vfOriginX": [Float(dom.originX)], "vfOriginY": [Float(dom.originY)],
                "vfSpanX": [Float(dom.spanX)], "vfSpanY": [Float(dom.spanY)],
                "vfActiveRes": [Float(dom.activeRes)], "vfRBound": [Float(dom.rBound)],
                "res": [Float(res)], "step": [0],
            ]
            let seedParams = SDFKit.pack(silhouetteLayout, base)
            try SDFKit.dispatch(ctx, enc, kSeed, library: lib, threads: grid) { e in
                self.bindUniform(e, kSeed, seedParams)
                if let s = kSeed.texture("fieldTex") { e.setTexture(field.texture, index: s.slot) }
                if let s = kSeed.texture("out") { e.setTexture(jfaA, index: s.slot) }
            }
            for (i, step) in jumps.enumerated() {
                base["step"] = [Float(step)]
                let p = SDFKit.pack(silhouetteLayout, base)
                let k = i % 2 == 0 ? kStepAB : kStepBA
                let (src, dst) = i % 2 == 0 ? (jfaA, jfaB) : (jfaB, jfaA)
                try SDFKit.dispatch(ctx, enc, k, library: lib, threads: grid) { e in
                    self.bindUniform(e, k, p)
                    if let s = k.textures.first(where: { $0.name.hasPrefix("src") }) { e.setTexture(src, index: s.slot) }
                    if let s = k.texture("out") { e.setTexture(dst, index: s.slot) }
                }
            }
        }
        try SDFKit.dispatch(ctx, enc, kGather, library: lib, threads: grid) { e in
            self.bindUniform(e, kGather, gatherParams)
            if let s = kGather.texture("outTex") { e.setTexture(outTex, index: s.slot) }
            if let s = kGather.texture("silhouetteTex") { e.setTexture(finalSilhouette, index: s.slot) }
            e.setSamplerState(ctx.device.linearClamp, index: 0)
        }
        try SDFKit.dispatch(ctx, enc, kAccumulate, library: lib, threads: grid) { e in
            self.bindUniform(e, kAccumulate, accumulateParams)
            if let s = kAccumulate.texture("sample") { e.setTexture(outTex, index: s.slot) }
            if let s = kAccumulate.texture("prev") { e.setTexture(prevTex, index: s.slot) }
            if let s = kAccumulate.texture("out") { e.setTexture(meanTex, index: s.slot) }
        }
        try SDFKit.dispatch(ctx, enc, kCopy, library: lib, threads: grid) { e in
            if let s = kCopy.textures.first(where: { $0.name.hasPrefix("src") }) { e.setTexture(meanTex, index: s.slot) }
            if let s = kCopy.texture("out") { e.setTexture(prevTex, index: s.slot) }
        }
        try SDFKit.dispatch(ctx, enc, kBlurH, library: lib, threads: grid) { e in
            self.bindUniform(e, kBlurH, blurParamsH)
            if let s = kBlurH.texture("input") { e.setTexture(meanTex, index: s.slot) }
            if let s = kBlurH.texture("intermediate") { e.setTexture(blurIntermediate, index: s.slot) }
            if let s = kBlurH.buffer("weights") { e.setBuffer(weightsH, offset: 0, index: s.slot) }
        }
        try SDFKit.dispatch(ctx, enc, kBlurV, library: lib, threads: grid) { e in
            self.bindUniform(e, kBlurV, blurParamsV)
            if let s = kBlurV.texture("src") { e.setTexture(blurIntermediate, index: s.slot) }
            if let s = kBlurV.texture("output") { e.setTexture(blurOutput, index: s.slot) }
            if let s = kBlurV.buffer("weights") { e.setBuffer(weightsV, offset: 0, index: s.slot) }
        }
        return outputs()
    }

    private func outputs() -> ComputeOutputs {
        ComputeOutputs(textures: ["compute_0": field.texture, "compute_1": blurOutput], extraFields: field.extraFields)
    }

    private func bindUniform(_ e: MTLComputeCommandEncoder, _ k: ComputeKernelDescriptor, _ bytes: [UInt8]) {
        if let s = k.buffers.first(where: { $0.space == "uniform" }) { SDFKit.setBytes(e, bytes, index: s.slot) }
    }

    /// Upstream `lightLanes`: the list prop → fixed-capacity lanes, positions mapped to placement space
    /// once on the CPU (`toPlacement`). Reads the list as packed into the node's uniforms (the same
    /// resolved values the fragment reads).
    private func lightLanes(_ ctx: ComputeContext, center: SIMD2<Double>, scale: Double, rotation: Double, aspect: Double) -> (pos: [Float], color: [Float], count: Int) {
        let count = min(Self.maxLights, Int(SDFKit.uniform(ctx, "n_x.lightsCount")?.first ?? 0))
        let positions = SDFKit.uniform(ctx, "n_x.lights_position") ?? []
        let colors = SDFKit.uniform(ctx, "n_x.lights_color") ?? []
        let intensities = SDFKit.uniform(ctx, "n_x.lights_intensity") ?? []
        var pos = [Float](repeating: 0, count: Self.maxLights * 4)
        var color = [Float](repeating: 0, count: Self.maxLights * 4)
        let r = rotation * Double.pi / 180
        let c = cos(r), s = sin(r)
        let sc = max(scale, 0.001)
        for i in 0..<count where i * 4 + 3 < positions.count {
            let stored = SIMD2(Double(positions[i * 4]), Double(positions[i * 4 + 1]))
            let dxAc = (stored.x - center.x) * aspect
            let dy = (1 - stored.y) - (1 - center.y)
            pos[i * 4] = Float((dxAc * c + dy * s) / sc + 0.5)
            pos[i * 4 + 1] = Float((dy * c - dxAc * s) / sc + 0.5)
            if i * 4 + 2 < colors.count {
                color[i * 4] = colors[i * 4]
                color[i * 4 + 1] = colors[i * 4 + 1]
                color[i * 4 + 2] = colors[i * 4 + 2]
            }
            color[i * 4 + 3] = i * 4 < intensities.count ? intensities[i * 4] : 0
        }
        return (pos, color, count)
    }
}
#endif
