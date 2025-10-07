# Accessibility in Epilogue

This document outlines the accessibility features implemented in Epilogue to ensure the app is usable by everyone.

## Overview

Epilogue has comprehensive accessibility support including VoiceOver labels, accessibility hints, and proper semantic markup throughout the app.

## VoiceOver Support

### Navigation
- **Tab Bar**: All three tabs (Library, Notes, Sessions) have descriptive labels and hints
- **Navigation**: Back buttons, settings buttons, and menu items are properly labeled
- **Interactive Elements**: All buttons, toggles, and controls have meaningful accessibility labels

### Key Views

#### Library View
- Book cards announce book title, author, and reading status
- Filter and view mode buttons clearly describe their purpose
- Add book button provides clear action description

#### Notes View
- Search bar with clear label and hint
- Filter menu describes available options
- Note and quote cards read content with proper context
- Selection mode provides feedback on selected state
- Empty state clearly communicates when there are no notes

#### Book Detail View
- Reading session controls (start/end) clearly labeled
- Reading status menu announces current status
- Section tabs properly labeled and indicate selected state
- Progress indicators and controls accessible

#### Settings View
- All toggles announce their current state
- Navigation links describe their destination
- Important actions (export, delete) include warning hints
- Gradient theme selector clearly describes current theme

## Accessibility Features

### Labels
Every interactive element has a descriptive `accessibilityLabel` that clearly states what the element is.

### Hints
Complex or important interactions include `accessibilityHint` that explains what will happen when the user interacts with the element.

### Identifiers
UI elements have `accessibilityIdentifier` for automated testing and consistent identification.

### Reduce Motion
The app respects the "Reduce Motion" accessibility setting:
- Animations are reduced or disabled when the setting is enabled
- Critical UI transitions remain functional without animations

### Dynamic Type
- SwiftUI provides automatic Dynamic Type support for standard text elements
- The app uses carefully designed fixed font sizes for visual consistency
- This is a common design choice in visually-focused apps

## Localization Support

All accessibility strings are localized in 8 languages:
- English
- Spanish
- French
- German
- Japanese
- Chinese (Simplified)
- Portuguese
- Arabic (with RTL support)

## Testing Recommendations

### VoiceOver Testing
1. Enable VoiceOver: Settings → Accessibility → VoiceOver
2. Navigate through each main view (Library, Notes, Sessions)
3. Test common workflows:
   - Adding a book
   - Creating a note
   - Starting a reading session
   - Changing reading status

### Reduce Motion Testing
1. Enable Reduce Motion: Settings → Accessibility → Motion → Reduce Motion
2. Verify animations are appropriately reduced
3. Ensure all UI transitions remain functional

### Voice Control Testing
1. Enable Voice Control: Settings → Accessibility → Voice Control
2. Test navigation using voice commands
3. Verify all interactive elements are reachable

## Implementation Details

### Code Organization
- Accessibility labels are defined inline with the UI components
- Common accessibility strings are centralized in `LocalizationHelper.swift`
- All accessibility strings are in `Localizable.strings` for each language

### Key Files Modified
- `CleanNotesView.swift`: Notes list with search and filters
- `BookDetailView.swift`: Book details and session controls
- `LibraryView.swift`: Book library grid/list
- `SettingsView.swift`: App settings and toggles
- `NavigationContainer.swift`: Tab bar navigation
- `LocalizationHelper.swift`: Centralized accessibility string definitions

## Future Enhancements

### Potential Improvements
- Add more granular Dynamic Type support for critical text
- Expand accessibility labels for complex ambient mode interactions
- Add accessibility support for visual effects and animations
- Implement custom rotor actions for advanced VoiceOver users

### Accessibility Best Practices Followed
✅ Meaningful labels on all interactive elements
✅ Helpful hints for complex interactions
✅ Proper semantic structure with headings
✅ Respect for accessibility settings (reduce motion)
✅ Full localization support
✅ Consistent accessibility patterns throughout the app

## Resources

- [Apple's Accessibility Guidelines](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [SwiftUI Accessibility Documentation](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [VoiceOver Testing Guide](https://developer.apple.com/library/archive/technotes/TestingAccessibilityOfiOSApps/TestAccessibilityonYourDevicewithVoiceOver/TestAccessibilityonYourDevicewithVoiceOver.html)

## Contact

For accessibility feedback or issues, please open an issue on the project repository.
