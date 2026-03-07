# Decisions

## 2025-12 - ColorCube over alternative extraction methods
**Context:** Tried multiple approaches to color extraction from book covers
**Decision:** ColorCube 3D histogram with OKLAB color space
**Reason:** Most accurate for book covers, handles dark covers well. Lives in `Core/Colors/OKLABColorExtractor.swift`

## 2025-12 - @Observable over @ObservableObject
**Context:** Migrating state management to Swift 6 patterns
**Decision:** Use `@Observable` macro exclusively, avoid legacy `@StateObject`/`@ObservableObject`
**Reason:** Swift 6 concurrency compliance, cleaner API, better performance

## 2025-12 - Enhanced vibrant gradients over desaturated
**Context:** Book atmospheric gradients looked washed out
**Decision:** Boost saturation and brightness via `enhanceColor()` in `BookAtmosphericGradientView`
**Reason:** Book covers deserve vivid, immersive backgrounds — not muted pastels

## 2026-01 - Claude-powered intelligent query routing
**Context:** Needed AI for reading companion chat
**Decision:** Route queries through local models first, Perplexity for factual lookups, Claude for conversational/recommendation queries
**Reason:** Minimizes API costs while keeping responses fast and contextual

## 2026-01 - Knowledge graph for thematic connections
**Context:** Wanted to surface connections between books in a user's library
**Decision:** Built entity extraction + graph query system with SwiftData-backed KnowledgeNode/MemoryThread models
**Reason:** Enables "books like this" and thematic insight features without external graph DB

## 2026-01 - Session memory system
**Context:** Context lost between Claude Code sessions — re-exploration wastes time
**Decision:** Three-file memory system (`memory/active.md`, `decisions.md`, `sessions.md`) tracked in git
**Reason:** Lightweight, no tooling dependencies, versioned with the project, readable by any session
