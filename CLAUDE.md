# Epilogue - iOS Reading Companion

## Project Overview
Epilogue is a personal iOS app for capturing thoughts about books. Built with SwiftUI for iOS 26, featuring Liquid Glass effects, Metal shaders, ambient mode with transcription, and quote capture via camera OCR.

**Location:** `/Users/kris/Epilogue`

## Session Memory
Read `memory/active.md` before starting work. It contains current project state,
recent changes, and next steps from previous sessions. Update memory files after
commits or completing features.

---

## Critical Rules

### NEVER Do These
1. **NEVER modify .pbxproj files** - Let Xcode handle project configuration
2. **NEVER use .background() before .glassEffect()** - Breaks Liquid Glass completely
3. **NEVER use SF Symbol "sparkles"** - Forbidden in this app
4. **NEVER rewrite working code** - ColorCube extraction works, refine don't rebuild
5. **NEVER say "You're absolutely right"** - Be direct, not sycophantic

### ALWAYS Do These
1. **Test after EVERY change** - Clean build (Cmd+Shift+K), then run (Cmd+R)
2. **Show code before changing** - Let me approve approach first
3. **Make incremental changes** - One thing at a time
4. **Commit working states** - So we can rewind if needed

---

## Skills Reference

Load these skills from `~/.claude/skills/` when relevant:

| Skill | When to Load |
|-------|-------------|
| `swiftui-liquid-glass` | Implementing or reviewing Liquid Glass effects |
| `swift-concurrency-expert` | Fixing Swift 6 concurrency errors, actor isolation, Sendable issues |
| `swiftui-performance-audit` | Diagnosing scroll jank, slow renders, excessive view updates |
| `swiftui-view-refactor` | Restructuring views, fixing @Observable patterns, dependency injection |
| `app-store-changelog` | Generating release notes from git history |

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

### Color Extraction
- **Location:** `Epilogue/Core/Colors/OKLABColorExtractor.swift`
- **Method:** ColorCube 3D histogram with edge detection

### Gradient System
- **Location:** `Epilogue/Core/Background/BookAtmosphericGradientView.swift`
- **Style:** Enhanced colors (vibrant, not desaturated)
- **Key Function:** `enhanceColor()` - boosts saturation and brightness

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
├── Services/         # API calls, data services
└── EpilogueWidgets/  # Widget extension
```

---

## Session Starting Template

```
Working on Epilogue iOS app at /Users/kris/Epilogue

Task: [specific task description]
```

---

## Git Safety

### Before Risky Changes
```bash
git add . && git commit -m "WIP: Pre-Claude checkpoint" && git push
```

### If Things Break
```bash
git status && git diff
git reset --hard HEAD
```
