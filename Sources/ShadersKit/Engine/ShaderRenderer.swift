#if canImport(Metal)
import Foundation
import Metal
import simd

/// Renders a layer tree with Metal: every node becomes one or more fullscreen passes into
/// intermediate rgba16Float textures, siblings are composited with the blend/mask kit, and a
/// final present pass applies tone mapping and the sRGB transfer into the destination texture.
public final class ShaderRenderer {
    public let device: ShaderDevice
    public var options: RenderOptions
    public private(set) var stats = FrameStats()
    /// When true (offscreen renders, tests) the first use of a shader compiles synchronously.
    /// Interactive views leave this false so a new shader never stalls the frame; the node is
    /// skipped until its background compile finishes.
    public var blockingCompile = false

    private let pool: TexturePool
    private var states: [String: NodeState] = [:]
    private var frameIndex = 0
    private var uniformScratch: UnsafeMutableRawPointer
    private var uniformScratchSize = 16384
    private var packers: [String: UniformPacker] = [:]
    private var currentRoots: [ShaderNode] = []
    private var maskCache: [String: MTLTexture] = [:]
    private var frame = FrameInput(pixelSize: SIMD2(1, 1))

    public init(device: ShaderDevice, options: RenderOptions = RenderOptions()) {
        self.device = device
        self.options = options
        pool = TexturePool(device: device.device)
        uniformScratch = UnsafeMutableRawPointer.allocate(byteCount: uniformScratchSize, alignment: 16)
    }

    deinit {
        uniformScratch.deallocate()
    }

    // MARK: - Public entry points

    /// Renders `nodes` into `target` (any render-target texture) using `commandBuffer`.
    public func render(_ nodes: [ShaderNode], frame: FrameInput, into target: MTLTexture, commandBuffer: MTLCommandBuffer) {
        frameIndex += 1
        stats = FrameStats()
        self.frame = frame
        currentRoots = nodes
        maskCache.removeAll(keepingCapacity: true)
        let w = max(1, Int(frame.pixelSize.x))
        let h = max(1, Int(frame.pixelSize.y))
        let composed = composite(nodes, key: "root", width: w, height: h, cb: commandBuffer)
        present(composed, into: target, cb: commandBuffer)
        pool.endFrame()
        if frameIndex % 120 == 0 { collectGarbage() }
    }

    /// Renders to a new bgra8Unorm texture and waits for completion (thumbnails, tests).
    /// Shaders compile synchronously here so the result is complete.
    public func renderOffscreen(_ nodes: [ShaderNode], frame: FrameInput) -> MTLTexture? {
        let prev = blockingCompile
        blockingCompile = true
        defer { blockingCompile = prev }
        let w = max(1, Int(frame.pixelSize.x))
        let h = max(1, Int(frame.pixelSize.y))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead]
        d.storageMode = .shared
        guard let target = device.device.makeTexture(descriptor: d), let cb = device.queue.makeCommandBuffer() else { return nil }
        render(nodes, frame: frame, into: target, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()
        return target
    }

    /// Drops cached per-node state (simulation buffers, media) for nodes no longer rendered.
    public func resetState() {
        states.removeAll()
    }

    // MARK: - Composition

    private func stateKey(_ node: ShaderNode, fallback: String) -> String {
        node.attributes.id.map { "id:\($0)" } ?? fallback
    }

    private func state(for key: String) -> NodeState {
        if let s = states[key] {
            s.lastFrame = frameIndex
            return s
        }
        let s = NodeState()
        s.lastFrame = frameIndex
        states[key] = s
        return s
    }

    private var frameIndexForState: Int { frameIndex }

    private func collectGarbage() {
        states = states.filter { frameIndex - $0.value.lastFrame < 600 }
    }

    private func packer(for desc: ShaderDescriptor) -> UniformPacker {
        if let p = packers[desc.name] { return p }
        let p = UniformPacker(descriptor: desc)
        packers[desc.name] = p
        return p
    }

    private func isPlainLayer(_ a: LayerAttributes) -> Bool {
        a.blendMode == .normal && a.opacity >= 1 && a.mask == nil && (a.transform?.isIdentity ?? true)
    }

    /// Composites visible siblings bottom-to-top. Returns nil when nothing is drawn.
    private func composite(_ children: [ShaderNode], key: String, width: Int, height: Int, cb: MTLCommandBuffer) -> MTLTexture? {
        let visible = children.enumerated().filter { $0.element.attributes.visible }
        if visible.isEmpty { return nil }
        if visible.count == 1, isPlainLayer(visible[0].element.attributes) {
            let (i, child) = visible[0]
            return renderNode(child, key: stateKey(child, fallback: "\(key)/\(i)"), width: width, height: height, cb: cb)
        }
        var acc: MTLTexture? = nil
        for (i, child) in visible {
            let childKey = stateKey(child, fallback: "\(key)/\(i)")
            guard var out = renderNode(child, key: childKey, width: width, height: height, cb: cb) else { continue }
            if let t = child.attributes.transform, !t.isIdentity {
                out = transformPass(out, t, width: width, height: height, cb: cb) ?? out
            }
            var maskTex: MTLTexture? = nil
            if let m = child.attributes.mask {
                maskTex = renderMask(m, key: childKey, width: width, height: height, cb: cb)
            }
            acc = blendPass(base: acc, overlay: out, attributes: child.attributes, mask: maskTex, width: width, height: height, cb: cb)
        }
        return acc
    }

    private func renderMask(_ mask: MaskConfig, key: String, width: Int, height: Int, cb: MTLCommandBuffer) -> MTLTexture? {
        switch mask.source {
        case .node(let n):
            return renderNode(n, key: "\(key)/mask", width: width, height: height, cb: cb)
        case .layer(let id):
            if let t = maskCache[id] { return t }
            var found: ShaderNode? = nil
            for r in currentRoots where found == nil {
                r.forEachNode { n in if found == nil, n.attributes.id == id { found = n } }
            }
            guard let src = found else { return nil }
            let t = renderNode(src, key: "id:\(id)", width: width, height: height, cb: cb)
            if let t { maskCache[id] = t }
            return t
        }
    }

    // MARK: - Node passes

    private func renderNode(_ node: ShaderNode, key: String, width: Int, height: Int, cb: MTLCommandBuffer) -> MTLTexture? {
        guard let desc = ShaderRegistry.descriptor(node.type) else {
            stats.unsupportedNodes.append(node.type)
            return nil
        }
        stats.nodes += 1
        var st = state(for: key)
        if st.shaderName != desc.name {
            st = NodeState()
            st.shaderName = desc.name
            st.lastFrame = frameIndexForState
            states[key] = st
        }
        var childTex: MTLTexture? = nil
        if desc.acceptsChildren, !node.children.isEmpty {
            childTex = composite(node.children, key: key, width: width, height: height, cb: cb)
        }
        if desc.name == "Group" {
            return childTex
        }
        if desc.flags.requiresChild, childTex == nil {
            // a filter without content draws nothing (matches upstream "needs input" ghosting)
            return nil
        }
        var props = desc.defaultProps
        for (k, v) in node.props where !v.isNull { props[k] = v }
        let pk = packer(for: desc)
        guard let variant = pk.selectVariant(props) else { return nil }
        let library: MTLLibrary
        do {
            if blockingCompile {
                library = try device.library(forShader: desc.msl)
            } else if let ready = try device.libraryIfReady(forShader: desc.msl) {
                library = ready
            } else {
                stats.pendingCompiles += 1
                return nil
            }
        } catch {
            stats.compileErrors.append("\(desc.name): \(error)")
            return nil
        }
        pk.advanceClocks(props: props, state: st, deltaTime: frame.deltaTime)
        _ = HostFieldsHooks.apply(descriptor: desc, props: props, frame: frame, options: options, state: st, width: width, height: height)
        ensureScratch(pk.size)
        pk.pack(props: props, state: st, frame: frame, options: options, into: uniformScratch)

        var rtt: [String: MTLTexture] = [:]
        var computeTextures: [String: MTLTexture] = [:]
        var mediaTextures: [String: MTLTexture] = [:]
        var output: MTLTexture? = nil
        var computeDone = false
        if let mediaType = MediaPrograms.program(for: desc.name) {
            let mctx = MediaContext(device: device, descriptor: desc, frame: frame, props: props, commandBuffer: cb, width: width, height: height, state: st, options: options)
            do {
                let program: MediaProgram
                if let existing = st.storage["__media"] as? MediaProgram { program = existing } else {
                    program = try mediaType.init(context: mctx)
                    st.storage["__media"] = program
                }
                let out = try program.encode(mctx)
                mediaTextures = out.textures
                if !out.extraFields.isEmpty {
                    for (k, v) in out.extraFields { st.extraFields[k] = v }
                    pk.pack(props: props, state: st, frame: frame, options: options, into: uniformScratch)
                }
            } catch {
                stats.compileErrors.append("\(desc.name) media: \(error)")
            }
        } else if desc.role == .media, !stats.unsupportedNodes.contains(desc.name) {
            stats.unsupportedNodes.append(desc.name)
        }
        for pass in variant.passes {
            if pass.kind == .final, !computeDone {
                computeDone = true
                if desc.flags.hasCompute || variant.computeSteps > 0 {
                    runCompute(node: node, descriptor: desc, variant: variant, props: props, packer: pk, state: st, library: library, child: childTex, rtt: rtt, width: width, height: height, cb: cb, outputs: &computeTextures)
                }
            }
            guard let target = pool.acquire(width: width, height: height, format: device.intermediateFormat, label: pass.entry) else { return nil }
            let pipeline: MTLRenderPipelineState
            do {
                pipeline = try device.pipeline(library: library, fragment: pass.entry, pixelFormat: device.intermediateFormat)
            } catch {
                stats.compileErrors.append("\(pass.entry): \(error)")
                return nil
            }
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = target
            rpd.colorAttachments[0].loadAction = .dontCare
            rpd.colorAttachments[0].storeAction = .store
            guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return nil }
            enc.label = pass.entry
            enc.setRenderPipelineState(pipeline)
            if pass.usesUniforms {
                enc.setFragmentBytes(uniformScratch, length: pk.size, index: 0)
            }
            for slot in pass.textures {
                let tex = computeTextures[slot.key] ?? mediaTextures[slot.key] ?? resolveTexture(slot.key, node: node, descriptor: desc, props: props, state: st, child: childTex, rtt: rtt)
                enc.setFragmentTexture(tex, index: slot.slot)
            }
            for s in pass.samplers {
                enc.setFragmentSamplerState(device.sampler(named: s.name), index: s.slot)
            }
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
            stats.passes += 1
            if pass.kind == .rtt, let k = pass.textureKey {
                rtt[k] = target
            } else {
                output = target
            }
        }
        return output
    }

    /// Runs the node's compute program (if one is ported) between the RTT and final passes.
    private func runCompute(node: ShaderNode, descriptor desc: ShaderDescriptor, variant: ShaderVariant, props: [String: PropValue], packer pk: UniformPacker, state st: NodeState, library: MTLLibrary, child: MTLTexture?, rtt: [String: MTLTexture], width: Int, height: Int, cb: MTLCommandBuffer, outputs: inout [String: MTLTexture]) {
        guard let programType = ComputePrograms.program(for: desc.name) else {
            if !stats.unsupportedNodes.contains(desc.name) { stats.unsupportedNodes.append(desc.name) }
            return
        }
        let ctx = ComputeContext(device: device, descriptor: desc, library: library, frame: frame, props: props, uniformBytes: UnsafeRawPointer(uniformScratch), uniformSize: pk.size, childTexture: child, rttTextures: rtt, commandBuffer: cb, width: width, height: height, state: st)
        do {
            let program: ComputeProgram
            if let existing = st.storage["__program"] as? ComputeProgram {
                program = existing
            } else {
                program = try programType.init(context: ctx)
                st.storage["__program"] = program
            }
            let result = try program.encode(ctx)
            outputs = result.textures
            if !result.extraFields.isEmpty {
                for (k, v) in result.extraFields { st.extraFields[k] = v }
                pk.pack(props: props, state: st, frame: frame, options: options, into: uniformScratch)
            }
            stats.passes += 1
        } catch {
            stats.compileErrors.append("\(desc.name) compute: \(error)")
        }
    }

    private func resolveTexture(_ key: String, node: ShaderNode, descriptor: ShaderDescriptor, props: [String: PropValue], state: NodeState, child: MTLTexture?, rtt: [String: MTLTexture]) -> MTLTexture {
        if key.hasPrefix("rtt_") {
            return rtt[key] ?? device.placeholderTexture
        }
        if key.hasPrefix("media_") {
            if descriptor.flags.requiresChild || descriptor.flags.acceptsOptionalChild {
                return child ?? device.placeholderTexture
            }
            return device.placeholderTexture
        }
        // compute_* / video_* — provided by shader-specific programs (not yet ported)
        if let t = state.storage[key] as? MTLTexture { return t }
        return device.placeholderTexture
    }

    private func ensureScratch(_ size: Int) {
        if size > uniformScratchSize {
            uniformScratch.deallocate()
            uniformScratchSize = max(size, uniformScratchSize * 2)
            uniformScratch = UnsafeMutableRawPointer.allocate(byteCount: uniformScratchSize, alignment: 16)
        }
    }

    // MARK: - Compositor passes

    private struct BlendParams {
        var mode: Int32
        var opacity: Float
        var maskType: Int32
        var flags: Int32
    }

    private struct PresentParams {
        var toneMode: Int32
        var premultiply: Int32
        var srgb: Int32
        var pad: Int32
        var background: SIMD4<Float>
    }

    private struct TransformParams {
        var offset: SIMD2<Float>
        var anchor: SIMD2<Float>
        var rotation: Float
        var scale: Float
        var aspect: Float
        var edges: Int32
    }

    private func fullscreen(_ pipelineName: String, into target: MTLTexture, format: MTLPixelFormat, cb: MTLCommandBuffer, body: (MTLRenderCommandEncoder) -> Void) {
        guard let pipeline = try? device.compositorPipeline(pipelineName, pixelFormat: format) else {
            stats.compileErrors.append("compositor \(pipelineName) unavailable")
            return
        }
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = target
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.label = pipelineName
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentSamplerState(device.linearClamp, index: 0)
        body(enc)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
    }

    private func blendPass(base: MTLTexture?, overlay: MTLTexture, attributes: LayerAttributes, mask: MTLTexture?, width: Int, height: Int, cb: MTLCommandBuffer) -> MTLTexture? {
        guard let target = pool.acquire(width: width, height: height, format: device.intermediateFormat, label: "blend \(attributes.blendMode.rawValue)") else { return nil }
        var params = BlendParams(mode: Int32(attributes.blendMode.shaderIndex), opacity: max(0, min(1, attributes.opacity)), maskType: mask == nil ? -1 : Int32(attributes.mask?.type.shaderIndex ?? 0), flags: base == nil ? 1 : 0)
        fullscreen("sk_blend", into: target, format: device.intermediateFormat, cb: cb) { enc in
            enc.setFragmentBytes(&params, length: MemoryLayout<BlendParams>.stride, index: 0)
            enc.setFragmentTexture(base ?? device.placeholderTexture, index: 0)
            enc.setFragmentTexture(overlay, index: 1)
            enc.setFragmentTexture(mask ?? device.placeholderTexture, index: 2)
        }
        stats.blendPasses += 1
        return target
    }

    private func transformPass(_ src: MTLTexture, _ t: LayerTransform, width: Int, height: Int, cb: MTLCommandBuffer) -> MTLTexture? {
        guard let target = pool.acquire(width: width, height: height, format: device.intermediateFormat, label: "transform") else { return nil }
        var params = TransformParams(offset: SIMD2(t.offsetX, t.offsetY), anchor: SIMD2(t.anchorX, t.anchorY), rotation: t.rotation * .pi / 180, scale: t.scale, aspect: frame.aspect, edges: Int32(t.edges.uniformValue))
        fullscreen("sk_transform", into: target, format: device.intermediateFormat, cb: cb) { enc in
            enc.setFragmentBytes(&params, length: MemoryLayout<TransformParams>.stride, index: 0)
            enc.setFragmentTexture(src, index: 0)
        }
        stats.passes += 1
        return target
    }

    private func present(_ src: MTLTexture?, into target: MTLTexture, cb: MTLCommandBuffer) {
        let isSRGB: Bool
        switch target.pixelFormat {
        case .bgra8Unorm_srgb, .rgba8Unorm_srgb: isSRGB = true
        default: isSRGB = false
        }
        let bg = options.backgroundColor
        var params = PresentParams(toneMode: Int32(options.toneMapping.shaderIndex), premultiply: options.premultiplyAlpha ? 1 : 0, srgb: isSRGB ? 0 : 1, pad: 0, background: bg)
        fullscreen("sk_present", into: target, format: target.pixelFormat, cb: cb) { enc in
            enc.setFragmentBytes(&params, length: MemoryLayout<PresentParams>.stride, index: 0)
            enc.setFragmentTexture(src ?? device.placeholderTexture, index: 0)
        }
        stats.passes += 1
    }
}
#endif
