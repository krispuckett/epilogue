# Book Recommendation Chat - Comprehensive Design Document

## Table of Contents
1. [Conversation Design](#1-conversation-design)
2. [Recommendation Intelligence](#2-recommendation-intelligence)  
3. [UI/UX Patterns](#3-uiux-patterns)
4. [Integration Points](#4-integration-points)
5. [Technical Architecture](#5-technical-architecture)
6. [Personality & Tone](#6-personality--tone)
7. [Prompt Templates](#7-prompt-templates)
8. [Example Conversations](#8-example-conversations)

---

## Executive Summary

A conversational book discovery interface that leverages Epilogue's existing:
- Chat infrastructure (UnifiedChatView, OptimizedPerplexityService)
- Recommendation engine (RecommendationEngine, LibraryTasteAnalyzer)
- Voice capabilities (VoiceRecognitionManager, ambient mode)
- Rich reading data (library, highlights, notes, sessions)

**Core Insight**: Users have rich behavioral data that can power deeply personalized recommendations through natural conversation.

**Implementation Strategy**: Add new session type to existing UnifiedChatView rather than building separate interface.

---

## 1. CONVERSATION DESIGN

### 1.1 First Message (System Greeting)

The greeting adapts based on user state:

**State 1: New User (Empty Library)**
```
📖 Welcome! I'm your book discovery companion.

I can help you find books based on:
  • Mood or vibe you're going for
  • Authors or books you've enjoyed
  • Topics or themes you're curious about
  • Even just "surprise me with something great"

What kind of book are you in the mood for?
```

**State 2: Returning User (Has Library, No Recent Activity)**
```
📚 Hey! Ready to discover your next read?

I see you enjoy [top genre from library]. I can suggest
something similar, or help you explore a completely  
different direction.

What sounds good?
```

**State 3: Active Reader (Recent completion or progress)**
```
✨ Welcome back!

I noticed you just finished [Recent Book] - that's a [tone]
story about [theme]. Want something in a similar vein, or
ready for something totally different?
```

**State 4: Mood-Based (Time of day/season awareness)**
```
🌙 Good evening!

Perfect time for reading. Are you thinking something  
immersive to get lost in, or lighter fare to wind down?
```

### 1.2 Conversation Flow Decision Tree

```
User Message Received
    ↓
┌────────────────────────────────────────┐
│ Intent Classification                   │
├────────────────────────────────────────┤
│ 1. Specific (book/author mentioned)    │ → Immediate recommendation
│ 2. Clear genre/mood/theme              │ → Immediate recommendation  
│ 3. Comparative ("like X")              │ → Immediate recommendation
│ 4. Vague ("something good")            │ → Ask ONE clarifying question
│ 5. Mood-based ("I'm bored")            │ → Ask about desired outcome
│ 6. Exploratory ("surprise me")         │ → Library analysis → Recommend
└────────────────────────────────────────┘
```

### 1.3 Clarifying Questions Strategy

**Golden Rule**: Maximum 2 questions before recommending.  
Users came for suggestions, not interrogation.

**Question Progression (Pick 1-2 max):**

1. **First Filter: Fiction vs. Non-Fiction** (if completely vague)
   - "Are you thinking fiction or non-fiction?"
   
2. **Second Filter: Mood/Pace** (most useful question)
   - "What's the vibe - something gripping and fast-paced, or more thoughtful and literary?"
   - "Looking to escape reality, or learn something new?"
   - "Light and fun, or deep and challenging?"

3. **Third Filter: Length** (rarely needed)
   - "Short enough to finish this weekend, or a longer commitment?"

**Anti-Patterns to Avoid:**
❌ "What's your favorite genre?" (Too academic)
❌ "On a scale of 1-10..." (Too formal)
❌ Multiple questions in one message (Overwhelming)
✅ Single, conversational, choice-based questions

### 1.4 When to Recommend vs. Ask

| User Input | Response Type | Reasoning |
|------------|---------------|-----------|
| "A mystery" | **Recommend 3-4** | Genre is clear, show variety (cozy/noir/psychological) |
| "Like Agatha Christie" | **Recommend immediately** | Clear reference point |
| "Something good" | **Ask 1 question** | Too vague, need fiction/non-fiction |
| "I'm bored" | **Ask about outcome** | Bored → escape or stimulation? |
| "For my book club" | **Ask about club's taste** | Social context needs clarification |
| "Surprise me" | **Analyze library → Recommend** | Use taste profile for unexpected pick |
| "Beach read" | **Recommend immediately** | Clear mood/context |
| "Make me cry" | **Recommend immediately** | Clear emotional goal |

### 1.5 Conversation Memory

**Within Session:**
- Remember all books mentioned (theirs and recommendations)
- Track "already read" rejections
- Remember stated preferences ("I prefer female authors")
- Recall mood/context from start of conversation

**Across Sessions:**
- Remember which books were recommended before (don't repeat)
- Track conversation history (can they reference "that book you suggested last week")
- Learn from patterns (always rejects romance → stop suggesting)

**Implementation:**
- Use existing `ConversationMemory` service from ambient mode
- Store in `AISession` with `sessionType: .bookDiscovery`
- Persist conversation history per user

### 1.6 Handling Common Responses

**"I've already read that"**
```
Got it! Let me try a different direction.

[Immediately suggest alternative]

Have you read [Different Book]? It has [shared appeal]
but approaches it through [different angle].
```

**"Tell me more about [Recommended Book]"**
```
[Book Title] by [Author]

[2-3 sentence spoiler-free summary]

What makes it special:
• [Key theme/appeal point 1]
• [Key theme/appeal point 2]

[Why it fits their request]

Want me to add it to your library, or keep exploring?
```

**"I don't like [genre/author/theme]"**
```
Noted - no [genre/author/theme]. Let me pivot.

[Suggest different direction entirely]
```

**"Something shorter/longer"**
```
[Adjust recommendations by page count, mention length]

[Book] is about [X] pages - perfect for [timeframe]
```

