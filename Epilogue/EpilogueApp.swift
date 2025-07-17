import SwiftUI
import SwiftData

@main
struct EpilogueApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatThread.self,
            ThreadedChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Force dark mode for the app
        }
        .modelContainer(sharedModelContainer)
    }
}