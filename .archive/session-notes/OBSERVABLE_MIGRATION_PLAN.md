# @Observable Migration Plan for Epilogue

## Overview
This document outlines a safe, incremental migration plan from `ObservableObject` to the modern `@Observable` macro introduced in iOS 17.

## Current State Analysis
- **20 classes** using `ObservableObject`
- **73 files** with `@StateObject`, `@ObservedObject`, or `@EnvironmentObject`
- **155 total** property wrapper occurrences

## Migration Benefits
1. **Performance**: Automatic granular observation (only observes used properties)
2. **Simplicity**: No need for `@Published` property wrappers
3. **Memory**: Better memory management with automatic cleanup
4. **SwiftUI Integration**: Better integration with SwiftUI's rendering system

## Phase 1: Low-Risk Services (Week 1)
Start with services that have minimal UI dependencies:

### Batch 1A - Utility Services
- [ ] `ErrorHandlingService` - Simple error state management
- [ ] `ImageCacheMonitor` - Cache monitoring with basic state
- [ ] `MotionManager` - Device motion tracking

### Batch 1B - Data Services  
- [ ] `CommandHistoryManager` - Command history tracking
- [ ] `NotesSyncManager` - Note synchronization
- [ ] `SessionSummaryGenerator` - Session summary generation

**Testing After Phase 1:**
- Run all unit tests
- Test error handling flows
- Verify image caching works
- Check command history persistence

## Phase 2: AI & Processing Services (Week 2)
Services with moderate complexity:

### Batch 2A - AI Services
- [ ] `ResponseSynthesizer` - AI response generation
- [ ] `NoteIntelligenceEngine` - Note analysis
- [ ] `SessionIntelligence` - Session insights

### Batch 2B - Ambient Processing
- [ ] `SmartContentBuffer` - Content buffering
- [ ] `SessionContinuationService` - Session continuation
- [ ] `ColorIntelligenceEngine` - Color extraction

**Testing After Phase 2:**
- Test AI response generation
- Verify ambient processing flows
- Check session continuation

## Phase 3: Core Services (Week 3)
Critical services requiring careful testing:

### Batch 3A - Main Services
- [ ] `AICompanionService` - Main AI service (singleton)
- [ ] `OptimizedPerplexityService` - Perplexity integration
- [ ] `BookScannerService` - Book scanning

### Batch 3B - Ambient Services
- [ ] `UltraFastAmbientProcessor` - Fast ambient processing
- [ ] `TrueAmbientProcessor` - Full ambient processing
- [ ] `AmbientReadingIntegrationManager` - Ambient integration

**Testing After Phase 3:**
- Full ambient mode testing
- Book scanning workflows
- AI companion interactions

## Phase 4: View Models (Week 4)
View-specific models:

- [ ] `NotesViewModel` - Notes view state
- [ ] `ResponseViewModel` - Response display state

## Migration Pattern

### Before (ObservableObject):
```swift
class MyService: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published private(set) var error: Error?
    
    func loadItems() {
        isLoading = true
        // ...
    }
}

// Usage
struct MyView: View {
    @StateObject private var service = MyService()
    // or
    @ObservedObject var service: MyService
    // or  
    @EnvironmentObject var service: MyService
}
```

### After (@Observable):
```swift
@Observable
class MyService {
    var items: [Item] = []
    var isLoading = false
    private(set) var error: Error?
    
    func loadItems() {
        isLoading = true
        // ...
    }
}

// Usage
struct MyView: View {
    @State private var service = MyService()
    // or
    var service: MyService  // if passed in
    // or
    @Environment(MyService.self) var service
}
```

## Step-by-Step Migration Process

### For Each Class:

1. **Create Feature Branch**
   ```bash
   git checkout -b migrate-observable-[service-name]
   ```

2. **Update Class Declaration**
   - Add `import Observation` if needed
   - Replace `class X: ObservableObject` with `@Observable class X`
   - Remove all `@Published` property wrappers
   - Keep `private(set)` for read-only properties

3. **Update Usage Sites**
   - `@StateObject` → `@State`
   - `@ObservedObject` → plain property
   - `@EnvironmentObject` → `@Environment(ServiceType.self)`

4. **Update Environment Injection**
   ```swift
   // Before
   .environmentObject(service)
   
   // After
   .environment(service)
   ```

5. **Test Thoroughly**
   - Run unit tests
   - Test UI interactions
   - Check for memory leaks
   - Verify state updates

6. **Commit & Push**
   ```bash
   git add .
   git commit -m "Migrate [ServiceName] to @Observable"
   git push origin migrate-observable-[service-name]
   ```

## Special Considerations

### Singletons
Services using `shared` singleton pattern:
- `AICompanionService.shared`
- `NotesSyncManager.shared`
- `ErrorHandlingService.shared`

These need special handling to maintain singleton behavior with @Observable.

### Combine Integration
Services using Combine publishers need careful migration:
- Keep `PassthroughSubject` and `CurrentValueSubject` for now
- Can gradually migrate to async/await patterns

### SwiftData Integration
Services working with SwiftData models should be migrated after testing SwiftData compatibility.

## Rollback Plan

If issues arise:
1. **Immediate Rollback**: Git revert the specific migration commit
2. **Partial Rollback**: Keep @Observable but add back @Published for problematic properties
3. **Hybrid Approach**: Some services stay ObservableObject while others migrate

## Success Metrics

- [ ] No regression in app functionality
- [ ] Improved scroll performance (measure with Instruments)
- [ ] Reduced memory usage (measure with Memory Graph)
- [ ] Cleaner code with fewer property wrappers
- [ ] All tests passing

## Testing Checklist for Each Migration

- [ ] Unit tests pass
- [ ] UI updates correctly
- [ ] No memory leaks
- [ ] State persistence works
- [ ] Background updates work
- [ ] Error states handled
- [ ] Performance acceptable

## Notes

- iOS 17.0+ required for @Observable
- Some third-party libraries may need updates
- Consider keeping ObservableObject for public APIs if needed
- Document any workarounds needed

## References

- [Apple Documentation: Observation](https://developer.apple.com/documentation/observation)
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/wwdc23/10149)
- [Migration Guide](https://www.swiftbysundell.com/articles/observable-macro/)