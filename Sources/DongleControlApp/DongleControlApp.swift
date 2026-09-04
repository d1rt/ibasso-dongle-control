import DongleControlFeature
import SwiftUI

@main
struct DongleControlApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Dongle Control for iBasso") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Device") { model.manualRefresh() }
                    .keyboardShortcut("r")
                    .disabled(model.connectedProfile == nil)
            }
        }
    }
}
