import SwiftUI
import Combine
import OSLog

// MARK: - Ambient Mode Type

/// Defines the two distinct ambient mode experiences
enum AmbientModeType: Equatable {
    /// Generic ambient mode - library-wide intelligence, recommendations, reading plans
    case generic
    /// Book-specific ambient mode - deep dive into a specific book
    case bookSpecific(Book)

    var isGeneric: Bool {
        if case .generic = self { return true }
        return false
    }

    var book: Book? {
        if case .bookSpecific(let book) = self { return book }
        return nil
    }
}

/// Enhanced coordinator for Epilogue ambient mode
@MainActor
public class EpilogueAmbientCoordinator: ObservableObject {
    static let shared = EpilogueAmbientCoordinator()

    @Published var isActive = false
    @Published var preSelectedBook: Book?
    @Published var initialBook: Book?  // Book to start with when launched from BookDetailView
    @Published var initialQuestion: String?  // Initial question to ask when launching
    @Published var existingSession: AmbientSession?  // Existing session to continue from
    @Published var ambientMode: AmbientModeType = .generic  // Track which mode we're in

    private init() {}

    func launch(from context: LaunchContext = .general, book: Book? = nil) {
        preSelectedBook = book
        initialBook = book  // Set initialBook so AmbientModeView can pick it up

        // Set ambient mode type based on book presence
        if let book = book {
            ambientMode = .bookSpecific(book)
        } else {
            ambientMode = .generic
        }

        Task {
            await prepareServices()
        }

        isActive = true

        // Use voiceModeStart instead of ambientModeStart
        HapticManager.shared.voiceModeStart()

        #if DEBUG
        print("🚀 Launching ambient mode from: \(context)")
        print("🎯 Mode: \(ambientMode.isGeneric ? "Generic" : "Book-Specific")")
        if let book = book {
            print("📚 With book: \(book.title)")
        }
        #endif
    }

    /// Launch generic ambient mode (no book context)
    func launchGenericMode(initialQuestion: String? = nil) {
        ambientMode = .generic
        preSelectedBook = nil
        initialBook = nil
        self.initialQuestion = initialQuestion

        Task {
            await prepareServices()
        }

        isActive = true
        HapticManager.shared.voiceModeStart()

        #if DEBUG
        print("🚀 Launching GENERIC ambient mode")
        if let question = initialQuestion {
            print("❓ Initial question: \(question)")
        }
        #endif
    }

    /// Launch book-specific ambient mode
    func launchBookMode(book: Book, initialQuestion: String? = nil) {
        ambientMode = .bookSpecific(book)
        preSelectedBook = book
        initialBook = book
        self.initialQuestion = initialQuestion

        Task {
            await prepareServices()
        }

        isActive = true
        HapticManager.shared.voiceModeStart()

        #if DEBUG
        print("🚀 Launching BOOK-SPECIFIC ambient mode")
        print("📚 Book: \(book.title)")
        #endif
    }

    func dismiss() {
        isActive = false
        preSelectedBook = nil
        initialBook = nil
        ambientMode = .generic
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
        case commandPalette  // New: launched from command palette
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
    @Published var existingSession: AmbientSession?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.epilogue.app", category: "SimplifiedAmbient")
    
    // MARK: - Initialization
    
    private init() {
        logger.info("SimplifiedAmbientCoordinator initialized")
    }
    
    // MARK: - Public Methods
    
    /// Open ambient reading - optionally with a pre-selected book, initial question, or existing session
    func openAmbientReading(with book: Book? = nil, initialQuestion: String? = nil, existingSession: AmbientSession? = nil) {
        logger.info("🎙️ Opening ambient reading via SimplifiedAmbientCoordinator")
        #if DEBUG
        print("🎙️ DEBUG: SimplifiedAmbientCoordinator.openAmbientReading() called")
        #endif

        // Set initial book context if provided
        if let book = book {
            currentBook = book
            // CRITICAL: Also set in AmbientBookDetector to establish session lock
            // This prevents unwanted book switching during the session
            AmbientBookDetector.shared.setCurrentBook(book)
            logger.info("📚 Starting ambient mode with book: \(book.title)")
        }

        if let question = initialQuestion {
            logger.info("❓ Starting with question: \(question)")
        }

        // Store existing session for context continuation
        if let session = existingSession {
            self.existingSession = session
            logger.info("📖 Continuing from previous session with \((session.capturedQuestions ?? []).count) questions")
        }

        // Haptic feedback
        HapticManager.shared.voiceModeStart()

        // Use EpilogueAmbientCoordinator which ContentView observes
        // This will present the NEW AmbientModeView
        withAnimation(DesignSystem.Animation.springStandard) {
            EpilogueAmbientCoordinator.shared.isActive = true
            EpilogueAmbientCoordinator.shared.initialBook = book
            EpilogueAmbientCoordinator.shared.initialQuestion = initialQuestion
            EpilogueAmbientCoordinator.shared.existingSession = existingSession
            #if DEBUG
            print("🎙️ DEBUG: isPresented set to true, initial book: \(book?.title ?? "none")")
            #endif
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
            self.existingSession = nil
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