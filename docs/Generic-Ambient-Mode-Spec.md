# Generic Ambient Mode - Feature Specification

## Executive Summary

Generic Ambient Mode is a **reading-focused conversational companion** for Epilogue users when they're not actively reading a specific book. It provides personalized guidance, recommendations, and insights based on the user's entire reading journey while maintaining clear boundaries around its purpose: **helping people read better, more, and more meaningfully**.

## Core Philosophy

### What It IS
- **A reading companion** - Helps users navigate their reading life
- **Personalized advisor** - Uses library, history, and patterns to give tailored advice
- **Memory-enabled** - Remembers past conversations and reading context
- **Proactive guide** - Suggests next steps based on reading patterns

### What It's NOT
- **General-purpose ChatGPT** - Not for homework, recipes, or general questions
- **Productivity tool** - Not a task manager or note-taking app
- **Social platform** - Not for sharing or community features
- **Book-specific discussion** - That's a separate mode with different context

## Use Cases & User Needs

### 1. Discovery & Recommendations
**User need:** "What should I read next?"

**Capabilities:**
- Smart recommendations based on reading history and patterns
- Exploration of themes from recent reading
- Series continuations and related works
- Mood-based suggestions ("I want something lighter")
- Challenge suggestions ("ready for something more ambitious?")

**Personalization signals:**
- Library taste analysis (genres, authors, themes)
- Recent reading sessions and completion rates
- Highlighted passages and captured questions
- Reading phase (exploring → developing → deepening → mastering)
- Time since last book finished

### 2. Reading Habits & Patterns
**User need:** "How can I read more consistently?"

**Capabilities:**
- Analyze reading session patterns (time of day, duration, frequency)
- Identify blockers ("you tend to drop books around page 150")
- Suggest optimal reading times based on history
- Celebrate milestones and progress
- Compare current pace to past patterns

**Personalization signals:**
- Reading session analytics (duration, frequency, pace)
- Drop-off patterns (abandoned books, when they quit)
- Successful completion patterns
- Ambient vs. traditional reading mode preferences

### 3. Reflection on Finished Books
**User need:** "I just finished a book and want to process it"

**Capabilities:**
- Guide post-reading reflection
- Connect themes to other books in library
- Suggest related reading
- Help articulate insights from the reading
- Create reading journal entries

**Personalization signals:**
- Past ambient sessions for that book
- Captured quotes, notes, and questions
- Session insights (themes, emotional arc, realizations)
- Cross-book thematic connections

### 4. Library Organization & Curation
**User need:** "Help me make sense of my reading collection"

**Capabilities:**
- Identify thematic clusters in library
- Suggest reading sequences ("these three books go well together")
- Find forgotten gems ("you haven't touched this in a year")
- Curate custom reading lists for moods/goals
- Analyze library evolution over time

**Personalization signals:**
- Complete book library with metadata
- Reading status (finished, in-progress, abandoned, want-to-read)
- User ratings and notes
- Date added vs. date read patterns

### 5. Deep Topic Exploration
**User need:** "I want to understand [theme] better across my reading"

**Capabilities:**
- Cross-reference theme across multiple books
- Suggest deep dives into specific topics
- Connect concepts from different readings
- Create thematic reading paths

**Personalization signals:**
- Key topics from all ambient sessions
- Recurring themes in library
- Character and theme sentiment tracking
- Session intelligence pattern detection

### 6. Reading Stats & Insights
**User need:** "Show me my reading patterns"

**Capabilities:**
- Reading pace and volume analytics
- Genre diversity analysis
- Question complexity evolution
- Engagement depth trends
- Personal reading milestones

**Personalization signals:**
- All reading session data
- Session intelligence analytics
- Question evolution patterns
- Thematic diversity metrics

### 7. Pre-Reading Preparation
**User need:** "I'm about to start [book], what should I know?"

**Capabilities:**
- Spoiler-free context and background
- Connection to books already read
- Suggest preparation questions
- Set reading intentions

**Personalization signals:**
- Smart book enrichment (themes, style, setting)
- Related books in library
- User's reading phase and complexity preferences

### 8. Book Club & Discussion Prep
**User need:** "Help me prepare for book club discussion"

**Capabilities:**
- Review captured highlights and questions
- Generate discussion prompts
- Identify key themes and character arcs
- Prepare thoughtful talking points

**Personalization signals:**
- All captured content for the book
- Ambient session summaries
- Session insights (themes, emotional arc)
- User's question patterns

## Boundary Management

### In-Scope Requests
✅ Anything related to:
- Reading habits, patterns, goals
- Book recommendations and discovery
- Discussing books in user's library
- Analyzing reading statistics
- Exploring literary themes and concepts
- Improving reading comprehension or enjoyment
- Book-adjacent topics (authors, literary movements, publishing)

### Out-of-Scope Requests
❌ Politely decline and redirect:
- General knowledge questions ("what's the capital of France?")
- Homework help not related to reading
- Technical support for non-reading apps
- Social media content creation
- General life advice unrelated to reading
- Current events and news

### Graceful Redirects

**Template responses:**

```
User: "Help me write an email to my boss"
Assistant: "I'm focused on helping you with your reading journey. But
I notice you recently read [relevant book] - would you like to discuss
how its insights might apply to workplace communication?"
```

```
User: "What's the weather tomorrow?"
Assistant: "I'm here to help with your reading life rather than general
questions. Would you like a recommendation for what to read tomorrow instead?"
```

```
User: "Tell me about the French Revolution"
Assistant: "I can help you find great books about the French Revolution
in your library or suggest new ones. I see you have [related book] -
have you started it yet?"
```

### Suggesting Book-Specific Mode

The system should recognize when to suggest switching to book-specific ambient mode:

**Triggers:**
- User asks detailed questions about a specific book
- Multiple consecutive questions about same book
- Quotes or references specific passages
- Asks about characters or plot details

**Transition prompt:**
```
"It sounds like you want to dive deep into [Book]. Would you like to
switch to book-specific ambient mode? There I can see exactly where
you are in your reading and help with live discussions."

[Switch to Book Mode] [Stay in General Mode]
```

## Context & Personalization

### Available Context Layers

**1. Library Context**
- All books with metadata, status, ratings
- Smart enrichment (themes, style, characters)
- Book color palettes for visual continuity
- Series information and reading order

**2. Reading History**
- All reading sessions with timestamps, duration, pace
- Current book and page number
- Recently finished books
- Abandoned or paused books

**3. Captured Content**
- All quotes, notes, questions across all books
- Favorite highlights
- Unanswered questions
- Tags and organization

**4. Session Intelligence**
- Past ambient sessions (book-specific and generic)
- Key topics explored
- Question evolution patterns
- Thematic connections discovered
- Emotional journey tracking
- Reading phase (exploring → mastering)

**5. Reading Patterns**
- Preferred reading times
- Average session duration
- Completion rates
- Genre preferences and diversity
- Reading level progression
- Drop-off patterns

**6. Conversation Memory**
- Recent generic ambient conversations
- Topic threads and continuity
- Referenced books and themes
- Unresolved questions or goals

### Context Injection Strategy

**Always Include:**
- Recent conversation history (last 10 messages)
- Current reading (book + page if active session)
- Recently finished books (last 3)
- In-progress books (up to 5)

**Conditionally Include (based on query):**
- **For recommendations:** Taste profile, recent completions, genre preferences
- **For habit questions:** Reading session analytics, patterns, optimal times
- **For specific book:** Full book context, all captured content, session summaries
- **For themes:** Cross-book thematic analysis, related sessions, key topics
- **For stats:** Full analytics, session intelligence, evolution metrics

**Never Include (Privacy):**
- Raw sensitive notes marked private
- Location or device-specific data
- Payment or subscription details
- Specific timestamps unless relevant

### Privacy Principles

1. **User control** - Clear settings for what data AI can access
2. **Transparency** - Show what context is being used
3. **Minimal data** - Only include relevant context for query
4. **Anonymization** - No external identifiers sent to AI
5. **Local processing** - Sensitive analytics done on-device

## Entry Points & Triggers

### Primary Entry Points

**1. Dedicated Generic Ambient Tab**
- Persistent access from main navigation
- Icon: Ambient orb without book context
- Always available, even while reading a book

**2. Quick Actions**
- Long-press ambient orb → "General Reading Chat"
- Siri: "Talk to Epilogue about my reading"
- Spotlight: "Reading assistant"

**3. Contextual Triggers**
- Finish a book → "Want to reflect on this book or discuss what to read next?"
- Long period without reading → "I've noticed you haven't read in a while..."
- New book added to library → "Would you like recommendations based on this?"
- Reading milestone reached → "You've read 10 books this year! Want to see patterns?"

**4. Onboarding**
- First launch after completing setup
- Introduction to capabilities
- Sample prompts to get started

### Visual Distinction from Book-Specific Mode

**Generic Mode Indicators:**
- **Gradient:** Enhanced amber gradient (default) - warm, inviting, neutral
- **Header:** "Reading Companion" or "Epilogue Assistant"
- **Icon:** Ambient orb without book cover overlay
- **Status:** "Not reading a specific book right now"
- **Color theme:** Warm neutrals (amber, honey, soft gold)

**Book-Specific Mode Indicators:**
- **Gradient:** Book cover color palette (extracted colors)
- **Header:** Book title + current chapter/page
- **Icon:** Ambient orb with book cover thumbnail
- **Status:** "Reading [Book] - Page X"
- **Color theme:** Book-specific palette

**Mode Switcher:**
```
┌─────────────────────────────────┐
│ 📚 Reading The Odyssey          │ ← Current book mode
│ 💬 General Reading Chat         │ ← Generic mode
└─────────────────────────────────┘
```

## Conversation Memory & Continuity

### Session Types

**1. Ad-hoc Queries** (ephemeral)
- Single question, quick response
- Minimal context retention
- Example: "Recommend a sci-fi book"

**2. Threaded Conversations** (persistent)
- Extended discussion with memory
- Topic tracking and continuity
- Example: "Help me plan my reading for the year"

### Memory Scope

**Short-term (current session):**
- All messages in current conversation
- Active topics and entities
- User's current reading state
- Pending follow-ups or questions

**Medium-term (recent sessions):**
- Last 5 generic ambient conversations
- Topics explored in past week
- Recent books discussed
- Ongoing reading goals or challenges

**Long-term (historical):**
- Significant conversations archived
- Major insights or breakthroughs
- Reading milestones and celebrations
- User preferences learned over time

### Memory Implementation

**Storage:**
- Extends existing `ConversationMemory` service
- Separate thread ID for generic mode (`generic-ambient-{uuid}`)
- Session summaries auto-generated after conversation ends
- Tagged with topics, books mentioned, intent

**Retrieval:**
- Semantic search for relevant past conversations
- Entity-based retrieval (book titles, themes, authors)
- Time-based relevance decay
- User can explicitly reference: "Remember when we talked about..."

**Context Window:**
- Last 10 messages always included
- Relevant past summaries (up to 3) if semantically similar
- Total context budget: ~4K tokens for conversation history

### Cross-Reference with Book Sessions

Generic mode can reference book-specific sessions:
- "In your last session reading The Odyssey, you asked about..."
- "You seemed really engaged with themes of homecoming across several books"
- "Your questions about [character] show you're in the deepening phase"

## Technical Architecture

### Shared Infrastructure

**Reuses from Book-Specific Mode:**
- ✅ `AmbientModeView` - Same UI, different context injection
- ✅ `UnifiedChatView` - Already handles `bookContext == nil`
- ✅ `AICompanionService` - Same AI routing and processing
- ✅ `ConversationMemory` - Extended for generic threads
- ✅ Chat UI components (ChatMessageView, UnifiedChatInputBar, etc.)
- ✅ Voice recognition and transcription
- ✅ Gradient background system (use EnhancedAmberGradient)

**New/Modified Components:**
- 🔧 `GenericAmbientContextManager` - Builds library-wide context
- 🔧 `GenericAmbientCoordinator` - Navigation for non-book mode
- 🆕 `AmbientModeSelector` - Switch between generic and book modes
- 🔧 System prompts for generic vs. book-specific behavior

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     AmbientModeView                          │
│  (Main UI - shared between generic and book-specific)        │
└────────────────────┬────────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    ┌─────▼──────┐      ┌──────▼─────────────┐
    │  Generic   │      │   Book-Specific    │
    │   Context  │      │      Context       │
    │            │      │                    │
    │  Library   │      │  Current Book      │
    │  Reading   │      │  Chapter/Page      │
    │  History   │      │  Live Progress     │
    │  Patterns  │      │  Book Enrichment   │
    │  Taste     │      │  Recent Questions  │
    └─────┬──────┘      └──────┬─────────────┘
          │                    │
          └────────┬───────────┘
                   │
          ┌────────▼─────────┐
          │ Context Manager  │
          │  (Unified API)   │
          └────────┬─────────┘
                   │
          ┌────────▼─────────┐
          │ AI Companion     │
          │    Service       │
          └────────┬─────────┘
                   │
          ┌────────▼─────────┐
          │   AI Provider    │
          │ (Claude/GPT-4o)  │
          └──────────────────┘
```

### Context Manager Design

**`GenericAmbientContextManager.swift`** (new)

```swift
class GenericAmbientContextManager: ObservableObject {
    private let libraryService: LibraryService
    private let sessionIntelligence: SessionIntelligence
    private let tasteAnalyzer: LibraryTasteAnalyzer
    private let conversationMemory: ConversationMemory

    func buildContext(for message: String) async -> GenericAmbientContext {
        // Analyze message intent
        let intent = detectIntent(message)

        // Build relevant context based on intent
        var context = GenericAmbientContext()

        // Always include
        context.recentConversation = conversationMemory.getRecent(limit: 10)
        context.currentReading = getCurrentReadingSnapshot()
        context.recentlyFinished = getRecentlyFinished(limit: 3)

        // Conditional based on intent
        switch intent {
        case .recommendation:
            context.tasteProfile = tasteAnalyzer.analyzeTaste()
            context.genrePreferences = libraryService.getGenreDistribution()

        case .habits:
            context.readingPatterns = sessionIntelligence.getPatterns()
            context.sessionAnalytics = sessionIntelligence.getAnalytics()

        case .bookDiscussion(let bookTitle):
            context.bookContext = findBook(title: bookTitle)
            context.capturedContent = getCapturedContent(for: bookTitle)
            context.sessionSummaries = getSessionSummaries(for: bookTitle)

        case .thematicExploration(let theme):
            context.thematicConnections = sessionIntelligence.findThemeConnections(theme)
            context.relatedBooks = findBooksWithTheme(theme)

        case .stats:
            context.fullAnalytics = sessionIntelligence.getFullAnalytics()
            context.milestones = getMilestones()

        case .general:
            // Lightweight context
            context.libraryOverview = getLibrarySnapshot()
        }

        return context
    }
}
```

### State Management

**`AmbientMode` enum** (add case)
```swift
enum AmbientMode {
    case bookSpecific(book: Book, page: Int?)
    case generic
    case none  // Not in ambient mode
}
```

**`AmbientCoordinatorProtocol`** (shared interface)
```swift
protocol AmbientCoordinatorProtocol {
    var currentMode: AmbientMode { get }
    var conversationMemory: ConversationMemory { get }

    func sendMessage(_ message: String) async
    func switchMode(to: AmbientMode)
    func endSession()
}
```

### System Prompts

**Generic Mode System Prompt:**
```
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

Available context:
{context_summary}

Remember past conversations and build on them naturally.
```

**Book-Specific Mode System Prompt:**
```
You are Epilogue's reading companion for {book_title}.

You help readers engage deeply with this specific book while they read.

Your purpose:
- Answer questions about plot, characters, themes
- Provide context without spoilers (they're on page {current_page})
- Help them think more deeply about what they're reading
- Capture and organize their thoughts, quotes, questions

[...existing book-specific instructions...]
```

### Navigation Flow

```
ContentView
  ├─ TabView
  │   ├─ Library Tab
  │   ├─ Reading Tab
  │   ├─ Ambient Tab ← NEW: Always shows current mode
  │   └─ Profile Tab
  │
  ├─ AmbientModeSheet (modal)
  │   ├─ Mode Selector (top)
  │   │   ├─ Generic Mode
  │   │   └─ Book-Specific Mode(s)
  │   │
  │   └─ AmbientModeView
  │       ├─ if mode == .generic
  │       │   └─ GenericAmbientContextManager
  │       │
  │       └─ if mode == .bookSpecific(book)
  │           └─ AmbientContextManager (existing)
```

## Live Activities for Generic Mode

### Decision: NO Live Activities for Generic Mode (v1)

**Rationale:**
- Live Activities are for **ongoing, continuous states** (active reading session)
- Generic mode conversations are typically **short, ad-hoc interactions**
- Lock screen widget for "chat about reading" is less compelling than "reading X book"
- Avoid notification fatigue and Lock Screen clutter

**Alternative:**
- **Siri shortcuts** for quick access: "Hey Siri, ask Epilogue about my reading"
- **Home Screen widget** showing recent conversation or reading stats
- **Notification prompts** for contextual moments (finished book, milestone)

**Future consideration:**
- If users have extended generic sessions (15+ minutes), could offer Live Activity
- "Reading Planning Session" or "Library Organization" could warrant persistent widget
- Wait for usage data to validate need

## UI Specifications

### Generic Mode Visual Identity

**Color Palette:**
```swift
// GenericAmbientTheme.swift
struct GenericAmbientTheme {
    // Warm, inviting neutrals
    static let primaryGradient = [
        Color(hex: "#E8B65F"),  // Warm amber
        Color(hex: "#D4A056"),  // Rich honey
        Color(hex: "#C89941")   // Deep gold
    ]

    // Accent colors
    static let accentColor = Color(hex: "#E8B65F")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.8)

    // Orb visualization
    static let orbCore = Color(hex: "#FFD700")
    static let orbGlow = Color(hex: "#E8B65F").opacity(0.6)
}
```

**Background Gradient:**
- Reuse `EnhancedAmberGradient` from existing code
- Subtle breathing animation (slower than book mode)
- No voice-reactive modulation (less distracting for thinking)

### Mode Switcher Component

**Visual Design:**
```
┌──────────────────────────────────────┐
│ ┌──────────────────────────────────┐ │
│ │  💬 Reading Companion            │ │ ← Generic (active)
│ └──────────────────────────────────┘ │
│                                      │
│  📚 The Odyssey (Page 234)          │ ← Book mode (available)
│  📕 Lord of the Rings (Page 45)      │
└──────────────────────────────────────┘
```

**Interaction:**
- Tap to switch modes instantly
- Slide-down from top (like notification panel)
- Haptic feedback on mode change
- Smooth transition with gradient cross-fade

### Empty States

**First Launch:**
```
┌──────────────────────────────────────┐
│                                      │
│         🌟                           │
│                                      │
│    Welcome to Your Reading           │
│         Companion                    │
│                                      │
│  I can help you:                     │
│  • Find your next great book         │
│  • Build better reading habits       │
│  • Explore your reading patterns     │
│  • Reflect on what you've read       │
│                                      │
│  Try asking:                         │
│  "What should I read next?"          │
│  "Show me my reading patterns"       │
│  "Help me read more consistently"    │
│                                      │
└──────────────────────────────────────┘
```

**No Recent Conversation:**
```
┌──────────────────────────────────────┐
│                                      │
│  What would you like to explore?     │
│                                      │
│  📊 See reading insights             │
│  📚 Get book recommendations         │
│  💭 Reflect on recent reading        │
│  🎯 Set reading goals                │
│                                      │
└──────────────────────────────────────┘
```

### Conversation UI

**Message Types:**

1. **User Message** (same as book mode)
   - Right-aligned bubble
   - User's text
   - Timestamp

2. **Assistant Message** (same as book mode)
   - Left-aligned bubble
   - AI response
   - Timestamp

3. **Book Reference** (new)
   - Embedded book card in message
   - Cover thumbnail + title + author
   - Tap to view book or switch to book mode
   ```
   ┌─────────────────────────────────┐
   │ Based on your recent reading,   │
   │ I recommend:                    │
   │                                 │
   │ ┌───┬───────────────────────┐   │
   │ │📕│ The Left Hand of        │   │
   │ │  │ Darkness                │   │
   │ │  │ Ursula K. Le Guin       │   │
   │ └───┴───────────────────────┘   │
   │                                 │
   │ It explores themes of identity  │
   │ similar to your highlights in...│
   └─────────────────────────────────┘
   ```

4. **Stats Card** (new)
   - Embedded data visualization
   - Reading pace, genres, milestones
   - Tap to expand full stats view

5. **Action Prompts** (new)
   - Suggested follow-up questions
   - Quick action buttons
   ```
   ┌─────────────────────────────────┐
   │ You've read 12 books this year! │
   │                                 │
   │ [See Patterns] [Next Book]      │
   └─────────────────────────────────┘
   ```

### Input Methods

**Text Input:**
- Same `UnifiedChatInputBar` as book mode
- Placeholder: "Ask about your reading..."
- Support for multi-line input
- Send button

**Voice Input:**
- Ambient orb button (bottom center)
- Tap to toggle listening
- Visual feedback (pulsing, transcription)
- Same voice recognition as book mode

**Quick Prompts:**
- Swipe up from input bar to show suggestions
- Contextual based on recent activity
- Examples:
  - "What should I read next?"
  - "Show my reading stats"
  - "Books I've abandoned"
  - "Plan my reading this month"

### Mode Indicator (Persistent)

```
┌──────────────────────────────────────┐
│  💬 Reading Companion           ⚙️  │ ← Header
├──────────────────────────────────────┤
│                                      │
│  [Conversation Messages]             │
│                                      │
│                                      │
└──────────────────────────────────────┘
│  Ask about your reading...      🎙  │ ← Input
└──────────────────────────────────────┘
```

### Transition Animations

**Generic → Book Mode:**
1. Gradient cross-fades from amber to book colors (0.3s)
2. Header morphs from "Reading Companion" to book title (0.3s)
3. Context panel slides in with book info (0.2s delay)

**Book → Generic Mode:**
1. Gradient fades to amber (0.3s)
2. Book context panel slides out (0.2s)
3. Header morphs to "Reading Companion" (0.3s)

## Scope Recommendations

### V1 - Launch (MVP)

**Core Features:**
✅ Generic ambient conversation (text + voice)
✅ Book recommendations using existing recommendation engine
✅ Reading habit insights using SessionIntelligence
✅ Reflection on finished books
✅ Library overview and organization
✅ Mode switcher (generic ↔ book-specific)
✅ Conversation memory (short-term only)
✅ Basic boundary management (polite redirects)
✅ UI with amber gradient and mode indicators

**Technical:**
✅ GenericAmbientContextManager
✅ GenericAmbientCoordinator
✅ Extend UnifiedChatView for mode switching
✅ Generic system prompts
✅ Intent detection for context injection

**Explicitly OUT for V1:**
❌ Live Activities for generic mode
❌ Long-term conversation memory and search
❌ Cross-session thematic exploration
❌ Advanced stats visualizations
❌ Reading goal tracking and challenges
❌ Social features (sharing, book clubs)
❌ Siri shortcuts (can come post-launch)

**Success Metrics:**
- % of users who try generic mode
- Average session length
- Conversation topics (recommendations vs. habits vs. reflection)
- Retention: Do users return to generic mode?
- Conversion: Generic → book-specific mode switches

---

### V2 - Enhancement (3-6 months post-launch)

**Based on V1 learnings, prioritize:**

**1. Long-term Memory**
- Persistent conversation threads
- Semantic search across past conversations
- "Remember when we talked about..."
- Annual reading reflections

**2. Thematic Exploration**
- Cross-book theme analysis
- Visual theme maps
- Guided deep dives into topics
- Reading path creation

**3. Goal Setting & Tracking**
- Set reading goals (books per month, genre diversity)
- Progress tracking with gentle reminders
- Milestone celebrations
- Challenge suggestions

**4. Enhanced Stats**
- Beautiful data visualizations
- Reading evolution over time
- Comparative insights (vs. past years)
- Export reading reports

**5. Siri & Shortcuts**
- "Hey Siri, what should I read next?"
- Quick stats queries via Siri
- Voice-initiated generic sessions
- Custom shortcuts for power users

---

### V3 - Advanced (6-12 months)

**Advanced Intelligence:**
- Predictive recommendations (before they ask)
- Proactive insights ("You might enjoy X based on Y")
- Reading style analysis (deep vs. wide, fast vs. slow)
- Personalized reading strategies

**Social & Community:**
- Book club features (discussion prep, shared questions)
- Reading buddy matching (opt-in)
- Anonymous reading insights sharing
- Community reading challenges

**Integration:**
- Goodreads import and sync
- Export to other services
- Reading journal export (PDF, Markdown)
- Integration with learning tools (Readwise++)

---

## Open Questions & Decisions Needed

### 1. Conversation Threading
**Question:** Should generic mode support multiple concurrent threads or single linear conversation?

**Options:**
- A) Single thread (simpler, matches book mode)
- B) Multiple threads with labels ("Recommendations," "Habit Coaching," etc.)

**Recommendation:** Start with A (single thread) for V1, consider B for V2 based on user behavior

---

### 2. Context Visibility
**Question:** Should users see what context the AI is using?

**Options:**
- A) Transparent (show "Using data from: library, last 5 sessions, taste profile")
- B) Hidden (seamless experience, no technical details)
- C) Optional toggle in settings

**Recommendation:** C - Default hidden, advanced users can enable "Show AI Context"

---

### 3. Proactive Suggestions
**Question:** Should generic mode ever initiate conversation?

**Options:**
- A) Reactive only (user always starts)
- B) Contextual prompts ("You finished a book! Want to reflect?")
- C) Scheduled check-ins ("How's your reading going this week?")

**Recommendation:** Start with B (contextual prompts) for V1, very conservative frequency

---

### 4. Voice-First vs. Text-First
**Question:** Is generic mode primarily voice or text?

**Options:**
- A) Voice-first (like book mode, emphasize ambient orb)
- B) Text-first (chat interface default)
- C) Equal weight

**Recommendation:** B for generic mode - Most queries are thoughtful and better suited to text. Voice available but not default.

---

### 5. Session Duration
**Question:** Should generic sessions have time limits?

**Options:**
- A) No limit (conversation can go indefinitely)
- B) Soft limit (gentle prompt after 30 min: "Want to continue?")
- C) Hard limit (auto-end after 1 hour)

**Recommendation:** B - Most conversations should be <15 min, long sessions might indicate mode confusion

---

## Summary

Generic Ambient Mode is a **natural extension** of Epilogue's existing ambient architecture, leveraging the rich user data and conversation infrastructure already in place.

**Key principles:**
1. **Focused purpose** - Reading companion, not general assistant
2. **Deeply personalized** - Uses library, history, and patterns
3. **Shared infrastructure** - Minimal new code, extend existing systems
4. **Clear boundaries** - Graceful redirects, suggest book mode when appropriate
5. **Memory-enabled** - Remembers context and past conversations
6. **Distinct identity** - Amber gradient, clear mode indicators

**V1 Scope** is achievable with existing codebase and provides immediate value to users for discovery, habits, and reflection.

**Success depends on:**
- Effective boundary management (staying on-topic)
- High-quality recommendations (leveraging taste analysis)
- Natural conversation memory (building on past discussions)
- Clear mode distinction (never confusing with book mode)
