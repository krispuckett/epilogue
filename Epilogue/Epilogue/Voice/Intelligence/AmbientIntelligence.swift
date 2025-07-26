import Foundation
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientIntelligence")

// MARK: - Intelligence Response
struct IntelligenceResponse {
    let reaction: DetectedReaction
    let suggestion: String
    let action: IntelligenceAction
    let confidence: Float
    let visualHint: VisualHint
}

enum IntelligenceAction {
    case offer(String) // Offer assistance with specific prompt
    case search(String) // Search for related content
    case explain(String) // Explain a concept
    case connect(String) // Show connections to other ideas
    case clarify(String) // Clarify confusion
    case expand(String) // Expand on a topic
    case wait // Just acknowledge, don't act
}

struct VisualHint {
    let color: String
    let animation: AnimationType
    let intensity: Float
    
    enum AnimationType {
        case pulse
        case ripple
        case sparkle
        case glow
        case swirl
    }
}

// MARK: - Reading Context
struct ReadingContext {
    var currentBook: String?
    var currentChapter: String?
    var recentTopics: [String] = []
    var readingDuration: TimeInterval = 0
    var lastInteractionTime: Date?
    var genre: String?
    var userMood: UserMood = .neutral
    
    enum UserMood {
        case engaged
        case confused
        case excited
        case contemplative
        case neutral
    }
}

// MARK: - Ambient Intelligence System
@MainActor
class AmbientIntelligence: ObservableObject {
    @Published var isActive = false
    @Published var currentContext = ReadingContext()
    @Published var lastResponse: IntelligenceResponse?
    @Published var suggestionHistory: [IntelligenceResponse] = []
    @Published var privacyMode = false
    @Published var autoStopTimer: Timer?
    
    // Components
    private let voiceManager = VoiceRecognitionManager()
    private let reactionDetector = NaturalReactionDetector()
    private var cancellables = Set<AnyCancellable>()
    
    // Settings
    @Published var sensitivity: Float = 0.7
    @Published var responseDelay: TimeInterval = 2.0 // Wait before offering help
    @Published var autoStopDuration: TimeInterval = 300 // 5 minutes of inactivity
    
    // Reaction tracking
    private var reactionBuffer: [DetectedReaction] = []
    private let maxBufferSize = 10
    private var responseTimer: Timer?
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func activate(context: ReadingContext? = nil) {
        isActive = true
        
        if let context = context {
            currentContext = context
            reactionDetector.adjustSensitivity(for: context.genre ?? "general")
        }
        
        voiceManager.startAmbientListening()
        resetAutoStopTimer()
        
        logger.info("Ambient Intelligence activated")
        
        NotificationCenter.default.post(
            name: Notification.Name("AmbientIntelligenceActivated"),
            object: nil
        )
    }
    
    func deactivate() {
        isActive = false
        voiceManager.stopListening()
        autoStopTimer?.invalidate()
        responseTimer?.invalidate()
        
        logger.info("Ambient Intelligence deactivated")
        
        NotificationCenter.default.post(
            name: Notification.Name("AmbientIntelligenceDeactivated"),
            object: nil
        )
    }
    
    func updateContext(book: String? = nil, chapter: String? = nil, genre: String? = nil) {
        if let book = book {
            currentContext.currentBook = book
        }
        if let chapter = chapter {
            currentContext.currentChapter = chapter
        }
        if let genre = genre {
            currentContext.genre = genre
            reactionDetector.adjustSensitivity(for: genre)
        }
    }
    
    func processUserInput(_ input: String) async {
        // Manual input processing for testing
        if let reaction = await reactionDetector.detectReaction(from: input) {
            await handleDetectedReaction(reaction)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Listen for natural reactions from voice recognition
        NotificationCenter.default.publisher(for: Notification.Name("NaturalReactionDetected"))
            .compactMap { $0.object as? String }
            .sink { [weak self] utterance in
                Task {
                    await self?.processNaturalReaction(utterance)
                }
            }
            .store(in: &cancellables)
        
        // Monitor voice activity
        voiceManager.$recognitionState
            .sink { [weak self] state in
                if state == .listening {
                    self?.resetAutoStopTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    private func processNaturalReaction(_ utterance: String) async {
        guard isActive else { return }
        
        // Skip very short utterances to avoid processing partial words
        guard utterance.split(separator: " ").count >= 3 else {
            logger.debug("Skipping short utterance: \(utterance)")
            return
        }
        
        // Detect reaction type
        guard let reaction = await reactionDetector.detectReaction(from: utterance) else {
            return
        }
        
        await handleDetectedReaction(reaction)
    }
    
    private func handleDetectedReaction(_ reaction: DetectedReaction) async {
        // Add to buffer
        reactionBuffer.append(reaction)
        if reactionBuffer.count > maxBufferSize {
            reactionBuffer.removeFirst()
        }
        
        // Update user mood based on reactions
        updateUserMood()
        
        // Cancel existing timer
        responseTimer?.invalidate()
        
        // Determine if we should respond
        let shouldRespond = await shouldRespondToReaction(reaction)
        
        if shouldRespond {
            // Wait before responding to avoid being too eager
            responseTimer = Timer.scheduledTimer(withTimeInterval: responseDelay, repeats: false) { [weak self] _ in
                Task {
                    await self?.generateResponse(for: reaction)
                }
            }
        } else {
            // Just acknowledge with visual feedback
            provideVisualFeedback(for: reaction)
        }
        
        resetAutoStopTimer()
    }
    
    private func shouldRespondToReaction(_ reaction: DetectedReaction) async -> Bool {
        // Don't respond too frequently
        if let lastResponse = lastResponse,
           Date().timeIntervalSince(lastResponse.reaction.timestamp) < 30 {
            return false
        }
        
        // Always respond to confusion or explicit questions
        if reaction.type == .confusion || reaction.utterance.contains("?") {
            return true
        }
        
        // Respond to strong reactions
        if reaction.confidence > 0.85 {
            return true
        }
        
        // Check reaction patterns
        let recentReactions = reactionBuffer.suffix(3)
        let confusionCount = recentReactions.filter { $0.type == .confusion }.count
        if confusionCount >= 2 {
            return true
        }
        
        // Context-aware decisions
        if currentContext.userMood == .confused && reaction.sentiment < 0 {
            return true
        }
        
        return false
    }
    
    private func generateResponse(for reaction: DetectedReaction) async {
        let action = determineAction(for: reaction)
        let suggestion = generateSuggestion(for: reaction, action: action)
        let visualHint = generateVisualHint(for: reaction)
        
        let response = IntelligenceResponse(
            reaction: reaction,
            suggestion: suggestion,
            action: action,
            confidence: reaction.confidence,
            visualHint: visualHint
        )
        
        lastResponse = response
        suggestionHistory.append(response)
        
        // Maintain history size
        if suggestionHistory.count > 50 {
            suggestionHistory.removeFirst()
        }
        
        // Post notification for UI
        NotificationCenter.default.post(
            name: Notification.Name("IntelligenceResponseReady"),
            object: response
        )
        
        logger.info("Generated response for \(reaction.type.rawValue): \(suggestion)")
    }
    
    private func determineAction(for reaction: DetectedReaction) -> IntelligenceAction {
        switch reaction.type {
        case .confusion:
            return .clarify("Would you like me to explain this concept?")
        case .wonder:
            return .expand("I can explore this idea further if you'd like")
        case .discovery:
            return .connect("This connects to several other concepts")
        case .excitement:
            return .search("Let me find similar fascinating content")
        case .connection:
            return .expand("I see the connection you're making")
        case .reflection:
            return .wait
        case .disagreement:
            return .offer("Would you like to discuss this perspective?")
        case .surprise:
            return .explain("This is indeed surprising because...")
        case .understanding:
            return .wait
        case .agreement:
            return .wait
        }
    }
    
    private func generateSuggestion(for reaction: DetectedReaction, action: IntelligenceAction) -> String {
        // Context-aware suggestion generation
        let bookContext = currentContext.currentBook ?? "this content"
        
        switch (reaction.type, action) {
        case (.confusion, .clarify):
            return "I noticed you might be confused about this part. Would you like me to break it down?"
        case (.wonder, .expand):
            let topic = extractTopic(from: reaction.utterance)
            return "Your curiosity about \(topic) is interesting. There's more to explore here."
        case (.discovery, .connect):
            return "Great insight! This connects to ideas you've encountered before."
        case (.excitement, .search):
            return "You seem excited about this! I can find similar passages in \(bookContext)."
        default:
            return "I'm here if you'd like to explore this further."
        }
    }
    
    private func generateVisualHint(for reaction: DetectedReaction) -> VisualHint {
        let animation: VisualHint.AnimationType
        let intensity: Float
        
        switch reaction.type {
        case .excitement:
            animation = .sparkle
            intensity = 0.9
        case .confusion:
            animation = .swirl
            intensity = 0.7
        case .discovery:
            animation = .ripple
            intensity = 0.8
        case .wonder:
            animation = .pulse
            intensity = 0.6
        case .connection:
            animation = .glow
            intensity = 0.7
        default:
            animation = .pulse
            intensity = 0.5
        }
        
        return VisualHint(
            color: reaction.type.color,
            animation: animation,
            intensity: intensity * reaction.confidence
        )
    }
    
    private func provideVisualFeedback(for reaction: DetectedReaction) {
        let visualHint = generateVisualHint(for: reaction)
        
        NotificationCenter.default.post(
            name: Notification.Name("VisualFeedbackRequested"),
            object: visualHint
        )
    }
    
    private func updateUserMood() {
        let recentReactions = reactionBuffer.suffix(5)
        
        let excitementCount = recentReactions.filter { $0.type == .excitement }.count
        let confusionCount = recentReactions.filter { $0.type == .confusion }.count
        let wonderCount = recentReactions.filter { $0.type == .wonder }.count
        
        if confusionCount >= 3 {
            currentContext.userMood = .confused
        } else if excitementCount >= 2 {
            currentContext.userMood = .excited
        } else if wonderCount >= 2 {
            currentContext.userMood = .contemplative
        } else if !recentReactions.isEmpty {
            currentContext.userMood = .engaged
        } else {
            currentContext.userMood = .neutral
        }
    }
    
    private func extractTopic(from utterance: String) -> String {
        // Simple topic extraction - could be enhanced with NLP
        let words = utterance.split(separator: " ")
        if let aboutIndex = words.firstIndex(of: "about"),
           aboutIndex < words.count - 1 {
            return String(words[aboutIndex + 1])
        }
        return "this concept"
    }
    
    private func resetAutoStopTimer() {
        autoStopTimer?.invalidate()
        autoStopTimer = Timer.scheduledTimer(withTimeInterval: autoStopDuration, repeats: false) { [weak self] _ in
            logger.info("Auto-stopping due to inactivity")
            self?.deactivate()
        }
    }
}

// MARK: - Privacy Extensions
extension AmbientIntelligence {
    func enablePrivacyMode() {
        privacyMode = true
        // Reduce sensitivity and disable certain features
        sensitivity = 0.9
        responseDelay = 5.0
        
        logger.info("Privacy mode enabled")
    }
    
    func disablePrivacyMode() {
        privacyMode = false
        sensitivity = 0.7
        responseDelay = 2.0
        
        logger.info("Privacy mode disabled")
    }
}

// MARK: - Learning System
extension AmbientIntelligence {
    func learnFromSession() {
        let trends = reactionDetector.getReactionTrends()
        
        // Analyze patterns and adjust behavior
        if let dominantReaction = trends.max(by: { $0.value < $1.value }) {
            logger.info("Dominant reaction type: \(dominantReaction.key.rawValue) (\(dominantReaction.value) occurrences)")
            
            // Adjust sensitivity based on patterns
            if dominantReaction.key == .confusion && dominantReaction.value > 5 {
                sensitivity = max(0.5, sensitivity - 0.1)
                logger.info("Lowering sensitivity due to frequent confusion")
            }
        }
        
        // Store session data for future learning
        let sessionSummary = [
            "duration": currentContext.readingDuration,
            "reactionCount": reactionBuffer.count,
            "dominantMood": currentContext.userMood
        ] as [String : Any]
        
        UserDefaults.standard.set(sessionSummary, forKey: "lastReadingSession")
    }
}