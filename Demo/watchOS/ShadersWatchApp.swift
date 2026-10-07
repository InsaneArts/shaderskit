import SwiftUI
import ShadersKit

@main
struct ShadersWatchApp: App {
    /// `-openShader Plasma` opens a component directly (screenshots).
    @State private var path: [String] = UserDefaults.standard.string(forKey: "openShader").map { [$0] } ?? []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                WatchGalleryView()
            }
        }
    }
}

/// Components that render without compute programs, grouped by category.
struct WatchGalleryView: View {
    var body: some View {
        List {
            ForEach(Catalog.categories) { category in
                let entries = category.entries.filter { !$0.hasCompute && $0.role != .media }
                if !entries.isEmpty {
                    Section(category.name) {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry.name) {
                                Label(entry.name, systemImage: entry.role.symbol)
                                    .foregroundStyle(entry.role.tint)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Shaders")
        .navigationDestination(for: String.self) { name in
            WatchShaderView(name: name)
        }
    }
}

/// Full-screen preview; the Digital Crown drives the first numeric prop.
struct WatchShaderView: View {
    let name: String
    private let prop: PropDescriptor?
    @State private var value: Double

    init(name: String) {
        self.name = name
        let prop = ShaderRegistry.descriptor(name)?.props.first { p in
            !p.ui.hidden && p.ui.types.contains("range") && p.ui.min != nil && p.ui.max != nil
        }
        self.prop = prop
        _value = State(initialValue: Double(prop?.defaultValue.numberValue ?? 0))
    }

    private var nodes: [ShaderNode] {
        var props: [String: PropValue] = [:]
        if let prop { props[prop.name] = .number(Float(value)) }
        return [PreviewFactory.node(type: name, props: props)]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            ShaderView(nodes: nodes)
            if let prop {
                Text("\(prop.label) \(value, specifier: "%.2f")")
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 6)
            }
        }
        .ignoresSafeArea()
        .navigationTitle(name)
        .focusable()
        .digitalCrownRotation(
            $value,
            from: Double(prop?.ui.min ?? 0),
            through: Double(prop?.ui.max ?? 1),
            by: prop?.ui.step.map(Double.init),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
}
