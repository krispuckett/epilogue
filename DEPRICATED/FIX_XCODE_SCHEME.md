# Fix Xcode Scheme Issue

The project files have been reorganized but the Xcode project file still references old locations. This is causing the "Cannot clean Build Folder without an active scheme" error.

## Quick Fix Steps:

1. **Open Xcode**
2. **Close the project** if it's open
3. **Delete derived data**:
   - `rm -rf ~/Library/Developer/Xcode/DerivedData/Epilogue-*`
4. **Open the project again in Xcode**
5. **If the scheme is missing**:
   - Click on the scheme selector (next to the Run button)
   - Select "Manage Schemes..."
   - Click the "+" button
   - Create a new scheme named "Epilogue"
   - Select the "Epilogue" target

## Alternative: Let Xcode Fix References

1. In Xcode, you'll see many files in red (missing)
2. For each red file:
   - Right-click → "Show in Finder"
   - Navigate to the new location (check the structure below)
   - Select the file to update the reference

## New File Structure:
```
Epilogue/Views/
├── Chat/
│   ├── ChatView.swift
│   ├── ChatConversationView.swift
│   └── ...
├── Components/
│   ├── UniversalCommandBar.swift
│   ├── LiquidCommandPalette.swift
│   └── ...
├── Core/
│   ├── OKLABColorExtractor.swift
│   ├── BookCoverBackgroundView.swift
│   ├── ColorExtractionDiagnostic.swift
│   └── DisplayColorScheme.swift (NEW - needs to be added)
├── Library/
│   ├── BookDetailView.swift
│   ├── LibraryView.swift
│   └── ...
└── Notes/
    ├── NotesView.swift
    └── ...
```

## Adding DisplayColorScheme.swift to Project

1. In Xcode, right-click on the `Core` group
2. Select "Add Files to Epilogue..."
3. Navigate to `Epilogue/Core/Colors/DisplayColorScheme.swift`
4. Make sure "Copy items if needed" is unchecked
5. Make sure "Epilogue" target is checked
6. Click "Add"

## If All Else Fails

The simplest solution might be to:
1. Create a new Xcode project
2. Add all the Swift files from their new locations
3. Copy over the Info.plist and xcconfig settings