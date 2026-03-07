import SwiftUI

@main
struct IPA2CatalystApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 968, height: 528)
        }
        .defaultSize(width: 968, height: 528)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
