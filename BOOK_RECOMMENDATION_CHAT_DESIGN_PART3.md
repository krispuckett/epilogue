## 3. UI/UX PATTERNS

### 3.1 Chat Interface Design

**Base Component**: Extend existing `UnifiedChatView.swift` with new session type

#### Message Layout

```
┌─────────────────────────────────────────┐
│ 📚 Book Discovery                    [X]│ ← Header
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────┐          │
│  │ User Message             │          │ ← User bubble (left)
│  │ "I need a mystery"       │          │
│  └──────────────────────────┘          │
│                            [timestamp]  │
│                                         │
│          ┌──────────────────────────┐  │
│          │ Assistant Message        │  │ ← Assistant (right)
│          │ "Great choice! Mystery..."│  │
│          └──────────────────────────┘  │
│                            [timestamp]  │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  📖 BOOK CARD                   │   │ ← Book recommendation
│  │  [Cover]  The Murder of         │   │   card (inline)
│  │           Roger Ackroyd          │   │
│  │           Agatha Christie        │   │
│  │                                  │   │
│  │  "Classic mystery with brilliant│   │
│  │   unreliable narrator..."        │   │
│  │                                  │   │
│  │  [Add to Library] [Tell Me More]│   │
│  └─────────────────────────────────┘   │
│                                         │
├─────────────────────────────────────────┤
│ [Text Input] "Or something lighter..." │ ← Input bar
│ [Mic] [Emoji]                     [Send]│
└─────────────────────────────────────────┘
```

#### Visual Specs (Using Existing DesignSystem)

**Colors:**
- Background: `DesignSystem.surfaceBackground`
- Message bubbles: `.glassEffect()` (NO background before!)
- User bubble: `DesignSystem.glassLight` + blue tint
- Assistant bubble: `DesignSystem.glassMedium`
- Text: `DesignSystem.textPrimary` / `.textSecondary`

**Spacing:**
- Message padding: `.md` (16pt)
- Between messages: `.sm` (12pt)
- Card padding: `.lg` (24pt)
- Edge margins: `.md` (16pt)

**Typography:**
- User message: `.body` (17pt), regular weight
- Assistant message: `.body` (17pt), regular weight
- Book title: `.title3` (20pt), semibold
- Book author: `.subheadline` (15pt), regular, secondary color
- Reasoning text: `.footnote` (13pt), regular, secondary color

**Corner Radius:**
- Message bubbles: `.medium` (12pt)
- Book cards: `.card` (16pt)
- Buttons: `.small` (8pt)

**Animations:**
- Message appear: `DesignSystem.springStandard`
- Streaming text: Fade in per word
- Book card appear: Slide up + fade (300ms ease)

### 3.2 Book Recommendation Card Design

**Compact Card (Inline in Chat)**

```
┌──────────────────────────────────────────┐
│ [📷 Cover     ]  The Name of the Wind    │
│ [   150x225px]  Patrick Rothfuss         │
│ [            ]                            │
│ [            ]  ⭐️⭐️⭐️⭐️⭐️ 4.5 · 662 pages   │
│                                           │
│  💡 "You loved lyrical prose in [Book    │
│      from Library]. This has stunning    │
│      language and deep worldbuilding."   │
│                                           │
│  [➕ Add to Library]  [📖 Tell Me More]  │
└──────────────────────────────────────────┘
```

**Expanded Card (After "Tell Me More")**

```
┌──────────────────────────────────────────┐
│ The Name of the Wind                     │
│ Patrick Rothfuss · 2007                  │
│ ⭐️ 4.5 · 662 pages · Fantasy             │
├──────────────────────────────────────────┤
│ [Cover Image - 300x450px]                │
├──────────────────────────────────────────┤
│ About This Book                          │
│                                           │
│ [2-3 sentence spoiler-free summary       │
│  from BookModel.smartSynopsis]           │
│                                           │
│ Key Themes                                │
│ • Magic · Coming of Age · Music          │
│                                           │
│ Similar To                                │
│ • The Lies of Locke Lamora               │
│ • The Way of Kings                        │
│                                           │
│ Why This Fits                             │
│ "You highlighted poetic passages in      │
│  [Previous Book]. Rothfuss's prose is    │
│  considered some of the most beautiful   │
│  in fantasy."                             │
│                                           │
│ [➕ Add to Library]  [✕ Not Interested]  │
└──────────────────────────────────────────┘
```

**Implementation:**
- Use existing `BookCard.swift` as base
- Add new variant: `.recommendationInline` and `.recommendationExpanded`
- Show atmospheric gradient background (use `BookAtmosphericGradientView`)
- Extract colors from cover with `ColorIntelligenceEngine`

### 3.3 Quick Actions

**Primary Actions** (Always visible):
1. **Add to Library** 
   - Adds book to reading list
   - Shows confirmation toast
   - Continues conversation ("Added! Want more like this?")

2. **Tell Me More**
   - Expands card with full details
   - Shows synopsis, themes, similar books
   - Why it was recommended

**Secondary Actions** (Revealed on long-press or swipe):
3. **Not Interested**
   - Removes from suggestions
   - Learns preference (don't recommend similar)
   - Continues conversation ("Got it! Let me try something else")

4. **Read Sample**
   - Opens Google Books preview (if available)
   - External link

5. **Share**
   - Share book details
   - "Recommended by Epilogue"

**Voice Quick Actions** (If in voice mode):
- "Add it" → Add to library
- "Tell me more" → Expand card
- "Next" → Skip to next recommendation
- "Something else" → Different direction

### 3.4 Conversation Context Header

**Show current context at top:**

```
┌──────────────────────────────────────┐
│ 📚 Book Discovery                    │
│ Finding: Mystery novels · Fast-paced │
└──────────────────────────────────────┘
```

**Context Types:**
- Empty state: "What are you in the mood for?"
- Active search: "Finding: [criteria]"
- After library analysis: "Based on your [genre] collection"
- Exploratory: "Discovering something new"

**Tap to edit:**
- User can tap header to change criteria
- "Actually, I want something lighter"
- Resets conversation context

### 3.5 Streaming Response Pattern

**Use existing streaming from OptimizedPerplexityService:**

```
Assistant: "Let me find something perfect..."
           [Spinner 2 seconds]
           
Assistant: "Based on your love of mystery,
           I have three recommendations..."
           [Stream in word by word]
           
[Book Card 1 fades in]
[Book Card 2 fades in after 300ms]
[Book Card 3 fades in after 600ms]
```

**Progressive Loading:**
1. Show typing indicator
2. Stream text response
3. Show book cards with stagger effect
4. Load cover images asynchronously

### 3.6 Conversation History & Scrollback

**Session Management:**
- Each discovery session creates new `AISession` with `sessionType: .bookDiscovery`
- Sessions persist in SwiftData
- User can scroll back through history

**Session List View:**

```
┌──────────────────────────────────────┐
│ Book Discovery                       │
├──────────────────────────────────────┤
│ ⏱️ Today                             │
│  "Mystery recommendations"           │
│   3 books suggested                  │
│                                       │
│ ⏱️ 3 days ago                        │
│  "Something like Dune"               │
│   5 books suggested, 2 added         │
│                                       │
│ ⏱️ Last week                         │
│  "Summer reading"                    │
│   4 books suggested, 1 added         │
└──────────────────────────────────────┘
```

**Tap to restore:**
- Tapping session loads conversation history
- Can continue conversation from where left off
- See which books were added

### 3.7 Empty States

**No Library Yet:**
```
📚 Start Your Reading Journey

I can recommend books based on:
• Your favorite authors or books
• Mood or vibe you're after
• Genres or topics you love

Tell me what you're looking for, or say
"surprise me" for a curated pick!
```

**No Results Found:**
```
Hmm, I'm not finding great matches for
"[user's request]".

Could you tell me a bit more about what
you're hoping for? Like:
• A book or author you enjoyed
• The mood or feeling you want
• Fiction vs. non-fiction preference
```

**All Recommendations Rejected:**
```
Alright, let me try a totally different
direction!

What if we approached this from a different
angle - what's a book you absolutely loved?
I'll find something with similar appeal but
different in [the ways they rejected].
```

### 3.8 Transitions & Navigation

**From Chat to Book Detail:**
- Tap book card → Navigate to full `BookDetailView`
- Book detail shows:
  - Full metadata
  - Reading session history (if added)
  - AI chat about this book
  - Add to library / Mark as reading

**From Book Detail back to Discovery:**
- Back button returns to conversation
- Conversation state preserved
- Can continue asking for more

**From Library to Discovery:**
- Library view has "Discover More" button
- Opens discovery chat with context:
  "I see you like [pattern from library]. Want more?"

**From Ambient Mode to Discovery:**
- "Recommend books like this" voice command
- Opens discovery with current book as reference

### 3.9 Voice Integration

**Voice Input:**
- Mic button in input bar
- Uses existing `VoiceRecognitionManager`
- Transcription shows in real-time
- Send on pause/silence detection

**Voice Output:**
- Optional TTS reading recommendations
- Uses `VoiceSynthesizer` from ambient mode
- Reads: Title, Author, Why it's recommended
- User can say "tell me more" or "next"

**Voice-First Discovery Mode:**
- Activated from ambient mode
- Full voice interaction
- "Hey Epilogue, recommend a mystery"
- Hands-free browsing

### 3.10 Accessibility

**VoiceOver Support:**
- Book cards have clear labels
- "The Name of the Wind by Patrick Rothfuss. Rated 4.5 stars. Recommended because you enjoy lyrical prose."
- Actions clearly labeled: "Add to Library button", "Tell Me More button"

**Dynamic Type:**
- All text scales with system font size
- Book cards reflow for larger text
- Minimum touch target 44x44pt

**Color & Contrast:**
- Text meets WCAG AA standards
- Glass effects maintain readability
- High contrast mode support

**Reduced Motion:**
- Respect accessibility settings
- No streaming animation, show full text
- Fade transitions only, no slides

