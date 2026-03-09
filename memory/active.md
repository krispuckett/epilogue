# Active Context

## Current Focus
Deep audit easy wins — working through P1/P2 backlog from Epilogue V2 Deep Audit Linear project.

## Recent Changes (This Session)
- KRI-43 (commit 40d4f82): Type-safe notification names — 95 static properties, 55+ files, ~200 replacements
- KRI-41 (commit a98975b): Throttle VoiceRecognitionManager amplitude to ≤10 Hz
- KRI-49 (commit a98975b): Add 200-entry LRU eviction to ResponseCache
- KRI-48 (commit b65806f): Surface AI errors + data save failures to users in AmbientMode
- KRI-52/KRI-80 (commit 6291b68): Wire ReadingStreakWidget to real data via App Group
- KRI-58 (commit 1e8dcb6): Extract 6 ambient sheet backgrounds into 3 shared components

## Previous Session Changes
- KRI-45, KRI-68, KRI-69, KRI-74 (commit 52692c9): 4 bug fixes
- KRI-42 Waves 1-2 (commits b3b7384, 8dfe788): 37 classes migrated to @Observable
- KRI-35 (commit 729dd9a): Write-through cache for UserDefaults/SwiftData
- Bug bash (commit c505016): KRI-71,72,38,39,70,36,37,85,46,75

## Deep Audit Status: 27 Done, 1 Canceled, 22 Backlog
Key remaining issues:
- KRI-54 [P0]: Decompose AmbientModeView (7500 lines) — too large for easy win
- KRI-73 [P1]: CloudKit fallback silently forking data
- KRI-76 [P1]: Hardcoded book knowledge in SmartEpilogueAI
- KRI-78 [P1]: Metal function constants for shader quality tiers
- KRI-55 [P1]: Surface Metal shader library in production UI
- Various P2 widget/feature issues remaining

## Known Issues
- 61 remaining ObservableObject classes (Voice/AI/Ambient infrastructure)
- Pre-existing uncommitted changes in EnhancedGoogleBooksService.swift, CLAUDE.md
- KRI-35 gap: LibraryViewModel mutation methods still only write UserDefaults
