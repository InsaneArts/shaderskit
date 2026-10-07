#if canImport(Metal)
import Foundation
import Metal

/// Errors raised while preparing GPU resources.
public enum ShaderEngineError: Error, CustomStringConvertible {
    case noMetalDevice
    case missingResource(String)
    case compile(String, underlying: Error)
    case missingFunction(String)
    case unknownShader(String)

    public var description: String {
        switch self {
        case .noMetalDevice: return "No Metal device is available"
        case .missingResource(let r): return "Missing shader resource \(r)"
        case .compile(let name, let e): return "Failed to compile \(name): \(e)"
        case .missingFunction(let f): return "Missing Metal function \(f)"
        case .unknownShader(let s): return "Unknown shader component \(s)"
        }
    }
}

/// Shared Metal state: device, queue, compiled libraries and pipeline caches.
public final class ShaderDevice: @unchecked Sendable {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let intermediateFormat: MTLPixelFormat = .rgba16Float

    let compositorLibrary: MTLLibrary
    let fullscreenVertex: MTLFunction
    let linearClamp: MTLSamplerState
    let nearestClamp: MTLSamplerState
    let linearRepeat: MTLSamplerState
    let nearestRepeat: MTLSamplerState

    private let lock = NSLock()
    private var libraries: [String: Result<MTLLibrary, Error>] = [:]
    private var pipelines: [PipelineKey: MTLRenderPipelineState] = [:]
    private var computePipelines: [String: MTLComputePipelineState] = [:]
    /// 1×1 transparent black texture bound where a pass expects an input that is not available.
    let placeholderTexture: MTLTexture

    private struct PipelineKey: Hashable {
        var library: ObjectIdentifier
        var fragment: String
        var format: MTLPixelFormat
    }

    /// The default shared device, or nil when Metal is unavailable (e.g. some CI environments).
    public static let shared: ShaderDevice? = {
        guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
        return try? ShaderDevice(device: dev)
    }()

    public init(device: MTLDevice) throws {
        self.device = device
        guard let q = device.makeCommandQueue() else { throw ShaderEngineError.noMetalDevice }
        q.label = "ShadersKit"
        queue = q
        guard let src = ShaderRegistry.mslSource("Compositor") else { throw ShaderEngineError.missingResource("Compositor.metal") }
        do {
            compositorLibrary = try device.makeLibrary(source: src, options: ShaderDevice.compileOptions())
        } catch {
            throw ShaderEngineError.compile("Compositor", underlying: error)
        }
        guard let v = compositorLibrary.makeFunction(name: "sk_fullscreen_vertex") else { throw ShaderEngineError.missingFunction("sk_fullscreen_vertex") }
        fullscreenVertex = v
        func sampler(_ filter: MTLSamplerMinMagFilter, _ address: MTLSamplerAddressMode) throws -> MTLSamplerState {
            let d = MTLSamplerDescriptor()
            d.minFilter = filter
            d.magFilter = filter
            d.mipFilter = .notMipmapped
            d.sAddressMode = address
            d.tAddressMode = address
            d.normalizedCoordinates = true
            guard let s = device.makeSamplerState(descriptor: d) else { throw ShaderEngineError.noMetalDevice }
            return s
        }
        linearClamp = try sampler(.linear, .clampToEdge)
        nearestClamp = try sampler(.nearest, .clampToEdge)
        linearRepeat = try sampler(.linear, .repeat)
        nearestRepeat = try sampler(.nearest, .repeat)
        let pd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 1, height: 1, mipmapped: false)
        pd.usage = [.shaderRead]
        guard let ph = device.makeTexture(descriptor: pd) else { throw ShaderEngineError.noMetalDevice }
        var zero: [UInt16] = [0, 0, 0, 0]
        ph.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &zero, bytesPerRow: 8)
        ph.label = "ShadersKit placeholder"
        placeholderTexture = ph
    }

    static func compileOptions() -> MTLCompileOptions {
        let o = MTLCompileOptions()
        if #available(macOS 15, iOS 18, tvOS 18, visionOS 2, *) {
            o.mathMode = .fast
        } else {
            o.fastMathEnabled = true
        }
        return o
    }

    func sampler(named name: String) -> MTLSamplerState {
        switch name {
        case "nearestClamp": return nearestClamp
        case "linearRepeat": return linearRepeat
        case "nearestRepeat": return nearestRepeat
        default: return linearClamp
        }
    }

    private var compiling: Set<String> = []
    private let compileQueue = DispatchQueue(label: "ShadersKit.compile", qos: .userInitiated, attributes: .concurrent)

    /// The compiled library for a shader's MSL resource (compiled once, cached). Blocks on first use.
    public func library(forShader msl: String) throws -> MTLLibrary {
        lock.lock()
        if let cached = libraries[msl] {
            lock.unlock()
            return try cached.get()
        }
        lock.unlock()
        let result = compileNow(msl)
        lock.lock()
        libraries[msl] = result
        compiling.remove(msl)
        lock.unlock()
        return try result.get()
    }

    /// Non-blocking variant used by the renderer: returns the library when ready, nil while a
    /// background compile is in flight (the node is skipped for that frame), and throws when the
    /// compile failed.
    func libraryIfReady(forShader msl: String) throws -> MTLLibrary? {
        lock.lock()
        if let cached = libraries[msl] {
            lock.unlock()
            return try cached.get()
        }
        if compiling.contains(msl) {
            lock.unlock()
            return nil
        }
        compiling.insert(msl)
        lock.unlock()
        compileQueue.async { [weak self] in
            guard let self else { return }
            let result = self.compileNow(msl)
            self.lock.lock()
            self.libraries[msl] = result
            self.compiling.remove(msl)
            self.lock.unlock()
        }
        return nil
    }

    private func compileNow(_ msl: String) -> Result<MTLLibrary, Error> {
        guard let src = ShaderRegistry.mslSource(msl) else { return .failure(ShaderEngineError.missingResource("\(msl).metal")) }
        do {
            let lib = try device.makeLibrary(source: src, options: ShaderDevice.compileOptions())
            lib.label = "ShadersKit.\(msl)"
            return .success(lib)
        } catch {
            return .failure(ShaderEngineError.compile(msl, underlying: error))
        }
    }

    /// Pre-compiles a shader library (blocking; call from a background queue).
    public func precompile(_ msl: String) {
        _ = try? library(forShader: msl)
    }

    /// Compiles every component library in the background. `progress` is called on an arbitrary
    /// queue with (done, total).
    public func precompileAll(progress: ((Int, Int) -> Void)? = nil) {
        let names = ShaderRegistry.allNames
        let total = names.count
        var done = 0
        let doneLock = NSLock()
        for n in names {
            compileQueue.async { [weak self] in
                self?.precompile(n)
                doneLock.lock()
                done += 1
                let d = done
                doneLock.unlock()
                progress?(d, total)
            }
        }
    }

    /// Whether a shader library has already been compiled.
    public func isCompiled(_ msl: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if case .success? = libraries[msl] { return true }
        return false
    }

    func pipeline(library: MTLLibrary, fragment: String, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let key = PipelineKey(library: ObjectIdentifier(library), fragment: fragment, format: pixelFormat)
        lock.lock()
        if let p = pipelines[key] {
            lock.unlock()
            return p
        }
        lock.unlock()
        guard let fn = library.makeFunction(name: fragment) else { throw ShaderEngineError.missingFunction(fragment) }
        let d = MTLRenderPipelineDescriptor()
        d.label = fragment
        d.vertexFunction = fullscreenVertex
        d.fragmentFunction = fn
        d.colorAttachments[0].pixelFormat = pixelFormat
        let p = try device.makeRenderPipelineState(descriptor: d)
        lock.lock()
        pipelines[key] = p
        lock.unlock()
        return p
    }

    func compositorPipeline(_ fragment: String, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        try pipeline(library: compositorLibrary, fragment: fragment, pixelFormat: pixelFormat)
    }

    func computePipeline(library: MTLLibrary, name: String) throws -> MTLComputePipelineState {
        let key = "\(ObjectIdentifier(library).hashValue)/\(name)"
        lock.lock()
        if let p = computePipelines[key] {
            lock.unlock()
            return p
        }
        lock.unlock()
        guard let fn = library.makeFunction(name: name) else { throw ShaderEngineError.missingFunction(name) }
        let p = try device.makeComputePipelineState(function: fn)
        lock.lock()
        computePipelines[key] = p
        lock.unlock()
        return p
    }
}

/// Reuses intermediate render targets across passes and frames.
final class TexturePool {
    private struct Key: Hashable {
        var width: Int
        var height: Int
        var format: MTLPixelFormat
    }
    private let device: MTLDevice
    private var free: [Key: [MTLTexture]] = [:]
    private var inUse: [MTLTexture] = []

    init(device: MTLDevice) {
        self.device = device
    }

    func acquire(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float, label: String? = nil) -> MTLTexture? {
        let key = Key(width: max(1, width), height: max(1, height), format: format)
        if var list = free[key], let t = list.popLast() {
            free[key] = list
            inUse.append(t)
            t.label = label
            return t
        }
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: key.format, width: key.width, height: key.height, mipmapped: false)
        d.usage = [.shaderRead, .renderTarget, .shaderWrite]
        d.storageMode = .private
        guard let t = device.makeTexture(descriptor: d) else { return nil }
        t.label = label
        inUse.append(t)
        return t
    }

    /// Returns every texture acquired this frame to the free lists.
    func endFrame() {
        for t in inUse {
            let key = Key(width: t.width, height: t.height, format: t.pixelFormat)
            free[key, default: []].append(t)
        }
        inUse.removeAll(keepingCapacity: true)
        // keep memory bounded
        for (k, list) in free where list.count > 12 {
            free[k] = Array(list.prefix(12))
        }
    }

    func release(_ t: MTLTexture) {
        if let i = inUse.firstIndex(where: { $0 === t }) {
            inUse.remove(at: i)
            free[Key(width: t.width, height: t.height, format: t.pixelFormat), default: []].append(t)
        }
    }
}
#endif
