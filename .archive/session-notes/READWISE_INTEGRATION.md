# Readwise Integration Setup

## ⚠️ Important: Files Need to Be Added to Xcode

Due to project constraints, the Readwise integration files have been created but **need to be manually added to your Xcode project**. Without adding these files to Xcode, the app will not compile.

## Files Created

The following files have been created for the Readwise integration:

1. **ReadwiseService.swift** - Located at: `/Epilogue/Services/ReadwiseService.swift`
   - Contains the main Readwise API integration
   - Handles authentication, import, and export

2. **ReadwiseSyncView.swift** - Located at: `/Epilogue/Views/Settings/ReadwiseSyncView.swift`
   - Beautiful glass-effect UI for Readwise sync
   - Matches your app's design language

## How to Add to Xcode

### Step 1: Add Service File
1. Open your Epilogue project in Xcode
2. In the project navigator, right-click on the `Services` folder
3. Select "Add Files to 'Epilogue'..."
4. Navigate to and select `ReadwiseService.swift`
5. Make sure "Copy items if needed" is UNCHECKED
6. Make sure your app target is selected
7. Click "Add"

### Step 2: Add View File
1. In the project navigator, right-click on the `Views/Settings` folder
2. Select "Add Files to 'Epilogue'..."
3. Navigate to and select `ReadwiseSyncView.swift`
4. Make sure "Copy items if needed" is UNCHECKED
5. Make sure your app target is selected
6. Click "Add"

### Step 3: Build and Run
1. Clean the build folder (Cmd+Shift+K)
2. Build and run the project (Cmd+R)

## Known Issues Fixed

The following issues have been resolved in the code:
- ✅ Added `import Combine` to both files
- ✅ Removed duplicate `chunked` extension (already exists in GoodreadsImportService)
- ✅ Made GoodreadsImportService's `chunked` extension private to avoid conflicts
- ✅ Added `exportedToReadwise` property to CapturedQuote model
- ✅ Updated KeychainManager to support Readwise tokens

## ⚠️ Build Will Fail Until Files Are Added to Xcode

The project will not build successfully until both ReadwiseService.swift and ReadwiseSyncView.swift are properly added to the Xcode project. This is expected behavior.

## What's Been Modified

1. **KeychainManager.swift** - Added support for Readwise API tokens
2. **CapturedQuote model** - Added `exportedToReadwise` tracking
3. **SettingsView.swift** - Added Readwise sync option in Library Management section

## How It Works

1. Users go to Settings → Library Management → Sync with Readwise
2. Add their Readwise API token (get from readwise.io/access_token)
3. Choose sync direction (import, export, or two-way)
4. Tap "Sync Now" to sync highlights

## Features

- ✅ Two-way sync with Readwise
- ✅ Beautiful glass-effect UI matching your app design
- ✅ Secure token storage in Keychain
- ✅ Progress tracking during sync
- ✅ Rate limiting and error handling
- ✅ Duplicate detection
- ✅ Preserves all metadata (page numbers, timestamps, etc.)

## Testing

1. Get a Readwise API token from https://readwise.io/access_token
2. Go to Settings → Library Management → Sync with Readwise
3. Add your token
4. Try importing some highlights
5. Create some quotes in Epilogue and export them

The integration follows all your project guidelines and design patterns!