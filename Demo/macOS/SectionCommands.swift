import SwiftUI

/// Menu bar shortcuts: ⌘1 Gallery, ⌘2 Showcase, ⌘3 Playground.
struct SectionCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Gallery") { model.sidebarSelection = .all }
                .keyboardShortcut("1", modifiers: .command)
            Button("Showcase") { model.sidebarSelection = .showcase }
                .keyboardShortcut("2", modifiers: .command)
            Button("Playground") { model.sidebarSelection = .playground }
                .keyboardShortcut("3", modifiers: .command)
        }
    }
}
