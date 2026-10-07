import SwiftUI
import ShadersKit

/// Layers placed under the inspected component, so blend modes have something to blend with.
enum Backdrop: String, CaseIterable, Identifiable {
    case none, gradient, pattern

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var nodes: [ShaderNode] {
        switch self {
        case .none: return []
        case .gradient: return Subject.gradient.nodes
        case .pattern: return Subject.pattern.nodes
        }
    }
}

/// Full-bleed live preview plus an inspector generated from the component's descriptor.
struct ShaderDetailView: View {
    let name: String

    @Environment(AppModel.self) private var model
    @State private var props: [String: PropValue] = [:]
    @State private var attributes = LayerAttributes()
    @State private var subject: Subject
    @State private var backdrop: Backdrop = .none
    @State private var meter = FrameMeter()
    @State private var inspectorVisible = true
    @State private var exportedImage: ExportedImage?
    @State private var showCode = false
    @State private var pane: DetailPane = UserDefaults.standard.string(forKey: "detailPane") == "code" ? .code : .inspector
    @AppStorage("showHUD") private var showHUD = true
    @AppStorage("showHandles") private var showHandles = true

    private let entry: ShaderIndexEntry?
    private let descriptor: ShaderDescriptor?

    init(name: String) {
        self.name = name
        let entry = Catalog.entry(named: name)
        self.entry = entry
        self.descriptor = ShaderRegistry.descriptor(name)
        _subject = State(initialValue: entry.map(PreviewFactory.defaultSubject(for:)) ?? .scene)
        _props = State(initialValue: PreviewFactory.initialProps(for: name).merging(DetailPane.launchProps(for: name)) { $1 })
    }

    private var wraps: Bool { descriptor?.acceptsChildren ?? false }

    private var node: ShaderNode {
        PreviewFactory.node(type: name, props: props, attributes: attributes, subject: subject)
    }

    private var nodes: [ShaderNode] { backdrop.nodes + [node] }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 760
            let top = geo.safeAreaInsets.top
            Group {
                if wide {
                    HStack(spacing: 0) {
                        preview(topInset: top)
                        if inspectorVisible {
                            inspector
                                .padding(.top, top)
                                .frame(width: pane == .code ? min(440, geo.size.width * 0.46) : min(400, geo.size.width * 0.38))
                                .background(PanelBackground())
                                .transition(.move(edge: .trailing))
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        preview(topInset: top)
                            .frame(height: inspectorVisible ? max(240, geo.size.height * 0.46) + top : geo.size.height + top)
                        if inspectorVisible {
                            inspector
                                .background(PanelBackground())
                                .transition(.move(edge: .bottom))
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .animation(.smooth, value: inspectorVisible)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(name)
        .inlineTitle()
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar { toolbar }
        .sheet(isPresented: $showCode) {
            CodeExportSheet(title: name, code: CodeExporter.swift(for: nodes), promptNodes: nodes)
        }
        #if !os(tvOS)
        .sheet(item: $exportedImage) { image in
            SnapshotShareSheet(image: image)
        }
        #endif
    }

    // MARK: preview

    private func preview(topInset: CGFloat) -> some View {
        ZStack {
            PreviewWell()
            ShaderCanvas(nodes: nodes, onFrame: { meter.record($0) })
            #if !os(tvOS)
            if showHandles, let descriptor {
                PositionHandles(descriptor: descriptor, props: $props)
            }
            #endif
        }
        .overlay(alignment: .topLeading) {
            if showHUD {
                StatsHUD(meter: meter)
                    .padding(12)
                    .padding(.top, topInset)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if entry?.hasCompute == true {
                ComputePendingBanner()
                    .padding(12)
            } else if descriptor?.flags.usesPointer == true {
                Label("Drag on the preview: this shader follows the pointer", systemImage: "hand.draw")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassSurface(Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(12)
            }
        }
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: showHUD)
    }

    // MARK: inspector

    private var inspector: some View {
        VStack(spacing: 0) {
            Picker("Pane", selection: $pane) {
                ForEach(DetailPane.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            switch pane {
            case .inspector: propertyInspector
            case .code: CodePanel(name: name, nodes: nodes)
            }
        }
    }

    @ViewBuilder
    private var propertyInspector: some View {
        if let descriptor {
            InspectorView(descriptor: descriptor, props: $props, attributes: $attributes, onReset: reset) {
                AboutCard(entry: entry, descriptor: descriptor)
                if wraps {
                    InspectorSection(title: "Subject") {
                        SubjectPicker(selection: $subject)
                    }
                }
                InspectorSection(title: "Backdrop") {
                    Picker("Backdrop", selection: $backdrop) {
                        ForEach(Backdrop.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("Layers under the component, so blend modes have something to blend with.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ContentUnavailableView("Unknown component", systemImage: "questionmark.square.dashed", description: Text(name))
        }
    }

    private func reset() {
        props = PreviewFactory.initialProps(for: name)
        attributes = LayerAttributes()
        backdrop = .none
        if let entry { subject = PreviewFactory.defaultSubject(for: entry) }
    }

    // MARK: toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                inspectorVisible.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .accessibilityLabel(inspectorVisible ? "Hide Inspector" : "Show Inspector")
            }
            Menu {
                Toggle(isOn: $showHUD) { Label("Stats HUD", systemImage: "speedometer") }
                #if !os(tvOS)
                Toggle(isOn: $showHandles) { Label("Position Handles", systemImage: "scope") }
                #endif
                Divider()
                Button {
                    model.sendToPlayground(type: name, props: props, attributes: attributes, subject: wraps ? subject : nil)
                    model.galleryPath = []
                } label: {
                    Label("Open in Playground", systemImage: "square.3.layers.3d")
                }
                Button {
                    showCode = true
                } label: {
                    Label("Export Swift Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                #if !os(tvOS)
                Button {
                    exportSnapshot()
                } label: {
                    Label("Export Snapshot", systemImage: "camera")
                }
                #endif
                Divider()
                Button(role: .destructive, action: reset) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("More")
            }
        }
    }

    #if !os(tvOS)
    private func exportSnapshot() {
        let nodes = self.nodes
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ThumbnailRenderer.shared.renderNow(nodes, size: CGSize(width: 1200, height: 900), scale: 2, time: 2.5)
            DispatchQueue.main.async {
                if let image { exportedImage = ExportedImage(name: name, cgImage: image) }
            }
        }
    }
    #endif
}

/// Name, role, category, description and capability flags.
private struct AboutCard: View {
    let entry: ShaderIndexEntry?
    let descriptor: ShaderDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                RoleBadge(role: descriptor.role)
                if let category = descriptor.category {
                    Label(category, systemImage: Catalog.symbol(forCategory: category))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(descriptor.description)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if !flags.isEmpty || descriptor.flags.hasCompute {
                FlowRow(spacing: 6) {
                    if descriptor.flags.hasCompute { ComputeBadge(compact: true) }
                    ForEach(flags, id: \.self) { flag in
                        Text(flag)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var flags: [String] {
        let f = descriptor.flags
        var out: [String] = []
        if f.requiresChild { out.append("Wraps content") }
        if f.usesPointer { out.append("Pointer reactive") }
        if f.requiresRTT { out.append("Render-to-texture") }
        if f.hasUvRemap { out.append("UV remap") }
        if f.acceptsUVContext { out.append("UV context") }
        out.append("\(descriptor.props.count) props")
        return out
    }
}

/// Picks the content filters and warps are applied to.
struct SubjectPicker: View {
    @Binding var selection: Subject

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Subject.allCases) { subject in
                    Button {
                        selection = subject
                    } label: {
                        VStack(spacing: 6) {
                            SnapshotImage(key: "subject:\(subject.rawValue)", nodes: subject.nodes, size: CGSize(width: 64, height: 48), retryIfBlank: subject == .photo)
                                .frame(width: 64, height: 48)
                                .background(PreviewWell())
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(selection == subject ? Color.accentColor : Color.clear, lineWidth: 2.5)
                                )
                            Label(subject.title, systemImage: subject.symbol)
                                .font(.caption2.weight(.medium))
                                .labelStyle(.titleOnly)
                                .foregroundStyle(selection == subject ? Color.accentColor : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .selectionHaptic(trigger: selection)
    }
}

/// Wrapping horizontal layout for small chips.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX + 0.5 {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Inspector or Code, side by side with the preview.
enum DetailPane: String, CaseIterable, Identifiable {
    case inspector, code

    var id: String { rawValue }
    var title: String { self == .inspector ? "Inspector" : "Code" }
    var symbol: String { self == .inspector ? "slider.horizontal.3" : "chevron.left.forwardslash.chevron.right" }

    /// `-setProps "rayCount=24,color=#ff3d7f"` edits props at launch (screenshots, checks).
    static func launchProps(for name: String) -> [String: PropValue] {
        guard let raw = UserDefaults.standard.string(forKey: "setProps"), let d = ShaderRegistry.descriptor(name) else { return [:] }
        var out: [String: PropValue] = [:]
        for pair in raw.split(separator: ",") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2, let prop = d.prop(kv[0]) else { continue }
            if case .number = prop.defaultValue, let n = Float(kv[1]) { out[kv[0]] = .number(n) } else { out[kv[0]] = .string(kv[1]) }
        }
        return out
    }
}

/// Solid inspector background that reads well over the black preview in both appearances.
struct PanelBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        (scheme == .dark ? Color(red: 0.085, green: 0.085, blue: 0.105) : Color(red: 0.955, green: 0.955, blue: 0.97))
            .ignoresSafeArea(edges: .bottom)
    }
}
