## 4. INTEGRATION POINTS

### 4.1 Navigation Placement

**Option A: New Tab (Recommended)**

Add "Discover" as 5th tab in main navigation:

```
┌──────────────────────────────────────┐
│ [Library] [Search] [Discover] [Stats] [Settings] │
└──────────────────────────────────────┘
```

**Pros:**
- Prominent placement
- Clear discovery destination
- Separate from general chat

**Cons:**
- Adds another tab (5 total)

**Option B: Within Chat Tab**

Add session type selector in `UnifiedChatView`:

```
┌──────────────────────────────────────┐
│ Chat                              [•]│
│ [General] [Book Discovery] [Ambient] │
├──────────────────────────────────────┤
│ [Chat content]                        │
└──────────────────────────────────────┘
```

**Pros:**
- Leverages existing chat infrastructure
- No new tab needed
- Natural for conversational feature

**Cons:**
- Less discoverable
- Mixes purposes

**Option C: Floating Action Button**

FAB in Library view:

```
┌──────────────────────────────────────┐
│ Library                               │
│                                       │
│ [Book grid/list]                      │
│                                       │
│                            ┌────────┐ │
│                            │ 🔍💬   │ │
│                            │Discover│ │
│                            └────────┘ │
└──────────────────────────────────────┘
```

**Pros:**
- Contextual to browsing books
- Doesn't clutter navigation
- iOS-native pattern

**Cons:**
- Less prominent
- Easy to miss

**RECOMMENDATION: Option B (Within Chat)**
- Least friction implementation
- Natural conversational context
- Reuses UnifiedChatView infrastructure
- Can be promoted to tab later if heavily used

### 4.2 Entry Points Throughout App

**1. Library View**
```swift
// LibraryView.swift toolbar addition
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button(action: { openDiscovery() }) {
            Label("Discover Books", systemImage: "sparkles")
        }
    }
}
```

**2. Empty Library State**
```
┌──────────────────────────────────────┐
│ Your Library is Empty                │
│                                       │
│ [Large Book Icon]                     │
│                                       │
│ Start discovering books to add here   │
│                                       │
│ [🔍 Discover Books]                  │
│ [📷 Scan Book]                       │
└──────────────────────────────────────┘
```

**3. After Finishing a Book**
```
🎉 You finished [Book Title]!

┌──────────────────────────────────────┐
│ How was it?                           │
│ ⭐️⭐️⭐️⭐️⭐️                          │
│                                       │
│ [Find Similar Books]                  │
│ [Browse Next Read]                    │
└──────────────────────────────────────┘
```

**4. Ambient Mode Session End**
```
Session Summary
─────────────────
📖 [Book]: 45 minutes reading
💭 3 questions asked
✏️ 2 quotes captured

[Continue in Ambient] [Discover Similar Books]
```

**5. Search View (When no results)**
```
No books found for "[query]"

Want me to recommend something related?

[Get Recommendations]
```

**6. Book Detail View**
```
┌──────────────────────────────────────┐
│ [Book Title]                          │
│ [Author]                              │
│                                       │
│ [Read] [Share] [More Like This]      │
└──────────────────────────────────────┘
```

**7. Siri Shortcuts**
```
"Hey Siri, recommend a mystery book in Epilogue"
"Hey Siri, find me something to read in Epilogue"
"Hey Siri, surprise me with a book in Epilogue"
```

**8. Widgets (Future)**
```
┌─────────────────┐
│ Daily Pick      │
│                 │
│ [Cover]  [Book] │
│          [Info] │
│                 │
│ [Tap to View]   │
└─────────────────┘
```

### 4.3 Relationship to Existing Features

#### With Library
```
Discovery Chat → User adds book → Library
Library analysis → Discovery Chat (context)
Library patterns → Recommendation signals
```

**Implementation:**
- `LibraryViewModel` provides taste profile to discovery
- Discovery recommendations link directly to `addBook()` function
- Library updates trigger recommendation cache refresh

#### With Browse/Search
```
Search for "mystery" → No specific book in mind
                     ↓
                Suggest Discovery Chat
                     ↓
           Conversational recommendation
                     ↓
                Add to Library
```

**Implementation:**
- Search sheet includes "Or ask for recommendations" button
- Discovery can use search queries as conversation starters
- Both use `GoogleBooksAPI` for book data

#### With Ambient Mode
```
Ambient Session (reading Book A)
    ↓
User asks: "What should I read after this?"
    ↓
Trigger Discovery Chat with Book A as context
    ↓
Recommend books similar to or contrasting with Book A
```

**Implementation:**
- Ambient mode detects "recommendation" intent via `TrueAmbientProcessor`
- Creates `AmbientSessionContent` with type `.recommendation_request`
- Opens Discovery Chat with current book context
- Uses ambient session data (questions asked, themes discussed)

#### With Stats/Usage View
```
Stats View shows:
- Reading patterns (genres, pace, completion rate)
- Top authors, themes
- Time investment per genre

[Discover Based on My Stats]
    ↓
Discovery Chat with full profile context
```

**Implementation:**
- Stats view calculates reading analytics
- Discovery uses same metrics for recommendations
- "Optimize my reading" button → Discovery with goals

### 4.4 Ambient Mode Deep Integration

**Ambient → Discovery Flows:**

**Flow 1: "What should I read next?"**
```
Ambient Mode (reading "The Hobbit")
    ↓
User (voice): "What should I read after this?"
    ↓
TrueAmbientProcessor detects intent: .recommendation_request
    ↓
Discovery Chat opens with context:
"I see you're enjoying The Hobbit (epic fantasy,
 whimsical tone). Want more Middle-earth, similar
 fantasy, or something completely different?"
```

**Flow 2: While discussing themes**
```
Ambient Session for "1984"
User: "This totalitarian surveillance is chilling"
    ↓
Assistant: "Want to explore more dystopian futures,
           or books that examine authoritarianism
           differently?"
    ↓
[Discover Related Books] → Opens Discovery Chat
```

**Flow 3: After session summary**
```
Ambient Session Summary
📖 Crime and Punishment - 60 minutes
💭 Discussed: guilt, redemption, moral philosophy
    ↓
[Find Books About Similar Themes]
    ↓
Discovery: "You explored heavy philosophical
           questions. Want more existential fiction,
           or something lighter that still makes
           you think?"
```

**Technical Integration:**
- `AmbientSessionManager` can trigger discovery mode
- Pass `AmbientSession.id` to discovery for context
- Discovery reads session history (questions, themes discussed)
- Ambient UI shows "Discover" button when appropriate intent detected

### 4.5 Cross-Feature Data Flow

```
┌─────────────────────────────────────────┐
│           USER READING DATA             │
├─────────────────────────────────────────┤
│ • Library (books, progress, ratings)    │
│ • Highlights & Quotes                   │
│ • Notes                                 │
│ • Ambient Sessions (questions, themes)  │
│ • Reading duration & patterns           │
│ • Previous recommendations              │
└─────────────────────────────────────────┘
           ↓         ↓         ↓
    ┌──────────┐ ┌───────────┐ ┌──────────┐
    │ Library  │ │  Ambient  │ │  Stats   │
    │ Analyzer │ │  Context  │ │ Analytics│
    └──────────┘ └───────────┘ └──────────┘
           ↓         ↓         ↓
    ┌────────────────────────────────────┐
    │  DISCOVERY CHAT INTELLIGENCE       │
    │  (Conversational Recommendations)  │
    └────────────────────────────────────┘
           ↓
    ┌────────────────────────────────────┐
    │  RECOMMENDATIONS                    │
    │  • Book suggestions                 │
    │  • Reasoning/Why                    │
    │  • Personalized to user             │
    └────────────────────────────────────┘
           ↓
    ┌────────────────────────────────────┐
    │  USER ACTIONS                       │
    │  • Add to Library                   │
    │  • Start Ambient Session            │
    │  • Request more recommendations     │
    └────────────────────────────────────┘
```

### 4.6 Technical Integration Requirements

**Services to Modify:**

1. **NavigationCoordinator.swift**
   ```swift
   enum NavigationDestination {
       case library
       case search
       case chat(sessionType: SessionType)  // Add .bookDiscovery type
       case ambient(bookId: String?)
       case stats
       case settings
   }
   
   func openDiscovery(context: DiscoveryContext? = nil) {
       // Navigate to chat with bookDiscovery session
   }
   ```

2. **UnifiedChatView.swift**
   ```swift
   enum ChatSessionType {
       case general
       case bookDiscovery      // NEW
       case ambient
   }
   
   @State private var sessionType: ChatSessionType = .general
   
   // Add session type picker in header
   ```

3. **AISession.swift**
   ```swift
   enum SessionType: String, Codable {
       case discussion
       case summary
       case analysis
       case questions
       case characterAnalysis
       case themeExploration
       case bookDiscovery      // NEW
   }
   ```

4. **TrueAmbientProcessor.swift**
   ```swift
   enum ContentType {
       case quote
       case question
       case reflection
       case insight
       case connection
       case reaction
       case recommendationRequest  // NEW - triggers discovery
   }
   
   // Add pattern detection:
   // "what should I read next"
   // "recommend books like this"
   // "find me something similar"
   ```

**New Services to Create:**

1. **DiscoveryConversationService.swift**
   - Manages discovery chat state
   - Interprets user intent
   - Generates recommendations with reasoning
   - Handles conversation memory

2. **DiscoveryContext.swift**
   - Model for conversation context
   - Current book (if from ambient)
   - Stated preferences
   - Rejected recommendations

3. **RecommendationFormatter.swift**
   - Formats recommendations for chat display
   - Generates "why" explanations
   - Creates book cards

