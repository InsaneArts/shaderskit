#if canImport(Metal)
import Foundation
import Metal

/// Inputs for a media program (runs before a node's passes, independent of children).
public struct MediaContext {
    public let device: ShaderDevice
    public let descriptor: ShaderDescriptor
    public let frame: FrameInput
    public let props: [String: PropValue]
    public let commandBuffer: MTLCommandBuffer
    public let width: Int
    public let height: Int
    public let state: NodeState
    public let options: RenderOptions

    public func string(_ name: String) -> String? {
        (props[name] ?? descriptor.prop(name)?.defaultValue)?.stringValue
    }

    public func scalar(_ name: String) -> Float {
        guard let p = descriptor.prop(name) else { return 0 }
        return UniformPacker(descriptor: descriptor).scalar(p, props[name] ?? p.defaultValue)
    }
}

public struct MediaOutputs {
    /// Textures keyed by the composition texture key (`media_0`, `video_0`, …).
    public var textures: [String: MTLTexture] = [:]
    /// Values for the shader's `extraFields` (e.g. text layout metrics).
    public var extraFields: [String: [Float]] = [:]
    public init(textures: [String: MTLTexture] = [:], extraFields: [String: [Float]] = [:]) {
        self.textures = textures
        self.extraFields = extraFields
    }
}

/// A hand-written port of an upstream media shader's CPU side (image/video/camera/text sources).
public protocol MediaProgram: AnyObject {
    static var shaderNames: [String] { get }
    init(context: MediaContext) throws
    /// Produces this frame's textures. Return an empty result while a source is still loading.
    func encode(_ context: MediaContext) throws -> MediaOutputs
}

public enum MediaPrograms {
    nonisolated(unsafe) private static var table: [String: MediaProgram.Type] = [:]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registeredBuiltins = false

    public static func register(_ type: MediaProgram.Type) {
        lock.lock(); defer { lock.unlock() }
        for n in type.shaderNames { table[n] = type }
    }

    static func program(for shader: String) -> MediaProgram.Type? {
        lock.lock(); defer { lock.unlock() }
        if !registeredBuiltins {
            registeredBuiltins = true
            for t in builtinMediaPrograms { for n in t.shaderNames { table[n] = t } }
        }
        return table[shader]
    }

    public static var supportedShaders: [String] {
        _ = program(for: "")
        lock.lock(); defer { lock.unlock() }
        return table.keys.sorted()
    }
}
#endif
