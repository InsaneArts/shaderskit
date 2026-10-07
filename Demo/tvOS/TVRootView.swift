import SwiftUI
import ShadersKit

/// tvOS: top tabs, focus-driven gallery shelves.
struct TVRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.section) {
            NavigationStack(path: $model.galleryPath) {
                TVGalleryView()
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
    }
}

/// One shelf per category. The focused card drives a live hero preview behind the shelves;
/// cards themselves show cached snapshots, so only one Metal view runs at a time.
struct TVGalleryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: String?
    @State private var hero = "Aurora"

    private var heroEntry: ShaderIndexEntry? { Catalog.entry(named: hero) }
    private var isActive: Bool { model.section == .gallery && model.galleryPath.isEmpty && scenePhase == .active }

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroBackground
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 48) {
                    heroText
                        .frame(height: 300, alignment: .bottomLeading)
                    ForEach(Catalog.categories) { category in
                        VStack(alignment: .leading, spacing: 18) {
                            Label(category.name, systemImage: category.symbol)
                                .font(.title3.weight(.semibold))
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 40) {
                                    ForEach(category.entries) { entry in
                                        NavigationLink(value: ShaderRoute(name: entry.name)) {
                                            TVCard(entry: entry)
                                        }
                                        .buttonStyle(.card)
                                        .focused($focused, equals: entry.name)
                                    }
                                }
                                .padding(.vertical, 24)
                            }
                            .scrollClipDisabled()
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 80)
            }
        }
        .onChange(of: focused) { _, new in
            if let new { withAnimation(.easeInOut(duration: 0.4)) { hero = new } }
        }
        .navigationDestination(for: ShaderRoute.self) { route in
            ShaderDetailView(name: route.name)
        }
    }

    private var heroBackground: some View {
        ZStack {
            Color.black
            if let heroEntry, !heroEntry.hasCompute {
                ShaderCanvas(nodes: PreviewFactory.nodes(for: heroEntry), isPaused: !isActive)
                    .id(hero)
                    .transition(.opacity)
                    .opacity(0.7)
            } else if let heroEntry {
                PlaceholderArt(entry: heroEntry)
            }
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.55), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hero)
                .font(.system(size: 64, weight: .bold))
            if let heroEntry {
                Text(heroEntry.description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    RoleBadge(role: heroEntry.role)
                    if heroEntry.hasCompute { ComputeBadge() }
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private struct TVCard: View {
    let entry: ShaderIndexEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PreviewWell()
            if entry.hasCompute {
                PlaceholderArt(entry: entry)
            } else {
                SnapshotImage(key: "card:\(entry.name)", nodes: PreviewFactory.nodes(for: entry), size: CGSize(width: 240, height: 180))
            }
            Text(entry.name)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: 360, height: 240)
    }
}
