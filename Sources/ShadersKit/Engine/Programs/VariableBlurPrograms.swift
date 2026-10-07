#if canImport(Metal)
import Foundation
import Metal
import simd

// MARK: - Shared helpers (kit/blur.ts)

enum BlurKit {
    /// Upstream `INTENSITY_TO_RADIUS`: intensity (UI 0–200) → Gaussian pixel radius.
    static let intensityToRadius: Float = 0.36

    /// Upstream `buildFixedWeights`: full symmetric Gaussian (sigma = halfKernel / 3), normalized.
    static func fixedWeights(halfKernel: Int) -> [Float] {
        let sigma = Double(halfKernel) / 3
        var weights: [Double] = []
        var sum = 0.0
        for i in -halfKernel...halfKernel {
            let w = exp(-Double(i * i) / (2 * sigma * sigma))
            weights.append(w)
            sum += w
        }
        return weights.map { Float($0 / sum) }
    }

    /// The kernel that binds a texture named `texture` (kernels are matched by their bindings).
    static func kernel(_ info: ComputeInfo, binding texture: String, shader: String) throws -> ComputeKernelDescriptor {
        guard let k = info.kernels.first(where: { $0.texture(texture) != nil }) else {
            throw ShaderEngineError.missingFunction("\(shader) kernel binding \(texture)")
        }
        return k
    }

    static func uniformSlot(_ kernel: ComputeKernelDescriptor) -> ComputeKernelDescriptor.BufferSlot? {
        kernel.buffers.first { $0.space == "uniform" }
    }

    static func uniformLayout(_ info: ComputeInfo, _ kernel: ComputeKernelDescriptor, shader: String) throws -> UniformLayout {
        guard let slot = uniformSlot(kernel), let layout = info.uniformLayouts[slot.name] else {
            throw ShaderEngineError.missingFunction("\(shader) \(kernel.entry) params layout")
        }
        return layout
    }

    /// Compute-grid size the generated kernels were specialised for (the recorded textures).
    static func computeSize(_ info: ComputeInfo, default size: (Int, Int)) -> (width: Int, height: Int) {
        if let t = info.textures.first, let w = t.width, let h = t.height { return (w, h) }
        return size
    }

    /// The premultiplied child RTT the upstream hooks bind (`convertToTexture(childNode)`).
    static func childInput(_ ctx: ComputeContext) -> MTLTexture? {
        let key = ctx.descriptor.compute?.rttInputKeys.first ?? "rtt_0"
        return ctx.rttTextures[key] ?? ctx.childTexture
    }

    static func makeTexture(_ ctx: ComputeContext, _ width: Int, _ height: Int, _ format: MTLPixelFormat, _ label: String) throws -> MTLTexture {
        guard let t = ctx.makeTexture(width: width, height: height, format: format, label: label) else { throw ShaderEngineError.noMetalDevice }
        return t
    }

    static func makeBuffer(_ ctx: ComputeContext, _ length: Int, _ label: String) throws -> MTLBuffer {
        guard let b = ctx.makeBuffer(length: length, label: label) else { throw ShaderEngineError.noMetalDevice }
        return b
    }
}

// MARK: - Variable Gaussian scaffold

/// Port of upstream `createVariableGaussianBlurCompute` (kit/blur.ts): a per-pixel-radius separable
/// Gaussian at a fixed compute resolution. The caller writes `blurMap.r` (radius in input pixels)
/// before `encode` runs the H and V passes. Output is rgba16Float at compute resolution.
final class VariableGaussianBlur {
    let computeWidth: Int
    let computeHeight: Int
    let blurMap: MTLTexture
    let output: MTLTexture
    private let intermediate: MTLTexture
    private let weights: MTLBuffer
    private let paramsH: MTLBuffer
    private let paramsV: MTLBuffer
    private let kernelH: ComputeKernelDescriptor
    private let kernelV: ComputeKernelDescriptor
    private let layoutH: UniformLayout
    private let layoutV: UniformLayout

    init(context ctx: ComputeContext, halfKernel: Int, computeWidth: Int, computeHeight: Int) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute") }
        kernelH = try BlurKit.kernel(info, binding: "intermediate", shader: name)
        kernelV = try BlurKit.kernel(info, binding: "src", shader: name)
        layoutH = try BlurKit.uniformLayout(info, kernelH, shader: name)
        layoutV = try BlurKit.uniformLayout(info, kernelV, shader: name)
        self.computeWidth = computeWidth
        self.computeHeight = computeHeight
        blurMap = try BlurKit.makeTexture(ctx, computeWidth, computeHeight, .rgba32Float, "\(name) blurMap")
        intermediate = try BlurKit.makeTexture(ctx, computeWidth, computeHeight, .rgba16Float, "\(name) blur intermediate")
        output = try BlurKit.makeTexture(ctx, computeWidth, computeHeight, .rgba16Float, "\(name) blur output")
        let w = BlurKit.fixedWeights(halfKernel: halfKernel)
        weights = try BlurKit.makeBuffer(ctx, w.count * 4, "\(name) blur weights")
        memcpy(weights.contents(), w, w.count * 4)
        paramsH = try BlurKit.makeBuffer(ctx, layoutH.size, "\(name) blur paramsH")
        paramsV = try BlurKit.makeBuffer(ctx, layoutV.size, "\(name) blur paramsV")
    }

    /// Upstream `setInputDimensions` (also the initial write): H maps compute px → input px, V
    /// converts the input-pixel radius into compute-Y pixels.
    func setInputDimensions(_ ctx: ComputeContext, width: Int, height: Int) {
        setParams(ctx, inputWidth: Float(width), inputHeight: Float(height), scaleY: Float(height) / Float(computeHeight))
    }

    func setParams(_ ctx: ComputeContext, inputWidth: Float, inputHeight: Float, scaleY: Float) {
        ctx.pack(layoutH, ["inputWidth": [inputWidth], "inputHeight": [inputHeight]], into: paramsH)
        ctx.pack(layoutV, ["scaleY": [scaleY]], into: paramsV)
    }

    /// Dispatches the H then V pass (the map must already be filled earlier in `encoder`).
    func encode(_ ctx: ComputeContext, _ encoder: MTLComputeCommandEncoder, input: MTLTexture) throws {
        let threads = SIMD3<UInt32>(UInt32(computeWidth), UInt32(computeHeight), 1)
        try ctx.dispatch(encoder, kernelH, threads: threads) { e in
            if let s = kernelH.texture("blurMap") { e.setTexture(blurMap, index: s.slot) }
            if let s = kernelH.texture("input") { e.setTexture(input, index: s.slot) }
            if let s = kernelH.texture("intermediate") { e.setTexture(intermediate, index: s.slot) }
            if let s = kernelH.buffer("weights") { e.setBuffer(weights, offset: 0, index: s.slot) }
            if let s = BlurKit.uniformSlot(kernelH) { e.setBuffer(paramsH, offset: 0, index: s.slot) }
        }
        try ctx.dispatch(encoder, kernelV, threads: threads) { e in
            if let s = kernelV.texture("blurMap") { e.setTexture(blurMap, index: s.slot) }
            if let s = kernelV.texture("src") { e.setTexture(intermediate, index: s.slot) }
            if let s = kernelV.texture("output") { e.setTexture(output, index: s.slot) }
            if let s = kernelV.buffer("weights") { e.setBuffer(weights, offset: 0, index: s.slot) }
            if let s = BlurKit.uniformSlot(kernelV) { e.setBuffer(paramsV, offset: 0, index: s.slot) }
        }
    }
}

// MARK: - withVariableBlurCompute consumers

/// Port of upstream `withVariableBlurCompute` (static, non-map fill) for ProgressiveBlur,
/// TiltShift (std/effects/blurs `progressiveBlur`, `tiltShift`) and ReflectivePlane
/// (`depthRampBlur`): each frame the shader's fill kernel writes the radius map, then the
/// variable Gaussian blurs the child RTT. Publishes the blurred buffer as `compute_0`.
final class VariableBlurProgram: ComputeProgram {
    static let shaderNames = ["ProgressiveBlur", "TiltShift", "ReflectivePlane"]

    private let blur: VariableGaussianBlur
    private let fillKernel: ComputeKernelDescriptor
    private let fillLayout: UniformLayout
    private let fillParams: MTLBuffer
    private var canvasWidth = 0
    private var canvasHeight = 0

    init(context ctx: ComputeContext) throws {
        let name = ctx.descriptor.name
        guard let info = ctx.descriptor.compute else { throw ShaderEngineError.missingFunction("\(name) compute") }
        // halfKernel per upstream call site: tiltShift 14, ReflectivePlane HALF_KERNEL 30, default 24.
        let halfKernel: Int
        switch name {
        case "TiltShift": halfKernel = 14
        case "ReflectivePlane": halfKernel = 30
        default: halfKernel = 24
        }
        let size = BlurKit.computeSize(info, default: (1024, 640))
        blur = try VariableGaussianBlur(context: ctx, halfKernel: halfKernel, computeWidth: size.width, computeHeight: size.height)
        fillKernel = try BlurKit.kernel(info, binding: "blurMap_2", shader: name)
        fillLayout = try BlurKit.uniformLayout(info, fillKernel, shader: name)
        fillParams = try BlurKit.makeBuffer(ctx, fillLayout.size, "\(name) fill params")
    }

    /// The shader's per-frame `fillValues` (live post-transform CPU values; `center` is already
    /// `(x, 1 - y)`, the kernel recovers the authored y).
    private func fillValues(_ ctx: ComputeContext) -> [String: [Float]] {
        let aspect = Float(canvasWidth) / Float(canvasHeight)
        switch ctx.descriptor.name {
        case "ProgressiveBlur":
            let c = ctx.position("center")
            return [
                "angle": [ctx.scalar("angle")], "centerX": [c.x], "centerY": [c.y],
                "falloff": [ctx.scalar("falloff")], "aspect": [aspect],
                "maxRadius": [ctx.scalar("intensity") * BlurKit.intensityToRadius],
            ]
        case "TiltShift":
            let c = ctx.position("center")
            return [
                "angle": [ctx.scalar("angle")], "centerX": [c.x], "centerY": [c.y],
                "width": [ctx.scalar("width")], "falloff": [ctx.scalar("falloff")], "aspect": [aspect],
                "maxRadius": [ctx.scalar("intensity") * BlurKit.intensityToRadius],
            ]
        default: // ReflectivePlane (depthRampBlur)
            return [
                "height": [ctx.scalar("height")],
                "blurAmount": [ctx.scalar("blur")],
                // floored at 0.01: smoothstep is undefined at edge0 == edge1
                "blurDistance": [max(0.01, ctx.scalar("blurDistance"))],
            ]
        }
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let input = BlurKit.childInput(ctx) else { return ComputeOutputs() }
        let w = max(1, ctx.width), h = max(1, ctx.height)
        if w != canvasWidth || h != canvasHeight {
            canvasWidth = w
            canvasHeight = h
            blur.setInputDimensions(ctx, width: w, height: h)
        }
        ctx.pack(fillLayout, fillValues(ctx), into: fillParams)

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
        defer { enc.endEncoding() }
        enc.label = "\(ctx.descriptor.name) variable blur"
        // Fill the radius map first; the variable H/V passes then read it per pixel.
        let threads = SIMD3<UInt32>(UInt32(blur.computeWidth), UInt32(blur.computeHeight), 1)
        try ctx.dispatch(enc, fillKernel, threads: threads) { e in
            if let s = fillKernel.texture("blurMap_2") { e.setTexture(blur.blurMap, index: s.slot) }
            if let s = BlurKit.uniformSlot(fillKernel) { e.setBuffer(fillParams, offset: 0, index: s.slot) }
        }
        try blur.encode(ctx, enc, input: input)
        return ComputeOutputs(textures: ["compute_0": blur.output])
    }
}
#endif
