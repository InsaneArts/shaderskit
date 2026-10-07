import SwiftUI
import ShadersKit

/// One editable layer in the playground tree. `children` holds the content of filters/warps.
struct PlaygroundLayer: Identifiable, Equatable {
    var id = UUID()
    var type: String
    var props: [String: PropValue] = [:]
    var attributes = LayerAttributes()
    var children: [PlaygroundLayer] = []

    var node: ShaderNode {
        ShaderNode(type: type, props: props, children: children.map(\.node), attributes: attributes)
    }

    var entry: ShaderIndexEntry? { Catalog.entry(named: type) }
    var wraps: Bool { ShaderRegistry.descriptor(type)?.acceptsChildren ?? false }

    init(type: String, props: [String: PropValue] = [:], attributes: LayerAttributes = LayerAttributes(), children: [PlaygroundLayer] = []) {
        self.type = type
        self.props = props
        self.attributes = attributes
        self.children = children
    }

    init(node: ShaderNode) {
        self.init(type: node.type, props: node.props.filter { !$0.value.isNull }, attributes: node.attributes, children: node.children.map(PlaygroundLayer.init(node:)))
    }

    /// Fresh ids for the whole subtree (duplicates).
    func cloned() -> PlaygroundLayer {
        var copy = self
        copy.id = UUID()
        copy.children = children.map { $0.cloned() }
        return copy
    }
}

/// Flattened row for the layer list (top-most layer first, children indented).
struct LayerRow: Identifiable {
    let layer: PlaygroundLayer
    let depth: Int
    var id: UUID { layer.id }
}

/// The playground composition: a stack of layers, bottom to top.
@Observable
final class PlaygroundModel {
    var name = "Untitled"
    var layers: [PlaygroundLayer] = PlaygroundModel.starter
    var selection: UUID?

    static let starter: [PlaygroundLayer] = [
        PlaygroundLayer(type: "Swirl", props: ["colorA": .string("#3a0ca3"), "colorB": .string("#ff4d6a"), "detail": .number(1.6)]),
        PlaygroundLayer(type: "Vignette", props: ["intensity": .number(0.6)], children: [
            PlaygroundLayer(type: "Star", props: ["color": .string("#ffffff"), "radius": .number(0.3), "softness": .number(0.004)]),
        ]),
    ]

    var nodes: [ShaderNode] { layers.map(\.node) }
    var layerCount: Int { rows.count }

    var rows: [LayerRow] {
        var out: [LayerRow] = []
        func walk(_ list: [PlaygroundLayer], depth: Int) {
            for layer in list.reversed() {
                out.append(LayerRow(layer: layer, depth: depth))
                walk(layer.children, depth: depth + 1)
            }
        }
        walk(layers, depth: 0)
        return out
    }

    var selectedLayer: PlaygroundLayer? {
        guard let selection else { return nil }
        return find(selection, in: layers)
    }

    // MARK: editing

    /// Adds a component. Wrapping components (filters, warps) wrap the selected layer, or the
    /// whole stack when nothing is selected; everything else goes on top.
    func addLayer(type: String, props: [String: PropValue] = [:], attributes: LayerAttributes = LayerAttributes(), subject: Subject? = nil) {
        let wraps = ShaderRegistry.descriptor(type)?.acceptsChildren ?? false
        var layer = PlaygroundLayer(type: type, props: props.isEmpty ? PreviewFactory.initialProps(for: type) : props, attributes: attributes)
        if wraps, let subject {
            layer.children = subject.nodes.map(PlaygroundLayer.init(node:))
            layers.append(layer)
        } else if wraps {
            if let selection {
                wrap(selection, in: type)
                return
            }
            layer.children = layers.isEmpty ? Subject.scene.nodes.map(PlaygroundLayer.init(node:)) : layers
            layers = [layer]
        } else {
            layers.append(layer)
        }
        selection = layer.id
    }

    /// Replaces the layer with a new wrapping component that contains it.
    func wrap(_ id: UUID, in type: String) {
        let wrapperID = UUID()
        mutateSiblings(of: id) { list, index in
            var wrapper = PlaygroundLayer(type: type, props: PreviewFactory.initialProps(for: type))
            wrapper.id = wrapperID
            wrapper.children = [list[index]]
            list[index] = wrapper
        }
        selection = wrapperID
    }

    /// Replaces a wrapping layer with its children.
    func unwrap(_ id: UUID) {
        mutateSiblings(of: id) { list, index in
            let children = list[index].children
            list.replaceSubrange(index...index, with: children)
        }
        selection = nil
    }

    func remove(_ id: UUID) {
        mutateSiblings(of: id) { list, index in list.remove(at: index) }
        if selection == id { selection = nil }
    }

    func duplicate(_ id: UUID) {
        var newID: UUID?
        mutateSiblings(of: id) { list, index in
            let copy = list[index].cloned()
            newID = copy.id
            list.insert(copy, at: index + 1)
        }
        selection = newID
    }

    /// Moves a layer up (towards the top of the stack) or down among its siblings.
    func move(_ id: UUID, up: Bool) {
        mutateSiblings(of: id) { list, index in
            let target = up ? index + 1 : index - 1
            guard list.indices.contains(target) else { return }
            list.swapAt(index, target)
        }
    }

    func canMove(_ id: UUID, up: Bool) -> Bool {
        var result = false
        siblings(of: id) { list, index in
            result = list.indices.contains(up ? index + 1 : index - 1)
        }
        return result
    }

    /// `List.onMove` over the flattened rows: reorders the moved layer among its siblings
    /// according to where it was dropped.
    func moveRows(from source: IndexSet, to destination: Int) {
        let rows = self.rows
        guard let from = source.first, rows.indices.contains(from) else { return }
        let movingID = rows[from].id
        var ids = rows.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        mutateSiblings(of: movingID) { list, _ in
            let siblingIDs = Set(list.map(\.id))
            let byID = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            // rows are listed top-first, the model stores bottom-first
            list = ids.filter { siblingIDs.contains($0) }.reversed().compactMap { byID[$0] }
        }
    }

    func update(_ id: UUID, _ body: (inout PlaygroundLayer) -> Void) {
        func visit(_ list: inout [PlaygroundLayer]) -> Bool {
            for i in list.indices {
                if list[i].id == id { body(&list[i]); return true }
                if visit(&list[i].children) { return true }
            }
            return false
        }
        _ = visit(&layers)
    }

    func clear() {
        layers = []
        selection = nil
        name = "Untitled"
    }

    func load(_ preset: ShowcasePreset) {
        layers = preset.layers.map(PlaygroundLayer.init(node:))
        name = preset.title
        selection = nil
    }

    func load(_ document: CompositionDocument) {
        layers = document.layers.map { PlaygroundLayer(node: $0.node) }
        name = document.name
        selection = nil
    }

    // MARK: tree helpers

    private func find(_ id: UUID, in list: [PlaygroundLayer]) -> PlaygroundLayer? {
        for layer in list {
            if layer.id == id { return layer }
            if let hit = find(id, in: layer.children) { return hit }
        }
        return nil
    }

    private func mutateSiblings(of id: UUID, _ body: (inout [PlaygroundLayer], Int) -> Void) {
        func visit(_ list: inout [PlaygroundLayer]) -> Bool {
            if let i = list.firstIndex(where: { $0.id == id }) {
                body(&list, i)
                return true
            }
            for i in list.indices where visit(&list[i].children) { return true }
            return false
        }
        _ = visit(&layers)
    }

    private func siblings(of id: UUID, _ body: ([PlaygroundLayer], Int) -> Void) {
        func visit(_ list: [PlaygroundLayer]) -> Bool {
            if let i = list.firstIndex(where: { $0.id == id }) {
                body(list, i)
                return true
            }
            return list.contains { visit($0.children) }
        }
        _ = visit(layers)
    }
}
