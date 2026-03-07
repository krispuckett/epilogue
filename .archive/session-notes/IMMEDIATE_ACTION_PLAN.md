# Epilogue - Immediate Action Plan
## Priority Fixes for TestFlight Readiness

### 🚨 CRITICAL - Fix Today

#### 1. Memory Leak in SharedBookCoverManager
**File:** `/Epilogue/Core/Images/SharedBookCoverManager.swift`

**Issue:** Active tasks never cleared, causing memory buildup

**Fix:**
```swift
// Add to SharedBookCoverManager class:

// Clean up completed tasks periodically
private func cleanupTasks() {
    activeTasks = activeTasks.filter { _, task in
        !task.isCancelled && task.value == nil
    }
}

// Add deinit to cancel all tasks
deinit {
    activeTasks.values.forEach { $0.cancel() }
    activeTasks.removeAll()
}

// Modify loadAndCacheImage to clean up:
private func loadAndCacheImage(...) async -> UIImage? {
    defer {
        activeTasks[cacheKey] = nil
        cleanupTasks() // Periodic cleanup
    }
    // ... rest of implementation
}
```

#### 2. Create Privacy Manifest (Required for App Store)
**Create file:** `/Epilogue/PrivacyInfo.xcprivacy`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeCrashData</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

#### 3. Add Error Boundary
**Create file:** `/Epilogue/Core/Safety/ErrorBoundary.swift`

```swift
import SwiftUI

struct ErrorBoundary<Content: View>: View {
    @State private var hasError = false
    @State private var errorMessage = ""
    let content: () -> Content
    
    var body: some View {
        Group {
            if hasError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Something went wrong")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        hasError = false
                        errorMessage = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                content()
                    .onAppear {
                        // Set up error catching if needed
                    }
            }
        }
    }
}

extension View {
    func withErrorHandling() -> some View {
        ErrorBoundary {
            self
        }
    }
}
```

#### 4. Safe SwiftData Operations
**Create file:** `/Epilogue/Core/Safety/SafeSwiftData.swift`

```swift
import SwiftData
import SwiftUI

extension ModelContext {
    func safeSave() {
        do {
            if hasChanges {
                try save()
            }
        } catch {
            print("❌ SwiftData save failed: \(error)")
            // Don't crash, just log
        }
    }
    
    func safeFetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T: PersistentModel {
        do {
            return try fetch(descriptor)
        } catch {
            print("❌ SwiftData fetch failed: \(error)")
            return []
        }
    }
}

// Safe deletion with rollback
extension ModelContext {
    func safeDelete<T: PersistentModel>(_ model: T) {
        do {
            delete(model)
            try save()
        } catch {
            print("❌ SwiftData delete failed: \(error)")
            rollback()
        }
    }
}
```

#### 5. Fix Potential Retain Cycles
**File:** `/Epilogue/Services/OptimizedPerplexityService.swift`

**Fix weak references in closures:**
```swift
// Line ~99-101, add [weak self]:
await queueRequest(query: query, bookContext: bookContext, continuation: continuation)

// Should be:
Task { [weak self] in
    await self?.queueRequest(query: query, bookContext: bookContext, continuation: continuation)
}
```

---

### 📊 Performance Fixes - Day 2

#### 1. Optimize LazyVGrid Performance
**File:** `/Epilogue/Views/Library/LibraryView.swift`

```swift
// Replace LazyVGrid with optimized version:
struct OptimizedLibraryGrid: View {
    let books: [Book]
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 32
            ) {
                ForEach(books) { book in
                    LibraryGridItem(book: book)
                        .id(book.localId)
                        .task { // Use task instead of onAppear
                            await preloadNeighbors(for: book)
                        }
                }
            }
            .padding(.horizontal)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }
}
```

#### 2. Add Loading States
**Create file:** `/Epilogue/Core/Components/LoadingStates.swift`

```swift
import SwiftUI

struct SkeletonLoader: View {
    @State private var opacity = 0.4
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                    opacity = 1.0
                }
            }
    }
}

struct BookCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonLoader()
                .frame(height: 200)
                .cornerRadius(8)
            
            SkeletonLoader()
                .frame(height: 16)
            
            SkeletonLoader()
                .frame(height: 14)
                .opacity(0.6)
        }
    }
}
```

---

### 📱 TestFlight Requirements - Day 3

#### 1. App Store Connect Metadata

**App Description (save to use later):**
```
Epilogue - Your AI-Powered Reading Companion

Transform your reading experience with Epilogue, the intelligent library manager that remembers every thought, quote, and insight from your literary journey.

KEY FEATURES:

📚 Smart Library Management
• Beautiful visual library with cover art
• Track reading progress and status
• Quick book discovery and addition
• Goodreads import support

💭 Ambient Reading Sessions
• Capture thoughts in real-time while reading
• Voice-to-text note taking
• Automatic session summaries
• Reading streak tracking

🤖 AI-Powered Chat
• Discuss books with AI that understands context
• Get personalized reading recommendations
• Deep-dive into themes and concepts
• Citation-backed responses

✨ Capture Everything
• Save meaningful quotes instantly
• Add personal notes and reflections
• Create reading questions for book clubs
• Export your insights

🎙️ Voice Intelligence
• Hands-free note capture
• Voice commands for quick actions
• Natural language processing
• WhisperKit integration

Epilogue isn't just another reading tracker - it's your personal reading assistant that helps you engage more deeply with every book you read.

Perfect for book clubs, students, researchers, and anyone who wants to remember and reflect on what they read.

Start building your literary legacy today.
```

**Keywords (100 chars):**
```
reading,books,library,notes,quotes,AI,book tracker,goodreads,book club,literature,reader,ebook
```

**What to Test:**
```
Please test the following features:
1. Adding books to your library (search or scan)
2. Creating notes and quotes while reading
3. Starting an ambient reading session
4. Using the AI chat to discuss books
5. Voice input for hands-free note taking
6. Syncing across devices (if applicable)
7. Dark mode and visual effects
8. Overall app performance and stability

Known Issues:
- Some book covers may load slowly on first launch
- Voice recognition requires iOS 26
```

#### 2. Screenshot Checklist
- [ ] 6.7" iPhone 26 Pro Max (1320 × 2868)
- [ ] 6.1" iPhone 26 Pro (1206 × 2622) 
- [ ] 5.5" iPhone 8 Plus (1242 × 2208)

**Suggested Screenshots:**
1. Library view with beautiful covers
2. Book detail with notes
3. AI chat conversation
4. Ambient reading session
5. Voice capture in action

---

### 🧪 Testing Checklist - Day 4

#### Core Functionality
- [ ] Add 10+ books rapidly
- [ ] Create 20+ notes/quotes
- [ ] Test with 100+ books in library
- [ ] Voice input in noisy environment
- [ ] Offline mode behavior
- [ ] Memory usage over time
- [ ] Battery usage during ambient session

#### Edge Cases
- [ ] No internet connection
- [ ] Invalid API key
- [ ] Corrupted book data
- [ ] Very long book titles
- [ ] Special characters in notes
- [ ] Rapid screen rotation
- [ ] Background/foreground transitions

#### Performance Metrics
- [ ] App launch time < 2 seconds
- [ ] Book search response < 1 second  
- [ ] Image loading < 3 seconds
- [ ] Smooth 60fps scrolling
- [ ] Memory usage < 200MB idle
- [ ] No memory leaks after 30 min use

---

### 📋 Pre-Submission Checklist

#### Code Cleanup
```bash
# Remove all print statements
grep -r "print(" --include="*.swift" . | wc -l
# Should be < 10 (only essential logs)

# Find force unwraps
grep -r "!" --include="*.swift" . | grep -v "!=" | wc -l
# Fix any critical ones

# Find TODOs
grep -r "TODO" --include="*.swift" . | wc -l
# Document or remove
```

#### Build Settings
- [ ] Set build configuration to Release
- [ ] Disable all debug flags
- [ ] Enable optimizations
- [ ] Strip debug symbols
- [ ] Validate entitlements

#### Final Tests
- [ ] Clean install test
- [ ] Upgrade from old version test
- [ ] iCloud sync test
- [ ] All device sizes test
- [ ] iOS 25 compatibility test

---

## Timeline

**Day 1 (Today):** Critical fixes
- Memory leaks ⏰ 2 hours
- Privacy manifest ⏰ 30 min
- Error boundaries ⏰ 1 hour
- Safety wrappers ⏰ 1 hour

**Day 2:** Performance
- Loading states ⏰ 2 hours
- Scroll optimization ⏰ 2 hours
- Image pipeline ⏰ 2 hours

**Day 3:** TestFlight prep
- Screenshots ⏰ 2 hours
- Metadata ⏰ 1 hour
- Build config ⏰ 1 hour

**Day 4:** Testing & submission
- Full testing ⏰ 3 hours
- Fix critical bugs ⏰ 2 hours
- Submit to TestFlight ⏰ 1 hour

---

*Ready for TestFlight in 4 days with focused execution*