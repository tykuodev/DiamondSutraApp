import SwiftUI

@main
struct DiamondSutraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Keep text/background colors consistent even when the system is in Dark Mode.
                .preferredColorScheme(.light)
        }
    }
}
