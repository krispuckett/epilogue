# Epilogue v2 Roadmap

> Strategic roadmap for Epilogue iOS — a personal reading companion app.
> Last updated: December 2025

---

## Current State Assessment

### Feature Completion Status

| Feature | Status | Notes |
|---------|--------|-------|
| **Core Library** | ✅ Complete | SwiftData + CloudKit sync, book search via Google Books API |
| **Book Details** | ✅ Complete | Cover extraction, enrichment, atmospheric gradients |
| **Quote Capture** | ✅ Complete | Manual, camera OCR (Live Text), voice transcription |
| **Note-Taking** | ✅ Complete | Linked to books, ambient session capture |
| **AI Chat** | ✅ Complete | Perplexity Sonar integration, book context awareness |
| **Ambient Mode** | ✅ Complete | Voice/text capture, reading sessions, atmospheric UI |
| **Color Extraction** | ✅ Complete | OKLAB ColorCube algorithm (minor role assignment bugs) |
| **iOS 26 Liquid Glass** | ✅ Complete | System glass effects, Metal shaders |
| **Widgets** | 🟡 Partial | Current reading, streak widgets work; Live Activity placeholder |
| **Recommendations** | ✅ Complete | Taste profile analysis + Perplexity-powered suggestions |
| **Reading Journeys** | ✅ Complete | Multi-book journeys, milestones, habit plans |
| **Goodreads Import** | ✅ Complete | CSV parsing, batch book addition |
| **Data Export** | ✅ Complete | JSON, Markdown, CSV export |
| **Siri Shortcuts** | ✅ Complete | Full intent coverage for books, notes, quotes |
| **Monetization** | ✅ Complete | StoreKit 2, monthly/annual subscriptions |
| **Live Activities** | 🔴 Placeholder | Basic scaffold only, no real functionality |
| **Chat Persistence** | 🟡 Partial | Many TODOs for thread saving in AmbientChatOverlay |
| **Foundation Models** | 🟡 Partial | Scaffolded for iOS 26, not fully integrated |

### Known Technical Debt

**High Priority:**
- `AmbientChatOverlay.swift` — 12+ TODOs for chat thread persistence
- `LiveActivityLifecycleManager.swift` — Live Activity not implemented
- `SecureAPIManager.swift` — StoreKit receipt validation not implemented
- `EpilogueWidgetsLiveActivity.swift` — Placeholder only

**Medium Priority:**
- `CommandProcessingManager.swift` — Status update command not implemented
- `MultiStepCommandParser.swift` — Several command types incomplete
- `OKLABColorExtractor.swift` — Color role assignment bugs (Silmarillion, Love Wins)
- `OfflineQueueManager.swift` — Book type conversion issues

**Low Priority:**
- Various `#if DEBUG` print statements throughout codebase
- DEPRICATED folder with legacy code still present
- Some feature flags default to `false` with no UI toggle

### Known Bugs

| Issue | Location | Severity |
|-------|----------|----------|
| Silmarillion shows green instead of blue | Color role assignment | Low |
| Love Wins shows red instead of blue | Color role assignment | Low |
| Chat threads not persisting in ambient mode | AmbientChatOverlay | Medium |
| Live Activity shows placeholder only | EpilogueWidgetsLiveActivity | Medium |

---

## V2 Feature Categories

### 1. Core Reading Experience

| Feature | User Value | Complexity | Dependencies | Revenue |
|---------|------------|------------|--------------|---------|
| **Page Logging UI Improvements** | 5 | 2 | None | None |
| **Reading Statistics Dashboard** | 4 | 3 | Reading sessions | Premium |
| **Book Collections/Shelves** | 5 | 3 | None | None |
| **Enhanced Book Search** | 3 | 2 | None | None |
| **ISBN Barcode Scanner** | 4 | 2 | Camera permission | None |
| **Manual Book Entry Form** | 3 | 2 | None | None |
| **Quote Organization/Tags** | 4 | 3 | None | None |
| **Reading Goals & Streaks** | 4 | 3 | Reading sessions | None |

### 2. AI Intelligence

| Feature | User Value | Complexity | Dependencies | Revenue |
|---------|------------|------------|--------------|---------|
| **Chat Thread Persistence** | 5 | 3 | SwiftData | None |
| **On-Device AI (Foundation Models)** | 5 | 4 | iOS 26+ | Premium |
| **Quote Analysis & Insights** | 4 | 3 | AI service | Premium |
| **Session Summaries** | 4 | 3 | Ambient mode | Premium |
| **Book-Specific Chat Contexts** | 4 | 2 | Chat persistence | None |
| **Smart Note Enhancement** | 3 | 3 | AI service | Premium |
| **Reading Habit Coaching** | 3 | 4 | Reading data | Premium |

### 3. Ambient Mode

| Feature | User Value | Complexity | Dependencies | Revenue |
|---------|------------|------------|--------------|---------|
| **Live Activity Implementation** | 5 | 4 | ActivityKit | None |
| **Dynamic Island Reading Timer** | 5 | 3 | Live Activity | None |
| **Voice Commands** | 4 | 4 | Speech recognition | Premium |
| **Auto-Transcription Mode** | 4 | 3 | Whisper/Speech | Premium |
| **Reading Timer with Breaks** | 3 | 2 | None | None |
| **Focus Mode Integration** | 3 | 2 | iOS Focus API | None |
| **Background Audio Cues** | 2 | 2 | AVFoundation | None |

### 4. Social & Sharing

| Feature | User Value | Complexity | Dependencies | Revenue |
|---------|------------|------------|--------------|---------|
| **Beautiful Quote Cards** | 5 | 3 | Image generation | None |
| **Share to Instagram Stories** | 4 | 2 | Share extension | None |
| **Export to Notion/Obsidian** | 4 | 3 | API integrations | None |
| **Readwise Integration** | 4 | 3 | Readwise API | None |
| **Book Club Features** | 3 | 5 | Backend needed | Future |
| **Public Reading Profile** | 2 | 5 | Backend needed | Future |

### 5. Monetization

| Feature | Gates | Priority |
|---------|-------|----------|
| **Free Tier** | 8 AI conversations/month, all core features | Launched |
| **Epilogue+ Monthly** | Unlimited AI, advanced features | Launched ($7.99) |
| **Epilogue+ Annual** | Same as monthly, 30% discount | Launched ($67) |
| **Premium AI Features** | On-device AI, voice commands, auto-transcription | v2.1 |
| **Reading Insights** | Statistics dashboard, habit coaching | v2.1 |
| **Export Integrations** | Readwise, Notion, Obsidian sync | v2.2 |

---

## Release Phases

### v2.0 — Foundation Polish

**Theme:** Fix technical debt, complete unfinished features

**Ship First:**
1. ✅ Chat thread persistence in ambient mode
2. ✅ Fix Live Activity (reading timer, book cover, session stats)
3. ✅ Dynamic Island integration
4. ✅ Book collections/shelves feature
5. ✅ Reading statistics dashboard
6. ✅ StoreKit receipt validation

**Technical Prerequisites:**
- Refactor `AmbientChatOverlay` to properly save chat threads to SwiftData
- Implement proper `ActivityAttributes` for reading sessions
- Add `BookCollection` model to SwiftData schema

**Definition of Done:**
- All TODOs in AmbientChatOverlay resolved
- Live Activity shows current book + reading time
- Dynamic Island compact/expanded views functional
- Users can create and manage book collections

---

### v2.1 — AI Evolution

**Theme:** Deeper AI integration, on-device processing

**Ship:**
1. Foundation Models integration (on-device AI for Plus users)
2. Session summaries (auto-generate after ambient sessions)
3. Quote analysis & insights
4. Voice commands in ambient mode
5. Auto-transcription toggle
6. Smart note enhancement

**Technical Prerequisites:**
- Finalize `FoundationModelsManager.swift` implementation
- Add session summary UI to ambient mode completion flow
- Implement quote sentiment/theme analysis pipeline
- Add speech recognition for command parsing

**Monetization:**
- Gate advanced AI features behind Epilogue+
- Consider tiered AI (free = Sonar, Plus = Foundation Models + Sonar)

---

### v2.2 — Connection & Export

**Theme:** Get data out, connect with other tools

**Ship:**
1. Beautiful quote card generator
2. Instagram Stories share template
3. Readwise two-way sync
4. Notion export integration
5. Obsidian vault export
6. iCloud export/backup

**Technical Prerequisites:**
- Image rendering pipeline for quote cards
- Readwise API integration
- Markdown export templates for Notion/Obsidian
- Background sync service for Readwise

---

### v2.3+ — Future Iterations

**Exploration:**
- Book club features (shared reading, discussions)
- Public reading profiles
- Reading challenges
- Widget customization
- Apple Watch companion
- Reading habit notifications
- CarPlay audiobook notes

---

## Technical Prerequisites

### Shared Infrastructure to Build First

| Infrastructure | Enables | Priority |
|----------------|---------|----------|
| **Chat Persistence Layer** | Chat history, session summaries, conversation recall | P0 |
| **Live Activity System** | Reading timer, Dynamic Island, lock screen presence | P0 |
| **Book Collection Model** | Shelves, organization, filtered views | P1 |
| **Image Generation Pipeline** | Quote cards, share images, export visuals | P1 |
| **Foundation Models Bridge** | On-device AI, privacy-first processing | P1 |
| **External Sync Service** | Readwise, Notion, Obsidian integrations | P2 |
| **Statistics Aggregation** | Reading insights, habit tracking, streaks | P2 |

### Architecture Changes Needed

1. **Chat Thread Model**
   ```swift
   @Model
   final class ChatThread {
       var id: UUID
       var book: BookModel?
       var messages: [ChatMessage]
       var createdAt: Date
       var lastMessageAt: Date
       var sessionId: UUID?  // Link to AmbientSession
   }
   ```

2. **Live Activity Attributes**
   ```swift
   struct ReadingActivityAttributes: ActivityAttributes {
       var bookTitle: String
       var bookAuthor: String
       var coverImageData: Data?

       struct ContentState: Codable, Hashable {
           var elapsedMinutes: Int
           var currentPage: Int?
           var totalPages: Int?
       }
   }
   ```

3. **Book Collection Model**
   ```swift
   @Model
   final class BookCollection {
       var id: UUID
       var name: String
       var books: [BookModel]
       var createdAt: Date
       var sortOrder: Int
       var icon: String?  // SF Symbol name
   }
   ```

---

## Prioritization Framework

### Scoring System

Each feature is scored on:
- **User Value (1-5):** How much users want/need this
- **Technical Complexity (1-5):** Development effort required
- **Revenue Potential:** None, Premium gate, or Future monetization
- **Dependencies:** What must exist first

### Priority Calculation

```
Priority Score = (User Value × 2) - Complexity + Revenue Bonus
```

Where:
- Revenue Bonus = 2 for Premium, 1 for Future, 0 for None

### Current Top Priorities

1. **Chat Thread Persistence** — Score: 9 (5×2 - 3 + 2)
2. **Live Activity Implementation** — Score: 8 (5×2 - 4 + 2)
3. **Book Collections** — Score: 7 (5×2 - 3 + 0)
4. **Reading Statistics** — Score: 7 (4×2 - 3 + 2)
5. **Foundation Models** — Score: 8 (5×2 - 4 + 2)

---

## Success Metrics

### v2.0 Targets
- 90% of ambient sessions save chat history
- Live Activity adopted by 60% of active readers
- 30% of users create at least one collection
- Crash-free rate > 99.5%

### v2.1 Targets
- 50% of Plus users try on-device AI features
- Session summary generation rate > 80%
- Voice command activation rate > 20%
- Plus conversion rate increase of 15%

### v2.2 Targets
- Quote card shares > 10,000/month
- Readwise sync activation > 25% of Plus users
- Export feature usage > 40% monthly

---

## Appendix: Feature Flag Status

| Flag | Default | Implemented |
|------|---------|-------------|
| `feature.ambient.new_mode` | true | Yes |
| `feature.ambient.voice_commands` | false | Partial |
| `feature.ambient.auto_transcription` | false | No |
| `feature.ai.quote_analysis` | true | Partial |
| `feature.ai.book_recommendations` | true | Yes |
| `feature.ai.session_summaries` | false | No |
| `feature.ai.enhanced_chat` | false | No |
| `feature.library.collections` | false | No |
| `feature.library.readwise_integration` | false | No |
| `feature.experimental.custom_camera` | false | Yes |
