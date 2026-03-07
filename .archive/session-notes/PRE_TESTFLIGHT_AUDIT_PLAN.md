# Epilogue Pre‑TestFlight Audit Plan

A programmatic, reviewer‑friendly checklist and remediation plan to bring Epilogue to production/App Store quality without altering code yet. Use this file to track decisions and edits.

## Scope
- Codebase: `Epilogue/Epilogue` (≈269 Swift files; ≈126 views) + Xcode project + SwiftPM target
- Areas: architecture, state, services, views, assets, performance, accessibility, privacy/compliance, testing, and release hygiene
- Method: file inventory, reference scans, usage checks, SwiftData + networking review, App Store readiness

## Highest‑Risk Items (prioritize first)
- Single app entry point: ensure only one `@main` in shipping target
- API key policy: remove any reconstructable key paths; Keychain only
- Perplexity service consolidation: migrate old `PerplexityService` callers to `OptimizedPerplexityService` (via integration bridge) and deprecate the former
- Production logging: gate or remove `print()`/verbose logs; introduce leveled logging
- Legal links: replace Settings placeholder Privacy/Terms URLs with live pages

## Suspected Dead/Legacy Code (confirm before removal)
- Views
  - Library: `OptimizedBookDetailView.swift`, `RefinedBookDetailView.swift`
  - Goodreads: `CleanGoodreadsImportView.swift` (Library uses `GoodreadsImportView`)
  - Chat: `PerplexityStyleSessionsView.swift`, `ModernSessionsView.swift` (previews only)
- Services
  - `Views/Components/PerplexityService.swift` (legacy duplicate of optimized service)
  - `Services/GoodreadsCleanImporter.swift` (redundant to `GoodreadsImportService.swift`?)
- Entry/Targets
  - `App/EpilogueApp.swift` vs `Epilogue/Epilogue/EpilogueApp.swift` — keep one in the shipping target
- Folder
  - `DEPRICATED/` — ensure fully excluded from targets

> Action: validate with Xcode target membership + “Find References”; retain previews that are still helpful.

## Architecture & State
- Pattern: SwiftUI + SwiftData + EnvironmentObjects; several singletons
- Risks: singleton sprawl; duplicated navigation coordinators; mixed notification routing
- Plan
  - Introduce a thin DI façade for services (Perplexity, GoogleBooks, Caching) at app root
  - Unify/cohere coordinators (navigation/ambient) behind one routing abstraction
  - Centralize Notification.Name constants

## Security & Privacy
- API keys
  - Use `KeychainManager` only; no obfuscated parts in source/binary
  - Validate key format and UX for missing key
- Privacy Manifest: present; accessed APIs listed (UserDefaults, timestamps, disk space)
- Permissions: camera/mic strings configured via build settings
- Remove production logs of sensitive text (clipboard, content) and debug IDs

## Accessibility
- Apply accessible animation gates broadly (Reduce Motion)
- Verify labels/hints for: Library cards, empty states, command palette, quick actions, chat input
- Ensure 44x44 hit targets across tappables
- Dynamic Type coverage across onboarding/empty states/chat/notes

## Performance
- Library Grid/List
  - Prefer thumbnails for scrolling; prefetch neighbors; keep skeletons
- Streaming UI
  - Token batching is in place; verify main‑thread work/batching interval
- Image caching
  - Verify eviction/limits; separate thumbnail/full‑size caches
- Task lifecycles
  - Make long‑running tasks cancellable on disappear

## Testing
- Unit
  - Google Books parsing/selection; ResponseCache; KeychainManager; SessionSummaryGenerator
- Integration
  - Goodreads CSV import → enrichment → library add
  - Add‑book pipeline (search → add → cover palette)
  - Cover replacement flow
- UI (XCTest)
  - Onboarding flow; Library empty → Add Book; Notes empty state; Chat empty → start session; Ambient enter/exit
- Performance
  - Library scroll smoothness; Book detail open time

## Release Hygiene
- Treat warnings as errors (Release)
- SwiftLint + SwiftFormat with minimal, repo‑aligned rules
- Real Privacy Policy/Terms links
- Exclude test files/scripts/logs from app bundle (e.g., `test_import.csv`, `build_output.log`)
- Validate PrivacyInfo.xcprivacy against APIs actually used (no missing categories)

## Consolidation Map
- App entry
  - Keep `Epilogue/Epilogue/EpilogueApp.swift` + `ContentView`
  - Exclude `App/EpilogueApp.swift` from shipping target
- Perplexity/AI
  - Canonical: `Services/OptimizedPerplexityService` (+ `AI/PerplexityIntegrationBridge`)
  - Migrate/retire: `Views/Components/PerplexityService.swift`
- Goodreads
  - Keep `GoodreadsImportView.swift` + `GoodreadsImportService.swift`
  - Remove `CleanGoodreadsImportView.swift` if unreferenced
- Book Detail
  - Keep `BookDetailView.swift`; retire alternates if unused

## Execution Plan (Phased)
- Phase 0 — Validate
  - Build all targets Debug/Release; capture warnings baseline
  - Export target memberships for duplicates; verify resource bundling
- Phase 1 — Service unification
  - Migrate callers to `OptimizedPerplexityService` via bridge
  - Remove reconstructable key logic from `SecureAPIManager` (retain only rate‑limit if needed)
- Phase 2 — Entry/Targets
  - Single `@main`; prune duplicate app target membership; clarify SwiftPM vs app module
- Phase 3 — Dead code cleanup
  - Remove unreferenced view variants/services; archive to `DEPRECATED/` if historical value
- Phase 4 — Logging
  - Introduce `Logger` wrapper; gate logs with `#if DEBUG`; scrub sensitive logs
- Phase 5 — UX guardrails
  - Audit Reduce Motion coverage; verify empty states and onboarding alignment/phrasing
- Phase 6 — Tests
  - Add unit/integration/UI/perf tests outlined above
- Phase 7 — App Store readiness
  - Replace legal links; re‑run validation; finalize privacy submission

## Verification Checklist
- [ ] Single `@main` in shipping target
- [ ] No API keys or reconstructable parts present in binary
- [ ] No debug prints in Release; logs gated
- [ ] Library → Detail → Back smooth; Chat streaming stable; Ambient transitions clean
- [ ] Accessibility labels/hints/size verified for key paths
- [ ] Privacy prompts correct; Privacy manifest accurate
- [ ] Settings links live and correct
- [ ] Archive validation passes; TestFlight build successful

## Open Decisions / Owner Input
- Confirm which BookDetail variant is canonical (`BookDetailView.swift` assumed)
- Confirm Goodreads importer to keep (`GoodreadsImportView.swift` assumed)
- Confirm legacy chat views to retire
- Confirm SwiftPM usage intent (shared module vs app duplication)

## Suggested Non‑Destructive Next Steps
- Produce a target membership report (Xcode) for suspected duplicates
- Run a strings scan on the built app to ensure no key fragments ship
- List all files in app bundle to confirm no test assets/logs are included
- Align SwiftLint/SwiftFormat rules with current style; add CI pre‑commit hook

---
Maintainer notes: keep this doc as the single source of truth for pre‑TestFlight hardening; update checkboxes as you migrate/confirm items.

