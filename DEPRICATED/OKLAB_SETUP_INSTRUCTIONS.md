# OKLAB Color Extraction Setup Instructions

## Step 1: Add OKLABColorExtractor.swift to Xcode Project

1. Open your Epilogue project in Xcode
2. Right-click on the `Epilogue` folder in the project navigator
3. Select "Add Files to 'Epilogue'..."
4. Navigate to: `/Users/kris/Epilogue/Epilogue/Core/Colors/`
5. Select `OKLABColorExtractor.swift`
6. Make sure "Copy items if needed" is UNCHECKED (file is already in place)
7. Make sure "Epilogue" target is checked
8. Click "Add"

## Step 2: Enable the Test Code in BookDetailView

Once the file is added to Xcode, uncomment the following in `BookDetailView.swift`:

1. **State variables** (around line 103):
```swift
@State private var oklabPalette: ColorPalette?
@State private var showColorDebug = true
```

2. **Task modifier** (around line 222):
```swift
await loadAndExtractColors()
```

3. **Debug view** (around line 193-197):
```swift
if showColorDebug, let palette = oklabPalette {
    colorDebugView(palette: palette)
        .padding(.horizontal, 24)
        .padding(.top, 16)
}
```

4. **Color extraction methods** (lines 716-836):
Remove the `/*` at line 716 and `*/` at line 836

## Step 3: Build and Run

After uncommenting, build and run the project. When you navigate to any book detail view, you should see:
- Colored circles showing the extracted palette
- Console output with detailed extraction information

## Troubleshooting

If you still get "Cannot find type 'ColorPalette' in scope" errors:
1. Clean build folder (Shift+Cmd+K)
2. Close and reopen Xcode
3. Make sure the file shows up in the project navigator under Core/Colors/

## What You'll See

The debug view displays:
- 4 color circles (Primary, Secondary, Accent, Background)
- Luminance value (0-1)
- Whether the image is monochromatic
- Extraction quality percentage
- Recommended text color (white or black)

Console output includes all color values and extraction metrics.