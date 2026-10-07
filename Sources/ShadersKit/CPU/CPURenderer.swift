import Foundation
import simd
import CoreGraphics

/// CPU rasterizer: renders the same layer trees as the Metal engine using the generated Swift
/// shader programs. Used on watchOS (no Metal) and for cross-checking the GPU path in tests.
public final class CPURenderer {
    public var options: RenderOptions
    public private(set) var stats = FrameStats()

    private var states: [String: NodeState] = [:]
    private var packers: [String: UniformPacker] = [:]
    private var uniformScratch = [UInt8](repeating: 0, count: 16384)
    private var frame = FrameInput(pixelSize: SIMD2(1, 1))
    private var currentRoots: [ShaderNode] = []
    private let placeholder = CPUTexture(width: 1, height: 1)
    /// Rows are rasterized in parallel on this many threads.
    public var threadCount = max(2, ProcessInfo.processInfo.activeProcessorCount)

    public init(options: RenderOptions = RenderOptions()) {
        self.options = options
    }

    /// Suggested backing scale for a view of this size: keeps per-frame work affordable.
    public static func renderScale(for size: CGSize) -> CGFloat {
        let pixels = size.width * size.height
        if pixels <= 0 { return 1 }
        // target ≈ 24k pixels per frame (e.g. 180×130) — Apple Watch screens are ~400×500 points
        let target: CGFloat = 24_000
        return min(1, max(0.25, (target / pixels).squareRoot()))
    }

    // MARK: - Public

    /// Renders into a CPU texture (linear light, straight alpha).
    public func render(_ nodes: [ShaderNode], frame: FrameInput) -> CPUTexture? {
        stats = FrameStats()
        self.frame = frame
        currentRoots = nodes
        let w = max(1, Int(frame.pixelSize.x))
        let h = max(1, Int(frame.pixelSize.y))
        return composite(nodes, key: "root", width: w, height: h)
    }

    /// Renders and encodes to an 8-bit premultiplied CGImage (sRGB OETF applied).
    public func renderImage(_ nodes: [ShaderNode], frame: FrameInput, options: RenderOptions? = nil) -> CGImage? {
        if let options { self.options = options }
        let w = max(1, Int(frame.pixelSize.x))
        let h = max(1, Int(frame.pixelSize.y))
        let composed = render(nodes, frame: frame)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let tone = self.options.toneMapping.shaderIndex
        let bg = self.options.backgroundColor
        let premultiply = self.options.premultiplyAlpha
        bytes.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: h) { y in
                for x in 0..<w {
                    var c = composed?.pixels[y * w + x] ?? SIMD4()
                    if bg.w > 0 { c = CPU_Compositor.blend_normal(bg, c, 1) }
                    var rgb = CPU_Compositor.sk_tone(tone, pointwiseMax(SIMD3(c.x, c.y, c.z), SIMD3(repeating: 0)))
                    rgb = CPU_Compositor.linearToSrgb(sk_clamp(rgb, SIMD3(repeating: 0), SIMD3(repeating: 1)))
                    let a = sk_clamp(c.w, 0, 1)
                    if premultiply { rgb *= a }
                    let o = (y * w + x) * 4
                    buf[o] = CPURenderer.byte(rgb.x)
                    buf[o + 1] = CPURenderer.byte(rgb.y)
                    buf[o + 2] = CPURenderer.byte(rgb.z)
                    buf[o + 3] = CPURenderer.byte(a)
                }
            }
        }
        let cs = self.options.colorSpace == .displayP3Linear ? (CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()) : CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: (premultiply ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.last).rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    public func resetState() { states.removeAll() }

    /// NaN-safe 0...1 → 0...255 conversion (shaders may produce NaN at singularities).
    @inline(__always) static func byte(_ v: Float) -> UInt8 {
        if v.isNaN { return 0 }
        return UInt8(min(max(v * 255 + 0.5, 0), 255))
    }

    // MARK: - Composition (mirrors ShaderRenderer)

    private func stateKey(_ node: ShaderNode, fallback: String) -> String {
        node.attributes.id.map { "id:\($0)" } ?? fallback
    }

    private var frameIndexForState: Int { 0 }

    private func state(for key: String) -> NodeState {
        if let s = states[key] { return s }
        let s = NodeState()
        states[key] = s
        return s
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

    private func composite(_ children: [ShaderNode], key: String, width: Int, height: Int) -> CPUTexture? {
        let visible = children.enumerated().filter { $0.element.attributes.visible }
        if visible.isEmpty { return nil }
        if visible.count == 1, isPlainLayer(visible[0].element.attributes) {
            let (i, child) = visible[0]
            return renderNode(child, key: stateKey(child, fallback: "\(key)/\(i)"), width: width, height: height)
        }
        var acc: CPUTexture? = nil
        for (i, child) in visible {
            let childKey = stateKey(child, fallback: "\(key)/\(i)")
            guard let out = renderNode(child, key: childKey, width: width, height: height) else { continue }
            var mask: CPUTexture? = nil
            if let m = child.attributes.mask {
                switch m.source {
                case .node(let n): mask = renderNode(n, key: "\(childKey)/mask", width: width, height: height)
                case .layer(let id):
                    var found: ShaderNode? = nil
                    for r in currentRoots where found == nil { r.forEachNode { n in if found == nil, n.attributes.id == id { found = n } } }
                    if let src = found { mask = renderNode(src, key: "id:\(id)", width: width, height: height) }
                }
            }
            acc = blend(base: acc, overlay: out, attributes: child.attributes, mask: mask, width: width, height: height)
        }
        return acc
    }

    private func blend(base: CPUTexture?, overlay: CPUTexture, attributes a: LayerAttributes, mask: CPUTexture?, width: Int, height: Int) -> CPUTexture {
        let out = CPUTexture(width: width, height: height)
        let mode = a.blendMode.shaderIndex
        let maskType = a.mask?.type.shaderIndex ?? -1
        let opacity = max(0, min(1, a.opacity))
        let hasMask = mask != nil
        out.pixels.withUnsafeMutableBufferPointer { dst in
            DispatchQueue.concurrentPerform(iterations: height) { y in
                for x in 0..<width {
                    let i = y * width + x
                    let b = base?.pixels[i] ?? SIMD4()
                    var o = overlay.pixels[i]
                    if hasMask, let m = mask { o = CPU_Compositor.sk_mask(maskType, o, m.pixels[i]) }
                    dst[i] = CPU_Compositor.sk_blend(mode, b, o, opacity)
                }
            }
        }
        stats.blendPasses += 1
        return out
    }

    private func renderNode(_ node: ShaderNode, key: String, width: Int, height: Int) -> CPUTexture? {
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
        var childTex: CPUTexture? = nil
        if desc.acceptsChildren, !node.children.isEmpty {
            childTex = composite(node.children, key: key, width: width, height: height)
        }
        if desc.name == "Group" { return childTex }
        if desc.flags.requiresChild, childTex == nil { return nil }
        guard let program = CPUPrograms.program(for: desc.name) else {
            if !stats.unsupportedNodes.contains(desc.name) { stats.unsupportedNodes.append(desc.name) }
            return nil
        }
        var props = desc.defaultProps
        for (k, v) in node.props where !v.isNull { props[k] = v }
        let pk = packer(for: desc)
        guard let variant = pk.selectVariant(props) else { return nil }
        pk.advanceClocks(props: props, state: st, deltaTime: frame.deltaTime)
        _ = HostFieldsHooks.apply(descriptor: desc, props: props, frame: frame, options: options, state: st, width: width, height: height)
        if uniformScratch.count < pk.size { uniformScratch = [UInt8](repeating: 0, count: pk.size) }
        uniformScratch.withUnsafeMutableBytes { raw in
            pk.pack(props: props, state: st, frame: frame, options: options, into: raw.baseAddress!)
        }
        var textures: [String: CPUTexture] = [:]
        if let c = childTex { textures["media_0"] = c }
        var output: CPUTexture? = nil
        for pass in variant.passes {
            guard let factory = program.passes[pass.entry] else {
                stats.unsupportedNodes.append("\(desc.name).\(pass.entry)")
                return nil
            }
            let target = CPUTexture(width: width, height: height)
            let pixelFn: CPUPixelFunction = uniformScratch.withUnsafeBytes { raw in
                factory(CPUPassEnvironment(uniformBytes: raw.baseAddress!, textures: textures, placeholder: placeholder))
            }
            let pixelSizeUV = SIMD2<Float>(1 / Float(width), 1 / Float(height))
            CPUDerivatives.pixelSizeUV = pixelSizeUV
            target.pixels.withUnsafeMutableBufferPointer { dst in
                DispatchQueue.concurrentPerform(iterations: height) { y in
                    let v = (Float(y) + 0.5) / Float(height)
                    for x in 0..<width {
                        let u = (Float(x) + 0.5) / Float(width)
                        let ctx = CPUPassContext(input: CPUFragmentInput(uv: SIMD2(u, v)), pixelSizeUV: pixelSizeUV)
                        dst[y * width + x] = pixelFn(ctx)
                    }
                }
            }
            stats.passes += 1
            if pass.kind == .rtt, let k = pass.textureKey {
                textures[k] = target
            } else {
                output = target
            }
        }
        return output
    }
}
