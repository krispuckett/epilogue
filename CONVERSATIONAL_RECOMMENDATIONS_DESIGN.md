# Conversational Recommendations System - Design Document

**Goal**: Transform book recommendations from a static list into an elegant, conversational experience that feels like talking to a knowledgeable bookstore owner.

**Inspiration**: Ben Blumenrose's feedback - "What authors do you love? What do you feel like reading? Oh ok have you tried this one?"

---

## 1. Architecture Overview

### Core Components

#### A. ConversationalRecommendationEngine (New Service)
**Location**: `Services/Recommendations/ConversationalRecommendationEngine.swift`

**Purpose**: Multi-turn conversational recommendation system that builds on the existing RecommendationEngine

**Key Features**:
- Maintains conversation state across multiple turns
- Asks clarifying questions based on mood/context
- Refines recommendations based on user feedback
- Remembers user preferences within session

**Conversation Flow**:
```
System: "What are you in the mood for?"
User: "Something light and fun"
System: "Perfect! Given you loved Project Hail Mary, how about..."
User: "More like that, but with fantasy"
System: "Ah! Let me find you something that blends humor with fantasy..."
```

#### B. ForYouSheet (New View)
**Location**: `Views/Library/ForYouSheet.swift`

**Purpose**: Beautiful, conversational UI for book recommendations

**Design Elements**:
- Liquid glass morphing interface (iOS 26)
- Chat-like conversation bubbles
- Book cards with cover art and elegant reasoning
- Progressive disclosure (tease → reveal → convince)
- Smooth animations and micro-interactions

#### C. Enhanced Ambient Mode Integration
**Location**: `Views/Ambient/AmbientModeView.swift` (enhancement only)

**Purpose**: Surface recommendations contextually in ambient mode without changing core functionality

**Enhancements**:
- Add "Discover" action pill alongside existing actions
- When no book context: "Based on your library, you might love..."
- Natural conversation starters: "Feeling adventurous? I have a suggestion..."

---

## 2. UI Design Specification

### ForYouSheet Design

#### Visual Hierarchy
```
┌─────────────────────────────────────┐
│  For You                        ✕   │  ← Liquid glass header
├─────────────────────────────────────┤
│                                     │
│  💭 What are you in the mood for?  │  ← System message
│                                     │
│  🗣️ "Something to help me relax"   │  ← User response
│                                     │
│  Perfect! Based on your love of... │  ← AI reasoning
│                                     │
│  ┌─────────────────────────────┐  │
│  │  📖 [Book Cover]            │  │  ← Book card
│  │  The Midnight Library       │  │
│  │  by Matt Haig              │  │
│  │                             │  │
│  │  "After reading Project     │  │  ← Personalized reasoning
│  │  Hail Mary, you'll love..." │  │
│  │                             │  │
│  │  [Add to Library]  [Pass]   │  │  ← Actions
│  └─────────────────────────────┘  │
│                                     │
│  More like this? / Something else? │  ← Refinement options
│                                     │
└─────────────────────────────────────┘
```

#### Glass Effect Hierarchy
- **Background**: Atmospheric gradient (like ambient mode)
- **Header**: `.glassEffect(.thin)` with no background
- **Book Cards**: `.glassEffect(.regular)` with frosted edges
- **Action Pills**: `.glassEffect(.ultraThin)` for buttons
- **Message Bubbles**: Subtle glass with content color tinting

#### Animation Strategy
- **Entry**: Morphing reveal from library button
- **Message Flow**: Fade up with slight bounce
- **Book Cards**: Scale + blur reveal (like book details)
- **Transitions**: Smooth cross-dissolve between states

---

## 3. Conversational Intelligence

### Context Analysis
The system analyzes:
1. **Current Library**: Genres, authors, themes (via LibraryTasteAnalyzer)
2. **Reading History**: Finished books, DNF books, favorites
3. **Time Context**: Time of day, season, upcoming holidays
4. **Mood Signals**: User's language, emoji use, question style
5. **Recent Activity**: Last books added, notes written, quotes saved

### Question Types

#### Opening Questions (First Interaction)
- "What are you in the mood for?"
- "Looking for something specific today?"
- "Want a recommendation based on what you've been reading?"
- "Feeling adventurous, or want something familiar?"

#### Refinement Questions (Follow-ups)
- "More like that?"
- "Too heavy / too light / too long?"
- "Fiction or non-fiction?"
- "Want something completely different?"
- "What about [genre]? You seem to enjoy it"

#### Context-Aware Questions
- **Morning**: "Something energizing to start your day?"
- **Evening**: "Need a relaxing read before bed?"
- **Holiday Season**: "Looking for something festive?"
- **Travel Context**: "Planning a trip? Want something about [place]?"
- **After Finishing Book**: "Loved [book]? Want something similar?"

### Response Generation

#### Reasoning Style (Matches Epilogue's Voice)
- Natural, conversational, no emoji
- Personal ("After reading X, you'll love...")
- Specific ("This has the same wit as Weir but with fantasy")
- Confident but not pushy ("I think you'll really connect with...")
- Knowledgeable without being pretentious

#### Example Responses
```
Good: "Given your love of Tolkien and McCarthy's prose, you'll appreciate
      Guy Gavriel Kay's Tigana—it has that epic sweep you enjoy, but
      with more intimate character moments."

Avoid: "OMG you HAVE to read this! 🔥 It's SO GOOD! Everyone loves it!!!"
```

---

## 4. Technical Implementation

### State Management

```swift
@MainActor
class ConversationalRecommendationEngine: ObservableObject {
    @Published var conversationState: ConversationState = .initial
    @Published var messages: [ConversationMessage] = []
    @Published var currentRecommendations: [Recommendation] = []

    enum ConversationState {
        case initial               // First question
        case clarifying           // Asking follow-up questions
        case presenting           // Showing recommendations
        case refining             // User feedback, adjusting
        case completed            // User selected or dismissed
    }

    struct ConversationMessage {
        let id: UUID
        let content: String
        let isUser: Bool
        let timestamp: Date
        let metadata: MessageMetadata?
    }

    struct MessageMetadata {
        let mood: String?         // "relaxing", "exciting", "thoughtful"
        let genre: String?        // "fantasy", "biography", "sci-fi"
        let timeContext: String?  // "morning", "holiday", "travel"
    }
}
```

### Integration with Existing Systems

#### 1. RecommendationEngine (Existing)
- **Keep**: Current taste profile analysis
- **Enhance**: Add conversation context to prompts
- **Add**: Multi-turn conversation support

#### 2. OptimizedPerplexityService (Existing)
- **Use**: Streaming responses for natural conversation
- **Enhance**: Add recommendation-specific system prompts
- **Add**: Citation support for "readers like you enjoyed..."

#### 3. LibraryViewModel (Existing)
- **Use**: Book collection for analysis
- **Add**: "Add to Library" action from recommendations
- **Track**: Recommendation acceptance rate

---

## 5. Feature Flag & Settings

### Experiment Toggle
**Location**: Settings → Developer Options

```swift
@AppStorage("experimentalConversationalRecommendations")
private var conversationalRecsEnabled = false
```

**Toggle UI**:
```
Developer Options
├── Experimental Quote Capture  [✓]
└── Conversational Recommendations  [ ]  ← NEW
    "Transform recommendations into a conversation
     with an AI bookseller who knows your taste"
```

### Analytics Tracking
- Conversation turn count (how many back-and-forths)
- Recommendation acceptance rate
- Most common opening contexts (mood, genre, etc.)
- Time to first accepted recommendation
- Feature engagement rate

---

## 6. Entry Points (NO NEW BUTTONS)

### Smart Discovery Without UI Clutter

**Philosophy**: Users discover recommendations naturally through existing flows, not by adding more buttons.

### 1. Ambient Mode (Primary - Natural Language)
**Trigger**: User asks naturally in ambient mode
**Examples**:
- "What should I read next?"
- "Recommend me something"
- "I'm looking for a good book"
- "Surprise me with a book"

**Behavior**: Ambient mode seamlessly becomes recommendation interface

### 2. Library Empty State (Organic Discovery)
**Trigger**: User has < 3 books in library

**Empty State Card**:
```
╭─────────────────────────────╮
│ Start Your Library          │
│                             │
│ Tell me what you love, and  │
│ I'll help you find more     │
│                             │
│ [Start Discovery] ←─────────┼─ Only button in empty state
╰─────────────────────────────╯
```

### 3. Post-Book Completion (Automatic)
**Trigger**: Automatic sheet appears when user marks book "Read"

```
╭─────────────────────────────╮
│ Finished [Book]?            │
│                             │
│ Want me to find your next   │
│ great read?                 │
│                             │
│ [Yes] [Not now]             │
╰─────────────────────────────╯
```

### 4. Search Bar Integration (Clever!)
**Trigger**: User types "recommend" or "what should I read" in search bar

**Behavior**: Instead of searching, triggers ForYouSheet
- Smart intent detection in search input
- "Looking for a recommendation? Let's talk..."

### 5. Long Press "+" Button (Hidden Gesture)
**Trigger**: User long-presses the "Add Book" button

**Behavior**: Haptic feedback + quick action menu appears
```
┌─────────────────────────────┐
│ Manual Entry                │
│ Scan Barcode                │
│ Discover (AI Recommendations)│  ← New option
└─────────────────────────────┘
```

### 6. Pull-to-Discover (Experimental Toggle)
**Trigger**: User pulls down on library view (when at top)

**Behavior**: Instead of refresh, reveals recommendation prompt
- Only enabled if experiment flag is on
- Subtle hint on first use

### 7. Settings Deep Link
**Location**: Settings → Recommendations → "Get Recommendations Now"

**Purpose**: Fallback entry point for users who can't find it

---

## 7. Fast-Track Implementation Plan

### Day 1: Core Service
- [ ] Create `ConversationalRecommendationEngine.swift` (2-3 hours)
- [ ] Implement conversation state machine (2 hours)
- [ ] Add multi-turn prompt generation (1 hour)
- [ ] Test with mock responses (1 hour)

### Day 2: UI Foundation
- [ ] Create `ForYouSheet.swift` base structure (2 hours)
- [ ] Implement 2-3 book card layout (3 hours)
- [ ] Add message threading UI (2 hours)
- [ ] Wire up to ConversationalEngine (1 hour)

### Day 3: Integration & Polish
- [ ] Ambient mode integration (2 hours)
- [ ] Add all entry points (3 hours)
- [ ] Animations and transitions (2 hours)
- [ ] Test end-to-end flow (1 hour)

### Day 4: Edge Cases & Testing
- [ ] Handle error states (1 hour)
- [ ] Add experiment toggle (30 min)
- [ ] Analytics tracking (1 hour)
- [ ] Internal testing & fixes (3 hours)

### Day 5: Final Polish
- [ ] Accessibility pass (1 hour)
- [ ] Performance optimization (1 hour)
- [ ] TestFlight build (30 min)
- [ ] Documentation (30 min)

**Total: 3-5 days to production-ready** (working incrementally, testing as we go)

---

## 8. Success Metrics

### Quantitative
- **Engagement**: % of users who open ForYouSheet
- **Conversation Length**: Average turns per session
- **Conversion**: % of recommendations added to library
- **Retention**: Do users return to feature?

### Qualitative
- **Ben's Approval**: Does it match his bookstore vision?
- **User Feedback**: TestFlight reviews mention it positively?
- **Natural Feel**: Does it feel conversational, not robotic?
- **Discoverability**: Do users find it without being told?

---

## 9. Design Principles

### 1. Conversational, Not Transactional
- No lists of 10 books dumped at once
- Progressive revelation through dialogue
- User guides the experience

### 2. Elegant, Not Cluttered
- Liquid glass aesthetic
- Breathing room in layout
- Smooth, purposeful animations
- Single focus per screen state

### 3. Personal, Not Generic
- "After reading X..." not "People who liked X..."
- Specific reasoning, not generic praise
- Acknowledges user's actual library

### 4. Delightful, Not Pushy
- User can dismiss easily
- No pressure to accept recommendations
- Playful but respectful tone
- Can pause and return later

---

## 10. Open Questions

1. **Voice Integration**: Should Siri handle "recommend a book" intent?
2. **Social Proof**: Show "readers like you enjoyed..." citations?
3. **Library Import**: Offer to import from Goodreads for better recommendations?
4. **Seasonal Content**: Create special holiday recommendation flows?
5. **Series Awareness**: Detect when user is mid-series and avoid spoilers?

---

## Next Steps

1. **Review this design** with you
2. **Gather additional feedback** on UI direction
3. **Begin Phase 1 implementation** (ConversationalRecommendationEngine)
4. **Create prototype** for Ben to test

---

**Notes**:
- This builds on ALL existing infrastructure (no rewrites)
- Maintains Epilogue's design language (liquid glass, atmospheric gradients)
- Follows the app's conversational AI patterns (ambient mode style)
- Respects privacy (on-device analysis + optional cloud AI)
- Easy to toggle off if users don't want it
