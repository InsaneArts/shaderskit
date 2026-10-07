import SwiftUI
import ShadersKit

/// Codable mirror of `ShaderNode` (the package only makes `PropValue` Codable).
struct CodableLayer: Codable, Equatable {
    var type: String
    var props: [String: PropValue]
    var children: [CodableLayer]?
    var blendMode: BlendMode?
    var opacity: Float?
    var visible: Bool?
    var id: String?
    var transform: LayerTransform?
    var mask: CodableMask?

    struct CodableMask: Codable, Equatable {
        var layerID: String?
        /// Inline mask tree (an array, so the type is not recursive by value).
        var layers: [CodableLayer]?
        var type: MaskType
    }

    init(_ node: ShaderNode) {
        type = node.type
        props = node.props.filter { !$0.value.isNull }
        children = node.children.isEmpty ? nil : node.children.map(CodableLayer.init)
        let a = node.attributes
        blendMode = a.blendMode == .normal ? nil : a.blendMode
        opacity = a.opacity == 1 ? nil : a.opacity
        visible = a.visible ? nil : false
        id = a.id
        transform = a.transform
        if let m = a.mask {
            switch m.source {
            case .layer(let ref): mask = CodableMask(layerID: ref, layers: nil, type: m.type)
            case .node(let n): mask = CodableMask(layerID: nil, layers: [CodableLayer(n)], type: m.type)
            }
        }
    }

    var node: ShaderNode {
        var attributes = LayerAttributes(blendMode: blendMode ?? .normal, opacity: opacity ?? 1, visible: visible ?? true, id: id, transform: transform)
        if let mask {
            if let ref = mask.layerID {
                attributes.mask = MaskConfig(source: .layer(ref), type: mask.type)
            } else if let n = mask.layers?.first {
                attributes.mask = MaskConfig(source: .node(n.node), type: mask.type)
            }
        }
        return ShaderNode(type: type, props: props, children: (children ?? []).map(\.node), attributes: attributes)
    }
}

/// A saved playground composition.
struct CompositionDocument: Codable, Identifiable, Equatable {
    var format = "shaderskit.composition"
    var version = 1
    var name: String
    var modified: Date
    var layers: [CodableLayer]

    var id: String { name }

    init(name: String, nodes: [ShaderNode]) {
        self.name = name
        self.modified = Date()
        self.layers = nodes.map(CodableLayer.init)
    }

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ text: String) throws -> CompositionDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = Data(text.utf8)
        if let doc = try? decoder.decode(CompositionDocument.self, from: data) { return doc }
        // also accept a bare array of layers
        let layers = try decoder.decode([CodableLayer].self, from: data)
        return CompositionDocument(name: "Imported", nodes: layers.map(\.node))
    }
}

/// Saves compositions as JSON files (Application Support on iOS/macOS, Caches on tvOS).
@Observable
final class CompositionStore {
    private(set) var documents: [CompositionDocument] = []
    private(set) var lastError: String?

    private var directory: URL? {
        #if os(tvOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #endif
        guard let dir = base?.appendingPathComponent("Compositions", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func reload() {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            documents = []
            return
        }
        documents = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? String(contentsOf: url, encoding: .utf8)).flatMap { try? CompositionDocument.decode($0) } }
            .sorted { $0.modified > $1.modified }
    }

    func save(_ document: CompositionDocument) {
        guard let dir = directory else { return }
        let url = dir.appendingPathComponent(Self.fileName(document.name))
        do {
            try document.jsonString().write(to: url, atomically: true, encoding: .utf8)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        reload()
    }

    func delete(_ document: CompositionDocument) {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(Self.fileName(document.name)))
        reload()
    }

    private static func fileName(_ name: String) -> String {
        let safe = name.components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: " -_")).inverted).joined()
        return (safe.isEmpty ? "Untitled" : safe) + ".json"
    }
}
