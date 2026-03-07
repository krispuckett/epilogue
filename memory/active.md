# Active Context

## Current Focus
v2.0 bug bash — P0/P1 issues from deep audit. First pass complete (10 issues resolved). KRI-35 (UserDefaults/SwiftData desync) scoped out for dedicated session.

## Recent Changes
- Bug bash commit c505016: 9 issues fixed across Waves 1-4
  - KRI-71: Removed debug cache clearing from startup
  - KRI-72: Deleted unused EpilogueWidgetsLiveActivity.swift
  - KRI-38: Removed loadSampleData() from production
  - KRI-39: Deleted unused EmptyStateView.noBooks
  - KRI-70: Fixed Task.detached + @MainActor contradiction
  - KRI-36: Fixed PerformanceMonitor data race (removed metricsQueue)
  - KRI-37: Replaced fatalError with graceful fallback in LibraryService
  - KRI-85: Phased startup into 3 tiers (critical/UI-ready/background)
  - KRI-46: Added library search by title/author (.searchable)
  - KRI-75: Limited preloadAllBookCovers to 6 visible books (was 20)
- KRI-40: Closed — no hardcoded secrets found, downgraded to P3
- KRI-77: Closed — try! in #Preview is standard (macro doesn't support try)

## Open Questions
- KRI-35 (UserDefaults/SwiftData desync) is the biggest remaining P0 — needs dedicated session
  - `com.epilogue.savedBooks` dual-written to UserDefaults + SwiftData from 15+ files
  - All Siri Intents read from UserDefaults only
  - LogPagesIntent updates UserDefaults only (no SwiftData sync)
- KRI-47 (edit button on NoteDetailView) not yet addressed
- KRI-42 (@Observable migration) — large mechanical change, needs batching
- Pre-existing uncommitted changes in EnhancedGoogleBooksService.swift, AmbientModeView.swift, CLAUDE.md

## Next Steps
- Dedicated session for KRI-35 UserDefaults/SwiftData desync
- Continue remaining P1 issues (KRI-47, KRI-42, etc.)
- Test library search on device
- Review and commit pre-existing uncommitted changes
