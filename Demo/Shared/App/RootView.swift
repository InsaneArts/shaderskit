import SwiftUI
import ShadersKit

struct RootView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        SplitRootView()
        #elseif os(tvOS)
        TVRootView()
        #else
        if horizontalSizeClass == .regular {
            SplitRootView()
        } else {
            TabRootView()
        }
        #endif
    }
}

/// iPhone: one tab per section.
struct TabRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.section) {
            NavigationStack(path: $model.galleryPath) {
                GalleryView(category: nil)
            }
            .tabItem { Label(AppSection.gallery.title, systemImage: AppSection.gallery.symbol) }
            .tag(AppSection.gallery)

            NavigationStack {
                ShowcaseView()
            }
            .tabItem { Label(AppSection.showcase.title, systemImage: AppSection.showcase.symbol) }
            .tag(AppSection.showcase)

            NavigationStack {
                PlaygroundView()
            }
            .tabItem { Label(AppSection.playground.title, systemImage: AppSection.playground.symbol) }
            .tag(AppSection.playground)
        }
        .selectionHaptic(trigger: model.section)
    }
}

/// iPad and macOS: sidebar with categories and sections.
struct SplitRootView: View {
    @Environment(AppModel.self) private var model
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $model.sidebarSelection) {
                Section("Library") {
                    SidebarRow(title: "All Shaders", symbol: "square.grid.2x2", count: Catalog.entries.count)
                        .tag(SidebarItem.all)
                    ForEach(Catalog.categories) { category in
                        SidebarRow(title: category.name, symbol: category.symbol, count: category.entries.count)
                            .tag(SidebarItem.category(category.name))
                    }
                }
                Section("Create") {
                    SidebarRow(title: AppSection.showcase.title, symbol: AppSection.showcase.symbol, count: ShowcasePresets.all.count)
                        .tag(SidebarItem.showcase)
                    SidebarRow(title: AppSection.playground.title, symbol: AppSection.playground.symbol, count: model.playground.layerCount)
                        .tag(SidebarItem.playground)
                }
            }
            .navigationTitle("ShadersKit")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
            #endif
        } detail: {
            switch model.section {
            case .gallery:
                NavigationStack(path: $model.galleryPath) {
                    GalleryView(category: model.category)
                }
                .id(model.category ?? "all")
            case .showcase:
                NavigationStack { ShowcaseView() }
            case .playground:
                NavigationStack { PlaygroundView() }
            }
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }
}
