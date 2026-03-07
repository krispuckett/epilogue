# Adding UIImageColors to Epilogue

To get Apple Music quality color extraction, add UIImageColors via Swift Package Manager:

## Steps in Xcode:

1. Open your Epilogue project in Xcode
2. Select the project file in the navigator
3. Select the Epilogue target
4. Go to the "Package Dependencies" tab
5. Click the "+" button
6. Enter the repository URL: `https://github.com/jathu/UIImageColors`
7. Click "Add Package"
8. Select "UIImageColors" product
9. Click "Add Package"

## Once Added:

Update `AppleMusicClaudeGradient.swift` to import and use UIImageColors:

```swift
import UIImageColors

// In extractColors() function, replace:
let extractor = OKLABColorExtractor()
if let extractedPalette = try? await extractor.extractPalette(from: image, imageSource: "BookCover") {
    // ...
}

// With:
let colors = image.getColors(quality: .high)

await MainActor.run {
    withAnimation(.easeInOut(duration: 0.8)) {
        colorPalette = ColorPalette(
            background: enhanceColor(Color(colors?.background ?? .black)),
            primary: enhanceColor(Color(colors?.primary ?? .gray)),
            secondary: enhanceColor(Color(colors?.secondary ?? .gray)),
            detail: enhanceColor(Color(colors?.detail ?? .white))
        )
    }
}
```

## Benefits:

- UIImageColors is battle-tested in production apps
- Handles edge cases like white backgrounds, monochromatic images
- Provides consistent, vibrant color extraction
- Much simpler than custom OKLAB implementation
- Same algorithm used by iTunes/Apple Music