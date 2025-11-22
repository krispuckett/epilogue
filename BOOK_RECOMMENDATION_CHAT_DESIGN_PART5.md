## 5. TECHNICAL ARCHITECTURE

### 5.1 System Architecture Diagram

```
┌────────────────────────────────────────────────────────────┐
│                    USER INTERFACE LAYER                     │
├────────────────────────────────────────────────────────────┤
│ UnifiedChatView (Extended)                                  │
│  ├─ Session Type Selector (.general | .bookDiscovery)      │
│  ├─ Message List (Scrollable chat history)                 │
│  ├─ Book Recommendation Cards (Inline)                     │
│  └─ Input Bar (Text + Voice)                               │
│                                                             │
│ BookRecommendationCard                                      │
│  ├─ Compact View (In chat)                                 │
│  ├─ Expanded View (After "Tell Me More")                   │
│  └─ Quick Actions (Add, Tell More, Not Interested)         │
└────────────────────────────────────────────────────────────┘
                           ↓ ↑
┌────────────────────────────────────────────────────────────┐
│                  CONVERSATION LAYER                         │
├────────────────────────────────────────────────────────────┤
│ DiscoveryConversationService                                │
│  ├─ Intent Classification (What does user want?)           │
│  ├─ Context Management (Track conversation state)          │
│  ├─ Response Generation (Format AI responses)              │
│  └─ Recommendation Orchestration                           │
│                                                             │
│ ConversationMemory (Existing - from Ambient)                │
│  ├─ Session context persistence                            │
│  ├─ Previous messages                                       │
│  └─ Rejected recommendations tracking                       │
└────────────────────────────────────────────────────────────┘
                           ↓ ↑
┌────────────────────────────────────────────────────────────┐
│                RECOMMENDATION ENGINE LAYER                  │
├────────────────────────────────────────────────────────────┤
│ RecommendationEngine (Existing)                             │
│  ├─ Generate recommendations from taste profile            │
│  └─ AI-powered suggestion generation                       │
│                                                             │
│ LibraryTasteAnalyzer (Existing)                             │
│  ├─ Extract genre preferences                              │
│  ├─ Identify author patterns                               │
│  └─ Detect themes from library                             │
│                                                             │
│ RecommendationFormatter (New)                               │
│  ├─ Generate "why" explanations                            │
│  ├─ Create personalized reasoning                          │
│  └─ Format for chat display                                │
│                                                             │
│ RecommendationCache (Existing)                              │
│  └─ Cache results (30-day TTL)                             │
└────────────────────────────────────────────────────────────┘
                           ↓ ↑
┌────────────────────────────────────────────────────────────┐
│                      AI/LLM LAYER                           │
├────────────────────────────────────────────────────────────┤
│ OptimizedPerplexityService (Existing)                       │
│  ├─ Chat API for conversational recommendations            │
│  ├─ Streaming responses                                     │
│  ├─ Citation and credibility                               │
│  └─ Quota management                                        │
│                                                             │
│ FoundationModelsManager (Existing - on-device)              │
│  └─ Quick intent classification (offline)                  │
│                                                             │
│ DiscoveryPromptBuilder (New)                                │
│  ├─ Build context-aware prompts                            │
│  ├─ Include user library analysis                          │
│  └─ Format conversation history                            │
└────────────────────────────────────────────────────────────┘
                           ↓ ↑
┌────────────────────────────────────────────────────────────┐
│                      DATA LAYER                             │
├────────────────────────────────────────────────────────────┤
│ SwiftData Models                                            │
│  ├─ AISession (with .bookDiscovery type)                   │
│  ├─ AIMessage (conversation messages)                      │
│  ├─ Book / BookModel (user library)                        │
│  ├─ Quote (highlights with themes)                         │
│  ├─ Note (user reflections)                                │
│  └─ AmbientSession (reading sessions)                      │
│                                                             │
│ LibraryService (Existing)                                   │
│  ├─ Book CRUD operations                                   │
│  └─ Sync UserDefaults ↔ SwiftData                         │
│                                                             │
│ GoogleBooksAPI (Existing)                                   │
│  ├─ Search books                                            │
│  ├─ Get book metadata                                       │
│  └─ Cover images                                            │
│                                                             │
│ BookEnrichmentService (Existing)                            │
│  ├─ Smart synopsis generation                              │
│  ├─ Theme extraction                                        │
│  └─ Character/setting analysis                             │
└────────────────────────────────────────────────────────────┘
```

### 5.2 LLM Integration Strategy

**Which Model to Use:**

| Task | Model | Reasoning |
|------|-------|-----------|
| Intent classification | On-device Foundation | Fast, offline, privacy-first |
| Recommendation generation | Perplexity API | Web-aware, up-to-date book data |
| Conversational responses | Perplexity API | Natural dialogue, streaming |
| "Why" explanations | Perplexity API | Nuanced reasoning |
| Library analysis | On-device Foundation | Private, no data leaves device |

**API Selection Logic:**
```swift
func selectModel(for task: DiscoveryTask) -> AIModel {
    switch task {
    case .intentClassification, .libraryAnalysis:
        return .foundationModels  // On-device, instant
    case .recommendation, .conversation, .reasoning:
        return .perplexity        // API, web-aware
    }
}
```

### 5.3 Prompt Engineering

**System Prompt for Discovery Chat:**

```
You are a knowledgeable book recommendation assistant for Epilogue,
a reading companion app. Your role is to help users discover their
next great read through natural conversation.

PERSONALITY:
- Enthusiastic about books but not pushy
- Conversational and warm, not robotic
- Literary without being pretentious
- Respectful of user's time (concise)

GUIDELINES:
- Ask at most 2 clarifying questions before recommending
- Provide 3-4 book suggestions with variety
- Always explain WHY each book is recommended
- Reference the user's library and reading patterns when relevant
- Don't recommend books the user has already read
- Include title, author, and brief (2-3 sentence) description
- Mention page count and publication year
- Give diverse options (different tones, lengths, eras)

USER CONTEXT:
{library_summary}
{recent_activity}
{preferences_stated}

CONVERSATION SO FAR:
{conversation_history}
```

**Dynamic Context Injection:**

```swift
struct DiscoveryPromptContext {
    let librarySummary: String       // "User has 23 books, mostly fantasy and sci-fi"
    let recentActivity: String?      // "Just finished 1984 (dystopian)"
    let preferencesStated: [String]  // ["fast-paced", "female authors"]
    let conversationHistory: [Message]
    let rejectedBooks: [String]      // Don't suggest again
    
    func build() -> String {
        // Construct prompt with all context
    }
}
```

### 5.4 Response Streaming

**Use existing OptimizedPerplexityService streaming:**

```swift
class DiscoveryConversationService {
    func sendMessage(_ message: String) async throws -> AsyncThrowingStream<String, Error> {
        let context = buildContext()
        let prompt = DiscoveryPromptBuilder.build(
            userMessage: message,
            context: context
        )
        
        // Stream response from Perplexity
        return try await OptimizedPerplexityService.shared.chatStream(
            message: prompt,
            bookContext: currentBook
        )
    }
}
```

**UI Handling:**
```swift
// In UnifiedChatView
for try await chunk in messageStream {
    currentMessage.append(chunk)
    // UI updates automatically via @Published
}

// After stream completes:
parseRecommendations(from: currentMessage)
showBookCards()
```

### 5.5 Book Database/API Strategy

**Primary Source: Google Books API**
- Already integrated via `GoogleBooksAPI.swift`
- Search for recommended books
- Get cover images, metadata, descriptions
- Free tier: 1000 requests/day (sufficient)

**Enrichment Pipeline:**
```
Recommendation from AI
    ↓
Search Google Books API for metadata
    ↓
Cache result in BookEnrichmentService
    ↓
Generate smart synopsis (if not exists)
    ↓
Extract cover colors (ColorIntelligenceEngine)
    ↓
Display in UI
```

**Caching Strategy:**
```swift
actor BookMetadataCache {
    private var cache: [String: BookMetadata] = [:]
    
    func fetch(title: String, author: String) async throws -> BookMetadata {
        let key = "\(title)|\(author)"
        
        // Check cache first
        if let cached = cache[key] {
            return cached
        }
        
        // Fetch from Google Books
        let result = try await GoogleBooksAPI.search(title: title, author: author)
        
        // Enrich
        let enriched = try await BookEnrichmentService.enrich(result)
        
        // Cache
        cache[key] = enriched
        
        return enriched
    }
}
```

### 5.6 Offline Considerations

**Offline Capabilities:**
1. **Library Analysis**: Fully offline using on-device Foundation
2. **Intent Classification**: Offline via Foundation
3. **Cached Recommendations**: Show previous recommendations
4. **Local Book Data**: Display from SwiftData

**Online-Required:**
1. **New Recommendations**: Requires Perplexity API
2. **Book Metadata Fetch**: Requires Google Books API
3. **Cover Image Download**: Requires network

**Graceful Degradation:**
```swift
if !NetworkMonitor.isConnected {
    // Show cached recommendations
    showCachedRecommendations()
    
    // Display message
    showBanner("Showing previous recommendations. Connect to get new suggestions.")
} else {
    // Normal flow
    fetchNewRecommendations()
}
```

### 5.7 Performance Optimization

**1. Async/Await Throughout**
```swift
Task {
    async let libraryAnalysis = LibraryTasteAnalyzer.analyze(books)
    async let trendingBooks = TrendingBooksService.fetch()
    
    let (profile, trending) = await (libraryAnalysis, trendingBooks)
    
    // Use both for context
}
```

**2. Lazy Loading**
- Load cover images asynchronously
- Paginate conversation history
- Stream AI responses (don't wait for full response)

**3. Caching Layers**
```
Memory Cache (in-app session)
    ↓ miss
Disk Cache (RecommendationCache - 30 days)
    ↓ miss
API Call (Perplexity, Google Books)
```

**4. Debouncing User Input**
```swift
@Published var searchText: String = ""

init() {
    $searchText
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink { [weak self] text in
            self?.performSearch(text)
        }
}
```

**5. Image Optimization**
- Downsample covers to 400px max (existing pattern)
- Use thumbnail URLs from Google Books
- Cache images via `CachedAsyncImage`

### 5.8 Data Models

**DiscoverySession (New)**
```swift
@Model
final class DiscoverySession {
    @Attribute(.unique) var id: UUID
    var dateCreated: Date
    var lastUpdated: Date
    
    // Conversation context
    var initialIntent: String?        // "mystery novels"
    var statedPreferences: [String]   // ["fast-paced", "female authors"]
    
    // Recommendations made
    var recommendedBooks: [String]    // Book IDs
    var rejectedBooks: [String]       // Books user said no to
    var addedBooks: [String]          // Books user added to library
    
    // Related data
    var sourceBook: String?           // If from "books like X"
    var ambientSessionId: UUID?       // If triggered from ambient
    
    @Relationship(deleteRule: .cascade)
    var messages: [AIMessage]?
}
```

**DiscoveryRecommendation (New)**
```swift
struct DiscoveryRecommendation: Identifiable, Codable {
    let id: String                    // Book ID
    let title: String
    let author: String
    let coverURL: String?
    let year: String?
    let pageCount: Int?
    let rating: Double?
    
    // Why recommended
    let reasoning: String             // Personalized explanation
    let matchScore: Float             // 0.0-1.0
    let categories: [String]          // [genre, mood, theme]
    
    // Metadata
    let synopsis: String?
    let themes: [String]?
    let similarTo: [String]?          // Book titles
    
    // User actions
    var wasAdded: Bool = false
    var wasRejected: Bool = false
    var askedForMore: Bool = false
}
```

### 5.9 Error Handling

**Error Types:**
```swift
enum DiscoveryError: LocalizedError {
    case networkUnavailable
    case apiQuotaExceeded
    case noRecommendationsFound
    case invalidUserInput
    case bookMetadataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Can't connect right now. Showing cached recommendations."
        case .apiQuotaExceeded:
            return "Daily recommendation limit reached. Try again tomorrow!"
        case .noRecommendationsFound:
            return "Hmm, couldn't find great matches. Try being more specific?"
        case .invalidUserInput:
            return "I didn't quite understand. Could you rephrase?"
        case .bookMetadataUnavailable:
            return "Having trouble loading book details. Try again?"
        }
    }
}
```

**User-Facing Error Messages:**
```
Network Error:
"Looks like you're offline. I can show you previous recommendations,
or wait until you're back online for fresh suggestions."

API Quota:
"You've been discovering a lot today! I've reached my daily
recommendation limit. Check back tomorrow for more suggestions,
or browse your saved recommendations from earlier."

No Results:
"Hmm, I'm not finding great matches. Could you tell me a bit
more about what you're looking for?"
```

### 5.10 Analytics & Monitoring

**Events to Track:**
```swift
enum DiscoveryAnalyticsEvent {
    case sessionStarted(source: String)        // where user opened discovery
    case messageSent(intentType: String)       // classified intent
    case recommendationsShown(count: Int)
    case bookAdded(bookId: String, position: Int)
    case bookRejected(bookId: String, reason: String?)
    case tellMeMoreTapped(bookId: String)
    case sessionEnded(duration: TimeInterval, booksAdded: Int)
    case errorOccurred(error: DiscoveryError)
}
```

**Metrics to Monitor:**
```
- Conversion rate (recommendations → added to library)
- Average session length
- Messages per recommendation
- Recommendation position that gets most adds (1st, 2nd, 3rd?)
- Most common rejection reasons
- API latency and error rates
- Cache hit rate
```

**Implementation:**
```swift
class DiscoveryAnalytics {
    func track(_ event: DiscoveryAnalyticsEvent) {
        // Log to analytics service
        // Use existing PerplexityPerformanceMonitor patterns
    }
}
```

