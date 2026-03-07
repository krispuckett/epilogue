# Epilogue Marketing Page Brief

> A complete feature inventory, design system, and creative direction for building the Epilogue marketing website. This document is self-contained — pass it to a new Claude Code session to design and build the site.

---

## What Is Epilogue?

Epilogue is an iOS reading companion that transforms how you think about books. It's not a book tracker. It's not a reading log. It's the space between finishing a page and forming a thought — captured, connected, and remembered.

Built for iOS 26 with Liquid Glass, Metal shaders, and a multi-model AI architecture that routes questions to the right intelligence (Claude for literary analysis, Perplexity for web-connected facts, Foundation Models for instant on-device answers). Every book creates its own visual world through color extraction from covers. Every note you write becomes part of a knowledge graph that finds connections you'd never see on your own.

622 commits. 6.5 months. Built entirely through Claude Code by a designer who doesn't write traditional code.

---

## The Pitch (Hero Section)

**Headline options:**
- "Your books remember everything. Now your app does too."
- "The reading companion that thinks alongside you."
- "Every book deserves more than a star rating."
- "Read. Capture. Connect. Remember."

**Subheadline:**
Epilogue is an AI-powered reading companion for iOS that captures your thoughts, finds hidden connections across your library, and creates a living record of your reading life — all wrapped in an interface that transforms with every book you open.

---

## Feature Sections (Marketing Hierarchy)

### 1. Ambient Mode — "Never Leave the Page"
**The headline feature. Nothing else does this.**

While you're reading a physical book, Epilogue becomes an ambient companion:
- **Voice capture** — speak a thought, it's transcribed and saved instantly
- **Camera OCR** — photograph a page, select text, save as a quote with attribution
- **Live transcription** — real-time speech-to-text with Whisper
- **Contextual AI** — ask questions about your book mid-read, get answers that respect where you are (no spoilers)
- **Atmospheric gradients** — the screen breathes with colors extracted from your book's cover, responsive to your voice

The interface is voice-first. You never have to put the book down to capture a thought.

**Key differentiator:** Other apps make you switch contexts. Epilogue sits beside you while you read.

---

### 2. Knowledge Graph — "See What You've Really Been Reading"
**The intelligence layer that makes Epilogue different from every book tracker.**

Every note, quote, and conversation feeds a semantic knowledge graph:
- **Automatic entity extraction** — characters, themes, concepts, locations pulled from your notes using on-device AI (never leaves your phone)
- **300-dimensional semantic embeddings** — fuzzy "vibe" search across your entire library
- **Cross-book connections** — "The Odyssey and Dune both explore the hero's return"
- **Thematic pattern discovery** — "You're drawn to stories about isolation across 5 different books"
- **Reading milestones** — emerging interests, author patterns, quote clusters

**Key differentiator:** Goodreads tracks what you read. Epilogue understands *why* you read.

---

### 3. Multi-Model AI Companion — "The Right Brain for Every Question"
**Not one AI. An orchestra of them.**

Epilogue's Intelligent Query Router analyzes every question in <1ms and sends it to the best model:

| Question Type | Routed To | Why |
|---|---|---|
| "What does this symbolism mean?" | Claude | Deep literary analysis |
| "What movie was this adapted into?" | Perplexity/Sonar | Web-connected facts with citations |
| "Who is Frodo?" | Foundation Models | Instant, on-device, no network needed |
| "Compare this to 1984" | Hybrid (both) | Needs both research and analysis |

Additional intelligence:
- **Series spoiler protection** — knows you're on Book 3 of 5, won't spoil Book 4
- **Reading-progress awareness** — 30% through? Answers only reference events up to that point
- **Citation tracking** — every web-sourced answer includes credibility-scored sources
- **Memory across sessions** — "Building on what we discussed yesterday about..."
- **Follow-up suggestions** — contextually relevant next questions, filtered for spoilers

**Key differentiator:** Most apps call one API. Epilogue routes to the right intelligence, caches responses, prevents spoilers, cites sources, and remembers what you've discussed before.

---

### 4. Book-Derived Atmospheric Design — "Every Book Is Its Own World"
**The app literally looks different for every book.**

Epilogue extracts color palettes from book covers using a ColorCube 3D histogram in OKLAB color space:
- **Primary, secondary, accent, and background colors** derived from each cover
- **Atmospheric gradients** that breathe with subtle animation
- **Dark covers get special treatment** — multi-scale analysis captures small accent colors from title bars and emblems
- **Voice-responsive visuals** — gradients pulse and shift based on audio input in ambient mode
- **9 premium gradient themes** (Amber Glow, Ocean Depths, Forest Mist, Sunset Bloom, Midnight Hour, Volcanic Core, Aurora Borealis, Nebula Dreams, Daybreak)

The visual experience is atmospheric, not decorative. It creates mood. It honors the book.

**Key differentiator:** Every other reading app looks the same regardless of what you're reading. Epilogue transforms.

---

### 5. Reading Plans & Gentle Accountability — "Build the Habit Without the Guilt"

Reading plans that feel like a companion, not a coach:
- **Habit plans** — 7/14/21/30-day kickstarts with daily rituals
- **Reading challenges** — target books per month/year with flexible ambition levels
- **Timeline visualization** — day-by-day progress without shame
- **Streak tracking** — celebrates consistency without punishing breaks
- **Smart notifications** — gentle check-ins that adapt to your schedule
- **Pause without penalty** — life happens, your plan waits

The companion voice uses "we/let's" instead of "I/me." It reads alongside you.

**Key differentiator:** No gamification pressure. No "you missed 3 days" guilt. Just gentle nudges.

---

### 6. Rich Notes & Quotes — "Your Reading Journal, Elevated"

Capture every kind of reading thought:
- **Markdown-supported notes** with rich text formatting
- **Camera OCR quotes** from physical books with page attribution
- **Voice-transcribed notes** from ambient mode
- **Tag system** for organization
- **Favorites** for quick access
- **Smart filtering** — by book, by type, by tag, by date
- **Readwise export** — one-click sync to your highlight ecosystem
- **Markdown export** for portability

Sources tracked: manual, ambient session, OCR, transcription. Every note knows where it came from.

---

### 7. Social Reading — "Read Together, Privately"

A social layer designed around privacy, not surveillance:
- **Companion invitations** — invite one person to read the same book
- **Fuzzy progress sharing** — they see rough progress (0.0-1.0), not exact page numbers
- **Trail markers** — leave thoughts, quotes, and questions at chapter-level positions
- **Discovery ceremony** — when your companion reaches a marker, it's revealed like finding a note in a library book
- **No public profiles, no feeds, no followers** — just two people sharing a reading experience

**Key differentiator:** Social reading without the performance. No public shelves. No competitive reviews.

---

### 8. Session Summaries & Reflections — "Every Conversation Remembered"

After discussing a book with the AI:
- **AI-generated session reflections** — warm, literary summaries of what you explored
- **Thematic summaries** — what themes emerged, what questions lingered
- **Smart session titles** — not "Book Discussion #42" but titles that capture the essence
- **Emotional tone tracking** — curious, reflective, analytical, enthusiastic
- **Next-session prompts** — "Watch for this theme in your next chapter"

Reading sessions become literary events worth looking back on.

---

### 9. Vibe-Based Recommendations — "Find Books That Feel the Same"

Recommendations that reject genre shelving:
- **Mood-based discovery** — "I want something unsettling but beautiful"
- **Emotional vibe matching** — finds books with the same resonance, not the same plot
- **Taste profile analysis** — learns from your entire library, not one book
- **8 mood categories** — cozy, epic, thoughtful, emotional, challenging, surprising, comforting, unsettling
- **Google Books enrichment** — cover art and metadata for every recommendation

The system prompt explicitly says: *"NEVER just match by genre or author. Find the emotional thread that connects books across categories."*

**Key differentiator:** "You loved Project Hail Mary? Try The Martian" is boring. Epilogue finds surprising connections.

---

### 10. Deep iOS Integration — "It Belongs on Your Phone"

Epilogue is a first-class iOS citizen:
- **Home Screen widgets** — current reading, streak counter, ambient mode launcher, welcome back
- **Dynamic Island** — live activity during ambient sessions, welcome-back animations
- **Siri integration** — "Continue reading" with App Intents
- **Spotlight search** — find books system-wide
- **CloudKit sync** — library syncs across devices
- **Offline-first** — full functionality without network, queues sync for later
- **Liquid Glass UI** — native iOS 26 design language throughout

---

### 11. Book Enrichment — "Know Your Books Deeply"

When you add a book, Epilogue automatically generates:
- **Smart synopsis** — 2-3 sentences, spoiler-free, literary (not Wikipedia)
- **Key themes** — not just "fiction" but actual thematic content
- **Major characters** with roles
- **Setting and tone** descriptions
- **Literary style** classification
- **Series information** — name, order, total books

This enrichment powers every AI conversation. The companion doesn't just know you asked about a book — it understands the book.

---

### 12. Camera Book Scanner — "Add Books in Seconds"

Three ways to add books:
- **ISBN barcode scanning** — point, scan, added
- **Cover image detection** — recognize a book by its cover
- **Text search** — Google Books + Open Library fallback
- **Goodreads CSV import** — bring your entire library with metadata preservation
- **Custom cover upload** — for editions not in databases
- **Manual entry** — for the books that defy categorization

---

## By the Numbers

| Metric | Value |
|---|---|
| Development time | 6.5 months |
| Total commits | 622 |
| Active development days | 99 |
| Built with | Claude Code (by a designer, not a programmer) |
| iOS minimum | iOS 26 |
| AI models used | 3 (Claude, Perplexity/Sonar, Foundation Models) |
| Gradient themes | 9 |
| Widget types | 4 |
| Siri intents | 6 |
| Knowledge graph dimensions | 300 (NLEmbedding) |

---

## Design System for the Marketing Website

### Color Palette

**Background:** `#1C1B1A` (deep brown-black) — this is the app's native background, always dark

**Text on dark:**
- Primary: `#FFFFFF`
- Secondary: `rgba(255,255,255,0.70)`
- Tertiary: `rgba(255,255,255,0.50)`
- Quaternary: `rgba(255,255,255,0.30)`

**Surface colors:**
- Card: `rgba(255,255,255,0.05)`
- Hover: `rgba(255,255,255,0.10)`
- Pressed: `rgba(255,255,255,0.15)`

**Semantic colors:**
- Success: `rgb(51, 204, 102)` — bright green
- Warning: `rgb(255, 178, 51)` — golden yellow
- Error: `rgb(255, 77, 77)` — coral red
- Info: `rgb(51, 153, 255)` — sky blue

**Gradient theme accents (use for section backgrounds and hero animations):**

| Theme | Primary Color | CSS RGB |
|---|---|---|
| Amber Glow | Golden amber | `rgb(255, 166, 89)` |
| Ocean Depths | Bright teal | `rgb(13, 166, 209)` |
| Forest Mist | Vibrant green | `rgb(87, 158, 107)` |
| Sunset Bloom | Coral pink | `rgb(250, 115, 133)` |
| Midnight Hour | Electric blue | `rgb(56, 82, 184)` |
| Volcanic Core | Orange | `rgb(242, 89, 46)` |
| Aurora Borealis | Mint green | `rgb(115, 242, 191)` |
| Nebula Dreams | Purple | `rgb(166, 89, 242)` |
| Daybreak | Sky blue | `rgb(64, 153, 217)` |

### Glass Effect (CSS equivalent)

```css
.glass-card {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 0.5px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.glass-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, 0.1) 0%,
    transparent 50%
  );
  pointer-events: none;
}
```

### Typography

Use system font stack to match iOS feel:
```css
font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', system-ui, sans-serif;
```

**Scale:**
- Display: 57px / regular
- H1: 32px / semibold
- H2: 28px / semibold
- H3: 24px / semibold
- Title: 22px / medium
- Body: 16px / regular
- Caption: 14px / medium
- Label: 12px / medium
- Small: 11px / medium

**Letter spacing:**
- Tight: 0.6px (dense lists)
- Normal: 0.8px (default body)
- Wide: 1.2px (elegant spacing)
- Extra wide: 1.5px (premium headings)

### Spacing (8px grid)

```
4px   — xxs
8px   — xs
12px  — sm
16px  — md (standard)
24px  — lg
32px  — xl
48px  — xxl
64px  — xxxl
```

### Corner Radii

```
8px   — tags, badges
12px  — small controls
16px  — cards, sheets
20px  — larger cards
24px  — full-screen sheets
100px — pill buttons
```

### Shadows

```css
/* Subtle */
box-shadow: 0 2px 4px rgba(0, 0, 0, 0.10);

/* Card */
box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);

/* Elevated */
box-shadow: 0 6px 12px rgba(0, 0, 0, 0.20);

/* Floating */
box-shadow: 0 10px 20px rgba(0, 0, 0, 0.25);
```

### Animation

```css
/* Standard spring-like */
transition: all 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94);

/* Bouncy */
transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);

/* Smooth/ambient */
transition: all 0.4s cubic-bezier(0.25, 0.1, 0.25, 1.0);

/* Quick snap */
transition: all 0.2s cubic-bezier(0.25, 0.46, 0.45, 0.94);

/* Breathing gradient animation */
@keyframes breathe {
  0%, 100% { opacity: 0.6; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.02); }
}
animation: breathe 5s ease-in-out infinite;
```

### Mood & Principles

1. **Dark mode native** — no light mode. The site should feel like reading at night.
2. **Ambient & atmospheric** — gradients breathe, surfaces have depth, nothing is flat
3. **Literary & introspective** — the tone is thoughtful, not hype. Warm, not cold.
4. **Glass-forward** — translucent surfaces, subtle borders, layered depth
5. **Book-responsive** — if possible, hero sections should show how the app transforms based on different book covers
6. **Motion is purposeful** — never gratuitous. Subtle parallax, breathing gradients, gentle reveals on scroll
7. **Premium without pretension** — sophisticated but approachable

---

## Website Structure Recommendation

### Section Flow

1. **Hero** — app name, tagline, atmospheric gradient background (cycling through book-derived colors), phone mockup showing ambient mode
2. **Ambient Mode** — the headline feature, video or animation of voice capture + OCR
3. **Knowledge Graph** — visualization of thematic connections, "see what you've really been reading"
4. **AI Companion** — multi-model routing diagram, spoiler protection, conversation memory
5. **Visual Design** — book-derived gradients, "every book is its own world", side-by-side of different books creating different atmospheres
6. **Reading Plans** — gentle accountability, habit building, timeline visualization
7. **Notes & Quotes** — rich capture, camera OCR, voice transcription, export
8. **Social Reading** — trail markers, companion invitations, privacy-first
9. **iOS Integration** — widgets, Dynamic Island, Siri, Spotlight, CloudKit
10. **Recommendations** — vibe-based discovery, mood chips
11. **The Story** — "Built by a designer through Claude Code. 622 commits. Every line of code written in conversation." (This is a powerful narrative — lean into it)
12. **Download CTA** — App Store badge, final gradient flourish

### Content Tone

- First person plural ("we built", "we believe") or second person ("your library", "your thoughts")
- Literary references welcome — the audience reads
- No tech jargon in headlines. Technical details in supporting copy.
- Confident but not loud. The app speaks for itself.
- Avoid: "revolutionary", "game-changing", "powered by AI" as empty buzzwords
- Prefer: specific, concrete descriptions of what the feature actually does

### Asset Needs

- iPhone 16 Pro mockups showing:
  - Ambient mode with atmospheric gradient
  - Library view with book covers
  - Knowledge graph connections visualization
  - Camera OCR capturing a quote
  - Reading plan timeline
  - Session summary reflection
- Book cover images (for demonstrating color extraction)
- Gradient animations (CSS or Lottie)
- Optional: short video clips of the app in use

---

## Technical Notes for the Web Build

- **Framework:** Vite + React + TypeScript + Tailwind CSS
- **Components:** shadcn/ui for base components
- **Animations:** Framer Motion for scroll-triggered reveals and parallax
- **Gradients:** CSS animations with the 9 theme colors, potentially cycling on scroll
- **Glass effects:** `backdrop-filter: blur()` with layered surfaces
- **Responsive:** Mobile-first (the audience uses iPhones)
- **Performance:** Lazy load images, optimize animations for mobile GPU
- **Dark mode only** — no light mode toggle needed
- **Font:** System font stack (`-apple-system` etc.) to match iOS native feel

---

## Appendix: Full Feature Checklist

### Core Reading Experience
- [x] Book library with grid/list views
- [x] Reading status tracking (unread, reading, finished)
- [x] Reading progress (current page / total pages)
- [x] Half-star ratings (0.5 increments)
- [x] Book enrichment (synopsis, themes, characters, setting, tone)
- [x] Series detection and tracking

### Capture Methods
- [x] Manual text notes with markdown
- [x] Voice transcription (Whisper)
- [x] Camera OCR (multi-column detection)
- [x] ISBN barcode scanning
- [x] Book cover detection

### AI Intelligence
- [x] Multi-model query routing (Claude / Perplexity / Foundation Models)
- [x] Series-aware spoiler protection
- [x] Reading-progress-aware responses
- [x] Citation tracking with credibility scores
- [x] Conversation memory across sessions
- [x] Follow-up question generation
- [x] Session summaries and reflections
- [x] Intelligent title generation

### Knowledge System
- [x] Semantic knowledge graph (300-dim embeddings)
- [x] Automatic entity extraction (on-device)
- [x] Cross-book thematic connections
- [x] Proactive insight generation
- [x] Reading pattern discovery

### Social
- [x] Companion invitations
- [x] Fuzzy progress sharing
- [x] Trail markers (thoughts/quotes at positions)
- [x] Discovery ceremony for found markers
- [x] Literary postcard sharing
- [x] Shareable quote cards

### Reading Plans
- [x] Habit plans (7/14/21/30 days)
- [x] Reading challenges
- [x] Timeline visualization
- [x] Streak tracking
- [x] Smart notifications
- [x] Pause/resume without penalty

### Recommendations
- [x] Vibe-based matching (not genre)
- [x] Mood-based discovery (8 moods)
- [x] Taste profile analysis
- [x] Google Books enrichment

### iOS Integration
- [x] 4 Home Screen widgets
- [x] Dynamic Island / Live Activities
- [x] 6 Siri App Intents
- [x] Spotlight search
- [x] CloudKit sync
- [x] Offline-first architecture

### Import/Export
- [x] Goodreads CSV import
- [x] Google Books search
- [x] Open Library fallback
- [x] Readwise export
- [x] Markdown export
- [x] Custom cover upload

### Visual Design
- [x] iOS 26 Liquid Glass effects
- [x] OKLAB color extraction from covers
- [x] 9 premium gradient themes
- [x] Metal shader effects (water ripple, cosmic orb)
- [x] Voice-responsive atmospheric gradients
- [x] Breathing animations
- [x] Dark mode native (no light mode)

### Developer Story
- [x] Built by a designer (not a programmer)
- [x] Entirely through Claude Code
- [x] 622 commits across 6.5 months
- [x] 99 active development days
- [x] Metal shaders, AI routing, knowledge graphs — all built conversationally
