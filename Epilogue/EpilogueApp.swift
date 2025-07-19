import SwiftUI
import SwiftData

@main
struct EpilogueApp: App {
    @State private var modelContainer: ModelContainer?
    
    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .preferredColorScheme(.dark)
                    .modelContainer(container)
            } else {
                // Minimal launch screen while loading
                ZStack {
                    Color(red: 0.11, green: 0.105, blue: 0.102)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .scaleEffect(1.5)
                }
                .task {
                    await setupModelContainer()
                }
            }
        }
    }
    
    @MainActor
    private func setupModelContainer() async {
        let schema = Schema([
            ChatThread.self,
            ThreadedChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Failed to create ModelContainer: \(error)")
            // Create a basic container as fallback
            modelContainer = try? ModelContainer(for: schema)
        }
    }
}