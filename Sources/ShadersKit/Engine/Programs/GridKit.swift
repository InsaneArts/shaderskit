#if canImport(Metal)
import Foundation
import Metal
import simd

/// Shared host parts for the grid / feedback simulation family: the pieces upstream keeps in
/// `std/sim/grids.ts` (settle gate, ping-pong pair, frame clamp), `gpu/kit/host/pointer.ts`
/// (pointer velocity tracker), `gpu/kit/dataEncoding.ts` (`toHalfFloat`) and the per-compose
/// kernel factories (baked constants re-specialized at runtime, see `specializedLibrary`).
///
/// Framework extension: everything here is additive (no framework file is edited). Per-kernel
/// uniforms go through `setBytes` (`pack`/`setUniform`) so a frame never rewrites a buffer the
/// previous in-flight frame is still reading.
enum GridKit {
    // MARK: Props

    /// Upstream `(getCpuValue(name) as number) ?? fallback` for an untransformed numeric prop.
    static func num(_ props: [String: PropValue], _ name: String, _ fallback: Float) -> Float {
        if let v = props[name], !v.isNull, let n = v.numberValue { return n }
        return fallback
    }

    static func num(_ ctx: ComputeContext, _ name: String, _ fallback: Float) -> Float {
        num(ctx.props, name, fallback)
    }

    static func string(_ ctx: ComputeContext, _ name: String) -> String? {
        ctx.props[name]?.stringValue
    }

    /// A field of the node's packed `combined` uniform block (post-transform, as the fragment sees it).
    static func uniformFloats(_ ctx: ComputeContext, _ path: String, count: Int) -> [Float]? {
        guard let f = ctx.descriptor.uniformLayout.field(path), f.offset + count * 4 <= ctx.uniformSize else { return nil }
        return (0..<count).map { ctx.uniformBytes.load(fromByteOffset: f.offset + $0 * 4, as: Float.self) }
    }

    /// JavaScript `Math.round` (half rounds toward +∞).
    static func jsRound(_ x: Float) -> Float { (x + 0.5).rounded(.down) }

    // MARK: Kernels

    static func kernel(_ ctx: ComputeContext, _ index: Int) throws -> ComputeKernelDescriptor {
        guard let k = ctx.descriptor.compute?.kernel(index) else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) compute kernel \(index)")
        }
        return k
    }

    /// The uniform layout bound to a kernel's `uniform` slot.
    static func uniformLayout(_ ctx: ComputeContext, _ kernel: ComputeKernelDescriptor) throws -> UniformLayout {
        guard let slot = kernel.buffers.first(where: { $0.space == "uniform" }),
              let layout = ctx.descriptor.compute?.uniformLayouts[slot.name] else {
            throw ShaderEngineError.missingFunction("\(kernel.entry) uniform layout")
        }
        return layout
    }

    /// Packs a kernel uniform struct (WGSL offsets) into bytes for `setBytes`.
    static func pack(_ layout: UniformLayout, _ values: [String: [Float]]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: max(16, layout.size))
        bytes.withUnsafeMutableBytes { raw in
            for f in layout.fields {
                guard let v = values[f.path], !v.isEmpty else { continue }
                if f.type == "i32" {
                    raw.storeBytes(of: Int32(v[0]), toByteOffset: f.offset, as: Int32.self)
                } else if f.type == "u32" {
                    raw.storeBytes(of: UInt32(max(0, v[0])), toByteOffset: f.offset, as: UInt32.self)
                } else {
                    for (i, x) in v.prefix(f.size / 4).enumerated() {
                        raw.storeBytes(of: x, toByteOffset: f.offset + i * 4, as: Float.self)
                    }
                }
            }
        }
        return bytes
    }

    static func setUniform(_ e: MTLComputeCommandEncoder, _ kernel: ComputeKernelDescriptor, _ bytes: [UInt8]) {
        guard let slot = kernel.buffers.first(where: { $0.space == "uniform" }) else { return }
        bytes.withUnsafeBytes { e.setBytes($0.baseAddress!, length: $0.count, index: slot.slot) }
    }

    static func setBuffer(_ e: MTLComputeCommandEncoder, _ kernel: ComputeKernelDescriptor, _ name: String, _ buffer: MTLBuffer) {
        if let s = kernel.buffer(name) { e.setBuffer(buffer, offset: 0, index: s.slot) }
    }

    static func setTexture(_ e: MTLComputeCommandEncoder, _ kernel: ComputeKernelDescriptor, _ name: String, _ texture: MTLTexture) {
        if let s = kernel.texture(name) { e.setTexture(texture, index: s.slot) }
    }

    // MARK: Resources

    /// A GPU-private storage buffer (zeroed by `zero` before first use, like WebGPU's zero-init).
    static func privateBuffer(_ ctx: ComputeContext, length: Int, label: String) throws -> MTLBuffer {
        guard let b = ctx.device.device.makeBuffer(length: max(16, length), options: [.storageModePrivate]) else {
            throw ShaderEngineError.noMetalDevice
        }
        b.label = label
        return b
    }

    static func texture(_ ctx: ComputeContext, _ width: Int, _ height: Int, _ format: MTLPixelFormat = .rgba16Float, label: String) throws -> MTLTexture {
        guard let t = ctx.makeTexture(width: width, height: height, format: format, label: label) else {
            throw ShaderEngineError.noMetalDevice
        }
        return t
    }

    /// Zero-fills textures (render-pass clear) and buffers (blit fill): WebGPU zero-initialises new
    /// resources, Metal does not.
    static func zero(textures: [MTLTexture] = [], buffers: [MTLBuffer] = [], cb: MTLCommandBuffer) {
        for t in textures {
            let rpd = MTLRenderPassDescriptor()
            rpd.colorAttachments[0].texture = t
            rpd.colorAttachments[0].loadAction = .clear
            rpd.colorAttachments[0].storeAction = .store
            rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            cb.makeRenderCommandEncoder(descriptor: rpd)?.endEncoding()
        }
        guard !buffers.isEmpty, let blit = cb.makeBlitCommandEncoder() else { return }
        defer { blit.endEncoding() }
        for b in buffers { blit.fill(buffer: b, range: 0..<b.length, value: 0) }
    }

    /// Uploads CPU data into a private texture through a staging buffer, ordered on `cb`.
    static func upload(_ bytes: UnsafeRawBufferPointer, bytesPerRow: Int, to texture: MTLTexture, device: MTLDevice, cb: MTLCommandBuffer) {
        guard let base = bytes.baseAddress,
              let staging = device.makeBuffer(bytes: base, length: bytes.count, options: [.storageModeShared]),
              let blit = cb.makeBlitCommandEncoder() else { return }
        defer { blit.endEncoding() }
        blit.copy(from: staging, sourceOffset: 0, sourceBytesPerRow: bytesPerRow, sourceBytesPerImage: bytesPerRow * texture.height,
                  sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                  to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
    }

    /// Upstream `toHalfFloat` (kit/dataEncoding.ts), bit for bit.
    static func halfBits(_ value: Float) -> UInt16 {
        let v = max(-65504, min(65504, value))
        let x = Int32(bitPattern: v.bitPattern)
        var bits = (x >> 16) & 0x8000
        var m = (x >> 12) & 0x07ff
        let e = (x >> 23) & 0xff
        if e < 103 { return UInt16(truncatingIfNeeded: bits) }
        if e > 142 {
            bits |= 0x7c00
            bits |= e == 255 ? 0 : (x & 0x007f_ffff)
            return UInt16(truncatingIfNeeded: bits)
        }
        if e < 113 {
            m |= 0x0800
            bits |= (m >> (114 - e)) + ((m >> (113 - e)) & 1)
            return UInt16(truncatingIfNeeded: bits)
        }
        bits |= ((e - 112) << 10) | (m >> 1)
        bits += m & 1
        return UInt16(truncatingIfNeeded: bits)
    }

    // MARK: Kernel specialization

    /// One textual edit of a shader's generated MSL: `find` must occur exactly `count` times.
    struct Patch {
        var find: String
        var replace: String
        var count: Int
        init(_ find: String, _ replace: String, count: Int = 1) {
            self.find = find
            self.replace = replace
            self.count = count
        }
    }

    nonisolated(unsafe) private static var specialized: [String: MTLLibrary] = [:]
    private static let specializedLock = NSLock()

    /// Upstream bakes some prop values into its kernels per compose (grid size, sort axis, detect
    /// mode, march grid, …) and the transpiler emitted the kernel for one value only. This compiles
    /// a copy of the shader's MSL with the baked literals rewritten for `key` (cached per key). An
    /// empty patch list returns the shipped library. A patch that does not match throws, so a
    /// regenerated MSL file cannot silently fall back to the wrong variant.
    static func specializedLibrary(_ ctx: ComputeContext, key: String, patches: [Patch]) throws -> MTLLibrary {
        if patches.isEmpty { return ctx.library }
        let cacheKey = "\(ctx.descriptor.msl)#\(key)"
        specializedLock.lock()
        if let lib = specialized[cacheKey] { specializedLock.unlock(); return lib }
        specializedLock.unlock()
        guard var src = ShaderRegistry.mslSource(ctx.descriptor.msl) else {
            throw ShaderEngineError.missingResource("\(ctx.descriptor.msl).metal")
        }
        for p in patches {
            let n = src.components(separatedBy: p.find).count - 1
            guard n == p.count else {
                throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) kernel specialization '\(key)': expected \(p.count)× `\(p.find.prefix(60))`, found \(n)")
            }
            src = src.replacingOccurrences(of: p.find, with: p.replace)
        }
        let lib: MTLLibrary
        do {
            lib = try ctx.device.device.makeLibrary(source: src, options: ShaderDevice.compileOptions())
        } catch {
            throw ShaderEngineError.compile("\(ctx.descriptor.msl)#\(key)", underlying: error)
        }
        specializedLock.lock()
        specialized[cacheKey] = lib
        specializedLock.unlock()
        return lib
    }

    /// Replaces the text between two unique markers (both kept).
    static func regionPatch(_ src: String, from start: String, to end: String, with body: String) -> Patch? {
        guard let a = src.range(of: start), let b = src.range(of: end, range: a.upperBound..<src.endIndex) else { return nil }
        return Patch(start + String(src[a.upperBound..<b.lowerBound]) + end, start + body + end)
    }

    /// The same context dispatching from another library (a specialized kernel copy).
    static func with(_ ctx: ComputeContext, library: MTLLibrary) -> ComputeContext {
        if library === ctx.library { return ctx }
        return ComputeContext(device: ctx.device, descriptor: ctx.descriptor, library: library, frame: ctx.frame, props: ctx.props,
                              uniformBytes: ctx.uniformBytes, uniformSize: ctx.uniformSize, childTexture: ctx.childTexture,
                              rttTextures: ctx.rttTextures, commandBuffer: ctx.commandBuffer, width: ctx.width, height: ctx.height, state: ctx.state)
    }

    /// Upstream `createLateBoundChildInput` resolves to the child RTT (premultiplied).
    static func child(_ ctx: ComputeContext) -> MTLTexture? {
        ctx.rttTextures["rtt_0"] ?? ctx.childTexture
    }

    // MARK: Frame program parts (std/sim/grids.ts)

    /// `op.settle`: skip the frame once `settleMs` of simulated time has passed without activity.
    struct SettleGate {
        var simSinceActive: Float = 0
        mutating func tick(active: Bool) { if active { simSinceActive = 0 } }
        mutating func skip(settleMs: Float, dt: Float) -> Bool {
            let skip = simSinceActive > settleMs
            if !skip { simSinceActive += dt * 1000 }
            return skip
        }
    }

    /// `createPingPongPair`: `read` holds the current state, `write` is the scratch side.
    struct PingPong<T> {
        let a: T
        let b: T
        private(set) var flipped = false
        init(_ a: T, _ b: T) { self.a = a; self.b = b }
        var read: T { flipped ? b : a }
        var write: T { flipped ? a : b }
        mutating func swap() { flipped.toggle() }
        mutating func reset() { flipped = false }
    }

    /// `createPointerVelocityTracker` (gpu/kit/host/pointer.ts). ShadersKit has no `seen` flag, so
    /// every sample is real (the upstream legacy path).
    struct PointerTracker {
        struct Frame {
            var x: Float, y: Float, prevX: Float, prevY: Float
            var dx: Float, dy: Float, dragDist: Float
            var velX: Float, velY: Float, smoothVelX: Float, smoothVelY: Float, smoothSpeed: Float
            var teleport: Bool, moving: Bool
        }
        var smoothing: Float = 0.2
        var teleportGuard: Float = 0.25
        var minDrag: Float = 0.0006
        var prevX: Float = 0.5
        var prevY: Float = 0.5
        var smoothVelX: Float = 0
        var smoothVelY: Float = 0

        mutating func update(_ p: SIMD2<Float>, dt: Float) -> Frame {
            let oldX = prevX, oldY = prevY
            let rawDx = p.x - oldX, rawDy = p.y - oldY
            let dragDist = (rawDx * rawDx + rawDy * rawDy).squareRoot()
            let teleport = dragDist >= teleportGuard
            prevX = p.x
            prevY = p.y
            let dx = teleport ? 0 : rawDx
            let dy = teleport ? 0 : rawDy
            let invDt = 1 / max(dt, 0.001)
            let velX = dx * invDt, velY = dy * invDt
            smoothVelX = smoothVelX * (1 - smoothing) + velX * smoothing
            smoothVelY = smoothVelY * (1 - smoothing) + velY * smoothing
            return Frame(x: p.x, y: p.y, prevX: oldX, prevY: oldY, dx: dx, dy: dy, dragDist: dragDist,
                         velX: velX, velY: velY, smoothVelX: smoothVelX, smoothVelY: smoothVelY,
                         smoothSpeed: (smoothVelX * smoothVelX + smoothVelY * smoothVelY).squareRoot(),
                         teleport: teleport, moving: !teleport && dragDist > minDrag)
        }
    }

    /// Upstream `isMobileGpuViewport()` device tier.
    static var isMobileGpu: Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }
}
#endif
