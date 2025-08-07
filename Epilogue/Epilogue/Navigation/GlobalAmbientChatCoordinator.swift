import SwiftUI
import AVFoundation
import OSLog
import Combine

/// Global coordinator for ambient chat functionality across the app
@MainActor
final class GlobalAmbientChatCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = GlobalAmbientChatCoordinator()
    
    // MARK: - Published State
    
    @Published var isPresented = false
    @Published var currentBookContext: Book?
    @Published var isVoiceMode = false
    @Published var sessionActive = false
    @Published var isPaused = false
    
    // MARK: - Private State
    
    private var preSelectedBook: Book?
    private var initialMessage: String?
    private var sessionStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let voiceManager = VoiceRecognitionManager.shared
    private let hapticManager = HapticManager.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "com.epilogue.app", category: "GlobalAmbientChat")
    
    // Session state
    private var lastCapturedItem: String?
    private var sessionTranscripts: [String] = []
    
    // User defaults keys
    private let lastBookContextKey = "GlobalAmbientChat.lastBookContext"
    private let sessionPreferencesKey = "GlobalAmbientChat.preferences"
    private let interruptedSessionKey = "GlobalAmbientChat.interruptedSession"
    
    // MARK: - Initialization
    
    private init() {
        // DISABLED: setupVoiceCommandListener() - Using SimplifiedAmbientCoordinator instead
        restoreSessionState()
        setupNotificationObservers()
        
        logger.info("GlobalAmbientChatCoordinator initialized (voice commands disabled)")
    }
    
    // MARK: - Public API
    
    /// Present ambient chat with optional configuration
    func presentAmbientChat(
        preSelectedBook: Book? = nil,
        startInVoiceMode: Bool = false,
        initialMessage: String? = nil
    ) {
        logger.info("Presenting ambient chat - Book: \(preSelectedBook?.title ?? "none"), Voice: \(startInVoiceMode)")
        
        self.preSelectedBook = preSelectedBook ?? loadLastBookContext()
        self.initialMessage = initialMessage
        self.isVoiceMode = startInVoiceMode
        
        // Set current book context
        if let book = self.preSelectedBook {
            currentBookContext = book
            saveLastBookContext(book)
        }
        
        // Haptic feedback
        hapticManager.commandPaletteOpen()
        
        // Present with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = true
        }
        
        // Start voice mode if requested
        if startInVoiceMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startVoiceMode()
            }
        }
        
        // Start session
        startSession()
    }
    
    /// Dismiss ambient chat
    func dismissAmbientChat(animated: Bool = true) {
        logger.info("Dismissing ambient chat")
        
        // Stop voice if active
        if isVoiceMode {
            stopVoiceMode()
        }
        
        // Save session state
        saveSessionState()
        
        // Haptic feedback
        hapticManager.lightTap()
        
        // Dismiss with animation
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                isPresented = false
            }
        } else {
            isPresented = false
        }
        
        // Clear temporary state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.resetTemporaryState()
        }
    }
    
    /// Switch to a different book context
    func switchToBook(_ book: Book) {
        logger.info("Switching to book: \(book.title)")
        
        currentBookContext = book
        saveLastBookContext(book)
        
        // Haptic feedback
        hapticManager.bookOpen()
        
        // Post notification for UI update
        NotificationCenter.default.post(
            name: Notification.Name("AmbientChatBookChanged"),
            object: book
        )
        
        // Visual confirmation
        showToast("Switched to \(book.title)")
    }
    
    // MARK: - Voice Mode Management
    
    func startVoiceMode() {
        guard !isVoiceMode else { return }
        
        logger.info("Starting voice mode")
        isVoiceMode = true
        isPaused = false
        
        voiceManager.startAmbientListening()
        hapticManager.voiceModeStart()
        
        // Audio feedback
        playSystemSound(.beginRecording)
    }
    
    func stopVoiceMode() {
        guard isVoiceMode else { return }
        
        logger.info("Stopping voice mode")
        isVoiceMode = false
        
        voiceManager.stopListening()
        hapticManager.lightTap()  // Changed from voiceModeEnd() which doesn't exist
        
        // Audio feedback
        playSystemSound(.endRecording)
    }
    
    func pauseVoiceMode() {
        guard isVoiceMode && !isPaused else { return }
        
        logger.info("Pausing voice mode")
        isPaused = true
        
        voiceManager.stopListening()
        hapticManager.lightTap()
        
        showToast("Voice paused")
    }
    
    func resumeVoiceMode() {
        guard isVoiceMode && isPaused else { return }
        
        logger.info("Resuming voice mode")
        isPaused = false
        
        voiceManager.startAmbientListening()
        hapticManager.lightTap()
        
        showToast("Voice resumed")
    }
    
    // MARK: - Voice Command Processing
    
    private func setupVoiceCommandListener() {
        // Listen to transcribed text from VoiceRecognitionManager
        voiceManager.$transcribedText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self, !text.isEmpty, self.isVoiceMode else { return }
                self.processVoiceCommand(text)
            }
            .store(in: &cancellables)
    }
    
    private func processVoiceCommand(_ text: String) {
        let lowercased = text.lowercased()
        
        logger.debug("Processing potential voice command: \(text)")
        
        // Book switching
        if lowercased.contains("switch to") || lowercased.contains("change to") {
            if let bookName = extractBookName(from: text) {
                findAndSwitchToBook(bookName)
            }
            return
        }
        
        // Voice control commands
        if lowercased.contains("stop listening") || lowercased == "pause" {
            pauseVoiceMode()
            return
        }
        
        if lowercased.contains("resume") || lowercased == "continue" {
            resumeVoiceMode()
            return
        }
        
        // Navigation commands
        if lowercased.contains("close chat") || lowercased == "exit" {
            dismissAmbientChat()
            return
        }
        
        if lowercased.contains("show my books") || lowercased.contains("book list") {
            showBookSelector()
            return
        }
        
        // Session commands
        if lowercased.contains("read back") || lowercased.contains("repeat") {
            readLastCapturedItem()
            return
        }
        
        if lowercased.contains("clear session") || lowercased.contains("start over") {
            clearSession()
            return
        }
        
        // Store as transcript if not a command
        if !isVoiceCommand(text) {
            self.sessionTranscripts.append(text)
            self.lastCapturedItem = text
        }
    }
    
    private func isVoiceCommand(_ text: String) -> Bool {
        let commandKeywords = [
            "switch to", "change to", "stop listening", "pause", "resume", 
            "continue", "close chat", "exit", "show my books", "book list",
            "read back", "repeat", "clear session", "start over"
        ]
        
        let lowercased = text.lowercased()
        return commandKeywords.contains { lowercased.contains($0) }
    }
    
    private func extractBookName(from text: String) -> String? {
        // Extract book name after "switch to" or "change to"
        let patterns = ["switch to ", "change to "]
        
        for pattern in patterns {
            if let range = text.lowercased().range(of: pattern) {
                let bookName = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !bookName.isEmpty {
                    return bookName
                }
            }
        }
        
        return nil
    }
    
    private func findAndSwitchToBook(_ searchTerm: String) {
        // Get books from LibraryViewModel
        let libraryViewModel = LibraryViewModel()
        let books = libraryViewModel.books
        
        // Find best match using fuzzy search
        let lowercasedSearch = searchTerm.lowercased()
        
        if let exactMatch = books.first(where: { 
            $0.title.lowercased() == lowercasedSearch 
        }) {
            switchToBook(exactMatch)
        } else if let partialMatch = books.first(where: { 
            $0.title.lowercased().contains(lowercasedSearch) 
        }) {
            switchToBook(partialMatch)
        } else {
            showToast("Book '\(searchTerm)' not found")
            hapticManager.warning()
        }
    }
    
    // MARK: - Actions
    
    private func showBookSelector() {
        logger.info("Showing book selector")
        
        // Post notification to show book grid
        NotificationCenter.default.post(
            name: Notification.Name("ShowAmbientBookSelector"),
            object: nil
        )
        
        hapticManager.lightTap()
        showToast("Select a book")
    }
    
    private func readLastCapturedItem() {
        guard let item = lastCapturedItem else {
            showToast("Nothing to read back")
            return
        }
        
        logger.info("Reading back last item")
        
        let utterance = AVSpeechUtterance(string: item)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        speechSynthesizer.speak(utterance)
        hapticManager.lightTap()
    }
    
    private func clearSession() {
        logger.info("Clearing session")
        
        sessionTranscripts.removeAll()
        lastCapturedItem = nil
        sessionStartTime = Date()
        
        hapticManager.success()
        showToast("Session cleared")
        
        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name("AmbientSessionCleared"),
            object: nil
        )
    }
    
    // MARK: - Session Management
    
    private func startSession() {
        sessionActive = true
        sessionStartTime = Date()
        
        logger.info("Session started")
        
        // Check for interrupted session
        if let interrupted = loadInterruptedSession() {
            restoreInterruptedSession(interrupted)
        }
    }
    
    private func saveSessionState() {
        guard sessionActive else { return }
        
        // Convert to properly serializable types
        let bookId = currentBookContext?.localId.uuidString ?? ""
        let startTime = sessionStartTime?.timeIntervalSince1970 ?? 0
        let lastItem = lastCapturedItem ?? ""
        
        // Create dictionary with proper types
        let sessionData: [String: Any] = [
            "bookId": bookId,
            "startTime": startTime,
            "transcripts": sessionTranscripts as NSArray,  // Explicitly cast to NSArray
            "lastItem": lastItem
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: sessionData, options: [])
            UserDefaults.standard.set(data, forKey: interruptedSessionKey)
            logger.info("Session state saved")
        } catch {
            logger.error("Failed to save session state: \(error.localizedDescription)")
        }
    }
    
    private func restoreSessionState() {
        // Restore last book context
        currentBookContext = loadLastBookContext()
        
        // Load preferences
        if let prefs = UserDefaults.standard.dictionary(forKey: sessionPreferencesKey) {
            isVoiceMode = prefs["voiceMode"] as? Bool ?? false
        }
    }
    
    private func loadInterruptedSession() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: interruptedSessionKey) else {
            return nil
        }
        
        do {
            let sessionData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return sessionData
        } catch {
            logger.error("Failed to load interrupted session: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func restoreInterruptedSession(_ data: [String: Any]) {
        sessionTranscripts = data["transcripts"] as? [String] ?? []
        lastCapturedItem = data["lastItem"] as? String
        
        if let timestamp = data["startTime"] as? TimeInterval {
            sessionStartTime = Date(timeIntervalSince1970: timestamp)
        }
        
        logger.info("Restored interrupted session with \(self.sessionTranscripts.count) transcripts")
        showToast("Session restored")
    }
    
    // MARK: - Persistence
    
    private func saveLastBookContext(_ book: Book) {
        let data = try? JSONEncoder().encode(book)
        UserDefaults.standard.set(data, forKey: lastBookContextKey)
    }
    
    private func loadLastBookContext() -> Book? {
        guard let data = UserDefaults.standard.data(forKey: lastBookContextKey),
              let book = try? JSONDecoder().decode(Book.self, from: data) else {
            return nil
        }
        return book
    }
    
    private func resetTemporaryState() {
        preSelectedBook = nil
        initialMessage = nil
        sessionTranscripts.removeAll()
        sessionActive = false
        
        // Clear interrupted session
        UserDefaults.standard.removeObject(forKey: interruptedSessionKey)
        UserDefaults.standard.synchronize()  // Force synchronization
    }
    
    // MARK: - Notifications
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.saveSessionState()
            }
            .store(in: &cancellables)
        
        // Listen for navigation requests
        NotificationCenter.default.publisher(for: Notification.Name("RequestAmbientChat"))
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] info in
                let book = info["book"] as? Book
                let voiceMode = info["voiceMode"] as? Bool ?? false
                let message = info["message"] as? String
                
                self?.presentAmbientChat(
                    preSelectedBook: book,
                    startInVoiceMode: voiceMode,
                    initialMessage: message
                )
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    
    private func showToast(_ message: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ShowGlassToast"),
            object: ["message": message]
        )
    }
    
    private func playSystemSound(_ sound: SystemSoundID) {
        AudioServicesPlaySystemSound(sound)
    }
}

// MARK: - System Sound Extensions

extension SystemSoundID {
    static let beginRecording: SystemSoundID = 1113
    static let endRecording: SystemSoundID = 1114
    static let success: SystemSoundID = 1054
    static let warning: SystemSoundID = 1053
}

// MARK: - View Extension for Presentation

extension View {
    func ambientChatPresentation() -> some View {
        @ObservedObject var coordinator = GlobalAmbientChatCoordinator.shared
        
        return self
            .fullScreenCover(isPresented: .init(
                get: { coordinator.isPresented },
                set: { coordinator.isPresented = $0 }
            )) {
                UnifiedChatView(
                    preSelectedBook: coordinator.currentBookContext,
                    startInVoiceMode: coordinator.isVoiceMode,
                    isAmbientMode: true  // This is ambient mode
                )
                .environmentObject(LibraryViewModel())
                .environmentObject(NotesViewModel())
                .environmentObject(NavigationCoordinator.shared)
                .preferredColorScheme(.dark)
                .statusBarHidden(coordinator.isVoiceMode)
            }
    }
}