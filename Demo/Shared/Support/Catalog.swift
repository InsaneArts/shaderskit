import SwiftUI
import ShadersKit

/// One gallery category with its components.
struct ShaderCategory: Identifiable, Hashable {
    let name: String
    let entries: [ShaderIndexEntry]

    var id: String { name }
    var symbol: String { Catalog.symbol(forCategory: name) }
    var liveCount: Int { entries.filter { !$0.hasCompute }.count }

    static func == (lhs: ShaderCategory, rhs: ShaderCategory) -> Bool { lhs.name == rhs.name && lhs.entries.count == rhs.entries.count }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

/// The 199 components, grouped and searchable.
enum Catalog {
    static let entries: [ShaderIndexEntry] = ShaderRegistry.index

    static let categoryOrder = ["Textures", "Shapes", "Distortions", "Stylize", "Adjustments", "Blurs", "Transitions", "Interactive", "Shape Effects", "Utilities"]

    static let categories: [ShaderCategory] = {
        let grouped = Dictionary(grouping: entries) { $0.categoryName }
        let known = categoryOrder.compactMap { name in grouped[name].map { ShaderCategory(name: name, entries: $0) } }
        let extra = grouped.keys.filter { !categoryOrder.contains($0) }.sorted().map { ShaderCategory(name: $0, entries: grouped[$0] ?? []) }
        return known + extra
    }()

    static var liveCount: Int { entries.filter { !$0.hasCompute }.count }
    static var computeCount: Int { entries.filter(\.hasCompute).count }

    static func entry(named name: String) -> ShaderIndexEntry? {
        entries.first { $0.name == name }
    }

    static func symbol(forCategory name: String) -> String {
        switch name {
        case "Textures": return "paintpalette"
        case "Shapes": return "star.circle"
        case "Distortions": return "tornado"
        case "Stylize": return "camera.filters"
        case "Adjustments": return "slider.horizontal.3"
        case "Blurs": return "aqi.medium"
        case "Transitions": return "arrow.left.arrow.right.square"
        case "Interactive": return "hand.point.up.left"
        case "Shape Effects": return "cube.transparent"
        case "Utilities": return "square.stack.3d.up"
        default: return "circle.grid.3x3"
        }
    }

    /// Case-insensitive match on name, description, category and role.
    static func matches(_ entry: ShaderIndexEntry, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return entry.name.localizedCaseInsensitiveContains(q)
            || entry.description.localizedCaseInsensitiveContains(q)
            || entry.categoryName.localizedCaseInsensitiveContains(q)
            || entry.role.title.localizedCaseInsensitiveContains(q)
    }
}

extension ShaderIndexEntry {
    var categoryName: String { category ?? "Other" }

    /// Components whose output depends on the pointer, a media source or a GPU compute program.
    var needsInteraction: Bool { descriptor?.flags.usesPointer ?? false }
    var descriptor: ShaderDescriptor? { ShaderRegistry.descriptor(name) }
}

extension ShaderRole {
    var title: String {
        switch self {
        case .generator: return "Generator"
        case .filter: return "Filter"
        case .warp: return "Warp"
        case .shape: return "Shape"
        case .shapeEffect: return "Shape Effect"
        case .simulation: return "Simulation"
        case .structural: return "Structural"
        case .media: return "Media"
        case .overlay: return "Overlay"
        }
    }

    var symbol: String {
        switch self {
        case .generator: return "sparkles"
        case .filter: return "camera.filters"
        case .warp: return "tornado"
        case .shape: return "star"
        case .shapeEffect: return "cube.transparent"
        case .simulation: return "atom"
        case .structural: return "square.stack.3d.up"
        case .media: return "photo"
        case .overlay: return "rectangle.on.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .generator: return Color(red: 0.69, green: 0.45, blue: 1.0)
        case .filter: return Color(red: 0.35, green: 0.62, blue: 1.0)
        case .warp: return Color(red: 1.0, green: 0.62, blue: 0.25)
        case .shape: return Color(red: 1.0, green: 0.42, blue: 0.62)
        case .shapeEffect: return Color(red: 0.25, green: 0.85, blue: 0.85)
        case .simulation: return Color(red: 0.35, green: 0.88, blue: 0.5)
        case .structural: return Color(red: 0.62, green: 0.66, blue: 0.75)
        case .media: return Color(red: 0.5, green: 0.5, blue: 1.0)
        case .overlay: return Color(red: 0.4, green: 0.9, blue: 0.75)
        }
    }

    /// Roles that wrap content (filters, warps, …) and can be nested around a layer.
    var wrapsContent: Bool {
        switch self {
        case .filter, .warp, .shapeEffect, .structural: return true
        default: return false
        }
    }
}
