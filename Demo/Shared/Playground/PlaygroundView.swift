import SwiftUI
import ShadersKit

/// Compose a stack of layers, nest filters, edit props, save and export Swift code.
struct PlaygroundView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var meter = FrameMeter()
    @State private var pane: Pane = .layers
    @State private var picker: PickerMode?
    @State private var showCode = false
    @State private var showLibrary = false
    @AppStorage("showHUD") private var showHUD = true

    enum Pane: String, CaseIterable, Identifiable {
        case layers = "Layers"
        case inspector = "Inspector"
        var id: String { rawValue }
    }

    private var playground: PlaygroundModel { model.playground }
    private var isActive: Bool { model.section == .playground && scenePhase == .active }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 980 {
                HStack(spacing: 0) {
                    layersPanel
                        .frame(width: 290)
                        .background(.regularMaterial)
                    canvas
                    inspectorPanel
                        .frame(width: 370)
                        .background(.regularMaterial)
                }
            } else {
                VStack(spacing: 0) {
                    canvas
                        .frame(height: max(220, geo.size.height * 0.42))
                    Picker("Pane", selection: $pane) {
                        ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    switch pane {
                    case .layers: layersPanel
                    case .inspector: inspectorPanel
                    }
                }
                .background(.regularMaterial)
            }
        }
        .navigationTitle(playground.name)
        .inlineTitle()
        .toolbar { toolbar }
        .sheet(item: $picker) { mode in
            ComponentPicker(mode: mode) { type in
                withAnimation {
                    switch mode {
                    case .add: playground.addLayer(type: type)
                    case .wrap(let id): playground.wrap(id, in: type)
                    }
                }
                pane = .inspector
            }
        }
        .sheet(isPresented: $showCode) {
            CodeExportSheet(title: playground.name.replacingOccurrences(of: " ", with: ""), code: CodeExporter.swift(for: playground.nodes), promptNodes: playground.nodes)
        }
        .sheet(isPresented: $showLibrary) {
            LibrarySheet(playground: playground)
        }
        .onChange(of: playground.selection) { _, new in
            // compact layout: jump to the inspector for the newly selected layer
            if new != nil, pane == .layers { pane = .inspector }
        }
    }

    // MARK: panes

    private var canvas: some View {
        ZStack {
            PreviewWell()
            ShaderCanvas(nodes: playground.nodes, isPaused: !isActive, onFrame: { meter.record($0) })
            if playground.layers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.largeTitle)
                    Text("Empty canvas")
                        .font(.headline)
                    Button {
                        picker = .add
                    } label: {
                        Label("Add Layer", systemImage: "plus")
                    }
                    .glassButtonStyle()
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .overlay(alignment: .topLeading) {
            if showHUD {
                StatsHUD(meter: meter).padding(12)
            }
        }
        .clipped()
    }

    private var layersPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Text("\(playground.layerCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    picker = .add
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add Layer")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            LayerListView(playground: playground) { id in picker = .wrap(id) }
        }
    }

    @ViewBuilder
    private var inspectorPanel: some View {
        if let layer = playground.selectedLayer, let descriptor = ShaderRegistry.descriptor(layer.type) {
            InspectorView(descriptor: descriptor, props: propsBinding(layer.id), attributes: attributesBinding(layer.id), showsVisibility: true) {
                playground.update(layer.id) {
                    $0.props = [:]
                    $0.attributes = LayerAttributes()
                }
            } header: {
                LayerHeader(layer: layer, playground: playground) { picker = .wrap(layer.id) }
            }
            .id(layer.id)
        } else {
            ContentUnavailableView("No Selection", systemImage: "cursorarrow.click", description: Text("Select a layer to edit its props, blend mode and opacity."))
        }
    }

    private func propsBinding(_ id: UUID) -> Binding<[String: PropValue]> {
        Binding(
            get: { playground.selectedLayer?.props ?? [:] },
            set: { new in playground.update(id) { $0.props = new } }
        )
    }

    private func attributesBinding(_ id: UUID) -> Binding<LayerAttributes> {
        Binding(
            get: { playground.selectedLayer?.attributes ?? LayerAttributes() },
            set: { new in playground.update(id) { $0.attributes = new } }
        )
    }

    // MARK: toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                picker = .add
            } label: {
                Label("Add Layer", systemImage: "plus")
            }
            Button {
                showCode = true
            } label: {
                Label("Export Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Menu {
                Button {
                    showLibrary = true
                } label: {
                    Label("Library…", systemImage: "folder")
                }
                Menu {
                    ForEach(ShowcasePresets.all) { preset in
                        Button(preset.title) { withAnimation { playground.load(preset) } }
                    }
                } label: {
                    Label("Load Preset", systemImage: "sparkles")
                }
                Toggle(isOn: $showHUD) { Label("Stats HUD", systemImage: "speedometer") }
                Divider()
                Button(role: .destructive) {
                    withAnimation { playground.clear() }
                } label: {
                    Label("Clear Canvas", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}

/// Selected layer title with structural actions.
private struct LayerHeader: View {
    let layer: PlaygroundLayer
    let playground: PlaygroundModel
    var onWrap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(layer.type)
                    .font(.title3.weight(.bold))
                if let role = layer.entry?.role { RoleBadge(role: role, compact: true) }
                Spacer(minLength: 0)
            }
            if layer.entry?.hasCompute == true {
                ComputeBadge()
            }
            HStack(spacing: 8) {
                Button(action: onWrap) {
                    Label("Wrap", systemImage: "square.dashed.inset.filled")
                }
                if layer.wraps, !layer.children.isEmpty {
                    Button {
                        withAnimation { playground.unwrap(layer.id) }
                    } label: {
                        Label("Unwrap", systemImage: "square.dashed")
                    }
                }
                Button {
                    withAnimation { playground.move(layer.id, up: true) }
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(!playground.canMove(layer.id, up: true))
                .accessibilityLabel("Move Up")
                Button {
                    withAnimation { playground.move(layer.id, up: false) }
                } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(!playground.canMove(layer.id, up: false))
                .accessibilityLabel("Move Down")
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    withAnimation { playground.remove(layer.id) }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete Layer")
            }
            .font(.subheadline)
            .glassButtonStyle()
        }
    }
}
