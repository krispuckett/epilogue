# For You Sheet - UI Specification

**Design Language**: iOS 26 Liquid Glass with Epilogue's Atmospheric Gradients

---

## Screen States

### State 1: Opening Question
```
┌───────────────────────────────────────┐
│ ┌───────────────────────────────────┐ │
│ │ For You                        ✕  │ │ ← Liquid glass header (.thin)
│ └───────────────────────────────────┘ │
│                                       │
│   ╭─────────────────────────────╮    │
│   │ 💭 System                   │    │ ← Glass bubble (.ultraThin)
│   │                             │    │
│   │ What are you in the         │    │
│   │ mood for today?             │    │
│   ╰─────────────────────────────╯    │
│                                       │
│   ┌─────────────────────────────┐    │
│   │  Something light            │    │ ← Quick reply pills
│   └─────────────────────────────┘    │   Glass (.regular)
│                                       │
│   ┌─────────────────────────────┐    │
│   │  A challenge                │    │
│   └─────────────────────────────┘    │
│                                       │
│   ┌─────────────────────────────┐    │
│   │  Surprise me                │    │
│   └─────────────────────────────┘    │
│                                       │
│   ┌───────────────────┬─────────┐    │
│   │ Tell me more... ⌨️ │  🎤     │    │ ← Input bar (glass)
│   └───────────────────┴─────────┘    │
│                                       │
└───────────────────────────────────────┘
```

### State 2: AI Reasoning
```
┌───────────────────────────────────────┐
│ ┌───────────────────────────────────┐ │
│ │ For You                        ✕  │ │
│ └───────────────────────────────────┘ │
│                                       │
│   ╭─────────────────────────────╮    │
│   │ 💭 System                   │    │
│   │                             │    │
│   │ What are you in the         │    │
│   │ mood for today?             │    │
│   ╰─────────────────────────────╯    │
│                                       │
│       ╭─────────────────────────╮    │
│       │ 🗣️ You                  │    │ ← User message
│       │                         │    │   (right-aligned)
│       │ Something light         │    │
│       ╰─────────────────────────╯    │
│                                       │
│   ╭─────────────────────────────╮    │
│   │ 💭 System                   │    │
│   │                             │    │
│   │ Perfect! I know you loved   │    │ ← Streaming text
│   │ Project Hail Mary's humor.  │    │   appears word by word
│   │ Let me find something with  │    │
│   │ that same wit and warmth... │    │
│   │                             │    │
│   │ ▋                           │    │ ← Typing indicator
│   ╰─────────────────────────────╯    │
│                                       │
└───────────────────────────────────────┘
```

### State 3: Multiple Book Presentation (2-3 at once)
```
┌───────────────────────────────────────┐
│ ┌───────────────────────────────────┐ │
│ │ For You                        ✕  │ │
│ └───────────────────────────────────┘ │
│                                       │
│   ╭─────────────────────────────╮    │
│   │ 💭 System                   │    │
│   │                             │    │
│   │ Based on your love of       │    │
│   │ Project Hail Mary, here are │    │
│   │ 3 books I think you'd love: │    │
│   ╰─────────────────────────────╯    │
│                                       │
│  ╔═══════════════════════════════╗   │
│  ║ ┌───────┐ The Midnight       ║   │ ← Book 1
│  ║ │[Cover]│ Library             ║   │   Compact card
│  ║ └───────┘ Matt Haig           ║   │
│  ║                                ║   │
│  ║ Same warmth and humor, but    ║   │ ← Short reasoning
│  ║ more contemplative            ║   │   (1-2 sentences)
│  ║                                ║   │
│  ║ [Add] [Pass]                  ║   │ ← Inline buttons
│  ╚═══════════════════════════════╝   │
│                                       │
│  ╔═══════════════════════════════╗   │
│  ║ ┌───────┐ Station Eleven      ║   │ ← Book 2
│  ║ │[Cover]│ Emily St. John      ║   │
│  ║ └───────┘ Mandel              ║   │
│  ║                                ║   │
│  ║ Post-apocalyptic but hopeful. ║   │
│  ║ Literary like McCarthy        ║   │
│  ║                                ║   │
│  ║ [Add] [Pass]                  ║   │
│  ╚═══════════════════════════════╝   │
│                                       │
│  ╔═══════════════════════════════╗   │
│  ║ ┌───────┐ The House in the    ║   │ ← Book 3
│  ║ │[Cover]│ Cerulean Sea        ║   │
│  ║ └───────┘ T.J. Klune          ║   │
│  ║                                ║   │
│  ║ Cozy fantasy with that same   ║   │
│  ║ wit you loved in Weir         ║   │
│  ║                                ║   │
│  ║ [Add] [Pass]                  ║   │
│  ╚═══════════════════════════════╝   │
│                                       │
│   ┌─────────────────────────────┐    │
│   │  None of these? Tell me     │    │ ← Refinement
│   │  more about what you want   │    │
│   └─────────────────────────────┘    │
│                                       │
└───────────────────────────────────────┘
```

### State 4: Refinement Conversation
```
┌───────────────────────────────────────┐
│ ┌───────────────────────────────────┐ │
│ │ For You                        ✕  │ │
│ └───────────────────────────────────┘ │
│                                       │
│  [Previous messages scroll up...]     │
│                                       │
│       ╭─────────────────────────╮    │
│       │ 🗣️ You                  │    │
│       │                         │    │
│       │ More like that, but     │    │
│       │ with fantasy            │    │
│       ╰─────────────────────────╯    │
│                                       │
│   ╭─────────────────────────────╮    │
│   │ 💭 System                   │    │
│   │                             │    │
│   │ Ah! Humor + fantasy =       │    │
│   │ let me find you something   │    │
│   │ that blends both...         │    │
│   ╰─────────────────────────────╯    │
│                                       │
│  ╔═══════════════════════════════╗   │
│  ║  ┌─────────────┐              ║   │
│  ║  │   [Cover]   │  The House   ║   │ ← New recommendation
│  ║  │             │  in the      ║   │
│  ║  │             │  Cerulean    ║   │
│  ║  └─────────────┘  Sea         ║   │
│  ║                                ║   │
│  ║  T.J. Klune · 2020            ║   │
│  ║                                ║   │
│  ║  This has that same warmth    ║   │
│  ║  and wit as Weir, but in a    ║   │
│  ║  magical setting. Cozy        ║   │
│  ║  fantasy with laugh-out-loud  ║   │
│  ║  moments.                     ║   │
│  ║                                ║   │
│  ║  ┌────────────┐  ┌──────────┐ ║   │
│  ║  │ Add to     │  │   Pass   │ ║   │
│  ║  │  Library   │  │          │ ║   │
│  ║  └────────────┘  └──────────┘ ║   │
│  ╚═══════════════════════════════╝   │
│                                       │
└───────────────────────────────────────┘
```

---

## Color & Materials

### Background Gradient
**Matches ambient mode aesthetic**:
- Atmospheric gradient derived from most-read book covers
- Subtle, not distracting
- Dark mode: Deep blues/purples with color accents
- Light mode: Soft neutrals with color hints

### Glass Effects
```swift
// Header Bar
.glassEffect(.thin)
.tint(Color.white.opacity(0.7))

// System Message Bubbles
.glassEffect(.ultraThin)
.tint(Color.blue.opacity(0.1))

// User Message Bubbles
.glassEffect(.ultraThin)
.tint(Color.green.opacity(0.1))

// Book Cards
.glassEffect(.regular)
.shadow(radius: 20)

// Action Buttons
.glassEffect(.regular)
.tint(Color.white.opacity(0.05))

// Quick Reply Pills
.glassEffect(.thin)
```

### Typography
```swift
// System messages
Font.system(size: 16, weight: .regular)
Color.white.opacity(0.9)

// User messages
Font.system(size: 16, weight: .medium)
Color.white.opacity(0.95)

// Book title
Font.system(size: 24, weight: .bold)

// Book author
Font.system(size: 18, weight: .regular)

// Reasoning text
Font.system(size: 15, weight: .regular)
lineSpacing(4)

// Button labels
Font.system(size: 16, weight: .semibold)
```

---

## Animations

### Entry Animation
```swift
// From Library button tap
1. Library button scales down to 0.95
2. Full-screen overlay fades in (0.3s)
3. ForYouSheet morphs up from button position
4. Background gradient cross-fades in
5. First message fades up with slight bounce
```

### Message Animations
```swift
// System messages
- Fade in from 0 → 1 (0.4s ease out)
- Translate Y: 20 → 0
- Text streams in word by word (like ChatGPT)

// User messages
- Fade in from 0 → 1 (0.3s ease out)
- Translate Y: -10 → 0
- Scale: 0.95 → 1.0
```

### Book Card Reveal
```swift
// Dramatic entrance
1. Card fades in (0.5s)
2. Cover image: blur(10) → blur(0) + scale(1.05 → 1.0)
3. Text content: opacity(0 → 1) staggered by 0.1s
4. Buttons: scale(0.8 → 1.0) with spring animation
```

### Action Feedback
```swift
// "Add to Library" button
1. Button: scale(1.0 → 0.95 → 1.1) (spring)
2. Haptic: .success
3. Checkmark appears
4. Card fades out with scale down
5. Next recommendation slides up

// "Pass" button
1. Button: scale(1.0 → 0.95)
2. Haptic: .light
3. Card slides left and fades out
4. Next recommendation slides up from right
```

### Typing Indicator
```swift
// While AI is thinking
Three dots that:
- Fade in/out (0.6s, repeating)
- Scale: 1.0 → 1.2 → 1.0
- Staggered by 0.2s each
```

---

## Micro-Interactions

### Quick Reply Pills
```swift
// Hover/Press state
- Background: .glassEffect(.regular) → .glassEffect(.thick)
- Scale: 1.0 → 0.98 (on press)
- Haptic: .light (on press)
```

### Book Cover
```swift
// Long press to preview
- Scale: 1.0 → 1.05
- Shadow: 20 → 40
- Detail view modal appears
```

### Scroll Behavior
```swift
// Conversation thread
- Auto-scrolls to newest message
- Scroll indicator: Glass tinted
- Over-scroll: Elastic bounce
- Pull to refresh: Rotates "🔄" icon
```

---

## Responsive Layout

### iPhone Sizes
**iPhone 15 Pro (Standard)**:
- Book card: 90% screen width
- Cover image: 140pt × 210pt
- Padding: 20pt sides

**iPhone 15 Pro Max (Large)**:
- Book card: 85% screen width
- Cover image: 160pt × 240pt
- Padding: 24pt sides

**iPhone SE (Compact)**:
- Book card: 95% screen width
- Cover image: 120pt × 180pt
- Padding: 16pt sides
- Reduce button font size to 14pt

### iPad (Future)
- Two-column layout: Conversation | Book cards
- Larger cover images (200pt × 300pt)
- Side-by-side "Add" / "Pass" buttons

---

## Accessibility

### VoiceOver
```swift
// System messages
.accessibilityLabel("Recommendation assistant says: \(messageText)")

// Book cards
.accessibilityLabel("\(title) by \(author). \(reasoning)")

// Action buttons
.accessibilityLabel("Add \(title) to your library")
.accessibilityHint("Double tap to add this book")
```

### Dynamic Type
- Support all text sizes
- Book cards expand vertically
- Minimum touch target: 44pt

### Reduce Motion
- Skip morphing animations
- Use fade transitions only
- No parallax effects

### Color Blindness
- Don't rely on color alone for states
- Use icons + labels for actions
- High contrast mode support

---

## Edge Cases

### No Internet
```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I need internet to search   │
│ for new recommendations.    │
│ Check your connection?      │
╰─────────────────────────────╯

  ┌─────────────────┐
  │  Try Again      │
  └─────────────────┘
```

### Empty Library
```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ To give great              │
│ recommendations, I need to  │
│ know what you love.         │
│                             │
│ Add a few books to your     │
│ library first?              │
╰─────────────────────────────╯

  ┌─────────────────┐
  │  Add Books      │
  └─────────────────┘
```

### API Quota Exceeded
```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I've reached my thinking    │
│ limit for today. Try again  │
│ tomorrow?                   │
╰─────────────────────────────╯

  ┌─────────────────┐
  │  Got it         │
  └─────────────────┘
```

### User Rejects All Suggestions
```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Hmm, I'm not nailing your   │
│ taste yet. Want to tell me  │
│ more about what you're      │
│ looking for?                │
╰─────────────────────────────╯

  ┌─────────────────┐
  │  Start Over     │
  └─────────────────┘
```

---

## Technical Notes

### Performance
- Lazy load book covers (downsampled to 400pt)
- Cache AI responses for 1 hour
- Prefetch next 3 recommendations
- Limit conversation to 10 turns (then reset)

### Privacy
- All taste analysis happens on-device
- Only send anonymized preferences to Perplexity
- Never send full library list to cloud
- User can clear conversation history

### Testing Hooks
```swift
#if DEBUG
// Simulate slow AI response
@AppStorage("debugSlowAIResponse") var debugSlowAI = false

// Use mock recommendations
@AppStorage("debugMockRecommendations") var useMockData = false

// Show conversation state
@AppStorage("debugShowConversationState") var showDebugState = false
#endif
```

---

## Design Decisions (Confirmed)

1. ✅ **Button-based interaction** - Add/Pass buttons, no swiping
2. ✅ **Show 2-3 recommendations at once** - "Here's why each would work for you"
3. ✅ **Chat conversational-based** - Natural dialogue, not form-filling
4. ✅ **No new library buttons** - Smart entry points through existing flows
5. ✅ **Fast implementation** - 3-5 days, not weeks

## Open Questions

1. **Voice input support?** Allow users to speak their preferences in the sheet?
2. **Save conversation history?** Or ephemeral session-only?
3. **Share recommendations?** "Send to friend" feature?

