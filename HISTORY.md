# The History of Epilogue

**645 commits. 99 days. One designer who doesn't code, and an AI that does.**

Epilogue is a reading companion app for iOS, built almost entirely through Claude Code by a designer with no traditional programming background. What follows is the story as told by the git log — the breakthroughs, the crises, the all-caps commits at 2am, and the slow accumulation of something real.

---

## Act I: Genesis (July 13–20, 2025)

It started with a single commit:

```
5b69921 Initial commit: Epilogue iOS app with token-based note editor
```

July 13, 2025. The idea was modest — an app to capture thoughts about books. A note editor with tokens. The first few days were foundational: notes view, navigation, editing interface. By July 16, things got interesting. A Metal shader appeared (`47dc26e Add Metal shader system for Literary Companion empty state`), then was immediately deemed too chaotic and replaced with a calm cosmic orb (`ef633da Replace chaotic particle system with calm cosmic orb`). A pattern was established early: build it, hate it, rebuild it.

Perplexity AI integration landed on July 16. The app was already reaching beyond a simple note-taker.

By July 18, a threaded chat system was in place. July 20 brought lighting effects for book covers and advanced gradient systems. The ambition was accelerating faster than the foundation could support.

## Act II: The Gradient Wars (July 22 – September 10, 2025)

If there is a single thread that runs through Epilogue's history, it is the gradient system. The quest for beautiful, book-responsive color extraction consumed more commits than any other feature.

It began on July 22 with `92b69a8 Implement Ambient Book Background System with Advanced Color Intelligence`. Then came the Claude Voice Mode-style gradients (`eed6307`), the Apple Music + Claude gradient system (`920be9d`), and finally a complete replacement: `0538ecd Replace broken gradient system with Apple Music + Claude style`. The next day, another replacement: `2e3111e Fix gradient system: ColorCube extraction + atmospheric gradients`.

The gradient system would be refactored, reverted, and rebuilt at least five more times. Key moments:

- `bf4067b` — A massive commit touching accents, zoom levels, extractor compilation, vibrancy preferences. The next day: `611a67c revert: undo gradient/extractor tweaks`.
- `96778df Fix: Restore gradient system to 73e8793 behavior` — rolling back to a known good state by commit hash.
- `6c5a4c2 Checkpoint: Pre-gradient system refactor` — the word "checkpoint" appearing before gradient work, a lesson learned.
- PR #5: `Add intelligent color extraction system with comparison lab` — the system finally stabilized with ColorCube 3D histogram extraction and OKLAB color space.

The gradient wars taught a brutal lesson: color is subjective, and "better" is a moving target. Every improvement broke something else. Saturate too much and hues shift. Extract the wrong dominant color and the whole screen looks wrong. The commit log reads like a negotiation with physics.

## Act III: The Ambient Mode Saga (August 8 – September 12, 2025)

Ambient mode — a voice-driven reading companion where you talk about the book you're reading — was the app's most ambitious feature. Its development was also its most chaotic.

The first serious attempt landed August 8 (`aab91ee Fix: Implement intelligent ambient mode processing with SmartContentBuffer`). What followed was a 35-day sprint of relentless iteration, where some days produced 20+ commits just on ambient mode.

**August 16 was the worst day.** 28 commits. The commit messages tell the story:

```
9935254 Fix: Critical deduplication bug blocking question processing
9ebb855 Fix: Remove all question deduplication to allow natural flow
3cd258a Fix: Multiple critical issues with question processing
f9f3da6 Fix: Duplicate questions in UI and API key validation
97fd2e7 Fix: Make the vision actually work - smart question handling
cb321a9 Fix: ACTUALLY fix the broken ambient mode
16994e3 Fix: Revolutionary question handling - wait for complete before processing
1fb9d86 TEMP FIX: Hardcode API key to make it actually work
```

The caps lock tells you everything. "ACTUALLY fix." "TEMP FIX." The frustration of a system that kept breaking in new ways every time one thing was fixed. Questions were duplicating. The AI wasn't responding. The API key wasn't loading. At one point, the key was hardcoded just to prove the rest of the pipeline worked.

**August 17** brought another 23-commit day, including the introduction of FoundationModels integration, Neural Engine optimizations, and an IntelligentQueryRouter — infrastructure that would later prove essential but at the time created a cascade of compilation errors (`fd5867f`, `982b6ae`, `3e2e796`, `32507ce`...).

**August 19** was the morphing animation marathon. The input bar needed to morph between voice and text modes. 27 commits included three reverts:

```
c9777ed Revert "Fix: Implement iOS search-style horizontal expansion animation"
53668a8 Revert "Fix: Implement proper iOS search-style horizontal expansion"
70a414d Revert "Fix: Improve morphing animation symmetry"
```

And one moment of triumph: `095ac7d Fix: REMOVE DUPLICATE STOP BUTTON - finally fixed!` — the exclamation mark and escaped backslash suggesting this was typed with feeling.

## Act IV: The Great Cleanup and the Warning Apocalypse (August 22, 2025)

August 22 holds the record: **52 commits in a single day.**

It began with ambition: `58d40ed Add comprehensive error handling service`, `fb9bbce Add SwiftData migration service`, `fe28163 Replace AsyncImage with CachedAsyncImage`. Production-grade architecture. Monitoring. Analytics. Feature flags.

Then reality hit. The new systems introduced more compilation errors than they solved. The day became a cascade of fixes:

```
60d8cae Fix: Resolve CachedAsyncImage compilation errors
7bef7c6 Fix: Resolve compilation errors in LibraryView - fix missing brace and function scope
ada8245 Fix: Add missing Combine imports and fix TaskPriority namespace issues
250e0b9 Fix: Compilation errors in ContentViewExtensions
07add1b Fix: SafeSwiftData compilation errors
ccbc993 Fix: Compilation errors in monitoring systems
```

Twelve consecutive compilation fixes. The codebase was refactored into a state where nothing compiled. It took hours to dig out. By the end of the day, the settings view had to be reverted entirely (`b269c6c Revert: Restore original SettingsView`).

166 warnings were identified. The deprecation of `UIScreen.main` alone required changes across dozens of files. Force unwrapping was removed from at least eight files individually. It was the most productive and most painful day of the project.

## Act V: The iOS 26 Liquid Glass Reckoning (August–September 2025)

iOS 26 introduced Liquid Glass — Apple's new material design language. Epilogue adopted it aggressively, and paid for it.

The core lesson was discovered through trial and error: `.background()` before `.glassEffect()` breaks everything. This is now the #1 rule in the project's CLAUDE.md file. It was learned the hard way across dozens of commits.

The Menu component was particularly hostile. Between September 3–4, **ten consecutive commits** tried to make a simple reading status dropdown work with Liquid Glass:

```
55e7b84 Fix: Restore working Menu implementation for iOS 26
66e4720 Fix: Replace broken Menu with Popover for iOS 26 compatibility
d3da18f Revert: Restore EXACT working Menu with iOS 26 Liquid Glass styling
0cb6893 Fix: Use contextMenu with menuIndicator for iOS 26 SDK
85ed6a9 Fix: Simplify Menu to resolve iOS 26 selection issues
9574076 Fix: Add primaryAction to Menu for iOS 26 compatibility
157fc24 Fix: Replace broken Menu with custom iOS 26 Liquid Glass sheet
729172c Revert "Fix: Replace broken Menu with custom iOS 26 Liquid Glass sheet"
a93c893 Fix: Convert reading status Menu to contextMenu
39143d9 Fix: Revert reading status to StatusPill with Menu tap
```

Menu → Popover → Revert → ContextMenu → PrimaryAction → Simplify → Custom Sheet → Revert → ContextMenu → StatusPill. The component changed approach six times in two days before settling.

The safeAreaBar API was another battle. Four commits on September 17 alone tried different approaches, including two reverts, before finding the right pattern.

## Act VI: The Visual Intelligence Experiment (September 13, 2025)

Camera-based quote capture — point your phone at a book page, select text, save it as a quote. Fourteen commits in a single day:

```
da26ef6 Add Visual Intelligence to Ambient Mode
3049b3f Enhance Visual Intelligence with smart quote capturing
f17e860 feat: Add Live Text selection for precise quote capturing
fd42636 fix: Book scanner no longer closes after selecting a book
6c68cc4 feat: Enhanced Visual Intelligence text selection
54a1f37 fix: Update Enhanced Text Scanner to use iOS 26 liquid glass effects
8ead3b6 perf: Simplify text capture for better performance
371b2d1 refactor: Simplify text capture to clipboard-based approach
ed61dcd fix: Camera presentation and black screen issue
04a4075 feat: Add foundation for iOS 26 Visual Intelligence API
f13af57 fix: Implement REAL Visual Intelligence with camera text detection
c464123 feat: Implement snapshot → select → action flow for text capture
```

Notice the progression: grand vision, then simplification, then a black screen bug, then "Implement REAL Visual Intelligence" — suggesting the previous implementation was, well, not real. The camera feature eventually worked, but the path there included a complete rewrite of the approach from Live Text selection to clipboard-based to snapshot-based.

## Act VII: The Data Loss Crises (September 24 + October 2, 2025)

Two separate data loss events, each leaving scars in the commit log.

**September 24:**
```
1cc9240 URGENT FIX: Disable automatic data migration causing data loss
80ce91f CRITICAL: Disable CloudKitMigrationService in ContentView
```

A CloudKit migration service was automatically running on launch, and it was destroying data. The fix was surgical: disable it entirely.

**October 2:**
```
a20e9df Fix: CRITICAL DATA LOSS - Restore default CloudKit container
2ccd9f7 Fix: App stuck on loading spinner - faster CloudKit fallback
ae16aab Fix: CRITICAL - Remove TipKit causing app crash on iOS 26
```

The CloudKit container configuration was wrong, pointing to a non-default container and losing access to existing data. TipKit — Apple's feature discovery framework — was crashing the app entirely on iOS 26. Both were removed the same day. The loading spinner hung because CloudKit was failing silently.

These events established the project's defensive posture around data: checkpoint before changes, test after every change, commit working states.

## Act VIII: The Accidental Deletion (October 15, 2025)

```
056ae85 Code cleanup: Remove 40+ unused files
8ca19ca Fix: Restore critical AI and voice processing files deleted in cleanup
```

A code cleanup removed 40+ files. Some of them were not unused. The AI service and voice processing files were accidentally deleted, breaking the core ambient mode feature. They were restored in the next commit, but this is why the project now has a "checkpoint before cleanup" rule, established one commit earlier: `d6010f4 Checkpoint before code cleanup`.

## Act IX: App Store Submission (October 14–19, 2025)

The push to the App Store was its own mini-arc:

```
e7a70a1 Fix: Complete StoreKit 2 subscription implementation
5c07895 Fix: Perfect book scanner with 2-stage confirmation and updated app icon
d54d34e Fix: App Store submission preparation - critical security and stability fixes
69a03e2 Add comprehensive App Store review notes for v1.0.1 submission
830146f Fix: Add StoreKit retry logic for App Review
```

StoreKit 2 subscriptions, a paywall, a billing interval picker, conversation limits, free tier management — the entire monetization layer was built in roughly a week. The "Gandalf mode" developer bypass (`bc4f3cd Fix: Gandalf mode now properly bypasses all quota checks and paywalls`) became a recurring character, requiring four commits across November 13 to work correctly.

## Act X: The Note Expansion Obsession (November 15–17, 2025)

How should a long note expand when you tap it? This question consumed 20+ commits across three days.

First, sheets: `83e3854 Fix: Match sheet corner radius`. Then inline expansion: `368985e Fix: Remove sheet modal, expand notes inline gracefully`. Then a memory crash: `afca938 Fix: Replace GeometryReader with character-based estimation to prevent memory crash`.

Then the Show More pill needed to be smaller. Then it needed Liquid Glass. Then the blur effect was wrong. Then the gradient fade was wrong. Then actual blur was tried. Then proper text blur. Then matching the sheet design. Then adding a reader sheet again. Then removing the sheet again.

Finally, a Text Animation Lab was built (`6a38b27 Add: Text Animation Lab to Gandalf developer settings`) to iterate on expansion effects scientifically rather than by feel. Five different effect modes were prototyped. The winner: Scale+Blur progressive blur with staggered fade truncation.

## Act XI: The Reading Journey (November 22, 2025)

20 commits in a single day built an entire reading goals system from scratch:

```
dd081ec Feature: Reading Goals - Thoughtful companion for reading journey
2c3147f Fix: Resolve all build errors in reading journey feature
99c6a2c Fix: Critical bugs in reading journey creation
cf386ce Fix: Timeline visual connectivity in reading journey
ca3416c Fix: Complete visual polish overhaul for reading journey
b1366b5 Fix: Remove sparkles and add delete journey functionality
```

"Remove sparkles" — the SF Symbol "sparkles" is explicitly forbidden in the project. It appeared. It was removed. The rule exists for a reason.

The reading journey feature shipped through PR #3, the app's first feature delivered via pull request from a Claude-created branch. PRs became the standard workflow: PR #2 for rich text notes, PR #5 for the color extraction system, PR #6 for notification cleanup.

## Act XII: Intelligence Layer (January 2026)

The most recent phase shifted from UI polish to intelligence:

```
a0920db Add: Claude-powered reading companion with intelligent routing
599ec50 Add: Conversational recommendation flow with mood chips
c54e579 Add: Knowledge graph system for thematic connections
```

A knowledge graph for finding thematic connections between books. A recommendation engine with mood-based discovery. An intelligent query router that decides whether to use local models, Perplexity, or Claude. The app evolved from a note-taker to something closer to a reading companion with memory.

## Act XIII: The Side Quests

The branch list tells its own story. Not every branch was about the app:

- `claude/setup-consulting-business` — a complete business setup checklist for a consultancy called Monomythic
- `claude/monomythic-brand-design` — a full brand identity system
- `claude/permission-less-framework` — a methodology whitepaper called "Field Notes from the In-Between"
- `claude/epilogue-case-studies` — five technical case studies about building the app itself
- `claude/wcag-accessibility-audit` — WCAG 2.1 AA accessibility documentation
- `claude/ios-reading-app-epilogue` — a Figma Config 2025 competitive analysis

The same tool that built the app was used to build the narrative around it.

---

## By the Numbers

| Metric | Value |
|--------|-------|
| Total commits | 645 |
| Active development days | 99 |
| Date range | July 13, 2025 – January 24, 2026 |
| Busiest day | August 22 (52 commits) |
| Reverts | 21 |
| Commits containing "CRITICAL" | 16 |
| Commits containing "ACTUALLY" or "FINALLY" | 3 |
| Commits containing "Award-winning" | 4 |
| Pull requests merged | 4 |
| Files accidentally deleted then restored | ~10 |
| Times the gradient system was rebuilt | At least 6 |
| Times the Menu component changed approach | 6 in 2 days |
| Authors | 1 designer + Claude |

---

## What the Git Log Reveals

Reading 645 commits chronologically, patterns emerge:

**The fix-fix-fix cycle.** Features rarely landed in one commit. A typical feature took 5–15 commits: the initial implementation, then a cascade of fixes as edge cases surfaced. Ambient mode took over 100 commits to stabilize.

**Reverts as a learning tool.** 21 reverts across the project. Not failures — course corrections. The willingness to revert quickly prevented small problems from compounding.

**Emotional honesty in commit messages.** "ACTUALLY fix." "FINALLY fixed!" "TEMP FIX: Hardcode API key to make it actually work." The commit log doesn't pretend things went smoothly. The caps lock tells you when it was 1am and nothing was working.

**Checkpoints before danger.** After early crises, a pattern emerged: `d6010f4 Checkpoint before code cleanup`, `6c5a4c2 Checkpoint: Pre-gradient system refactor`, `98e8c6a WIP: Before Claude Code session`. The project learned to save its state before risky operations.

**Design sensibility driving technical decisions.** The gradient wars, the note expansion obsession, the morphing animation marathon — these weren't engineering exercises. They were a designer refusing to ship something that didn't feel right, iterating through Claude Code until it did.

This is a story about building software through conversation rather than typing it by hand. The commits are the footprints. The app is the trail.
