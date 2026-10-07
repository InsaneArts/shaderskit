import SwiftUI
import ShadersKit

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case gallery, showcase, playground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gallery: return "Gallery"
        case .showcase: return "Showcase"
        case .playground: return "Playground"
        }
    }

    var symbol: String {
        switch self {
        case .gallery: return "square.grid.2x2"
        case .showcase: return "sparkles.tv"
        case .playground: return "square.3.layers.3d"
        }
    }
}

struct ShaderRoute: Hashable {
    let name: String
}

/// Sidebar rows on iPad and macOS.
enum SidebarItem: Hashable {
    case all
    case category(String)
    case showcase
    case playground
}

/// App-wide navigation and shared models.
@Observable
final class AppModel {
    var section: AppSection = .gallery
    /// Category shown by the split-view gallery (nil = all).
    var category: String?
    var galleryPath: [ShaderRoute] = []
    /// Index of the showcase preset presented full screen, if any.
    var presentedPreset: Int?

    let playground = PlaygroundModel()
    let budget = LiveBudget(limit: DeviceClass.liveViewLimit)
    let launch = LaunchOptions()

    init() {
        if let section = launch.section { self.section = section }
        if let category = launch.category { self.category = category }
        if let name = launch.openShader, Catalog.entry(named: name) != nil {
            section = .gallery
            galleryPath = [ShaderRoute(name: name)]
        }
        presentedPreset = launch.presentPreset
        if launch.playgroundDemo { playground.load(ShowcasePresets.all[0]) }
    }

    var sidebarSelection: SidebarItem? {
        get {
            switch section {
            case .gallery: return category.map(SidebarItem.category) ?? .all
            case .showcase: return .showcase
            case .playground: return .playground
            }
        }
        set {
            switch newValue {
            case .all?: section = .gallery; category = nil; galleryPath = []
            case .category(let c)?: section = .gallery; category = c; galleryPath = []
            case .showcase?: section = .showcase
            case .playground?: section = .playground
            case nil: break
            }
        }
    }

    /// Opens a component in the playground as a new layer.
    func sendToPlayground(type: String, props: [String: PropValue], attributes: LayerAttributes, subject: Subject?) {
        playground.addLayer(type: type, props: props, attributes: attributes, subject: subject)
        section = .playground
    }
}

/// Launch arguments, used by screenshots and UI checks:
/// `-openShader LinearGradient`, `-section showcase`, `-category Textures`,
/// `-presentPreset 0`, `-playgroundDemo YES`, `-appearance light|dark`, `-audit YES`.
struct LaunchOptions {
    let openShader: String?
    let section: AppSection?
    let category: String?
    let presentPreset: Int?
    let playgroundDemo: Bool
    let appearance: ColorScheme?
    let audit: Bool

    init(defaults: UserDefaults = .standard) {
        openShader = defaults.string(forKey: "openShader")
        section = defaults.string(forKey: "section").flatMap(AppSection.init(rawValue:))
        category = defaults.string(forKey: "category")
        presentPreset = defaults.object(forKey: "presentPreset") == nil ? nil : defaults.integer(forKey: "presentPreset")
        playgroundDemo = defaults.bool(forKey: "playgroundDemo")
        switch defaults.string(forKey: "appearance") {
        case "light": appearance = .light
        case "dark": appearance = .dark
        default: appearance = nil
        }
        audit = defaults.bool(forKey: "audit")
    }
}
