import SwiftUI
import ShadersKit

/// Target platform named in the agent prompt.
enum PromptPlatform: String, CaseIterable, Identifiable {
    case iOS, iPadOS, macOS, tvOS, watchOS, visionOS

    var id: String { rawValue }

    /// The platform the demo is running on.
    static var current: PromptPlatform {
        #if os(macOS)
        return .macOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(visionOS)
        return .visionOS
        #else
        return DeviceClass.isPhone ? .iOS : .iPadOS
        #endif
    }
}

/// Builds the Swift snippet and the coding-agent prompt from `skills/shaderskit/PROMPT.md`.
enum AgentPrompt {
    static let defaultPlacement = "full-bleed background behind the main content"
    static let gitURL = "https://github.com/InsaneArts/shaderskit"
    static let installCommand = "npx skills add InsaneArts/shaderskit --skill shaderskit -y"
    /// UserDefaults key for a user-provided package location (git URL or local path).
    static let locationKey = "packageLocationOverride"

    /// Local checkout derived at build time: this file is Demo/Shared/Support/AgentPrompt.swift.
    static let repositoryRoot: String = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        return url.path
    }()

    static var storedOverride: String {
        UserDefaults.standard.string(forKey: locationKey) ?? ""
    }

    /// The "Location:" text. Defaults to the git URL; a local path override is named as an
    /// alternative, any other override replaces the URL.
    static func locationText(override: String = storedOverride) -> String {
        let o = override.trimmingCharacters(in: .whitespaces)
        if o.isEmpty { return gitURL }
        if o.hasPrefix("/") || o.hasPrefix("~") || o.hasPrefix("file://") || o.hasPrefix(".") {
            return "\(gitURL) (or the local checkout at \(o))"
        }
        return o
    }

    /// `import ShadersKit` plus the typed `ShaderView { … }` tree (defaults omitted).
    static func snippet(for nodes: [ShaderNode]) -> String {
        "import ShadersKit\n\n" + ShaderNode.swiftSource(for: nodes)
    }

    /// Distinct component types in the tree, in first-use order.
    static func componentNames(in nodes: [ShaderNode]) -> [String] {
        var names: [String] = []
        for root in nodes {
            root.forEachNode { if !names.contains($0.type) { names.append($0.type) } }
        }
        return names
    }

    /// The prompt for one component (`component` set) or a whole composition.
    static func prompt(nodes: [ShaderNode], component: String? = nil, platform: PromptPlatform, placement: String = defaultPlacement, locationOverride: String = storedOverride) -> String {
        let names = component.map { [$0] } ?? componentNames(in: nodes)
        let title = component ?? names.joined(separator: " + ")
        let place = placement.trimmingCharacters(in: .whitespaces).isEmpty ? defaultPlacement : placement
        let references = names.map { "skills/shaderskit/components/\($0).md" }.joined(separator: ", ")
        return """
        Add the ShadersKit "\(title)" shader to my \(platform.rawValue) app.

        Install the ShadersKit skill first if it is not already available:
            \(installCommand)
        Then use the `shaderskit` skill.

        Package: ShadersKit (Swift package, product "ShadersKit"). Location: \(locationText(override: locationOverride)).
        Minimum OS: iOS 17 / iPadOS 17 / macOS 14 / tvOS 17 / watchOS 10.

        Render exactly this configuration (change it only if I ask):

        ```swift
        \(snippet(for: nodes))
        ```

        Placement: \(place).

        Reference: \(references) (props, ranges, platform notes).

        Done means: the project builds for \(platform.rawValue), the shader renders in the running app, and the code
        uses the typed ShadersKit API above (no hand-written Metal, no renamed props).
        """
    }

    /// `-printPrompt <Component> [platform]`: prints the default prompt (used to verify the text).
    static func printFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-printPrompt"), i + 1 < args.count else { return }
        let name = args[i + 1]
        let platform = (i + 2 < args.count ? PromptPlatform(rawValue: args[i + 2]) : nil) ?? .current
        guard Catalog.entry(named: name) != nil else {
            print("[ShadersDemo prompt] unknown component \(name)")
            return
        }
        let nodes = [PreviewFactory.node(type: name, props: PreviewFactory.initialProps(for: name))]
        print("[ShadersDemo prompt] BEGIN\n\(prompt(nodes: nodes, component: name, platform: platform))\n[ShadersDemo prompt] END")
        fflush(stdout)
    }
}

/// Swift type and platform text shown in the API sheet. Mirrors the generated component docs.
enum PropAPI {
    static func swiftType(_ prop: PropDescriptor) -> String {
        let type = prop.ui.types.first { $0 != "map" } ?? ""
        switch type {
        case "color": return "ShaderColor"
        case "position": return "ShaderPosition"
        case "origin": return "ShaderOrigin"
        case "checkbox": return "Bool"
        case "gradient-stops": return "[ColorStop]?"
        case "select":
            switch prop.transform {
            case .colorSpace: return "ColorSpace"
            case .edges: return "EdgeMode"
            case .strokePosition: return "StrokePosition"
            default: return prop.name == "objectFit" ? "ObjectFit" : prop.name.prefix(1).uppercased() + prop.name.dropFirst()
            }
        case "range", "number", "font-weight":
            return (prop.ui.units?.contains("px") ?? false) || prop.ui.dimensional != nil ? "DimensionalValue" : "Float"
        case "list": return "[Item]"
        default: return "String"
        }
    }

    static func range(_ prop: PropDescriptor) -> String {
        if let options = prop.ui.options, !options.isEmpty {
            return options.map { CodeExporter.enumCaseName($0.value).map { ".\($0)" } ?? $0.value }.joined(separator: ", ")
        }
        if let lo = prop.ui.min, let hi = prop.ui.max {
            let step = prop.ui.step.map { ", step \(PropValue.format($0))" } ?? ""
            return "\(PropValue.format(lo)) … \(PropValue.format(hi))\(step)"
        }
        switch swiftType(prop) {
        case "ShaderColor": return "CSS color string"
        case "ShaderPosition": return "0…1, top-left origin"
        default: return "—"
        }
    }

    static func defaultText(_ prop: PropDescriptor) -> String {
        switch prop.defaultValue {
        case .null: return "nil"
        case .string(let s): return "\"\(s)\""
        case .position:
            let p = prop.defaultValue.uvPoint ?? .zero
            return "(\(PropValue.format(Float(p.x))), \(PropValue.format(Float(p.y))))"
        case .colorStops(let stops): return "\(stops.count) stops"
        case .list(let items): return "\(items.count) items"
        default: return prop.defaultValue.conditionKey
        }
    }

    static func platforms(_ entry: ShaderIndexEntry) -> String {
        if entry.hasCompute { return "Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes)." }
        if entry.cpuSupported { return "All platforms, including watchOS (CPU rasterizer)." }
        return "Metal only (iOS, iPadOS, macOS, tvOS, visionOS)."
    }
}
