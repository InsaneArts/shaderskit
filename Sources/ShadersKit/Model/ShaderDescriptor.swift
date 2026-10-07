import Foundation

/// What kind of component a shader is (drives how the engine wires children and passes).
public enum ShaderRole: String, Codable, Sendable, CaseIterable {
    case generator, filter, warp, shape, shapeEffect, simulation, structural, media, overlay
}

/// Declarative capabilities copied from the upstream `GpuShaderDefinition`.
public struct ShaderFlags: Codable, Sendable, Equatable {
    public var requiresRTT = false
    public var requiresChild = false
    public var acceptsOptionalChild = false
    public var blendWithChildren = false
    public var usesPointer = false
    public var acceptsUVContext = false
    public var providesUVContextViaCompute = false
    public var capturesDOM = false
    public var wantsBoundsParams = false
    public var hasCompute = false
    public var hasUvRemap = false
    public var hasMapSampleUVs = false
}

/// CPU-side value transform applied to a prop before it is written to its uniform field.
public enum PropTransform: Sendable, Equatable {
    case none
    case color
    case position
    case angle
    case edges
    case colorSpace
    case boolean
    case strokePosition
    case colorStops
    case list
    /// Select-style prop: option value → uniform float.
    case select([String: Float])
    /// Boolean prop with custom encodings.
    case booleanTable(trueValue: Float, falseValue: Float)
    /// Numeric prop scaled/offset on the CPU (`value * scale + offset`).
    case affine(scale: Float, offset: Float)
}

extension PropTransform: Codable {
    private enum CodingKeys: String, CodingKey { case kind, table, trueValue, falseValue, scale, offset }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "none": self = .none
        case "color": self = .color
        case "position": self = .position
        case "angle": self = .angle
        case "edges": self = .edges
        case "colorSpace": self = .colorSpace
        case "boolean": self = .boolean
        case "strokePosition": self = .strokePosition
        case "colorStops": self = .colorStops
        case "list": self = .list
        case "select": self = .select(try c.decode([String: Float].self, forKey: .table))
        case "booleanTable": self = .booleanTable(trueValue: try c.decode(Float.self, forKey: .trueValue), falseValue: try c.decode(Float.self, forKey: .falseValue))
        case "affine": self = .affine(scale: try c.decode(Float.self, forKey: .scale), offset: try c.decode(Float.self, forKey: .offset))
        default: self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try c.encode("none", forKey: .kind)
        case .color: try c.encode("color", forKey: .kind)
        case .position: try c.encode("position", forKey: .kind)
        case .angle: try c.encode("angle", forKey: .kind)
        case .edges: try c.encode("edges", forKey: .kind)
        case .colorSpace: try c.encode("colorSpace", forKey: .kind)
        case .boolean: try c.encode("boolean", forKey: .kind)
        case .strokePosition: try c.encode("strokePosition", forKey: .kind)
        case .colorStops: try c.encode("colorStops", forKey: .kind)
        case .list: try c.encode("list", forKey: .kind)
        case .select(let t): try c.encode("select", forKey: .kind); try c.encode(t, forKey: .table)
        case .booleanTable(let t, let f): try c.encode("booleanTable", forKey: .kind); try c.encode(t, forKey: .trueValue); try c.encode(f, forKey: .falseValue)
        case .affine(let s, let o): try c.encode("affine", forKey: .kind); try c.encode(s, forKey: .scale); try c.encode(o, forKey: .offset)
        }
    }
}

/// One selectable option of a select prop.
public struct PropOption: Codable, Sendable, Equatable, Hashable {
    public var label: String
    public var value: String
}

/// Editor metadata for a prop (control type, range, grouping).
public struct PropUI: Codable, Sendable, Equatable {
    public var types: [String] = []
    public var min: Float?
    public var max: Float?
    public var step: Float?
    public var options: [PropOption]?
    public var label: String?
    public var group: String?
    public var units: [String]?
    public var dimensional: String?
    public var hidden: Bool = false
    /// Raw upstream condition object (`{otherProp: value}` or `{otherProp: [values]}`), JSON-encoded.
    public var condition: [String: [String]]?
    /// List props: item field specs.
    public var item: [ListItemFieldConfigJSON]?
    public var maxItems: Int?
    public var minItems: Int?
    public var itemLabel: String?

    public var primaryType: String { types.first ?? "number" }
    public var isMappable: Bool { types.contains("map") }
}

/// JSON form of a list item field spec.
public struct ListItemFieldConfigJSON: Codable, Sendable, Equatable {
    public var name: String
    public var kind: String
    public var defaultValue: PropValue
    public var label: String?
    public var min: Float?
    public var max: Float?
    public var step: Float?
}

/// Metadata for a single prop.
public struct PropDescriptor: Codable, Sendable, Equatable {
    public var name: String
    public var defaultValue: PropValue
    public var description: String?
    public var transform: PropTransform
    public var ui: PropUI
    public var compileTime: Bool
    /// False for CPU-only props (strings, JSON shape configs, media URLs).
    public var isUniform: Bool
    /// WGSL type of the uniform field this prop writes (nil for CPU-only or multi-field props).
    public var uniformType: String?

    public var label: String { ui.label ?? name }
}

/// One uniform field of the node struct.
public struct UniformField: Codable, Sendable, Equatable {
    public var name: String
    public var type: String
    public var cpu: Bool
}

/// Extra per-frame CPU-derived uniform field.
public struct ExtraFieldDescriptor: Codable, Sendable, Equatable {
    public var name: String
    public var type: String
    public var initial: [Float]
}

/// A texture the pass samples, and which argument slot it is bound to.
public struct TextureSlot: Codable, Sendable, Equatable {
    public var key: String
    public var slot: Int
    public var external: Bool
}

public struct SamplerSlot: Codable, Sendable, Equatable {
    public var name: String
    public var slot: Int
}

public enum PassKind: String, Codable, Sendable {
    case rtt
    case final
}

/// One fullscreen fragment pass of a variant.
public struct PassDescriptor: Codable, Sendable, Equatable {
    public var kind: PassKind
    public var textureKey: String?
    public var entry: String
    public var textures: [TextureSlot]
    public var samplers: [SamplerSlot]
    public var usesUniforms: Bool
}

/// A texture key the composition declares (child media, RTT intermediate, compute output, video).
public struct TextureBinding: Codable, Sendable, Equatable {
    public var key: String
    public var kind: String
}

/// A compiled specialization for one combination of compile-time prop values.
public struct ShaderVariant: Codable, Sendable, Equatable {
    public var key: [String: PropValue]
    public var isDefault: Bool
    public var passes: [PassDescriptor]
    public var textures: [TextureBinding]
    public var computeSteps: Int
}

/// Offset of one scalar/vector/array field in the packed uniform buffer.
public struct UniformLayoutField: Codable, Sendable, Equatable {
    public var path: String
    public var offset: Int
    public var type: String
    public var size: Int
}

public struct UniformLayout: Codable, Sendable, Equatable {
    public var size: Int
    public var fields: [UniformLayoutField]

    public func field(_ path: String) -> UniformLayoutField? {
        fields.first { $0.path == path }
    }
}

/// Everything the engine and the inspector need to know about one shader component.
public struct ShaderDescriptor: Codable, Sendable, Equatable {
    public var name: String
    public var category: String?
    public var description: String
    public var role: ShaderRole
    public var species: String?
    public var deprecatedNames: [String]
    public var flags: ShaderFlags
    public var animatedTimeSpeedProp: String?
    public var extraAnimatedTimes: [String: String]
    public var extraFields: [ExtraFieldDescriptor]
    public var props: [PropDescriptor]
    public var fields: [UniformField]
    public var variantAxes: [String]
    public var variants: [ShaderVariant]
    public var uniformLayout: UniformLayout
    public var boundingBox: BoundingBoxDeclarationJSON?
    public var naturalSizeProp: String?
    /// Name of the MSL resource file (without extension) holding every variant's entry points.
    public var msl: String
    /// True when a CPU (watchOS) implementation was generated.
    public var cpuSupported: Bool
    /// Compute kernels and the recorded resource graph (compute-backed shaders only).
    public var compute: ComputeInfo?

    public func prop(_ name: String) -> PropDescriptor? {
        props.first { $0.name == name }
    }

    public var defaultVariant: ShaderVariant? {
        variants.first { $0.isDefault } ?? variants.first
    }

    /// True when the component wraps children (filters, warps, structural containers).
    public var acceptsChildren: Bool {
        flags.requiresChild || flags.acceptsOptionalChild || role == .structural
    }

    /// Default prop values keyed by name.
    public var defaultProps: [String: PropValue] {
        Dictionary(uniqueKeysWithValues: props.map { ($0.name, $0.defaultValue) })
    }
}

/// A compute kernel entry point with its argument slots.
public struct ComputeKernelDescriptor: Codable, Sendable, Equatable {
    public struct BufferSlot: Codable, Sendable, Equatable {
        public var name: String
        public var slot: Int
        public var space: String
        public var type: String
    }
    public struct TextureSlot: Codable, Sendable, Equatable {
        public var name: String
        public var slot: Int
        public var type: String
    }
    public var index: Int
    public var dims: Int
    public var entry: String
    public var sizeSlot: Int
    public var buffers: [BufferSlot]
    public var textures: [TextureSlot]

    public func buffer(_ name: String) -> BufferSlot? { buffers.first { $0.name == name } }
    public func texture(_ name: String) -> TextureSlot? { textures.first { $0.name == name } }
}

/// Recorded compute resources from the upstream composition (sizes/formats as upstream allocates them).
public struct ComputeInfo: Codable, Sendable, Equatable {
    public struct RecordedTexture: Codable, Sendable, Equatable {
        public var id: String
        public var width: Int?
        public var height: Int?
        public var format: String?
    }
    public struct RecordedBuffer: Codable, Sendable, Equatable {
        public var id: String
        public var type: String
        public var count: Int?
        public var element: String?
    }
    public struct RecordedUniform: Codable, Sendable, Equatable {
        public var id: String
        public var fields: [String]
    }
    public struct RecordedBindGroup: Codable, Sendable, Equatable {
        public var id: String
        public var entries: [String: String]
    }
    public struct KernelBindGroups: Codable, Sendable, Equatable {
        public var index: Int
        public var bindGroups: [String]
    }
    public var kernels: [ComputeKernelDescriptor]
    public var uniformLayouts: [String: UniformLayout]
    public var textures: [RecordedTexture]
    public var buffers: [RecordedBuffer]
    public var uniforms: [RecordedUniform]
    public var bindGroups: [RecordedBindGroup]
    public var kernelBindGroups: [KernelBindGroups]
    public var rttInputKeys: [String]

    public func kernel(_ index: Int) -> ComputeKernelDescriptor? { kernels.first { $0.index == index } }
}

/// JSON mirror of the upstream `boundingBoxDeclaration` (only the declarative parts).
public struct BoundingBoxDeclarationJSON: Codable, Sendable, Equatable {
    public struct Binding: Codable, Sendable, Equatable {
        public var prop: String
        public var `as`: String
    }
    public struct Bindings: Codable, Sendable, Equatable {
        public var x: Binding?
        public var y: Binding?
        public var width: Binding?
        public var height: Binding?
        public var rotation: Binding?
    }
    public var propBindings: Bindings?
    public var aspectRatio: Float?
    public var supportsResizeFit: Bool?
    public var boxResamplesContent: Bool?
    public var freeResize: Bool?
    public var softnessProp: String?

    /// The Swift declaration used by `DimensionalProps`.
    public var declaration: BoundingBoxDeclaration {
        var pb = PropBindings()
        if let b = propBindings {
            if let x = b.x { pb.x = PropBinding(prop: x.prop, as: x.as) }
            if let y = b.y { pb.y = PropBinding(prop: y.prop, as: y.as) }
            if let w = b.width { pb.width = PropBinding(prop: w.prop, as: w.as) }
            if let h = b.height { pb.height = PropBinding(prop: h.prop, as: h.as) }
            if let r = b.rotation { pb.rotation = PropBinding(prop: r.prop, as: r.as) }
        }
        return BoundingBoxDeclaration(propBindings: propBindings == nil ? nil : pb, softnessBinding: nil)
    }
}

/// Lightweight catalogue entry (name, category) for listing without loading every descriptor.
public struct ShaderIndexEntry: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var category: String?
    public var description: String
    public var role: ShaderRole
    public var acceptsChildren: Bool
    public var hasCompute: Bool
    public var cpuSupported: Bool
    public var id: String { name }
}

/// Loads descriptors from the package resource bundle and caches them.
public enum ShaderRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: ShaderDescriptor] = [:]
    nonisolated(unsafe) private static var indexCache: [ShaderIndexEntry]?

    /// All shipped components, sorted by name.
    public static var index: [ShaderIndexEntry] {
        lock.lock(); defer { lock.unlock() }
        if let i = indexCache { return i }
        guard let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "Descriptors"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ShaderIndexEntry].self, from: data) else {
            indexCache = []
            return []
        }
        indexCache = entries
        return entries
    }

    public static var allNames: [String] { index.map(\.name) }

    /// The descriptor for a component name (also accepts deprecated upstream names).
    public static func descriptor(_ name: String) -> ShaderDescriptor? {
        lock.lock(); defer { lock.unlock() }
        if let d = cache[name] { return d }
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Descriptors"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            let d = try JSONDecoder().decode(ShaderDescriptor.self, from: data)
            cache[name] = d
            return d
        } catch {
            assertionFailure("ShadersKit: failed to decode descriptor \(name): \(error)")
            return nil
        }
    }

    /// MSL source for a shader's variants.
    public static func mslSource(_ msl: String) -> String? {
        guard let url = Bundle.module.url(forResource: msl, withExtension: "metal", subdirectory: "MSL") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
