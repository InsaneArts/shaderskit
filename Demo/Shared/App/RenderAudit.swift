import SwiftUI
import ShadersKit

/// `-audit YES`: renders every component's gallery preview once and logs which ones draw
/// nothing, with frame stats. Used to verify that no card is unexpectedly empty.
enum RenderAudit {
    static func run() async {
        if UserDefaults.standard.bool(forKey: "dumpCode") { dumpCode() }
        var blank: [String] = []
        var failed: [String] = []
        for entry in Catalog.entries {
            let key = "audit:\(entry.name)"
            let thumb = await ThumbnailRenderer.shared.thumbnail(key: key, nodes: PreviewFactory.nodes(for: entry), size: CGSize(width: 96, height: 72), scale: 1)
            guard let thumb else { failed.append(entry.name); continue }
            if thumb.isBlank { blank.append(entry.hasCompute ? "\(entry.name)(compute)" : entry.name) }
        }
        print("[ShadersDemo audit] rendered \(Catalog.entries.count) components; failed=\(failed.count) blank=\(blank.count)")
        print("[ShadersDemo audit] blank: \(blank.joined(separator: ", "))")
        print("[ShadersDemo audit] failed: \(failed.joined(separator: ", "))")
        // renderer diagnostics for blank components that are not compute-backed
        guard let device = ShaderDevice.shared else { return }
        let renderer = ShaderRenderer(device: device)
        for name in blank where !name.hasSuffix("(compute)") {
            guard let entry = Catalog.entry(named: name) else { continue }
            renderer.resetState()
            _ = renderer.renderImage(PreviewFactory.nodes(for: entry), size: CGSize(width: 64, height: 48), time: 2.5)
            let s = renderer.stats
            print("[ShadersDemo audit] \(name): passes=\(s.passes) nodes=\(s.nodes) unsupported=\(s.unsupportedNodes) errors=\(s.compileErrors.map { String($0.prefix(300)) })")
        }
    }

    /// `-dumpCode YES`: writes Swift exported for every preset and for every component with
    /// all props changed from their defaults to `tmp/ExportedCode.swift`, so it can be
    /// type-checked against ShadersKit.
    static func dumpCode() {
        var out = ["import SwiftUI", "import ShadersKit", ""]
        for preset in ShowcasePresets.all {
            out.append(CodeExporter.swift(for: preset.layers, viewName: "Preset_\(preset.id)", imports: false))
        }
        for entry in Catalog.entries {
            guard let d = entry.descriptor else { continue }
            var props: [String: PropValue] = [:]
            for p in d.props { if let v = changedValue(p) { props[p.name] = v } }
            let node = PreviewFactory.node(type: entry.name, props: props, attributes: LayerAttributes(blendMode: .screen, opacity: 0.5))
            out.append(CodeExporter.swift(for: [node], viewName: "Component_\(entry.name)", imports: false))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ExportedCode.swift")
        try? out.joined(separator: "\n\n").write(to: url, atomically: true, encoding: .utf8)
        print("[ShadersDemo dump] wrote \(url.path)")
    }

    private static func changedValue(_ p: PropDescriptor) -> PropValue? {
        switch PropControl(p) {
        case .slider(let range, _)?:
            let v = Float(range.upperBound)
            return p.defaultValue.numberValue == v ? .number(Float(range.lowerBound)) : p.defaultValue.withNumber(v)
        case .color?: return .string("#123456")
        case .select(let options)?:
            guard let last = options.last(where: { $0.value != p.defaultValue.conditionKey }) else { return nil }
            if case .number = p.defaultValue { return .number(Float(last.value) ?? 0) }
            return .string(last.value)
        case .toggle?: return .bool(!(p.defaultValue.boolValue ?? false))
        case .position?: return .uv(CGPoint(x: 0.25, y: 0.75))
        case .origin?: return .string(p.defaultValue.stringValue == "top-left" ? "bottom-right" : "top-left")
        case .stops?: return .colorStops([ColorStop(color: "#ff0000", position: 0), ColorStop(color: "#0000ff", position: 1)])
        case .text?: return .string("Edited \"text\"")
        default: return nil
        }
    }
}
