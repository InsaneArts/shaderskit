#if canImport(Metal)
import Foundation
import Metal
import simd

/// Inputs available to a compute program each frame.
public struct ComputeContext {
    public let device: ShaderDevice
    public let descriptor: ShaderDescriptor
    public let library: MTLLibrary
    public let frame: FrameInput
    /// Resolved prop values (defaults merged with the node's props).
    public let props: [String: PropValue]
    /// The node's packed `combined` uniform block (same layout as the fragment passes read).
    public let uniformBytes: UnsafeRawPointer
    public let uniformSize: Int
    /// Composited children (straight alpha, linear light) when the node wraps content.
    public let childTexture: MTLTexture?
    /// RTT pass outputs already rendered this frame (e.g. `rtt_0`).
    public let rttTextures: [String: MTLTexture]
    public let commandBuffer: MTLCommandBuffer
    /// Output pixel size of the node.
    public let width: Int
    public let height: Int
    /// Per-node persistent state (same object every frame).
    public let state: NodeState

    /// Scalar value of a prop after its CPU transform (angles wrapped, selects encoded, …).
    public func scalar(_ name: String) -> Float {
        guard let p = descriptor.prop(name) else { return 0 }
        return UniformPacker(descriptor: descriptor).scalar(p, props[name] ?? p.defaultValue)
    }

    public func string(_ name: String) -> String? {
        (props[name] ?? descriptor.prop(name)?.defaultValue)?.stringValue
    }

    public func position(_ name: String) -> SIMD2<Float> {
        guard let p = descriptor.prop(name) else { return SIMD2(0.5, 0.5) }
        return UniformPacker(descriptor: descriptor).vec2(p, props[name] ?? p.defaultValue)
    }

    public func color(_ name: String, mode: ColorSpaceMode) -> SIMD4<Float> {
        guard let p = descriptor.prop(name) else { return SIMD4(0, 0, 0, 1) }
        return UniformPacker(descriptor: descriptor).vec4(p, props[name] ?? p.defaultValue, mode: mode)
    }
}

/// A hand-written port of one upstream compute hook: owns its textures/buffers, dispatches its
/// kernels each frame and returns the textures the fragment passes sample (`compute_N`).
public protocol ComputeProgram: AnyObject {
    /// Shader names this program implements (one program type may serve a whole family).
    static var shaderNames: [String] { get }
    init(context: ComputeContext) throws
    /// Encodes this frame's work. Returns textures keyed by `compute_<n>`, plus any extra uniform
    /// field values (`extraFields`) the fragment pass should receive.
    func encode(_ context: ComputeContext) throws -> ComputeOutputs
}

public struct ComputeOutputs {
    public var textures: [String: MTLTexture] = [:]
    /// Values for the shader's `extraFields` (name → components), written into the uniform block
    /// before the fragment passes run.
    public var extraFields: [String: [Float]] = [:]
    public init(textures: [String: MTLTexture] = [:], extraFields: [String: [Float]] = [:]) {
        self.textures = textures
        self.extraFields = extraFields
    }
}

/// Registry of compute program implementations.
public enum ComputePrograms {
    nonisolated(unsafe) private static var table: [String: ComputeProgram.Type] = [:]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registeredBuiltins = false

    /// Registers a program type for the shader names it declares.
    public static func register(_ type: ComputeProgram.Type) {
        lock.lock(); defer { lock.unlock() }
        for n in type.shaderNames { table[n] = type }
    }

    static func program(for shader: String) -> ComputeProgram.Type? {
        lock.lock(); defer { lock.unlock() }
        if !registeredBuiltins {
            registeredBuiltins = true
            for t in builtinPrograms { for n in t.shaderNames { table[n] = t } }
        }
        return table[shader]
    }

    /// Names of compute-backed shaders that have a program implementation.
    public static var supportedShaders: [String] {
        _ = program(for: "")
        lock.lock(); defer { lock.unlock() }
        return table.keys.sorted()
    }
}

// MARK: - Helpers shared by programs

public extension ComputeContext {
    /// Compute pipeline for a kernel entry (cached by the device).
    func pipeline(_ kernel: ComputeKernelDescriptor) throws -> MTLComputePipelineState {
        try device.computePipeline(library: library, name: kernel.entry)
    }

    /// Dispatches `kernel` over `threads` with the bounds guard the upstream wrapper uses.
    func dispatch(_ encoder: MTLComputeCommandEncoder, _ kernel: ComputeKernelDescriptor, threads: SIMD3<UInt32>, bind: (MTLComputeCommandEncoder) -> Void) throws {
        let pso = try pipeline(kernel)
        encoder.setComputePipelineState(pso)
        bind(encoder)
        var size = threads
        encoder.setBytes(&size, length: MemoryLayout<SIMD3<UInt32>>.stride, index: kernel.sizeSlot)
        let w = pso.threadExecutionWidth
        let h = max(1, pso.maxTotalThreadsPerThreadgroup / w)
        let tg: MTLSize = kernel.dims == 1 ? MTLSize(width: min(Int(threads.x), w * h), height: 1, depth: 1) : MTLSize(width: w, height: h, depth: 1)
        let grid = MTLSize(width: Int(threads.x), height: Int(threads.y), depth: Int(threads.z))
        if device.device.supportsFamily(.apple4) || device.device.supportsFamily(.mac2) {
            encoder.dispatchThreads(grid, threadsPerThreadgroup: tg)
        } else {
            let groups = MTLSize(width: (grid.width + tg.width - 1) / tg.width, height: (grid.height + tg.height - 1) / tg.height, depth: (grid.depth + tg.depth - 1) / tg.depth)
            encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
        }
    }

    /// Allocates a GPU-private texture usable as a storage + sampled texture.
    func makeTexture(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float, label: String? = nil) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: max(1, width), height: max(1, height), mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite, .renderTarget]
        d.storageMode = .private
        let t = device.device.makeTexture(descriptor: d)
        t?.label = label
        return t
    }

    func makeBuffer(length: Int, label: String? = nil) -> MTLBuffer? {
        let b = device.device.makeBuffer(length: max(16, length), options: [.storageModeShared])
        b?.label = label
        return b
    }

    /// Writes a small uniform struct following a kernel uniform layout (`compute.uniformLayouts[name]`).
    func pack(_ layout: UniformLayout, _ values: [String: [Float]], into buffer: MTLBuffer) {
        let p = buffer.contents()
        memset(p, 0, min(buffer.length, layout.size))
        for f in layout.fields {
            guard let v = values[f.path], !v.isEmpty else { continue }
            if f.type == "i32" { p.storeBytes(of: Int32(v[0]), toByteOffset: f.offset, as: Int32.self) }
            else if f.type == "u32" { p.storeBytes(of: UInt32(max(0, v[0])), toByteOffset: f.offset, as: UInt32.self) }
            else {
                for (i, x) in v.prefix(f.size / 4).enumerated() { p.storeBytes(of: x, toByteOffset: f.offset + i * 4, as: Float.self) }
            }
        }
    }

    /// Metal pixel format for an upstream WebGPU format string.
    static func pixelFormat(_ format: String?) -> MTLPixelFormat {
        switch format {
        case "rgba32float": return .rgba32Float
        case "r32float": return .r32Float
        case "rg32float": return .rg32Float
        case "r16float": return .r16Float
        case "rgba8unorm": return .rgba8Unorm
        default: return .rgba16Float
        }
    }
}
#endif
