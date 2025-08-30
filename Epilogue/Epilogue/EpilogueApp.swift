import SwiftUI
import SwiftData
import UserNotifications

@main
struct EpilogueApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var showAPIKeySetup = false
    
    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .preferredColorScheme(.dark)
                    .modelContainer(container)
                    .runSwiftDataMigrations()
                    .onAppear {
                        // Initialize secure API key management
                        initializeAPIKey()
                        
                        // Clear command history on app launch to prevent artifacts
                        Task { @MainActor in
                            CommandHistoryManager.shared.clearHistory()
                        }
                        
                        // Request notification permissions
                        requestNotificationPermissions()
                    }
                    .sheet(isPresented: $showAPIKeySetup) {
                        APIConfigurationView()
                    }
            } else {
                // Minimal launch screen while loading
                ZStack {
                    DesignSystem.Colors.surfaceBackground
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .tint(DesignSystem.Colors.primaryAccent)
                        .scaleEffect(1.5)
                }
                .task {
                    await setupModelContainer()
                }
            }
        }
    }
    
    private func initializeAPIKey() {
        // Check if API key exists in Keychain
        if let apiKey = KeychainManager.shared.getPerplexityAPIKey() {
            // API key is available
            print("✅ API key loaded from secure storage")
        } else if KeychainManager.shared.needsAPIKeyConfiguration() {
            // Show setup sheet on first launch or if key is missing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showAPIKeySetup = true
            }
        }
        
        // Clean up any legacy storage
        KeychainManager.shared.removeLegacyAPIKeyStorage()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
        
        // Set the delegate to handle notification taps
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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