import SwiftUI

@main
struct EpilogueApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Force dark mode for the app
        }
    }
}