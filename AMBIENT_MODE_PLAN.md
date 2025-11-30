# Ambient Mode Redesign Plan

## Executive Summary

Two distinct ambient modes with clear separation:
1. **Generic Ambient Mode** - Library-wide intelligence, recommendations, no book context
2. **Book-Specific Ambient Mode** - Deep dive into a specific book

---

## Current State Analysis

### What Exists (Working)
- `LibraryTasteAnalyzer` - On-device preference extraction (genres, authors, themes, reading level, era)
- `RecommendationEngine` - Perplexity-powered recommendations with Google Books enrichment
- `UnifiedChatView` - Main chat interface with book context support
- `SimplifiedAmbientCoordinator` - Entry point coordination
- `SuggestionChip` component in `ChatEmptyStates.swift` - ready to use but unused

### What's Broken/Missing
- Empty state is boring "No Conversations Yet" text
- Recommendation engine is orphaned - never called
- No "What should I read?" flow
- No conversational follow-ups
- Command palette has no ambient mode entry
- No distinction between generic vs book-specific modes

---

## Architecture: Two Modes

### 1. Generic Ambient Mode (No Book Context)

**Entry Points:**
- Command palette from Library, Notes, Settings (anywhere except book views)
- New "Ask Epilogue" quick action

**Purpose:**
- Get personalized book recommendations
- Ask about your reading habits
- Explore your library patterns
- Get suggestions based on mood/occasion

**Empty State - Liquid Glass Pills:**
```
[What should I read next?]
[Something like The Great Gatsby]
[A book for a rainy day]
[What genres do I gravitate toward?]
```

**Intelligence Flow:**
1. User asks "What should I read?"
2. Check if TasteProfile exists and is recent (< 7 days)
3. If no/stale profile → analyze library on-device
4. If profile is thin (< 5 books) → ask clarifying questions:
   - "What mood are you in?"
   - "Fiction or non-fiction?"
   - "Looking for something challenging or relaxing?"
5. Build context + call RecommendationEngine
6. Display recommendations as rich cards with covers
7. Allow "Tell me more about [book]" follow-ups

### 2. Book-Specific Ambient Mode

**Entry Points:**
- Ambient icon from any book view (BookDetailView, QuotesView, NotesView)
- "Discuss this book" from book context menu

**Purpose:**
- Ask questions about THIS book
- Capture quotes while reading
- Record reflections
- Get context (themes, characters, author)

**Empty State - Book-Contextual Pills:**
```
[What's the main theme?]
[Tell me about the author]
[Summarize where I left off]
[Capture a quote]
```

---

## Implementation Plan

### Phase 1: Foundation (Entry Points & Routing)

**File: `SimplifiedAmbientCoordinator.swift`**
- Add `openGenericAmbient()` method (no book context)
- Ensure `openAmbientReading(with: book)` requires a book
- Add `AmbientMode` enum: `.generic`, `.bookSpecific(Book)`

**File: `LiquidCommandPaletteV2.swift`**
- Add "Ask Epilogue" command to `commandSuggestions`
- Route to `SimplifiedAmbientCoordinator.shared.openGenericAmbient()`
- Only show when context is NOT `.bookDetail`

**File: `EnhancedQuickActionsBar.swift`**
- Modify ambient button behavior:
  - If `currentBook != nil` → book-specific mode
  - If `currentBook == nil` → generic mode

### Phase 2: Intelligent Empty States

**File: `ChatEmptyStates.swift`**
- Create `GenericAmbientEmptyState` view:
  - Liquid glass pills with smart suggestions
  - Animated staggered appearance
  - Personalized based on library size

- Update `BookEmptyStateView`:
  - Book-specific suggestion pills
  - Use book's color palette

**Pill Categories (Generic):**
```swift
enum SuggestionCategory {
    case recommendations  // "What should I read next?"
    case similar         // "Something like [recent book]"
    case mood           // "A book for [occasion]"
    case insights       // "What are my reading patterns?"
}
```

### Phase 3: Recommendation Integration

**File: `UnifiedChatView.swift`**
- Add recommendation state:
  ```swift
  @State private var tasteProfile: LibraryTasteAnalyzer.TasteProfile?
  @State private var recommendations: [RecommendationEngine.Recommendation] = []
  @State private var isLoadingRecommendations = false
  ```

- Add recommendation detection in message processing:
  - Detect "what should I read", "recommend", "suggestion" intents
  - Trigger recommendation flow

**New File: `RecommendationCardView.swift`**
- Rich card display for recommendations
- Book cover, title, author, reasoning
- "Add to Library" action
- "Tell me more" follow-up action

**New File: `AmbientRecommendationFlow.swift`**
- Orchestrates the recommendation conversation
- Handles clarifying questions if profile is thin
- Manages follow-up questions
- Caches recent recommendations

### Phase 4: Conversational Follow-ups

**File: `EnhancedIntentDetector.swift`**
- Add recommendation-specific intents:
  - `.askForRecommendation`
  - `.clarifyPreference`
  - `.bookInquiry(title: String)`
  - `.moodBasedRequest`

**Flow: Thin Profile Handling**
```
User: "What should I read?"
System: [Checks profile - only 3 books]
System: "I'd love to help! To give you great recommendations,
        tell me: are you in the mood for fiction or non-fiction?"
User: "Fiction, something adventurous"
System: [Updates context, generates recommendations]
System: [Shows 3-5 personalized recommendations]
```

### Phase 5: Polish & Proactivity

**Proactive Behaviors (Generic Mode):**
- If user hasn't read in 3+ days: "Ready to pick up where you left off?"
- If user finished a book recently: "Based on [Book], you might love..."
- On app open: Subtle recommendation nudge

**Proactive Behaviors (Book Mode):**
- Detect when user is near end of book: "Almost finished! Thoughts so far?"
- If user hasn't captured anything: "Anything worth remembering?"
- After 30 minutes: "Want me to summarize your session?"

---

## File Changes Summary

### New Files
1. `Views/Ambient/GenericAmbientEmptyState.swift` - Liquid glass pills for generic mode
2. `Views/Ambient/RecommendationCardView.swift` - Rich recommendation display
3. `Services/Ambient/AmbientRecommendationFlow.swift` - Recommendation conversation orchestration

### Modified Files
1. `Navigation/SimplifiedAmbientCoordinator.swift` - Add mode distinction
2. `Views/Components/LiquidCommandPaletteV2.swift` - Add "Ask Epilogue" command
3. `Views/Components/EnhancedQuickActionsBar.swift` - Route based on context
4. `Views/Chat/Components/ChatEmptyStates.swift` - Update empty states
5. `Views/Chat/UnifiedChatView.swift` - Integrate recommendations
6. `Services/Ambient/EnhancedIntentDetector.swift` - Add recommendation intents

---

## Success Criteria

1. **Generic Mode Entry**: User can enter generic ambient from command palette (not in book view)
2. **Book Mode Entry**: Tapping ambient icon in book view → scoped session
3. **Empty State**: Beautiful liquid glass pills, not boring text
4. **Recommendations Work**: "What should I read?" returns personalized recommendations
5. **Conversational**: If profile thin, system asks clarifying questions
6. **Rich Display**: Recommendations show as cards with covers
7. **Follow-ups**: User can drill into any recommendation

---

## Order of Implementation

1. **Phase 1** - Entry points & routing (foundation)
2. **Phase 2** - Empty states with liquid glass pills
3. **Phase 3** - Recommendation integration (the big one)
4. **Phase 4** - Conversational follow-ups
5. **Phase 5** - Polish & proactivity

Each phase should be committed separately and tested before moving on.
