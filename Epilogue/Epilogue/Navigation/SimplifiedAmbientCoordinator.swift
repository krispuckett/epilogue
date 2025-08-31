import SwiftUI
import Combine
import OSLog

/// Enhanced coordinator for Epilogue ambient mode
@MainActor
public class EpilogueAmbientCoordinator: ObservableObject {
    static let shared = EpilogueAmbientCoordinator()
    
    @Published var isActive = false
    @Published var preSelectedBook: Book?
    @Published var initialBook: Book?  // Book to start with when launched from BookDetailView
    
    private init() {}
    
    func launch(from context: LaunchContext = .general, book: Book? = nil) {
        preSelectedBook = book
        
        Task {
            await prepareServices()
        }
        
        isActive = true
        
        // Use voiceModeStart instead of ambientModeStart
        HapticManager.shared.voiceModeStart()
        
        print("🚀 Launching ambient mode from: \(context)")
    }
    
    func dismiss() {
        isActive = false
        preSelectedBook = nil
    }
    
    private func prepareServices() async {
        // Comment out AppleIntelligenceCore until it's implemented
        // await AppleIntelligenceCore.shared.warmUp()
        
        // Comment out VoiceRecognitionManager until it's properly configured
        // if !VoiceRecognitionManager.shared.isInitialized {
        //     await VoiceRecognitionManager.shared.initialize()
        // }
        
        // For now, just add a small delay to simulate preparation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    enum LaunchContext {
        case quickActions
        case bookDetail
        case library
        case general
    }
}

/// Simplified coordinator for ambient reading mode - voice-first, no book pre-selection
@MainActor
final class SimplifiedAmbientCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SimplifiedAmbientCoordinator()
    
    // MARK: - Published State
    
    @Published var isPresented = false
    @Published var currentBook: Book?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.epilogue.app", category: "SimplifiedAmbient")
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SimplifiedAmbientCoordinator initialized")
    }
    
    // MARK: - Public Methods
    
    /// Open ambient reading - optionally with a pre-selected book
    func openAmbientReading(with book: Book? = nil) {
        logger.info("🎙️ Opening ambient reading via SimplifiedAmbientCoordinator")
        print("🎙️ DEBUG: SimplifiedAmbientCoordinator.openAmbientReading() called")
        
        // Set initial book context if provided
        if let book = book {
            currentBook = book
            logger.info("📚 Starting ambient mode with book: \(book.title)")
        }
        
        // Haptic feedback
        HapticManager.shared.voiceModeStart()
        
        // Use EpilogueAmbientCoordinator which ContentView observes
        // This will present the NEW AmbientModeView
        withAnimation(DesignSystem.Animation.springStandard) {
            EpilogueAmbientCoordinator.shared.isActive = true
            EpilogueAmbientCoordinator.shared.initialBook = book
            print("🎙️ DEBUG: isPresented set to true, initial book: \(book?.title ?? "none")")
        }
    }
    
    /// Close ambient reading
    func closeAmbientReading() {
        logger.info("Closing ambient reading")
        
        // Light haptic feedback
        SensoryFeedback.light()
        
        // Dismiss
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isPresented = false
        }
        
        // Clear state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentBook = nil
        }
    }
    
    /// Update book context when detected from speech
    func setBookContext(_ book: Book) {
        logger.info("Book context detected: \(book.title)")
        
        currentBook = book
        
        // Light haptic for confirmation
        SensoryFeedback.light()
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: Notification.Name("AmbientBookDetected"),
            object: book
        )
    }
    
    /// Clear book context
    func clearBookContext() {
        logger.info("Clearing book context")
        
        currentBook = nil
        
        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("AmbientBookCleared"),
            object: nil
        )
    }
}

// MARK: - View Extension for Presentation

extension View {
    func simplifiedAmbientPresentation() -> some View {
        modifier(SimplifiedAmbientPresentationModifier())
    }
}

struct SimplifiedAmbientPresentationModifier: ViewModifier {
    @ObservedObject var coordinator = SimplifiedAmbientCoordinator.shared
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @AppStorage("useNewAmbientMode") private var useNewAmbient = true
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coordinator.isPresented) {
                // Use UnifiedChatView in ambient mode for beautiful gradient interface
                UnifiedChatView(
                    preSelectedBook: coordinator.currentBook,
                    startInVoiceMode: true,
                    isAmbientMode: true
                )
                .environmentObject(libraryViewModel)
                .environmentObject(notesViewModel)
                .environmentObject(NavigationCoordinator.shared)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onAppear {
                    print("🎨 UNIFIED CHAT: Beautiful gradient ambient mode active!")
                    print("🎨 Voice-responsive gradients with book context")
                }
            }
    }
}