import SwiftUI
import ShadersKit

/// Layer stack, top-most first. Children of filters and warps are indented under them.
struct LayerListView: View {
    @Bindable var playground: PlaygroundModel
    var onWrap: (UUID) -> Void

    var body: some View {
        List {
            ForEach(playground.rows) { row in
                Button {
                    playground.selection = row.id
                } label: {
                    LayerRowView(row: row, isSelected: playground.selection == row.id) {
                        playground.update(row.id) { $0.attributes.visible.toggle() }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(playground.selection == row.id ? Color.accentColor.opacity(0.18) : Color.clear)
                .contextMenu { actions(for: row) }
                #if os(iOS)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation { playground.remove(row.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        withAnimation { playground.duplicate(row.id) }
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(.indigo)
                }
                #endif
            }
            .onMove { source, destination in
                withAnimation { playground.moveRows(from: source, to: destination) }
            }
        }
        .listStyle(.plain)
        #if !os(tvOS)
        .scrollContentBackground(.hidden)
        #endif
        .overlay {
            if playground.layers.isEmpty {
                ContentUnavailableView("No Layers", systemImage: "square.3.layers.3d.slash", description: Text("Add a component with the + button."))
            }
        }
    }

    @ViewBuilder
    private func actions(for row: LayerRow) -> some View {
        Button {
            withAnimation { playground.move(row.id, up: true) }
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(!playground.canMove(row.id, up: true))
        Button {
            withAnimation { playground.move(row.id, up: false) }
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(!playground.canMove(row.id, up: false))
        Divider()
        Button {
            onWrap(row.id)
        } label: {
            Label("Wrap in Filter…", systemImage: "square.dashed.inset.filled")
        }
        if row.layer.wraps, !row.layer.children.isEmpty {
            Button {
                withAnimation { playground.unwrap(row.id) }
            } label: {
                Label("Unwrap", systemImage: "square.dashed")
            }
        }
        Button {
            withAnimation { playground.duplicate(row.id) }
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            withAnimation { playground.remove(row.id) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct LayerRowView: View {
    let row: LayerRow
    let isSelected: Bool
    var toggleVisibility: () -> Void

    private var layer: PlaygroundLayer { row.layer }

    var body: some View {
        HStack(spacing: 10) {
            if row.depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, CGFloat(row.depth - 1) * 14)
            }
            SnapshotImage(key: "row:\(layer.type)", nodes: [PreviewFactory.node(type: layer.type)], size: CGSize(width: 48, height: 36))
                .frame(width: 44, height: 33)
                .background(PreviewWell())
                .overlay {
                    if layer.entry?.hasCompute == true {
                        Image(systemName: "hourglass").font(.caption2).foregroundStyle(.orange)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(layer.type)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: toggleVisibility) {
                Image(systemName: layer.attributes.visible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.attributes.visible ? Color.secondary : Color.orange)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(layer.attributes.visible ? "Hide layer" : "Show layer")
        }
        .opacity(layer.attributes.visible ? 1 : 0.55)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts = [layer.entry?.role.title ?? "Layer"]
        if layer.attributes.blendMode != .normal { parts.append(layer.attributes.blendMode.title) }
        if layer.attributes.opacity < 1 { parts.append("\(Int((layer.attributes.opacity * 100).rounded()))%") }
        if layer.entry?.hasCompute == true { parts.append("compute pending") }
        return parts.joined(separator: " · ")
    }
}

/// Add a component, or choose the filter that wraps a layer.
enum PickerMode: Identifiable {
    case add
    case wrap(UUID)

    var id: String {
        switch self {
        case .add: return "add"
        case .wrap(let id): return "wrap-\(id)"
        }
    }
}

struct ComponentPicker: View {
    let mode: PickerMode
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [ShaderCategory] {
        Catalog.categories.compactMap { category in
            let entries = category.entries.filter { entry in
                if case .wrap = mode, !(entry.acceptsChildren && entry.role.wrapsContent) { return false }
                return Catalog.matches(entry, query: query)
            }
            return entries.isEmpty ? nil : ShaderCategory(name: category.name, entries: entries)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if case .add = mode {
                    Text("Generators and shapes go on top of the stack. Filters and warps wrap the selected layer (or the whole stack).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            Button {
                                onPick(entry.name)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    SnapshotImage(key: "row:\(entry.name)", nodes: [PreviewFactory.node(type: entry.name)], size: CGSize(width: 48, height: 36))
                                        .frame(width: 48, height: 36)
                                        .background(PreviewWell())
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.body.weight(.medium))
                                        Text(entry.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 4)
                                    if entry.hasCompute {
                                        Image(systemName: "hourglass")
                                            .foregroundStyle(.orange)
                                            .accessibilityLabel("Compute port pending")
                                    }
                                    RoleBadge(role: entry.role, compact: true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(section.name, systemImage: section.symbol)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search components")
            .navigationTitle(title)
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private var title: String {
        switch mode {
        case .add: return "Add Layer"
        case .wrap: return "Wrap in Filter"
        }
    }
}
