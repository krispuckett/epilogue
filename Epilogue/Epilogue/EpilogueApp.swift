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
                    .onAppear {
                        // Clear command history on app launch to prevent artifacts
                        Task { @MainActor in
                            CommandHistoryManager.shared.clearHistory()
                        }
                    }
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
        // Clear image caches on app launch (temporary for debugging)
        DisplayedImageStore.clearAllCaches()
        
        let schema = Schema([
            // ChatThread.self,  // Removed - old chat system
            // ThreadedChatMessage.self,  // Removed - old chat system
            // ColorPaletteModel.self,  // Removed - no longer exists
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self
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