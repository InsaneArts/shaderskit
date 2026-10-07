import SwiftUI
import ShadersKit

/// Inspector generated from a descriptor: props grouped by `ui.group`, `ui.hidden` and
/// `ui.condition` respected, plus blend / opacity layer controls.
struct InspectorView<Header: View>: View {
    let descriptor: ShaderDescriptor
    @Binding var props: [String: PropValue]
    @Binding var attributes: LayerAttributes
    var showsVisibility = false
    var onReset: () -> Void
    @ViewBuilder var header: () -> Header

    private var defaults: [String: PropValue] { descriptor.defaultProps }

    private struct PropGroup: Identifiable {
        let name: String
        var props: [PropDescriptor]
        var id: String { name }
    }

    private var groups: [PropGroup] {
        var result: [PropGroup] = []
        for prop in descriptor.props where PropControl(prop) != nil {
            guard prop.isVisible(in: props, defaults: defaults) else { continue }
            let name = prop.ui.group ?? "General"
            if let i = result.firstIndex(where: { $0.name == name }) {
                result[i].props.append(prop)
            } else {
                result.append(PropGroup(name: name, props: [prop]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header()
                ForEach(groups) { group in
                    InspectorSection(title: group.name) {
                        ForEach(group.props, id: \.name) { prop in
                            PropRow(prop: prop, value: binding(for: prop), siblings: props, defaults: defaults)
                        }
                    }
                }
                InspectorSection(title: "Layer") {
                    LayerControls(attributes: $attributes, showsVisibility: showsVisibility)
                    Button(role: .destructive, action: onReset) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButtonStyle()
                }
            }
            .padding(16)
            .animation(.snappy, value: groups.map(\.props.count))
        }
    }

    private func binding(for prop: PropDescriptor) -> Binding<PropValue> {
        Binding(
            get: { props[prop.name] ?? prop.defaultValue },
            set: { props[prop.name] = $0 }
        )
    }
}

extension InspectorView where Header == EmptyView {
    init(descriptor: ShaderDescriptor, props: Binding<[String: PropValue]>, attributes: Binding<LayerAttributes>, showsVisibility: Bool = false, onReset: @escaping () -> Void) {
        self.init(descriptor: descriptor, props: props, attributes: attributes, showsVisibility: showsVisibility, onReset: onReset) { EmptyView() }
    }
}

/// Rounded card grouping inspector rows.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

/// Blend mode, opacity and (in the playground) visibility.
struct LayerControls: View {
    @Binding var attributes: LayerAttributes
    var showsVisibility = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsVisibility {
                Toggle("Visible", isOn: $attributes.visible)
            }
            Picker("Blend Mode", selection: $attributes.blendMode) {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            #if !os(tvOS)
            .pickerStyle(.menu)
            #endif
            NumberSlider(title: "Opacity", value: Binding(
                get: { Double(attributes.opacity) },
                set: { attributes.opacity = Float($0) }
            ), range: 0...1, step: 0.01)
        }
    }
}

extension BlendMode {
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .normalOklch: return "Normal (OKLCH)"
        case .normalOklab: return "Normal (OKLab)"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .linearDodge: return "Linear Dodge"
        case .overlay: return "Overlay"
        case .difference: return "Difference"
        case .colorDodge: return "Color Dodge"
        case .exclusion: return "Exclusion"
        case .color: return "Color"
        case .luminosity: return "Luminosity"
        case .darken: return "Darken"
        case .lighten: return "Lighten"
        case .colorBurn: return "Color Burn"
        case .linearBurn: return "Linear Burn"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .hue: return "Hue"
        case .saturation: return "Saturation"
        }
    }
}
