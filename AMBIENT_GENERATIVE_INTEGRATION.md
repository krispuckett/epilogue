# Ambient Generative Actions - Integration Guide

## Overview

This system adds generative capabilities to Ambient Mode:
- **Template Generation**: Character maps, reading guides, theme trackers
- **Journey Creation**: Multi-book reading plans through conversation
- **Library Actions**: Add books via voice/text
- **Pattern Analysis**: Reading habit insights

All with **spoiler-safe** content filtering.

---

## Architecture

```
User Message
    ↓
EnhancedIntentDetector.detectGenerativeIntent()
    ↓
AmbientActionRouter.routeIntent()
    ↓
├─ Template Generation → TemplateGenerator
├─ Journey Creation → ConversationalJourneyBuilder
├─ Book Addition → (TODO: BookSearchService)
└─ Pattern Analysis → (TODO: PatternAnalyzer)
    ↓
Preview Component (TemplatePreviewCard, JourneyPreviewCard)
    ↓
User Confirms
    ↓
Save to SwiftData / Navigate to View
```

---

## Integration Points

### 1. Ambient Message Processing

**Location**: `TrueAmbientProcessor.swift` or wherever ambient messages are handled

**Add after existing intent detection:**

```swift
// Existing intent detection
let enhancedIntent = enhancedIntentDetector.detectIntent(from: message)

// NEW: Check for generative intents
if let generativeIntent = enhancedIntentDetector.detectGenerativeIntent(from: message) {
    let actionRouter = AmbientActionRouter(modelContext: modelContext)
    let action = await actionRouter.routeIntent(
        generativeIntent,
        currentBook: currentBook,
        conversationHistory: conversationHistory
    )

    return handleAmbientAction(action)
}

// Continue with existing processing...
```

### 2. Handle Ambient Actions

**Add new function to handle action results:**

```swift
func handleAmbientAction(_ action: AmbientAction) -> AmbientResponse {
    switch action {
    case .showTemplatePreview(let preview):
        // Show TemplatePreviewCard in chat
        return .showPreviewCard(preview)

    case .navigateToTemplate(let template, let book):
        // Navigate to CharacterMapView
        navigationCoordinator.navigate(to: .characterMap(template, book))
        return .message("Opening template...")

    case .showJourneyPreview(let preview):
        // Show JourneyPreviewCard in chat
        return .showJourneyCard(preview)

    case .showBookSearch(let request):
        // Open book search
        return .message("Searching for \(request.title)...")

    case .startConversationalFlow(let flow):
        // Handle multi-turn conversation
        return handleConversationalFlow(flow)

    case .message(let text):
        return .message(text)

    case .error(let error):
        return .error(error)
    }
}
```

### 3. Display Preview Cards in Chat

**Location**: `UnifiedChatView.swift` or wherever chat messages are rendered

**Add after message rendering:**

```swift
ForEach(messages) { message in
    // Existing message display
    MessageBubble(message: message)

    // NEW: Show action previews
    if let actionPreview = message.actionPreview {
        switch actionPreview {
        case .templatePreview(let preview):
            TemplatePreviewCard(preview: preview) {
                // On confirm
                navigateToTemplate(preview.template, preview.book)
            }

        case .journeyPreview(let preview):
            JourneyPreviewCard(preview: preview) {
                // On create
                createJourney(preview)
            }
        }
    }
}
```

### 4. Book Enrichment Trigger

**Location**: `LibraryViewModel.swift` or wherever books are added

**Add enrichment trigger when book is added:**

```swift
func addBook(_ book: Book) {
    modelContext.insert(book)
    try? modelContext.save()

    // NEW: Enrich book in background
    BookEnrichmentService.shared.enrichBookInBackground(book, context: modelContext)
}
```

### 5. Template Access from Book Detail

**Location**: `BookDetailView.swift` or book actions menu

**Add template options:**

```swift
Menu {
    // Existing actions...

    Divider()

    // NEW: Template actions
    if book.hasEnrichment {
        Menu("Tools") {
            Button {
                createTemplate(.characters)
            } label: {
                Label("Character Map", systemImage: "person.2")
            }

            Button {
                createTemplate(.guide)
            } label: {
                Label("Reading Guide", systemImage: "book")
            }

            Button {
                createTemplate(.themes)
            } label: {
                Label("Theme Tracker", systemImage: "lightbulb")
            }
        }
    } else {
        Text("Enriching book...")
            .foregroundStyle(.secondary)
    }
}

func createTemplate(_ type: TemplateType) {
    Task {
        let generator = TemplateGenerator(modelContext: modelContext)
        let enrichment = book.getEnrichment(context: modelContext)!

        let template = try? await generator.generateCharacterMap(
            for: book,
            enrichment: enrichment,
            progress: book.readingProgress
        )

        if let template = template {
            modelContext.insert(template)
            try? modelContext.save()
            showTemplate(template)
        }
    }
}
```

---

## Navigation Setup

**Add new navigation destinations:**

```swift
enum NavigationDestination {
    // Existing...
    case characterMap(GeneratedTemplate, Book)
    case readingGuide(GeneratedTemplate, Book)
    case themeTracker(GeneratedTemplate, Book)
}

// In navigation view:
.navigationDestination(for: NavigationDestination.self) { destination in
    switch destination {
    case .characterMap(let template, let book):
        CharacterMapView(book: book, template: template)

    case .readingGuide(let template, let book):
        // Similar view for reading guide

    case .themeTracker(let template, let book):
        // Similar view for theme tracker
    }
}
```

---

## Data Models Already Registered

The following models are already added to `ModelContainer`:
- `BookEnrichment`
- `GeneratedTemplate`

These will be automatically available in SwiftData.

---

## Testing Checklist

### 1. Template Generation
- [ ] Can request "create character map for Dune" from ambient
- [ ] Template preview appears in chat
- [ ] Can tap to open full template view
- [ ] Template shows correct chapter boundary
- [ ] No spoilers beyond current progress

### 2. Spoiler Protection
- [ ] Conservative mode shows 1 chapter behind
- [ ] Current mode shows exact progress
- [ ] Manual mode doesn't auto-update
- [ ] Update notifications appear at right times

### 3. Template Updates
- [ ] Can manually update to new chapter
- [ ] Update merges with existing content
- [ ] User notes are preserved
- [ ] Settings work correctly

### 4. Journey Creation
- [ ] Can request "create reading journey"
- [ ] Multi-turn conversation works
- [ ] Journey preview shows in chat
- [ ] Can create journey from preview

### 5. Book Enrichment
- [ ] Books enrich in background when added
- [ ] Enrichment status visible
- [ ] Templates fail gracefully if no enrichment
- [ ] Can retry enrichment if failed

---

## Error Handling

### No Enrichment
```swift
if book.getEnrichment(context: modelContext) == nil {
    return .message("This book hasn't been enriched yet. Give me a minute...")
}
```

### Generation Failure
```swift
do {
    let template = try await generator.generateCharacterMap(...)
} catch {
    return .error("Failed to generate template. Please try again.")
}
```

### Invalid Chapter Boundary
```swift
if book.readingProgress.currentChapter == nil {
    // Ask user
    return .question("What chapter are you on? This helps prevent spoilers.")
}
```

---

## Performance Notes

1. **Enrichment**: Happens in background, doesn't block UI
2. **Template Generation**: Takes 10-15s on-device, show loading state
3. **Preview Cards**: Render quickly, no heavy computation
4. **Updates**: Async, don't block scroll

---

## TODO: Remaining Work

### High Priority
1. **Sonar API Integration**: Complete `BookEnrichmentService` Sonar client
2. **Book Search**: Implement Google Books search for "add book" feature
3. **Journey Creation**: Wire up journey builder to `ReadingJourneyManager`

### Medium Priority
4. **Pattern Analysis**: Implement reading pattern insights
5. **Theme-based Recommendations**: Use enrichment for better recs
6. **Progressive Revelation UI**: Better visual for updates

### Low Priority
7. **Plot Timeline Template**: Fourth template type
8. **Export Templates**: Share character maps
9. **Template Themes**: Dark/light mode tweaks

---

## File Structure

```
Epilogue/
├── Models/
│   ├── BookEnrichment.swift ✓
│   └── GeneratedTemplate.swift ✓
│
├── Services/
│   ├── Enrichment/
│   │   └── BookEnrichmentService.swift ✓
│   │
│   ├── Templates/
│   │   ├── TemplateGenerator.swift ✓
│   │   ├── SpoilerSafeFilter.swift ✓
│   │   └── TemplateUpdateManager.swift ✓
│   │
│   └── Ambient/
│       ├── EnhancedIntentExtensions.swift ✓
│       ├── AmbientActionRouter.swift ✓
│       └── ConversationalJourneyBuilder.swift ✓
│
└── Views/
    ├── Templates/
    │   ├── CharacterMapView.swift ✓
    │   └── TemplateSpoilerSettings.swift ✓
    │
    └── Ambient/Components/
        ├── TemplatePreviewCard.swift ✓
        └── JourneyPreviewCard.swift ✓
```

---

## Quick Start

1. **Enable enrichment**: Uncomment enrichment trigger in book addition
2. **Add intent detection**: Add `detectGenerativeIntent()` check in message processor
3. **Wire up preview cards**: Add preview rendering in chat view
4. **Test with popular book**: Try "create character map for Dune"
5. **Verify spoiler protection**: Check boundary is conservative

---

## Support

For questions about integration, see:
- Architecture diagram above
- Code comments in each service file
- Example usage in test files (TODO: create these)
