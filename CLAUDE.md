# Epilogue - iOS Reading Companion

## Project Overview
Epilogue is a personal iOS app for capturing thoughts about books. Built with SwiftUI for iOS 26+, featuring Liquid Glass effects, Metal shaders, ambient mode with transcription, and quote capture via camera OCR.

**Location:** `/Users/kris/Epilogue`
**Bundle ID:** com.epilogue.app
**Minimum Target:** iOS 17.0 (iOS 26 for Liquid Glass features)

---

## Critical Rules

### NEVER Do These
1. **NEVER modify .pbxproj files** - Let Xcode handle project configuration
2. **NEVER use .background() before .glassEffect()** - Breaks Liquid Glass completely
3. **NEVER use SF Symbol "sparkles"** - Forbidden in this app
4. **NEVER rewrite working code** - ColorCube extraction works, just needs refinement
5. **NEVER say "You're absolutely right"** - Be direct, not sycophantic

### ALWAYS Do These
1. **Test after EVERY change** - Clean build (Cmd+Shift+K), then run (Cmd+R)
2. **Show code before changing** - Let me approve approach first
3. **Make incremental changes** - One thing at a time
4. **Commit working states** - So we can rewind if needed

---

## iOS 26 Liquid Glass Rules

```swift
// ❌ NEVER DO THIS - Breaks glass effects completely
.background(Color.white.opacity(0.1))
.glassEffect()

// ❌ ALSO BROKEN
.background(.clear)
.glassEffect()

// ✅ ALWAYS DO THIS - Apply directly with NO background modifiers
.glassEffect()

// ✅ Use glass tinting instead of backgrounds
.glassEffect(.regular.tint(.blue.opacity(0.3)))
```

**Glass weights available:** `.ultraThin`, `.thin`, `.regular`, `.thick`
**Group related glass:** Use `GlassEffectContainer` for multiple glass elements

---

## Architecture Overview

### Color Extraction (WORKING - Don't Rewrite)
- **Location:** `Epilogue/Core/Colors/OKLABColorExtractor.swift`
- **Method:** ColorCube 3D histogram with edge detection
- **Status:** ✅ Correctly extracts colors for most books
- **Known Issues:**
  - Silmarillion shows green instead of blue (role assignment issue)
  - Love Wins shows red instead of blue (role assignment issue)

### Gradient System
- **Location:** `Epilogue/Core/Background/BookAtmosphericGradientView.swift`
- **Style:** Enhanced colors (vibrant, not desaturated) like ambient chat
- **Key Function:** `enhanceColor()` - boosts saturation and brightness

### Image Loading
- Async processing to prevent UI freezing
- Downsampling to 400px max for performance
- Process heavy operations off main thread with async/await

### State Management
- Use `@Observable` macro (Swift 6 pattern)
- Avoid `@StateObject` and `@ObservableObject` (legacy patterns)
- Use `.task { }` instead of `.onAppear { Task { } }`

---

## Directory Structure

```
Epilogue/
├── App/              # App entry point, configuration
├── Core/             # Shared utilities, colors, backgrounds
│   ├── Colors/       # Color extraction (OKLABColorExtractor)
│   └── Background/   # Gradient views, atmospheric effects
├── Models/           # SwiftData models
├── Views/            # SwiftUI views
│   ├── AI/           # AI interaction views
│   ├── Chat/         # Conversation interfaces
│   └── ...
├── Services/         # API calls, data services
└── EpilogueWidgets/  # Widget extension
```

---

## Testing Books

After any color/gradient changes, test these:
| Book | Expected | Current Issue |
|------|----------|---------------|
| Lord of the Rings | Red + gold | ✅ Working |
| The Odyssey | Teal | ✅ Working |
| The Silmarillion | Blue | ❌ Shows green |
| Love Wins | Blue | ❌ Shows red |

### Console Output to Verify
```
🎨 ColorCube Extraction for [Book Name]
📊 Found X distinct color peaks
✅ Final ColorCube Palette:
  Primary: RGB(X, X, X)
  Secondary: RGB(X, X, X)
```

---

## Chat & AI View Patterns

### State Management for Chat
```swift
@Observable
final class ChatState {
    var messages: [Message] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var scrollPosition: String?
}
```

### Message Animation Sequence
```swift
.phaseAnimator([0, 1, 2], trigger: messageID) { content, phase in
    content
        .opacity(phase == 0 ? 0 : 1)
        .offset(y: phase == 0 ? 20 : 0)
} animation: { phase in
    switch phase {
    case 0: .easeOut(duration: 0.01)
    case 1: .spring(duration: 0.35, bounce: 0.3)
    default: .easeInOut(duration: 0.2)
    }
}
```

### Keyboard-Aware Scrolling
```swift
struct KeyboardAwareModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = frame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}
```

### Floating Composer with Glass
```swift
// ✅ CORRECT - Glass directly on content
TextField("Message...", text: $input)
    .padding()
    .glassEffect(.regular)

// ❌ WRONG - Background before glass
TextField("Message...", text: $input)
    .padding()
    .background(Color.white.opacity(0.1))
    .glassEffect()
```

---

## Performance Guidelines

1. **Use LazyVStack** for scrollable lists, not VStack
2. **Implement Equatable** on reusable views to prevent unnecessary redraws
3. **Downsample images** to 400px before processing
4. **Use async/await** for heavy operations - never block main thread
5. **Debounce scroll operations** (16ms delay)
6. **Limit concurrent animations** - max 4 at once

---

## Common Prompting Patterns

### When modifying colors
```
"I need to modify color extraction in OKLABColorExtractor.swift
Current issue: [describe specific problem]
Desired outcome: [what should happen]
Please show me the current implementation first."
```

### When modifying gradients
```
"I need to adjust gradients in BookAtmosphericGradientView.swift
Current: [describe current appearance]
Goal: [describe desired appearance]
Keep the enhanceColor approach from ambient chat."
```

### When adding a new feature
```
"I want to add [feature] to Epilogue.
Before writing code:
1. Show me which files would need to change
2. Outline the approach
3. Wait for my approval before implementing"
```

---

## Git Safety

### Before Claude Code Session
```bash
git add . && git commit -m "WIP: Pre-Claude checkpoint" && git push
```

### After Successful Changes
```bash
git add [specific files]
git commit -m "Fix: [what was fixed]"
git push origin main
```

### If Things Break
```bash
# See what changed
git status && git diff

# Undo everything
git reset --hard HEAD

# Restore specific file
git checkout origin/main -- path/to/broken/file.swift
```

---

## Session Starting Template

```
Working on Epilogue iOS app at /Users/kris/Epilogue

Context:
- iOS 26 with Liquid Glass (NO backgrounds before glass effects)
- ColorCube extraction working well
- Gradient system uses enhanceColor() like ambient chat

Rules:
- Don't modify .pbxproj files
- Make incremental changes
- Test after each change
- Show me the approach before implementing

Task: [specific task description]
```
