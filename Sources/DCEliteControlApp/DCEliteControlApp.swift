import SwiftUI

@main
struct DCEliteControlApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("DC Elite Control") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Device") { model.refresh() }
                    .keyboardShortcut("r")
            }
        }
    }
}
