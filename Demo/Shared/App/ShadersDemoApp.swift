import SwiftUI
import ShadersKit

@main
struct ShadersDemoApp: App {
    @State private var model = AppModel()

    init() {
        MetalSupport.warmUp()
        AgentPrompt.printFromLaunchArguments()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.budget)
                .preferredColorScheme(model.launch.appearance)
                .task {
                    if model.launch.audit { await RenderAudit.run() }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 860)
        .commands { SectionCommands(model: model) }
        #endif
    }
}
