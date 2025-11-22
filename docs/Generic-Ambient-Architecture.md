# Generic Ambient Mode - Technical Architecture

## Architecture Overview

Generic Ambient Mode reuses 80% of the existing book-specific ambient infrastructure, with targeted additions for library-wide context management and mode switching.

### Design Principles

1. **Maximize Code Reuse** - Same UI, services, and models where possible
2. **Context as Configuration** - Mode switching is context injection, not separate code paths
3. **Shared State Management** - Single conversation memory system, partitioned by mode
4. **Progressive Enhancement** - V1 uses existing infrastructure, V2+ adds sophistication

---

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ContentView (Root)                           │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
    ┌───────▼────────┐        ┌─────────▼────────┐
    │  TabView       │        │ AmbientModeSheet  │
    │  Navigation    │        │   (Modal)         │
    └────────────────┘        └─────────┬─────────┘
                                        │
                              ┌─────────▼─────────┐
                              │ AmbientModeView    │
                              │  (Shared UI)       │
                              └─────────┬──────────┘
                                        │
                    ┌───────────────────┼──────────────────┐
                    │                   │                  │
          ┌─────────▼──────┐  ┌─────────▼────────┐ ┌──────▼─────────┐
          │ Mode Selector  │  │  Chat Interface   │ │ Voice Input    │
          │  Component     │  │ (UnifiedChatView) │ │ (Shared)       │
          └─────────┬──────┘  └─────────┬─────────┘ └──────┬─────────┘
                    │                   │                  │
                    └───────────────────┼──────────────────┘
                                        │
                              ┌─────────▼──────────┐
                              │ AmbientCoordinator │
                              │   (Mode Router)    │
                              └─────────┬──────────┘
                                        │
                ┌───────────────────────┴───────────────────────┐
                │                                               │
      ┌─────────▼────────────┐                    ┌────────────▼──────────┐
      │ GenericContextManager│                    │ BookContextManager    │
      │  (NEW)               │                    │  (Existing)           │
      │                      │                    │                       │
      │ - Library data       │                    │ - Current book        │
      │ - Reading patterns   │                    │ - Page/chapter        │
      │ - Taste profile      │                    │ - Book enrichment     │
      │ - Cross-book themes  │                    │ - Reading progress    │
      └─────────┬────────────┘                    └────────────┬──────────┘
                │                                               │
                └───────────────────┬───────────────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │  ConversationMemory │
                          │   (Shared Service)  │
                          └─────────┬───────────┘
                                    │
                          ┌─────────▼──────────┐
                          │  AICompanionService │
                          │   (Shared Service)  │
                          └─────────────────────┘
```

---

## File Structure

### New Files (V1)

```
Epilogue/
├── Services/
│   └── Ambient/
│       ├── GenericAmbientContextManager.swift    [NEW]
│       └── AmbientModeType.swift                 [NEW]
│
├── Navigation/
│   └── UnifiedAmbientCoordinator.swift           [MODIFIED]
│
├── Views/
│   ├── Ambient/
│   │   ├── AmbientModeView.swift                 [MODIFIED]
│   │   └── Components/
│   │       └── AmbientModeSelector.swift         [NEW]
│   │
│   └── Components/
│       └── GenericAmbientBackground.swift        [NEW]
│
└── Models/
    └── AmbientMode.swift                         [MODIFIED]
```

### Modified Files (V1)

- `Services/Ambient/ConversationMemory.swift` - Add thread partitioning
- `Services/AICompanionService.swift` - Add generic system prompt
- `Views/Chat/UnifiedChatView.swift` - Add mode switcher integration
- `Models/AmbientSession.swift` - Support generic sessions

---

## Core Components

### 1. AmbientModeType (New)

**Purpose:** Enum defining ambient mode states

**File:** `Epilogue/Models/AmbientMode.swift`

```swift
import Foundation
import SwiftData

/// Represents the type of ambient conversation mode
enum AmbientModeType: Codable, Hashable {
    /// Generic reading companion (no specific book context)
    case generic

    /// Book-specific discussion (with book context)
    case bookSpecific(bookID: PersistentIdentifier, currentPage: Int?)

    /// Not in ambient mode
    case inactive

    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        default:
            return true
        }
    }

    var bookID: PersistentIdentifier? {
        switch self {
        case .bookSpecific(let id, _):
            return id
        default:
            return nil
        }
    }

    var isGeneric: Bool {
        if case .generic = self {
            return true
        }
        return false
    }

    /// Thread identifier for conversation memory
    var threadID: String {
        switch self {
        case .generic:
            return "generic-ambient"
        case .bookSpecific(let bookID, _):
            return "book-\(bookID.hashValue)"
        case .inactive:
            return "inactive"
        }
    }
}
```

---

### 2. GenericAmbientContextManager (New)

**Purpose:** Builds context for generic conversations based on user's library, reading history, and patterns

**File:** `Epilogue/Services/Ambient/GenericAmbientContextManager.swift`

```swift
import Foundation
import SwiftData

/// Builds rich context for generic ambient conversations
@MainActor
class GenericAmbientContextManager: ObservableObject {
    private let modelContext: ModelContext
    private let libraryService: LibraryService
    private let sessionIntelligence: SessionIntelligence
    private let tasteAnalyzer: LibraryTasteAnalyzer
    private let conversationMemory: ConversationMemory

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        libraryService: LibraryService,
        sessionIntelligence: SessionIntelligence,
        tasteAnalyzer: LibraryTasteAnalyzer,
        conversationMemory: ConversationMemory
    ) {
        self.modelContext = modelContext
        self.libraryService = libraryService
        self.sessionIntelligence = sessionIntelligence
        self.tasteAnalyzer = tasteAnalyzer
        self.conversationMemory = conversationMemory
    }

    // MARK: - Context Building

    /// Build context for a generic ambient message
    func buildContext(for message: String, conversationHistory: [ConversationMessage]) async -> String {
        let intent = detectIntent(message)

        var contextParts: [String] = []

        // Always include: Recent conversation
        contextParts.append(formatConversationHistory(conversationHistory))

        // Always include: Current reading state
        if let currentReading = getCurrentReadingSnapshot() {
            contextParts.append(currentReading)
        }

        // Always include: Recently finished books
        if let recentFinished = getRecentlyFinished(limit: 3) {
            contextParts.append(recentFinished)
        }

        // Conditional context based on intent
        switch intent {
        case .recommendation:
            if let taste = await buildTasteContext() {
                contextParts.append(taste)
            }

        case .habitAnalysis:
            if let patterns = await buildPatternContext() {
                contextParts.append(patterns)
            }

        case .bookDiscussion(let bookTitle):
            if let bookContext = await buildBookDiscussionContext(bookTitle: bookTitle) {
                contextParts.append(bookContext)
            }

        case .thematicExploration(let theme):
            if let themeContext = await buildThemeContext(theme: theme) {
                contextParts.append(themeContext)
            }

        case .statsQuery:
            if let stats = await buildStatsContext() {
                contextParts.append(stats)
            }

        case .general:
            if let overview = buildLibraryOverview() {
                contextParts.append(overview)
            }
        }

        return contextParts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Intent Detection

    private enum MessageIntent {
        case recommendation
        case habitAnalysis
        case bookDiscussion(bookTitle: String)
        case thematicExploration(theme: String)
        case statsQuery
        case general
    }

    private func detectIntent(_ message: String) -> MessageIntent {
        let lower = message.lowercased()

        // Recommendation keywords
        if lower.contains("recommend") || lower.contains("what should i read") ||
           lower.contains("next book") || lower.contains("suggestion") {
            return .recommendation
        }

        // Habit/pattern keywords
        if lower.contains("habit") || lower.contains("pattern") ||
           lower.contains("consistently") || lower.contains("more often") ||
           lower.contains("why can't i") {
            return .habitAnalysis
        }

        // Stats keywords
        if lower.contains("stats") || lower.contains("statistics") ||
           lower.contains("how many") || lower.contains("show me my") ||
           lower.contains("reading year") {
            return .statsQuery
        }

        // Theme exploration keywords
        let themeKeywords = ["theme", "across my reading", "connections between"]
        if themeKeywords.contains(where: { lower.contains($0) }) {
            // Extract theme if possible
            return .thematicExploration(theme: message)
        }

        // Book title detection
        if let bookTitle = detectBookMention(in: message) {
            return .bookDiscussion(bookTitle: bookTitle)
        }

        return .general
    }

    private func detectBookMention(in message: String) -> String? {
        let allBooks = libraryService.allBooks()

        for book in allBooks {
            if message.localizedCaseInsensitiveContains(book.title) {
                return book.title
            }
        }

        return nil
    }

    // MARK: - Context Builders

    private func getCurrentReadingSnapshot() -> String? {
        let descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let recentSessions = try? modelContext.fetch(descriptor),
              let activeSession = recentSessions.first(where: { $0.endTime == nil }),
              let book = activeSession.book else {
            return nil
        }

        return """
        CURRENT READING:
        - Book: \(book.title) by \(book.author)
        - Current page: \(book.currentPage) of \(book.pageCount ?? 0)
        - Started: \(activeSession.startTime.formatted(.relative(presentation: .named)))
        """
    }

    private func getRecentlyFinished(limit: Int) -> String? {
        let finished = libraryService.allBooks()
            .filter { $0.readingStatus == .finished }
            .sorted { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) }
            .prefix(limit)

        guard !finished.isEmpty else { return nil }

        let bookList = finished.map { book in
            let daysAgo = Calendar.current.dateComponents([.day], from: book.dateFinished ?? .now, to: .now).day ?? 0
            return "- \(book.title) (\(daysAgo) days ago)"
        }.joined(separator: "\n")

        return """
        RECENTLY FINISHED:
        \(bookList)
        """
    }

    private func buildTasteContext() async -> String? {
        let profile = await tasteAnalyzer.analyzeTaste()

        return """
        READER TASTE PROFILE:
        - Top genres: \(profile.topGenres.prefix(3).map(\.name).joined(separator: ", "))
        - Favorite authors: \(profile.favoriteAuthors.prefix(3).joined(separator: ", "))
        - Reading level: \(profile.readingLevel.rawValue)
        - Preferred era: \(profile.preferredEra?.description ?? "varied")
        - Key themes: \(profile.topThemes.prefix(5).joined(separator: ", "))
        """
    }

    private func buildPatternContext() async -> String? {
        let patterns = await sessionIntelligence.getReadingPatterns()
        let analytics = await sessionIntelligence.getSessionAnalytics()

        return """
        READING PATTERNS:
        - Average session: \(analytics.averageSessionDuration) minutes
        - Reading pace: \(analytics.averagePagesPerDay) pages/day
        - Most active: \(patterns.preferredReadingTime)
        - Completion rate: \(patterns.completionRate)%
        - Current reading phase: \(patterns.readingPhase.rawValue)

        DROP-OFF PATTERNS:
        \(patterns.dropOffAnalysis)
        """
    }

    private func buildBookDiscussionContext(bookTitle: String) async -> String? {
        guard let book = libraryService.findBook(title: bookTitle) else {
            return nil
        }

        // Get captured content
        let quotes = book.quotes.map { "- \"\($0.text)\" (p. \($0.pageNumber ?? 0))" }
            .joined(separator: "\n")
        let notes = book.notes.map { "- \($0.content)" }
            .joined(separator: "\n")

        // Get session summaries
        let sessions = book.ambientSessions
            .sorted { $0.startTime > $1.startTime }
            .prefix(3)
        let sessionSummaries = sessions.map { session in
            "Session \(session.startTime.formatted(.dateTime.month().day())): \(session.insights?.summary ?? "")"
        }.joined(separator: "\n")

        return """
        BOOK CONTEXT: \(book.title)

        Status: \(book.readingStatus.rawValue)
        Current page: \(book.currentPage) of \(book.pageCount ?? 0)
        User rating: \(book.userRating > 0 ? "\(book.userRating) stars" : "Not rated")

        CAPTURED QUOTES:
        \(quotes.isEmpty ? "None" : quotes)

        NOTES:
        \(notes.isEmpty ? "None" : notes)

        AMBIENT SESSION INSIGHTS:
        \(sessionSummaries.isEmpty ? "None" : sessionSummaries)
        """
    }

    private func buildThemeContext(theme: String) async -> String? {
        let connections = await sessionIntelligence.findThematicConnections(theme: theme)

        let relatedBooks = connections.map { connection in
            "- \(connection.book.title): \(connection.relevance)"
        }.joined(separator: "\n")

        return """
        THEMATIC EXPLORATION: \(theme)

        RELATED BOOKS IN LIBRARY:
        \(relatedBooks)

        CROSS-BOOK INSIGHTS:
        \(connections.first?.sharedThemes.joined(separator: ", ") ?? "")
        """
    }

    private func buildStatsContext() async -> String? {
        let analytics = await sessionIntelligence.getFullAnalytics()

        return """
        READING STATISTICS (This Year):

        Volume:
        - Books finished: \(analytics.booksFinished)
        - Total pages: \(analytics.totalPages)
        - Average book length: \(analytics.averageBookLength) pages

        Pace:
        - Pages per day (active): \(analytics.pagesPerDay)
        - Average session duration: \(analytics.avgSessionDuration) min

        Engagement:
        - Highlights captured: \(analytics.totalHighlights)
        - Questions asked: \(analytics.totalQuestions)
        - Ambient sessions: \(analytics.ambientSessionCount)

        Growth:
        - Question complexity: \(analytics.questionComplexityTrend)% increase
        - Reading phase: \(analytics.currentPhase.rawValue)
        """
    }

    private func buildLibraryOverview() -> String? {
        let allBooks = libraryService.allBooks()
        let finished = allBooks.filter { $0.readingStatus == .finished }.count
        let inProgress = allBooks.filter { $0.readingStatus == .reading }.count
        let wantToRead = allBooks.filter { $0.readingStatus == .wantToRead }.count

        return """
        LIBRARY OVERVIEW:
        - Total books: \(allBooks.count)
        - Finished: \(finished)
        - Currently reading: \(inProgress)
        - Want to read: \(wantToRead)
        """
    }

    private func formatConversationHistory(_ messages: [ConversationMessage]) -> String {
        let recent = messages.suffix(10)
        let formatted = recent.map { msg in
            "\(msg.isUser ? "User" : "Assistant"): \(msg.content)"
        }.joined(separator: "\n")

        return """
        RECENT CONVERSATION:
        \(formatted)
        """
    }
}
```

---

### 3. UnifiedAmbientCoordinator (Modified)

**Purpose:** Route between generic and book-specific modes, manage conversation state

**File:** `Epilogue/Navigation/UnifiedAmbientCoordinator.swift`

```swift
import Foundation
import SwiftData
import SwiftUI

@MainActor
class UnifiedAmbientCoordinator: ObservableObject {
    // MARK: - Published State

    @Published var currentMode: AmbientModeType = .inactive
    @Published var isPresented: Bool = false
    @Published var conversationMessages: [ConversationMessage] = []

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let libraryService: LibraryService
    private let conversationMemory: ConversationMemory
    private let aiService: AICompanionService

    // Context managers
    private var genericContextManager: GenericAmbientContextManager
    private var bookContextManager: AmbientContextManager

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        libraryService: LibraryService,
        sessionIntelligence: SessionIntelligence,
        tasteAnalyzer: LibraryTasteAnalyzer
    ) {
        self.modelContext = modelContext
        self.libraryService = libraryService
        self.conversationMemory = ConversationMemory(modelContext: modelContext)
        self.aiService = AICompanionService.shared

        self.genericContextManager = GenericAmbientContextManager(
            modelContext: modelContext,
            libraryService: libraryService,
            sessionIntelligence: sessionIntelligence,
            tasteAnalyzer: tasteAnalyzer,
            conversationMemory: conversationMemory
        )

        self.bookContextManager = AmbientContextManager(
            modelContext: modelContext,
            libraryService: libraryService
        )
    }

    // MARK: - Mode Management

    func switchToGenericMode() {
        currentMode = .generic
        loadConversation(for: .generic)
    }

    func switchToBookMode(book: Book, currentPage: Int? = nil) {
        currentMode = .bookSpecific(bookID: book.persistentModelID, currentPage: currentPage)
        loadConversation(for: currentMode)
    }

    func endSession() {
        // Save conversation state
        saveConversation()

        // Reset
        currentMode = .inactive
        conversationMessages = []
        isPresented = false
    }

    // MARK: - Message Handling

    func sendMessage(_ message: String) async {
        // Add user message to UI
        let userMessage = ConversationMessage(
            id: UUID(),
            content: message,
            isUser: true,
            timestamp: Date()
        )
        conversationMessages.append(userMessage)

        // Build context based on current mode
        let context: String
        switch currentMode {
        case .generic:
            context = await genericContextManager.buildContext(
                for: message,
                conversationHistory: conversationMessages
            )

        case .bookSpecific(let bookID, let currentPage):
            guard let book = try? modelContext.existingObject(for: bookID) as? Book else {
                return
            }
            context = await bookContextManager.buildContext(
                for: message,
                book: book,
                currentPage: currentPage,
                conversationHistory: conversationMessages
            )

        case .inactive:
            return
        }

        // Get system prompt
        let systemPrompt = getSystemPrompt(for: currentMode)

        // Call AI service
        do {
            let response = try await aiService.processMessage(
                message: message,
                context: context,
                systemPrompt: systemPrompt,
                conversationHistory: conversationMessages
            )

            // Add assistant response to UI
            let assistantMessage = ConversationMessage(
                id: UUID(),
                content: response,
                isUser: false,
                timestamp: Date()
            )
            conversationMessages.append(assistantMessage)

            // Save to conversation memory
            conversationMemory.addMessage(
                threadID: currentMode.threadID,
                content: message,
                isUser: true
            )
            conversationMemory.addMessage(
                threadID: currentMode.threadID,
                content: response,
                isUser: false
            )

        } catch {
            print("Error processing message: \(error)")
        }
    }

    // MARK: - Conversation Persistence

    private func loadConversation(for mode: AmbientModeType) {
        conversationMessages = conversationMemory.getRecentMessages(
            threadID: mode.threadID,
            limit: 50
        )
    }

    private func saveConversation() {
        conversationMemory.saveThread(threadID: currentMode.threadID)
    }

    // MARK: - System Prompts

    private func getSystemPrompt(for mode: AmbientModeType) -> String {
        switch mode {
        case .generic:
            return """
            You are Epilogue's reading companion. You help users with their reading
            journey when they're not actively reading a specific book.

            Your purpose:
            - Give personalized book recommendations based on their library and patterns
            - Help them read more consistently by analyzing their habits
            - Guide reflection on books they've finished
            - Explore themes and connections across their reading
            - Provide insights about their reading patterns and growth

            Your boundaries:
            - ONLY discuss books, reading, and literary topics
            - Politely redirect off-topic questions back to reading
            - Suggest switching to book-specific mode for deep book discussions
            - Don't act as a general-purpose assistant

            Your personality:
            - Thoughtful and literary, not overly casual
            - Genuinely curious about their reading journey
            - Encouraging but not patronizing
            - Specific and personalized, using their actual data

            Remember past conversations and build on them naturally.
            """

        case .bookSpecific(_, _):
            return """
            You are Epilogue's reading companion for a specific book.

            You help readers engage deeply with this book while they read.

            [... existing book-specific prompt ...]
            """

        case .inactive:
            return ""
        }
    }
}

// MARK: - ConversationMessage Model

struct ConversationMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
}
```

---

### 4. AmbientModeSelector (New Component)

**Purpose:** UI component for switching between generic and book-specific modes

**File:** `Epilogue/Views/Ambient/Components/AmbientModeSelector.swift`

```swift
import SwiftUI
import SwiftData

struct AmbientModeSelector: View {
    @Binding var currentMode: AmbientModeType
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastRead, order: .reverse) private var allBooks: [Book]

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Current mode header (always visible)
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    modeIcon(for: currentMode)
                    Text(modeTitle(for: currentMode))
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(
                    currentMode.isGeneric
                        ? Color(hex: "#E8B65F").opacity(0.2)
                        : Color.blue.opacity(0.2)
                )
            }

            // Mode options (when expanded)
            if isExpanded {
                VStack(spacing: 1) {
                    // Generic mode option
                    if !currentMode.isGeneric {
                        modeSwitchButton(
                            icon: "text.bubble",
                            title: "Reading Companion",
                            subtitle: "General reading chat",
                            isSelected: false
                        ) {
                            switchToMode(.generic)
                        }
                    }

                    Divider()

                    // Book-specific mode options
                    ForEach(activeReadingBooks, id: \.persistentModelID) { book in
                        modeSwitchButton(
                            icon: "book",
                            title: book.title,
                            subtitle: "Page \(book.currentPage)",
                            isSelected: currentMode.bookID == book.persistentModelID
                        ) {
                            switchToMode(.bookSpecific(
                                bookID: book.persistentModelID,
                                currentPage: book.currentPage
                            ))
                        }
                    }
                }
                .background(Color(.systemBackground))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Helpers

    private var activeReadingBooks: [Book] {
        allBooks
            .filter { $0.readingStatus == .reading }
            .prefix(5)
            .compactMap { $0 }
    }

    private func modeIcon(for mode: AmbientModeType) -> some View {
        Group {
            switch mode {
            case .generic:
                Image(systemName: "text.bubble")
                    .foregroundColor(Color(hex: "#E8B65F"))
            case .bookSpecific(let bookID, _):
                if let book = try? modelContext.existingObject(for: bookID) as? Book {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                }
            case .inactive:
                Image(systemName: "moon.zzz")
                    .foregroundColor(.gray)
            }
        }
    }

    private func modeTitle(for mode: AmbientModeType) -> String {
        switch mode {
        case .generic:
            return "Reading Companion"
        case .bookSpecific(let bookID, _):
            if let book = try? modelContext.existingObject(for: bookID) as? Book {
                return book.title
            }
            return "Book Mode"
        case .inactive:
            return "Inactive"
        }
    }

    private func modeSwitchButton(
        icon: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
    }

    private func switchToMode(_ mode: AmbientModeType) {
        withAnimation {
            currentMode = mode
            isExpanded = false
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
```

---

### 5. GenericAmbientBackground (New Component)

**Purpose:** Ambient amber gradient for generic mode

**File:** `Epilogue/Views/Components/GenericAmbientBackground.swift`

```swift
import SwiftUI

struct GenericAmbientBackground: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#E8B65F"),
                    Color(hex: "#D4A056"),
                    Color(hex: "#C89941")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Breathing overlay
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FFD700").opacity(0.3),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100 + animationOffset,
                endRadius: 400 + animationOffset
            )
            .blur(radius: 40)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                animationOffset = 50
            }
        }
    }
}
```

---

## System Prompt Management

### Generic Mode System Prompt

```swift
// In UnifiedAmbientCoordinator or separate SystemPrompts.swift

static let genericModePrompt = """
You are Epilogue's reading companion. You help users with their reading
journey when they're not actively reading a specific book.

Your purpose:
- Give personalized book recommendations based on their library and patterns
- Help them read more consistently by analyzing their habits
- Guide reflection on books they've finished
- Explore themes and connections across their reading
- Provide insights about their reading patterns and growth

Your boundaries:
- ONLY discuss books, reading, and literary topics
- Politely redirect off-topic questions back to reading
- Suggest switching to book-specific mode for deep book discussions
- Don't act as a general-purpose assistant

When to suggest book-specific mode:
- User asks detailed questions about a specific book
- Multiple consecutive questions about the same book
- User wants to discuss while actively reading
- Questions about plot, characters, or specific passages

Redirect template:
"It sounds like you want to dive deep into [Book]. Would you like to switch to
book-specific mode? There I can see exactly where you are in your reading and
help with live discussions."

Your personality:
- Thoughtful and literary, not overly casual
- Genuinely curious about their reading journey
- Encouraging but not patronizing
- Specific and personalized, using their actual data
- Never use phrases like "based on the data" - just use the insights naturally

Response guidelines:
- Keep responses concise (2-4 paragraphs for most queries)
- Use specific examples from their reading when possible
- Ask clarifying questions when helpful
- Offer 2-3 options rather than overwhelming with choices
- End with a clear next step or follow-up question

Remember past conversations and build on them naturally.
"""
```

---

## Conversation Memory Extension

### Thread Partitioning

**Modification to:** `Epilogue/Services/Ambient/ConversationMemory.swift`

```swift
// Add thread management

extension ConversationMemory {
    /// Save messages to a specific thread
    func addMessage(threadID: String, content: String, isUser: Bool) {
        let entry = MemoryEntry(
            threadID: threadID,
            content: content,
            isUser: isUser,
            timestamp: Date()
        )

        // Save to SwiftData
        modelContext.insert(entry)
        try? modelContext.save()
    }

    /// Get recent messages for a thread
    func getRecentMessages(threadID: String, limit: Int = 50) -> [ConversationMessage] {
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.threadID == threadID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let entries = try? modelContext.fetch(descriptor) else {
            return []
        }

        return entries.suffix(limit).map { entry in
            ConversationMessage(
                id: entry.id,
                content: entry.content,
                isUser: entry.isUser,
                timestamp: entry.timestamp
            )
        }
    }

    /// Get all threads
    func getAllThreads() -> [String] {
        let descriptor = FetchDescriptor<MemoryEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else {
            return []
        }

        return Array(Set(entries.map { $0.threadID }))
    }
}

// Add SwiftData model for memory entries
@Model
class MemoryEntry {
    @Attribute(.unique) var id: UUID
    var threadID: String
    var content: String
    var isUser: Bool
    var timestamp: Date

    init(threadID: String, content: String, isUser: Bool, timestamp: Date) {
        self.id = UUID()
        self.threadID = threadID
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
```

---

## Integration Points

### AmbientModeView Integration

**Modification to:** `Epilogue/Views/Ambient/AmbientModeView.swift`

```swift
// Add mode selector at top of view
var body: some View {
    ZStack {
        // Background based on mode
        if coordinator.currentMode.isGeneric {
            GenericAmbientBackground()
        } else {
            BookSpecificGradientBackground(book: currentBook)
        }

        VStack(spacing: 0) {
            // Mode selector (top)
            AmbientModeSelector(currentMode: $coordinator.currentMode)
                .padding(.horizontal)
                .padding(.top)

            // Chat interface (existing)
            UnifiedChatView(
                messages: coordinator.conversationMessages,
                onSend: { message in
                    Task {
                        await coordinator.sendMessage(message)
                    }
                }
            )
        }
    }
}
```

---

## Testing Strategy

### Unit Tests

```swift
// GenericAmbientContextManagerTests.swift

@MainActor
class GenericAmbientContextManagerTests: XCTestCase {
    var contextManager: GenericAmbientContextManager!
    var mockModelContext: ModelContext!

    override func setUp() async throws {
        // Setup test environment
        mockModelContext = try ModelContext(...)
        contextManager = GenericAmbientContextManager(...)
    }

    func testRecommendationIntent() async throws {
        let context = await contextManager.buildContext(
            for: "What should I read next?",
            conversationHistory: []
        )

        XCTAssertTrue(context.contains("TASTE PROFILE"))
        XCTAssertTrue(context.contains("Top genres"))
    }

    func testHabitAnalysisIntent() async throws {
        let context = await contextManager.buildContext(
            for: "Why can't I read more consistently?",
            conversationHistory: []
        )

        XCTAssertTrue(context.contains("READING PATTERNS"))
        XCTAssertTrue(context.contains("Average session"))
    }
}
```

### Integration Tests

- Mode switching preserves conversation state
- Context injection varies correctly by intent
- AI responses stay on-topic (reading-related)
- Graceful handling of off-topic requests

### UI Tests

- Mode selector displays correct options
- Gradient transitions smoothly
- Messages render correctly in both modes
- Voice input works in generic mode

---

## Performance Considerations

### Context Budget

**Maximum context size:** 6K tokens

**Budget allocation:**
- System prompt: ~400 tokens
- Conversation history: ~2K tokens (last 10 messages)
- User context: ~3K tokens (conditional based on intent)
- Reserved: ~600 tokens (safety margin)

**Optimization strategies:**
- Summarize old conversation history (>10 messages)
- Lazy-load analytics (only when stats requested)
- Cache taste profile (regenerate weekly)
- Limit cross-book theme analysis to relevant books

### Async Loading

All context building is async to prevent UI blocking:
```swift
Task {
    let context = await genericContextManager.buildContext(...)
    // Update UI
}
```

### Caching

**Cache candidates:**
- Taste profile (24 hour TTL)
- Library overview (update on book add/remove)
- Reading patterns (update daily)

---

## Migration Path

### Phase 1: Core Infrastructure (Week 1)
- [ ] Create `AmbientModeType` enum
- [ ] Create `GenericAmbientContextManager`
- [ ] Modify `ConversationMemory` for thread support
- [ ] Add generic system prompt to `AICompanionService`

### Phase 2: UI Components (Week 1-2)
- [ ] Create `AmbientModeSelector` component
- [ ] Create `GenericAmbientBackground` component
- [ ] Modify `AmbientModeView` to support mode switching
- [ ] Add mode indicator to chat interface

### Phase 3: Context Builders (Week 2)
- [ ] Implement recommendation context builder
- [ ] Implement habit analysis context builder
- [ ] Implement book discussion context builder
- [ ] Implement stats context builder

### Phase 4: Coordinator (Week 2-3)
- [ ] Create `UnifiedAmbientCoordinator`
- [ ] Implement mode switching logic
- [ ] Implement conversation persistence
- [ ] Wire up to `AmbientModeView`

### Phase 5: Testing & Polish (Week 3)
- [ ] Unit tests for context managers
- [ ] Integration tests for mode switching
- [ ] UI tests for mode selector
- [ ] Manual QA with real user data

### Phase 6: Soft Launch (Week 4)
- [ ] Beta test with select users
- [ ] Monitor conversation topics
- [ ] Gather feedback on boundary management
- [ ] Iterate based on usage patterns

---

## Open Technical Questions

### 1. Session Persistence
**Question:** Should generic sessions create `AmbientSession` records like book-specific mode?

**Options:**
- A) Yes, track all sessions uniformly
- B) No, generic sessions are more ephemeral
- C) Optional, only for extended sessions (>10 min)

**Recommendation:** A - Uniform tracking enables analytics

---

### 2. Context Caching Strategy
**Question:** How aggressively should we cache context?

**Options:**
- A) No caching (always fresh)
- B) In-memory caching (session lifetime)
- C) Persistent caching (disk, with TTL)

**Recommendation:** B for V1, C for V2+

---

### 3. Intent Detection Sophistication
**Question:** Simple keyword matching or ML-based classification?

**Options:**
- A) Keyword regex (fast, simple)
- B) Natural Language framework (Apple NLClassifier)
- C) LLM-based (use AI to classify intent)

**Recommendation:** A for V1, B for V2 (avoid extra AI call)

---

### 4. Mode Switch Confirmation
**Question:** Should mode switches require confirmation?

**Options:**
- A) Instant switch (no confirmation)
- B) Confirm for first switch (onboarding)
- C) Always confirm

**Recommendation:** A - Fast switching is key UX benefit

---

## Summary

The technical architecture for Generic Ambient Mode **maximizes code reuse** while providing **sophisticated context management** tailored to library-wide conversations.

**Key innovations:**
1. **Unified coordinator** - Single code path for both modes
2. **Intent-based context** - Smart, minimal context injection
3. **Thread partitioning** - Separate conversation memory per mode
4. **Shared UI** - Same components, different context
5. **Graceful boundaries** - System prompt handles redirects

**Implementation effort:**
- ~3 weeks for V1 (single developer)
- Reuses 80% of existing code
- Minimal new dependencies
- Low technical risk

**Success metrics:**
- Context size stays <6K tokens
- Response time <2 seconds
- Mode switches <500ms
- No conversation state loss on switch
