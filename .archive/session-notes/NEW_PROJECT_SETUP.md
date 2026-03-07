# EPILOGUE - NEW PROJECT SETUP GUIDE

## 1. Create New Xcode Project
- iOS App
- Name: **Epilogue**
- Interface: SwiftUI
- Language: Swift
- Use Core Data: **NO**
- Include Tests: **YES**

## 2. Delete Default ContentView.swift
Delete the ContentView.swift that Xcode creates by default

## 3. Add Files to Project

### ✅ CORE APP FILES
- [ ] `Epilogue/EpilogueApp.swift`
- [ ] `Epilogue/ContentView.swift`
- [ ] `Epilogue/Typography.swift`

### ✅ MODELS (create 'Models' group)
- [ ] `Epilogue/Models/ChatThread.swift`
- [ ] `Epilogue/Models/CommandIntent.swift`
- [ ] `Epilogue/Models/GoogleBooksAPI.swift`
- [ ] `Epilogue/Models/LiteraryQuotes.swift`

### ✅ CORE (create 'Core' group with subgroups)

**Core/Colors/:**
- [ ] `Epilogue/Core/Colors/OKLABColorExtractor.swift`
- [ ] `Epilogue/Core/Colors/DisplayColorScheme.swift`
- [ ] `Epilogue/Core/Colors/ColorExtractionDiagnostic.swift`

**Core/Background/:**
- [ ] `Epilogue/Core/Background/BookCoverBackgroundView.swift`

### ✅ VIEWS (create 'Views' group with subgroups)

**Views/Library/:**
- [ ] `Epilogue/Views/Library/BookDetailView.swift`
- [ ] `Epilogue/Views/Library/LibraryView.swift`
- [ ] `Epilogue/Views/Library/BookSearchSheet.swift`
- [ ] `Epilogue/Views/Library/EditBookSheet.swift`
- [ ] `Epilogue/Views/Library/SharedBookCoverView.swift`
- [ ] `Epilogue/Views/Library/BookPickerSheet.swift`
- [ ] `Epilogue/Views/Library/ReadingProgressIndicator.swift`
- [ ] `Epilogue/Views/Library/LiteraryLoadingView.swift`

**Views/Notes/:**
- [ ] `Epilogue/Views/Notes/NotesView.swift`
- [ ] `Epilogue/Views/Notes/NoteCardComponents.swift`
- [ ] `Epilogue/Views/Notes/NoteContextMenu.swift`

**Views/Chat/:**
- [ ] `Epilogue/Views/Chat/ChatView.swift`
- [ ] `Epilogue/Views/Chat/ChatConversationView.swift`
- [ ] `Epilogue/Views/Chat/ChatThreadListView.swift`
- [ ] `Epilogue/Views/Chat/ChatInputBar.swift`
- [ ] `Epilogue/Views/Chat/InteractiveChatInputBar.swift`

**Views/Components/:**
- [ ] `Epilogue/Views/Components/UniversalCommandBar.swift`
- [ ] `Epilogue/Views/Components/LiquidCommandPalette.swift`
- [ ] `Epilogue/Views/Components/CommandSuggestionsView.swift`
- [ ] `Epilogue/Views/Components/AmbientBackground.swift`
- [ ] `Epilogue/Views/Components/MarkdownText.swift`
- [ ] `Epilogue/Views/Components/ShimmerEffect.swift`
- [ ] `Epilogue/Views/Components/FeatherIcon.swift`

### ✅ AMBIENT (create 'Ambient' group)
- [ ] `Epilogue/Ambient/AmbientBookView.swift`
- [ ] `Epilogue/Ambient/ColorIntelligenceEngine.swift`

### ✅ VIEWMODELS (check if these exist first)
- [ ] `Epilogue/ViewModels/LibraryViewModel.swift` (if exists)
- [ ] `Epilogue/ViewModels/NotesViewModel.swift` (if exists)

### ✅ UTILITIES (check if these exist first)
- [ ] `Epilogue/Utilities/HapticManager.swift` (if exists)
- [ ] `Epilogue/Utilities/ViewExtensions.swift` (if exists)

## 4. Copy Resources
- [ ] Replace default `Assets.xcassets` with `Epilogue/Assets.xcassets`
- [ ] Check `Info.plist` for custom settings

## 5. Add to Info.plist
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Epilogue needs access to save book covers</string>
```

## 6. Build Settings
- iOS Deployment Target: **17.0** or higher
- Swift Language Version: **5.0**

## 7. After Adding All Files
1. Build project (⌘B)
2. Fix any import issues
3. Run on simulator

---

## ❌ DO NOT ADD (Deprecated Files)
All files in `Epilogue/Views/_Deprecated/` - these are old implementations

## File Count Summary
Based on current structure, you should be adding approximately:
- ~4 Core files
- ~8 Library view files  
- ~3 Notes view files
- ~5 Chat view files
- ~7 Component files
- ~4 Model files
- ~2 Ambient files

**Total: ~35-40 Swift files** (excluding deprecated ones)