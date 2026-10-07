import SwiftUI
import ShadersKit

/// Save, load, import and export playground compositions as JSON.
struct LibrarySheet: View {
    let playground: PlaygroundModel
    @Environment(\.dismiss) private var dismiss
    @State private var store = CompositionStore()
    @State private var name = ""
    @State private var message: String?

    private var current: CompositionDocument {
        CompositionDocument(name: name.isEmpty ? playground.name : name, nodes: playground.nodes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Composition") {
                    TextField("Name", text: $name)
                    Button {
                        store.save(current)
                        playground.name = current.name
                        message = "Saved “\(current.name)”."
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    #if !os(tvOS)
                    ShareLink(item: JSONFile(text: current.jsonString(), name: current.name), preview: SharePreview("\(current.name).json")) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    #endif
                    if Pasteboard.isAvailable {
                        Button {
                            Pasteboard.copy(current.jsonString())
                            message = "JSON copied to the clipboard."
                        } label: {
                            Label("Copy JSON", systemImage: "doc.on.doc")
                        }
                        Button {
                            importFromPasteboard()
                        } label: {
                            Label("Import JSON from Clipboard", systemImage: "doc.on.clipboard")
                        }
                    }
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Saved") {
                    if store.documents.isEmpty {
                        Text("No saved compositions yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.documents) { doc in
                        Button {
                            playground.load(doc)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(doc.name)
                                    Text("\(doc.layers.count) layers · \(doc.modified.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.down.doc")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { store.delete(doc) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { store.delete(store.documents[i]) }
                    }
                }
                Section("Start from a Preset") {
                    ForEach(ShowcasePresets.all) { preset in
                        Button {
                            playground.load(preset)
                            dismiss()
                        } label: {
                            Label(preset.title, systemImage: preset.symbol)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                name = playground.name
                store.reload()
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private func importFromPasteboard() {
        guard let text = Pasteboard.string() else {
            message = "The clipboard has no text."
            return
        }
        do {
            let doc = try CompositionDocument.decode(text)
            playground.load(doc)
            message = "Imported \(doc.layers.count) layers."
        } catch {
            message = "Not a composition: \(error.localizedDescription)"
        }
    }
}
