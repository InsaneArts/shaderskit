import SwiftUI
import ShadersKit

// MARK: - Code card

/// Designed code surface: monospaced, syntax coloured, horizontally scrolling, with a floating
/// copy button. Used for the live snippet and the prompt preview.
struct CodeCard: View {
    let code: String
    var highlightsSwift = true
    var showsCopy = true
    var fontSize: CGFloat = 12.5

    @Environment(\.colorScheme) private var scheme
    @State private var copied = false

    private var text: AttributedString {
        if highlightsSwift { return SwiftHighlighter.highlight(code, scheme: scheme) }
        var t = AttributedString(code)
        t.foregroundColor = SwiftHighlighter.palette(scheme).base
        return t
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: fontSize, design: .monospaced))
                    .lineSpacing(fontSize * 0.3)
                    .fixedSize(horizontal: true, vertical: true)
                    #if !os(tvOS)
                    .textSelection(.enabled)
                    #endif
                    .padding(18)
                    .padding(.trailing, showsCopy ? 30 : 0)
            }
            if showsCopy, Pasteboard.isAvailable {
                Button(action: copy) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(copied ? Color.green : Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy")
                .accessibilityLabel(copied ? "Copied" : "Copy")
                .padding(10)
                .impactHaptic(trigger: copied)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CodeCard.background(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(scheme == .dark ? 0.1 : 0.09), lineWidth: 1))
    }

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.075, green: 0.078, blue: 0.098) : Color(red: 0.972, green: 0.973, blue: 0.982)
    }

    private func copy() {
        Pasteboard.copy(code)
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { copied = false }
        }
    }
}

/// "All platforms" / "Metal only" capsule.
struct PlatformPill: View {
    let entry: ShaderIndexEntry

    private var allPlatforms: Bool { entry.cpuSupported && !entry.hasCompute }

    var body: some View {
        Label(allPlatforms ? "All platforms" : "Metal only", systemImage: allPlatforms ? "checkmark.seal" : "cpu")
            .labelStyle(BadgeLabelStyle(compact: true))
            .foregroundStyle(allPlatforms ? Color.green : Color.blue)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((allPlatforms ? Color.green : Color.blue).opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder((allPlatforms ? Color.green : Color.blue).opacity(0.3), lineWidth: 0.5))
            .help(PropAPI.platforms(entry))
    }
}

// MARK: - Code pane

/// Live Swift for the current configuration plus the prop API and agent prompt entry points.
struct CodePanel: View {
    let name: String
    let nodes: [ShaderNode]

    @State private var sheet: Sheet? = Sheet.launchValue

    enum Sheet: String, Identifiable {
        case api, prompt
        var id: String { rawValue }

        /// `-codeSheet api|prompt` opens a sheet at launch (screenshots).
        static var launchValue: Sheet? { UserDefaults.standard.string(forKey: "codeSheet").flatMap(Sheet.init(rawValue:)) }
    }

    private var entry: ShaderIndexEntry? { Catalog.entry(named: name) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    CodeCard(code: AgentPrompt.snippet(for: nodes))
                    Text("Updates live as you edit. Props at their defaults are omitted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                UseItCard(
                    onAPI: { sheet = .api },
                    onPrompt: { sheet = .prompt }
                )
            }
            .padding(16)
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .api: APISheet(name: name)
            case .prompt: AgentPromptSheet(title: name, nodes: nodes, component: name)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Swift")
                .font(.headline)
            if let entry { PlatformPill(entry: entry) }
            Spacer(minLength: 4)
            if let category = entry?.category {
                Label(category, systemImage: Catalog.symbol(forCategory: category))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// "Use it in your app" card with the two primary actions.
struct UseItCard: View {
    var onAPI: () -> Void
    var onPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("USE IT IN YOUR APP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)
            ActionRow(symbol: "list.bullet.rectangle.portrait", tint: .blue, title: "Prop API", subtitle: "Every prop with its Swift type, default and range", action: onAPI)
            Divider().padding(.leading, 58)
            ActionRow(symbol: "sparkles", tint: .purple, title: "Agent prompt", subtitle: "A ready prompt for a coding agent, with the skill install", action: onPrompt)
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

private struct ActionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prop API sheet

/// Every prop grouped by `ui.group`: monospaced name, type pill, default in code style, range.
struct APISheet: View {
    let name: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private struct PropGroup: Identifiable {
        let name: String
        var props: [PropDescriptor]
        var id: String { name }
    }

    private var groups: [PropGroup] {
        guard let d = ShaderRegistry.descriptor(name) else { return [] }
        var out: [PropGroup] = []
        for p in d.props {
            let g = p.ui.group ?? "General"
            if let i = out.firstIndex(where: { $0.name == g }) { out[i].props.append(p) } else { out.append(PropGroup(name: g, props: [p])) }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let entry = Catalog.entry(named: name), let d = entry.descriptor {
                        overview(entry, d)
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.name.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                            ForEach(Array(group.props.enumerated()), id: \.element.name) { index, prop in
                                if index > 0 { Divider().padding(.leading, 14) }
                                PropAPIRow(prop: prop)
                            }
                        }
                        .padding(.bottom, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
                    }
                }
                .padding(20)
            }
            .background(sheetBackground.ignoresSafeArea())
            .navigationTitle("\(name) API")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 640, idealHeight: 760)
        #endif
    }

    private var sheetBackground: Color {
        scheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.08) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private func overview(_ entry: ShaderIndexEntry, _ d: ShaderDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoleBadge(role: entry.role, compact: true)
                PlatformPill(entry: entry)
                Spacer(minLength: 0)
                Text("\(d.props.count) props")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(d.description)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text(PropAPI.platforms(entry))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("skills/shaderskit/components/\(name).md")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                #if !os(tvOS)
                .textSelection(.enabled)
                #endif
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

private struct PropAPIRow: View {
    let prop: PropDescriptor
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prop.name)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                Text(PropAPI.swiftType(prop))
                    .font(.system(.caption2, design: .monospaced).weight(.medium))
                    .foregroundStyle(SwiftHighlighter.palette(scheme).type)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SwiftHighlighter.palette(scheme).type.opacity(0.13), in: Capsule())
                Spacer(minLength: 8)
                Text(PropAPI.defaultText(prop))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(defaultColor)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(CodeCard.background(scheme), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
            }
            Text(PropAPI.range(prop))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let description = prop.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var defaultColor: Color {
        let p = SwiftHighlighter.palette(scheme)
        switch prop.defaultValue {
        case .string: return p.string
        case .number: return p.number
        case .bool: return p.keyword
        default: return p.base
        }
    }
}

// MARK: - Agent prompt sheet

/// Platform, placement and package location, a live preview and a prominent Copy.
struct AgentPromptSheet: View {
    let title: String
    let nodes: [ShaderNode]
    /// Single component name; nil for a composition.
    var component: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var platform = PromptPlatform.current
    @State private var placement = AgentPrompt.defaultPlacement
    @AppStorage(AgentPrompt.locationKey) private var locationOverride = ""
    @State private var copied = false

    private var prompt: String {
        AgentPrompt.prompt(nodes: nodes, component: component, platform: platform, placement: placement, locationOverride: locationOverride)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Paste this into a coding agent. It installs the `shaderskit` skill, adds the package and renders exactly this configuration in your project.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    field("Platform") {
                        Picker("Platform", selection: $platform) {
                            ForEach(PromptPlatform.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    #if !os(tvOS)
                    field("Placement") {
                        TextField("Where the effect goes", text: $placement, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }
                    field("Package location") {
                        TextField(AgentPrompt.gitURL, text: $locationOverride)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                        Text("Empty uses GitHub. A local path, such as \(AgentPrompt.repositoryRoot), is added as an alternative.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    #endif
                    if Pasteboard.isAvailable {
                        Button(action: copy) {
                            Label(copied ? "Copied to Clipboard" : "Copy Prompt", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .impactHaptic(trigger: copied)
                    }
                    field("Preview") {
                        CodeCard(code: prompt, highlightsSwift: false, showsCopy: false, fontSize: 11.5)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Agent Prompt")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 700, idealHeight: 820)
        #endif
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            content()
        }
    }

    private func copy() {
        Pasteboard.copy(prompt)
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.snappy) { copied = false }
        }
    }
}
