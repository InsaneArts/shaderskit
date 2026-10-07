import SwiftUI
import ShadersKit

/// Grid of components, grouped by category, searchable.
struct GalleryView: View {
    /// Fixed category from the sidebar; nil shows every category (with chips on iPhone).
    var category: String?

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var chip: String?
    @AppStorage("hideCompute") private var hideCompute = false
    @Namespace private var zoomSpace

    private var activeCategory: String? { category ?? chip }

    private var isActive: Bool {
        model.section == .gallery && model.galleryPath.isEmpty && scenePhase == .active
    }

    private var sections: [ShaderCategory] {
        Catalog.categories.compactMap { section in
            if let activeCategory, section.name != activeCategory { return nil }
            let entries = section.entries.filter { entry in
                (!hideCompute || !entry.hasCompute) && Catalog.matches(entry, query: query)
            }
            return entries.isEmpty ? nil : ShaderCategory(name: section.name, entries: entries)
        }
    }

    private var columns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 18)]
        #else
        DeviceClass.isPhone
            ? [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
            : [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 18)]
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if category == nil, query.isEmpty {
                    GalleryHeader()
                }
                if category == nil, DeviceClass.isPhone {
                    CategoryChips(selection: $chip)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                NavigationLink(value: ShaderRoute(name: entry.name)) {
                                    ShaderCard(entry: entry, isActive: isActive)
                                }
                                .buttonStyle(CardButtonStyle())
                                .zoomSource(id: entry.name, in: zoomSpace)
                                .contextMenu {
                                    if Pasteboard.isAvailable {
                                        Button {
                                            Pasteboard.copy(AgentPrompt.snippet(for: PreviewFactory.nodes(for: entry)))
                                        } label: {
                                            Label("Copy Swift", systemImage: "doc.on.doc")
                                        }
                                        Button {
                                            Pasteboard.copy(AgentPrompt.prompt(nodes: PreviewFactory.nodes(for: entry), component: entry.name, platform: .current))
                                        } label: {
                                            Label("Copy Agent Prompt", systemImage: "sparkles")
                                        }
                                    }
                                }
                            }
                        } header: {
                            SectionHeader(category: section)
                        }
                    }
                }
                if sections.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, DeviceClass.isPhone ? 16 : 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            if category == nil, chip == nil, let launchCategory = model.launch.category {
                chip = launchCategory
            }
        }
        .background { AmbientBackground(style: .aurora, isPaused: !isActive) }
        .navigationTitle(category ?? "Shaders")
        .searchable(text: $query, prompt: "Search \(Catalog.entries.count) shaders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle(isOn: $hideCompute) {
                        Label("Hide Compute-Pending", systemImage: "hourglass")
                    }
                } label: {
                    Label("Filter", systemImage: hideCompute ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .navigationDestination(for: ShaderRoute.self) { route in
            ShaderDetailView(name: route.name)
                .zoomDestination(id: route.name, in: zoomSpace)
        }
    }
}

/// Subtle press feedback for cards.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct SectionHeader: View {
    let category: ShaderCategory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
            Text(category.name)
                .font(.title2.weight(.bold))
            Text("\(category.entries.count)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Library summary at the top of the "all shaders" gallery.
private struct GalleryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metal port of the shaders.com component library. Every card is a real `ShaderView`.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                StatPill(value: Catalog.entries.count, label: "components", symbol: "square.grid.2x2", tint: .purple)
                StatPill(value: Catalog.liveCount, label: "live", symbol: "bolt.fill", tint: .green)
                StatPill(value: Catalog.computeCount, label: "compute pending", symbol: "hourglass", tint: .orange)
            }
        }
        .padding(.top, 4)
    }
}

private struct StatPill: View {
    let value: Int
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text("\(value)")
                    .font(.headline.monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Horizontal category filter.
struct CategoryChips: View {
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", symbol: "square.grid.2x2", value: nil)
                ForEach(Catalog.categories) { category in
                    chip(title: category.name, symbol: category.symbol, value: category.name)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .selectionHaptic(trigger: selection)
    }

    private func chip(title: String, symbol: String, value: String?) -> some View {
        let selected = selection == value
        return Button {
            withAnimation(.snappy) { selection = value }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background {
                    if selected {
                        Capsule().fill(Color.accentColor.gradient)
                    }
                }
                .glassSurface(Capsule())
        }
        .buttonStyle(.plain)
    }
}
