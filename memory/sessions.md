# Session Log

## 2026-01-29 - Session memory system
- Created `memory/` directory with active.md, decisions.md, sessions.md
- Added session memory reference to CLAUDE.md
- Backfilled from full git history

## 2026-01-24 - Offline caching and recommendation fixes
- Replaced AsyncImage with SharedBookCoverView for offline caching (5b602fe)
- Fixed recommendation engine and generic session improvements (142ffae)

## 2026-01-15 - CloudKit sync enrichment
- Auto-enrich books on app startup after CloudKit sync (0d1e7a2)

## 2026-01-13 - Custom covers and search performance
- Custom cover upload from photos (4b6901f)
- Search performance improvements (4b6901f)

## 2026-01-06 - Knowledge graph and AI companion
- Knowledge graph system for thematic connections (c54e579)
- Direct link to Goodreads export page in importer (c67d480)
- Conversational recommendation flow with mood chips (599ec50)
- Claude-powered reading companion with intelligent routing (a0920db)
- **Decision:** Route queries through local models first, Perplexity for factual, Claude for conversational

## 2025-12-29 - Reading Room and reading plan fixes
- The Reading Room — interactive 3D book experience with RealityKit (7007ef6)
- Cancel notifications when deleting reading plans (659a87e, 244b0b7)

## 2025-12-18 - Note save reliability
- Improved note/quote save reliability with proper validation and feedback (038522d)

## 2025-12-16 - Crash prevention pass
- Comprehensive crash prevention — removed force unwraps and unsafe patterns (453e7c0)

## 2025-12-12 - Notes UI polish
- Liquid glass buttons, system font, glass toast for notes section (af0b0aa)

## 2025-12-09 - Streaming performance
- v0 streaming best practices and polish (61b8eb8)

## 2025-12-07 - Bookstore preferences
- Bookstore preference setting and misc improvements (86a0578)

## 2025-12-03 - Ambient suggestion pills
- Book-specific ambient mode suggestion pills (071caf7)

## 2025-12-01/02 - Color extraction and cleanup
- Intelligent color extraction system with comparison lab (4b2f899)
- CloudKit sync failure fix — missing inverse relationship (0def0ec)
- Performance fixes — busy-wait loops, timer leaks, NoteIntelligenceEngine (5f6a61a)
- Dead code cleanup, warning fixes, removed unused experiments (6dc4506)
- CheckedContinuation double-resume crash fix in Vision framework (8cad973)

## 2025-11-30 - Gradient system refactor
- Checkpoint before gradient system refactor (6c5a4c2)
- Merged gradient system review PR (51c0de5)

## 2025-11-22/24 - Reading Goals feature
- Complete Ambient Generative Actions system (11485ea)
- Reading journey — full CRUD, check-in notifications, timeline polish (df0f223..e2f2ff7)
- Welcome screen as first screen instead of sheet (4c000bf)
- Companion voice copy change: "we/let's" instead of "I/me" (c22b69e)
- Removed sparkles, added delete journey (b1366b5)
- Replaced .background() with .glassEffect() in journey views (6c8cbd0)
- Rich text formatting for notes with markdown support (64075fe, 063bdf7)
- **Decision:** `.background()` before `.glassEffect()` breaks Liquid Glass — never do this

## 2025-11-21 - Live Activities and search fixes
- Live Activities auto-restart for ambient mode (9255e21)
- Self-published book search and exact match ranking (f174f31)
- Performance optimizations phase 2 (df511a6)

## 2025-11-17 - Text animation and search improvements
- Text Animation Lab in developer settings (6a38b27, 0efbeb2)
- Note card expansion — tried many approaches, settled on lineLimit with easeInOut (5448563)
- Google Books search improvements and new app icon (29552a5)

## 2025-11-16 - Note expansion iterations
- Extensive iteration on note expansion animations (a3a599d..92fbc08)
- Replaced GeometryReader with character-based estimation to prevent memory crash (afca938)

## 2025-11-15 - Smart note expansion
- Smart expansion system for notes/quotes with 3-tier intelligence (f97e315)
- Liquid glass "Show More" pill (5f8feba)
- Multiple sheet styling iterations matching AmbientSessionSummaryView (83e3854..e18e76a)

## 2025-11-14 - Siri and search
- 6 critical App Intents for Siri automation (7bf1d92)
- Infinite scrolling and ISBN-based search for Google Books (7b23d54)

## 2025-11-13 - Gandalf mode and enrichment
- Gandalf mode bypass for paywall/quota checks (bc4f3cd..dc2a233)
- Book enrichment connected to speech recognition (9ac0401)
- Spotlight integration for system-wide book search (dfb4513)
- Text formatting fix — preserving original line breaks (39a8e9b)

## 2025-11-11 - System integration
- Interactive widgets with Continue Reading button (fac2218)
- End-to-end Siri integration for Continue Reading (ed46dab)
- iOS 26 system integration vision doc (7b250b9)

## 2025-11-05 - Export and ratings
- Markdown export with intelligent titles and Readwise sync (1d0bd78)
- What's New sheet update (82280db)

## 2025-11-01 - Half-star ratings
- Half-star rating system with drag interaction (6379667)

## 2025-10-29 - Purchase celebration
- Purchase success celebration + atmospheric settings design (1cc3889)

## 2025-10 - StoreKit and settings
- StoreKit paywall, atmospheric settings, rating refactor (various commits)

## 2025-08 - Ambient mode and notes overhaul
- SmartContentBuffer for ambient mode processing (aab91ee)
- Bulk selection modernization for iOS 26 (b69ea87)
- Natural language book search in command palette (462d4b9, b7bc4ec)
- iOS 26 swipe actions for notes/quotes (0457916)
- Major UI standardization pass (dc4b75a)

## 2025-07-28/29 - Chat system and gradients
- Unified chat system replacing thread-based approach (e9e3ee4..e6ed3cc)
- ChatCommandPalette, BookContextPill, ChatMessageView (928683b..a10e9bf)
- ColorCube extraction + atmospheric gradients finalized (2e3111e)
- Voice-responsive gradients (fbc9cd3)
- **Decision:** ColorCube 3D histogram with OKLAB for color extraction — most accurate for book covers

## 2025-07-26/27 - AI integration and gradient iterations
- Perplexity AI integration (52c061a)
- WhisperKit dual transcription system (c0293cb)
- Multiple gradient system iterations (920be9d, eed6307, 92b69a8)
- API key security measures (bfa4645)

## 2025-07-20/22 - Ambient backgrounds and glass effects
- Ambient Book Background System with color intelligence (92b69a8)
- Book cover lighting effects (40ec6e4)
- Glass effect fixes for summary cards (2643842, 5c873be)

## 2025-07-16/19 - Metal shaders and commands
- Metal shader system — cosmic orb for Literary Companion (47dc26e, ef633da)
- Smart command system, converted popovers to native Menu (3c97b9d)
- Threaded chat system (dc65f77)

## 2025-07-13/15 - Project inception
- Initial commit: token-based note editor (5b69921)
- Notes view, navigation system, UI foundations (d001594, 05bd3c4)
- Perplexity AI integration (52c061a)
