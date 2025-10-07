# Epilogue Widget Extension Setup Guide

All widget implementation files have been created in `/Users/kris/Epilogue/Epilogue/EpilogueWidgets/`

Follow these steps to add the Widget Extension target and configure everything properly.

## Step 1: Create Widget Extension Target in Xcode

1. Open `Epilogue.xcodeproj` in Xcode
2. Click on the project in the navigator
3. Click the `+` button at the bottom of the targets list
4. Select `Widget Extension` from the template picker
5. Name it `EpilogueWidgets`
6. **IMPORTANT**: Uncheck "Include Configuration Intent" (we're using static widgets)
7. Click Finish
8. When prompted to activate the scheme, click Activate

## Step 2: Add Existing Widget Files to Target

1. In Xcode, select all files in the `EpilogueWidgets` folder:
   - `EpilogueWidgets.swift` (main bundle)
   - `Shared/WidgetDataProvider.swift`
   - `Shared/WidgetComponents.swift`
   - `Widgets/CurrentReadingWidget.swift`
   - `Widgets/ReadingSessionWidget.swift`
   - `Widgets/AmbientModeWidget.swift`
   - `Widgets/QuoteOfTheDayWidget.swift`
   - `Widgets/ReadingStreakWidget.swift`

2. Right-click → Add Files to "Epilogue"
3. Make sure `EpilogueWidgets` target is checked

## Step 3: Share Model Files with Widget Target

The widgets need access to your SwiftData models. In Xcode:

1. Select these model files:
   - `Epilogue/Models/BookModel.swift`
   - `Epilogue/Models/Note.swift` (for CapturedQuote)
   - `Epilogue/Models/ReadingSession.swift`
   - `Epilogue/Models/AmbientSession.swift`

2. In the File Inspector (right sidebar), check BOTH:
   - ✅ ReadEpilogue (main app)
   - ✅ EpilogueWidgets (widget extension)

## Step 4: Set Up App Groups

App Groups allow the main app and widget extension to share data.

### A. Create App Group

1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Click Identifiers → App Groups
3. Click `+` to create new App Group
4. Name: `group.com.epilogue.app`
5. Save

### B. Enable in Main App Target

1. Select `ReadEpilogue` target
2. Go to Signing & Capabilities tab
3. Click `+ Capability` → App Groups
4. Check `group.com.epilogue.app`

### C. Enable in Widget Target

1. Select `EpilogueWidgets` target
2. Go to Signing & Capabilities tab
3. Click `+ Capability` → App Groups
4. Check `group.com.epilogue.app`

## Step 5: Update SwiftData Container in Main App

In your main app's data initialization (likely `EpilogueApp.swift` or similar):

```swift
static var sharedContainer: ModelContainer = {
    let schema = Schema([BookModel.self, CapturedQuote.self, ReadingSession.self, AmbientSession.self])

    // Use App Group container URL
    let appGroupID = "group.com.epilogue.app"
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
        fatalError("Shared container not found")
    }

    let storeURL = containerURL.appendingPathComponent("EpilogueData.sqlite")
    let config = ModelConfiguration(
        "EpilogueData",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .automatic
    )

    return try! ModelContainer(for: schema, configurations: [config])
}()
```

## Step 6: Export Ambient Orb Image

1. In the main app, go to Settings → Developer Options
2. Find "Ambient Orb Exporter" (newly added tool)
3. Tap "Capture Orb Image"
4. Tap "Save to Files"
5. Save the image

### Add to Widget Assets:

1. In Xcode, select `EpilogueWidgets` → Assets
2. Click `+` → Import
3. Select the saved orb image
4. Name it `ambient-orb`
5. In Attributes Inspector, set Render As: Original

## Step 7: Add URL Scheme for Ambient Mode Widget

In `Info.plist` (main app target):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>epilogue</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.epilogue.app</string>
    </dict>
</array>
```

Then handle the URL in your app:

```swift
.onOpenURL { url in
    if url.scheme == "epilogue", url.host == "ambient" {
        // Navigate to Ambient Mode
        navigationCoordinator.navigateToAmbientMode()
    }
}
```

## Step 8: Build and Test

1. Select `EpilogueWidgets` scheme
2. Choose a simulator or device
3. Build and Run (Cmd+R)
4. Xcode will launch in widget editing mode
5. Test each widget type:
   - Current Reading (Small/Medium/Large)
   - Reading Session (Medium/Large)
   - Ask Epilogue (Small/Medium)
   - Quote of the Day (Large)
   - Reading Streak (Small)

## Step 9: Add to Main App

Once widgets work in the extension:

1. Select `ReadEpilogue` scheme
2. Build and Run the main app
3. Long-press home screen → Add Widget
4. Search for "Epilogue"
5. Add widgets to test with real data

## Troubleshooting

### "No timeline provider" error
- Make sure all widget files are added to `EpilogueWidgets` target

### "Model not found" error
- Verify model files are checked for both targets in File Inspector

### Widgets show "No data"
- Check App Groups are enabled in BOTH targets
- Verify SwiftData container URL uses App Group path
- Make sure you have books/quotes/sessions in the main app

### Ambient orb shows fallback gradient
- Export orb image using the AmbientOrbExporter tool
- Add to Assets catalog as "ambient-orb"

### Deep links don't work
- Add URL scheme to Info.plist
- Implement .onOpenURL handler in main app

## Widget Preview in Xcode

To preview widgets during development:

```swift
#Preview(as: .systemSmall) {
    CurrentReadingWidget()
} timeline: {
    CurrentReadingEntry(date: .now, book: WidgetBookData(
        title: "The Odyssey",
        author: "Homer",
        coverURL: "https://...",
        currentPage: 142,
        totalPages: 400
    ))
}
```

## Next Steps

1. ✅ Create Widget Extension target
2. ✅ Add files to target
3. ✅ Share model files
4. ✅ Set up App Groups
5. ✅ Export ambient orb
6. ✅ Test all widgets
7. ✅ Submit to TestFlight

Widgets will update automatically based on their timeline policies:
- **Current Reading**: Every 15 minutes
- **Reading Session**: Every 1 minute (if active), 15 minutes (inactive)
- **Ambient Mode**: Daily
- **Quote of the Day**: Daily at midnight
- **Reading Streak**: Daily at midnight
