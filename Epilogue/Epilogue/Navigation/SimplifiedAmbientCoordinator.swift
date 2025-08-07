import SwiftUI
import Combine
import OSLog

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
    
    /// Open ambient mode - always starts with voice
    func openAmbientMode() {
        logger.info("🎙️ Opening ambient mode via SimplifiedAmbientCoordinator")
        print("🎙️ DEBUG: SimplifiedAmbientCoordinator.openAmbientMode() called")
        print("🎙️ DEBUG: isPresented before = \(isPresented)")
        
        // Haptic feedback
        HapticManager.shared.voiceModeStart()
        
        // Present fullscreen
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = true
            print("🎙️ DEBUG: isPresented set to true")
        }
    }
    
    /// Close ambient mode
    func closeAmbientMode() {
        logger.info("Closing ambient mode")
        
        // Light haptic feedback
        HapticManager.shared.lightTap()
        
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
        HapticManager.shared.lightTap()
        
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
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coordinator.isPresented) {
                UnifiedChatView(
                    preSelectedBook: nil,  // Always start with no book
                    startInVoiceMode: true,  // Always start with voice
                    isAmbientMode: true
                )
                .environmentObject(LibraryViewModel())
                .environmentObject(NotesViewModel())
                .environmentObject(NavigationCoordinator.shared)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onAppear {
                    print("🚀 DEBUG: UnifiedChatView appeared in ambient mode")
                }
            }
    }
}