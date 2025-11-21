# Epilogue Accessibility Code Examples
**SwiftUI Accessibility Patterns & Best Practices**

Comprehensive, copy-paste ready code examples for implementing WCAG 2.1 AA accessibility in Epilogue.

---

## Table of Contents

1. [VoiceOver Support](#1-voiceover-support)
2. [Dynamic Type](#2-dynamic-type)
3. [Visual Accessibility](#3-visual-accessibility)
4. [Custom Controls](#4-custom-controls)
5. [Forms & Input](#5-forms--input)
6. [Navigation](#6-navigation)
7. [Modals & Sheets](#7-modals--sheets)
8. [Lists & Tables](#8-lists--tables)
9. [Reader-Specific Patterns](#9-reader-specific-patterns)
10. [Testing Utilities](#10-testing-utilities)

---

## 1. VoiceOver Support

### Basic Button Labeling

```swift
// ❌ BAD: No accessibility information
Button {
    addBookToLibrary()
} label: {
    Image(systemName: "plus")
}

// ✅ GOOD: Complete accessibility information
Button {
    addBookToLibrary()
} label: {
    Image(systemName: "plus")
}
.accessibilityLabel("Add book")
.accessibilityHint("Adds the current book to your library")
.accessibilityIdentifier("add-book-button") // For UI testing
```

### Combining Multiple Elements

```swift
// Book card with multiple pieces of information
struct LibraryBookCard: View {
    let book: Book

    var body: some View {
        HStack(spacing: 16) {
            // Cover image
            AsyncImage(url: book.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Book info
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.headline)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: book.progress)
                    .tint(.accentColor)

                Text("\(Int(book.progress * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // ✅ Combine all elements into single announcement
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open book")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        let progressPercent = Int(book.progress * 100)
        return """
        \(book.title) by \(book.author). \
        \(progressPercent)% complete. \
        \(book.status.displayName).
        """
    }
}
```

### Hiding Decorative Elements

```swift
struct BookDetailHeader: View {
    let book: Book

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient (decorative)
            LinearGradient(
                colors: book.themeColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .accessibilityHidden(true) // Decorative, not informative

            // Decorative pattern
            Image("pattern-overlay")
                .resizable()
                .opacity(0.1)
                .accessibilityHidden(true) // Decorative

            // Actual content
            VStack {
                Text(book.title)
                    .font(.largeTitle)
                    .bold()
                // This has semantic meaning - accessible

                Text(book.author)
                    .font(.title2)
                // This has semantic meaning - accessible
            }
            .padding()
        }
        .frame(height: 300)
    }
}
```

### Custom Actions

```swift
struct BookCardWithActions: View {
    let book: Book
    @State private var isFavorite = false
    @State private var showingShareSheet = false

    var body: some View {
        BookCardView(book: book)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(book.title) by \(book.author)")
            // ✅ Provide custom actions accessible via VoiceOver rotor
            .accessibilityAction(named: "Open book") {
                openBook()
            }
            .accessibilityAction(named: isFavorite ? "Remove from favorites" : "Add to favorites") {
                toggleFavorite()
            }
            .accessibilityAction(named: "Share") {
                showingShareSheet = true
            }
            .accessibilityAction(named: "View details") {
                showDetails()
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(book: book)
            }
    }

    func openBook() {
        // Implementation
    }

    func toggleFavorite() {
        isFavorite.toggle()
    }

    func showDetails() {
        // Implementation
    }
}
```

### Reading Order Control

```swift
struct BookDetailView: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (read first)
                headerSection
                    .accessibilitySortPriority(3)

                // Actions (read second)
                actionButtons
                    .accessibilitySortPriority(2)

                // Description (read third)
                descriptionSection
                    .accessibilitySortPriority(1)
            }
        }
    }

    var headerSection: some View {
        VStack {
            Text(book.title)
                .font(.title)
            Text(book.author)
                .font(.title2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title) by \(book.author)")
        .accessibilityAddTraits(.isHeader)
    }

    var actionButtons: some View {
        HStack {
            Button("Start Reading") { }
                .accessibilityLabel("Start reading \(book.title)")

            Button("Add to Library") { }
                .accessibilityLabel("Add \(book.title) to library")
        }
    }

    var descriptionSection: some View {
        Text(book.description)
            .accessibilityLabel("Description: \(book.description)")
    }
}
```

---

## 2. Dynamic Type

### Scaled Font Metrics

```swift
// ✅ BEST: ScaledMetric for custom sizing
struct ScaledTextView: View {
    // Scales relative to .body (default)
    @ScaledMetric var defaultSize: CGFloat = 17

    // Scales relative to .title
    @ScaledMetric(relativeTo: .title) var titleSize: CGFloat = 28

    // Scales relative to .caption
    @ScaledMetric(relativeTo: .caption) var captionSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapter Title")
                .font(.system(size: titleSize, weight: .bold))

            Text("Chapter content goes here...")
                .font(.system(size: defaultSize))

            Text("Page 42")
                .font(.system(size: captionSize))
                .foregroundColor(.secondary)
        }
    }
}

// ✅ GOOD: System text styles (automatically scale)
struct SystemTextStyles: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Large Title").font(.largeTitle)
            Text("Title").font(.title)
            Text("Title 2").font(.title2)
            Text("Title 3").font(.title3)
            Text("Headline").font(.headline)
            Text("Subheadline").font(.subheadline)
            Text("Body").font(.body)
            Text("Callout").font(.callout)
            Text("Footnote").font(.footnote)
            Text("Caption").font(.caption)
            Text("Caption 2").font(.caption2)
        }
    }
}
```

### Adaptive Layouts

```swift
struct AdaptiveButtonStack: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        // Change layout based on text size
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Vertical stack for large text
                VStack(spacing: 12) {
                    buttonContent
                }
            } else {
                // Horizontal stack for normal text
                HStack(spacing: 12) {
                    buttonContent
                }
            }
        }
    }

    @ViewBuilder
    var buttonContent: some View {
        Button("Save") { }
            .frame(minHeight: 44)

        Button("Cancel") { }
            .frame(minHeight: 44)

        Button("Delete") { }
            .frame(minHeight: 44)
    }
}
```

### Multi-Line Text Support

```swift
struct AdaptiveBookCard: View {
    let book: Book
    @ScaledMetric(relativeTo: .headline) var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) var authorSize: CGFloat = 15
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ✅ Allow unlimited wrapping
            Text(book.title)
                .font(.system(size: titleSize, weight: .semibold))
                .lineLimit(nil) // No line limit
                .fixedSize(horizontal: false, vertical: true) // Grow vertically

            Text(book.author)
                .font(.system(size: authorSize))
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
```

### Responsive Grid Layout

```swift
struct AdaptiveBookGrid: View {
    let books: [Book]
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: gridColumns,
                spacing: 16
            ) {
                ForEach(books) { book in
                    BookGridItem(book: book)
                }
            }
            .padding()
        }
    }

    var gridColumns: [GridItem] {
        // Adjust column count based on text size
        let columnCount: Int
        if dynamicTypeSize >= .accessibility3 {
            columnCount = 1 // Single column for very large text
        } else if dynamicTypeSize >= .accessibility1 {
            columnCount = 2 // Two columns for large text
        } else if dynamicTypeSize >= .large {
            columnCount = 3 // Three columns for medium text
        } else {
            columnCount = 4 // Four columns for small text
        }

        return Array(
            repeating: GridItem(.flexible(), spacing: 16),
            count: columnCount
        )
    }
}
```

### Minimum Tap Targets at All Sizes

```swift
struct AccessibleButton: View {
    let title: String
    let action: () -> Void

    @ScaledMetric var fontSize: CGFloat = 17
    @ScaledMetric var minTapSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                // ✅ Ensure minimum tap target size
                .frame(minWidth: minTapSize, minHeight: minTapSize)
        }
        .buttonStyle(.borderedProminent)
    }
}

// Icon buttons with minimum size
struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            if dynamicTypeSize.isAccessibilitySize {
                // Show label for large text
                Label(label, systemImage: icon)
            } else {
                // Icon only for normal text
                Image(systemName: icon)
            }
        }
        .frame(minWidth: 44, minHeight: 44) // Always minimum size
        .accessibilityLabel(label) // Always provide label
    }
}
```

---

## 3. Visual Accessibility

### Color Contrast Utilities

```swift
// Utility for checking color contrast
struct ContrastChecker {
    static func contrastRatio(
        foreground: Color,
        background: Color
    ) -> Double {
        let fgLum = relativeLuminance(foreground)
        let bgLum = relativeLuminance(background)

        let lighter = max(fgLum, bgLum)
        let darker = min(fgLum, bgLum)

        return (lighter + 0.05) / (darker + 0.05)
    }

    static func meetsWCAG_AA(
        foreground: Color,
        background: Color,
        fontSize: CGFloat,
        isBold: Bool = false
    ) -> Bool {
        let ratio = contrastRatio(
            foreground: foreground,
            background: background
        )

        // Large text (≥18pt or ≥14pt bold) needs 3:1
        // Normal text needs 4.5:1
        let isLargeText = fontSize >= 18 || (fontSize >= 14 && isBold)
        let minimumRatio: Double = isLargeText ? 3.0 : 4.5

        return ratio >= minimumRatio
    }

    private static func relativeLuminance(_ color: Color) -> Double {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        guard let components = uiColor.cgColor.components else {
            return 0
        }

        let transform: (CGFloat) -> Double = { channel in
            let value = Double(channel)
            return value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        let r = transform(components[0])
        let g = transform(components[1])
        let b = transform(components[2])

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
        #else
        return 0.5
        #endif
    }
}

// Extension for easy checking
extension Color {
    func meetsContrast(
        on background: Color,
        fontSize: CGFloat = 17,
        isBold: Bool = false
    ) -> Bool {
        ContrastChecker.meetsWCAG_AA(
            foreground: self,
            background: background,
            fontSize: fontSize,
            isBold: isBold
        )
    }

    // Get high contrast variant if needed
    func ensureContrast(
        on background: Color,
        fontSize: CGFloat = 17
    ) -> Color {
        if meetsContrast(on: background, fontSize: fontSize) {
            return self
        } else {
            // Return higher contrast alternative
            #if canImport(UIKit)
            return Color(.label) // System adaptive color
            #else
            return .primary
            #endif
        }
    }
}
```

### Accessible Status Indicators

```swift
// ✅ Color + Icon + Text (not color alone!)
struct ReadingStatusBadge: View {
    let status: ReadingStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)

            Text(status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.2))
        .foregroundColor(status.color)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }
}

enum ReadingStatus {
    case notStarted, reading, completed

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .reading: return "Reading"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .reading: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .reading: return .blue
        case .completed: return .green
        }
    }
}

// Progress indicator with text value
struct AccessibleProgressView: View {
    let progress: Double // 0.0 to 1.0
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)

                Spacer()

                // ✅ Always show percentage as text
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Visual progress bar
            ProgressView(value: progress)
                .tint(.accentColor)
                .accessibilityHidden(true) // Redundant with text
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Int(progress * 100)) percent complete")
    }
}
```

### Reduce Motion Support

```swift
struct AnimatedTransitionView: View {
    @State private var isPresented = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack {
            Button("Show Details") {
                // ✅ Disable animation if reduce motion enabled
                withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                    isPresented = true
                }
            }

            if isPresented {
                DetailView()
                    // ✅ Simple fade instead of complex animation
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                              )
                    )
            }
        }
    }
}

// Loading indicator with reduce motion
struct AccessibleLoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            if reduceMotion {
                // Simple static indicator
                Image(systemName: "hourglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            } else {
                // Animated progress view
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }

            Text("Loading...")
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading content")
    }
}

// Parallax effect with reduce motion alternative
struct ParallaxHeaderView: View {
    let book: Book
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let offset = geometry.frame(in: .global).minY

            AsyncImage(url: book.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    // ✅ Disable parallax if reduce motion enabled
                    .offset(y: reduceMotion ? 0 : offset * 0.5)
            } placeholder: {
                Color.gray
            }
        }
        .frame(height: 300)
    }
}
```

### High Contrast Mode Support

```swift
struct HighContrastButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorSchemeContrast) var contrast

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
        }
        .buttonStyle(.bordered)
        // ✅ Enhanced borders in high contrast mode
        .controlSize(contrast == .increased ? .large : .regular)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    Color.accentColor,
                    lineWidth: contrast == .increased ? 3 : 1
                )
        )
    }
}

// Card with high contrast support
struct HighContrastCard: View {
    let content: String
    @Environment(\.colorSchemeContrast) var contrast

    var body: some View {
        Text(content)
            .padding()
            // ✅ Solid background in high contrast
            .background(
                contrast == .increased
                    ? Color(.secondarySystemBackground)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.primary.opacity(
                            contrast == .increased ? 0.5 : 0.2
                        ),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            )
    }
}

// Icon rendering for high contrast
struct AdaptiveIcon: View {
    let symbolName: String
    @Environment(\.colorSchemeContrast) var contrast

    var body: some View {
        Image(systemName: symbolName)
            // ✅ Use filled icons in high contrast
            .symbolVariant(contrast == .increased ? .fill : .none)
            .font(.title2)
    }
}
```

---

## 4. Custom Controls

### Adjustable Control (Stepper Alternative)

```swift
struct AccessibleStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    let formatValue: (Int) -> String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(formatValue(value))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(formatValue(value))
        // ✅ Support VoiceOver increment/decrement
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if value < range.upperBound {
                    value += 1
                }
            case .decrement:
                if value > range.lowerBound {
                    value -= 1
                }
            @unknown default:
                break
            }
        }
        .accessibilityHint("Swipe up to increase, swipe down to decrease")
    }
}

// Usage:
struct FontSizeSetting: View {
    @AppStorage("fontSize") var fontSize = 17

    var body: some View {
        AccessibleStepper(
            value: $fontSize,
            range: 12...32,
            label: "Font Size",
            formatValue: { "\($0) points" }
        )
    }
}
```

### Custom Slider with Accessibility

```swift
struct AccessibleSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text(formattedValue)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            Slider(
                value: $value,
                in: range,
                step: step
            )
            .accessibilityLabel(label)
            .accessibilityValue(formattedValue)
            // ✅ Add increment/decrement support
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(range.upperBound, value + step)
                case .decrement:
                    value = max(range.lowerBound, value - step)
                @unknown default:
                    break
                }
            }
        }
    }

    var formattedValue: String {
        String(format: "%.1f", value)
    }
}

// Reading speed slider
struct ReadingSpeedControl: View {
    @State private var speed: Double = 1.0

    var body: some View {
        AccessibleSlider(
            value: $speed,
            range: 0.5...2.0,
            step: 0.1,
            label: "Reading Speed"
        )
    }
}
```

### Toggle with Rich Labels

```swift
struct AccessibleToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String?
    let icon: String?

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(description ?? "")
    }
}

// Usage:
struct SettingsView: View {
    @AppStorage("reduceMotion") var reduceMotion = false
    @AppStorage("haptics") var haptics = true

    var body: some View {
        Form {
            Section("Accessibility") {
                AccessibleToggle(
                    isOn: $reduceMotion,
                    title: "Reduce Motion",
                    description: "Minimizes animations throughout the app",
                    icon: "figure.walk.motion"
                )

                AccessibleToggle(
                    isOn: $haptics,
                    title: "Haptic Feedback",
                    description: "Provides tactile feedback for interactions",
                    icon: "hand.tap"
                )
            }
        }
    }
}
```

### Picker with Full Accessibility

```swift
struct AccessiblePicker<T: Hashable & CustomStringConvertible>: View {
    @Binding var selection: T
    let options: [T]
    let label: String

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option.description)
                    .tag(option)
            }
        } label: {
            Text(label)
        }
        .accessibilityLabel(label)
        .accessibilityValue(selection.description)
        .accessibilityHint("Double tap to choose \(label)")
    }
}

// Theme picker
enum Theme: String, CaseIterable, CustomStringConvertible {
    case light = "Light"
    case dark = "Dark"
    case auto = "Automatic"

    var description: String { rawValue }
}

struct ThemeSettingView: View {
    @AppStorage("theme") var theme: Theme = .auto

    var body: some View {
        AccessiblePicker(
            selection: $theme,
            options: Theme.allCases,
            label: "App Theme"
        )
        .pickerStyle(.segmented)
    }
}
```

---

## 5. Forms & Input

### Accessible Text Field

```swift
struct AccessibleTextField: View {
    @Binding var text: String
    let title: String
    let placeholder: String
    let validation: ((String) -> ValidationResult)?

    @State private var validationResult: ValidationResult = .valid
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Text field
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    if let validation = validation {
                        validationResult = validation(newValue)
                    }
                }
                // ✅ Accessibility
                .accessibilityLabel(title)
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .accessibilityHint(accessibilityHint)

            // Validation message
            if validationResult != .valid {
                HStack(spacing: 6) {
                    Image(systemName: validationResult.icon)
                        .foregroundColor(validationResult.color)

                    Text(validationResult.message)
                        .font(.caption)
                        .foregroundColor(validationResult.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(validationResult.accessibilityMessage)
            }
        }
    }

    var accessibilityHint: String {
        if validationResult != .valid {
            return "Invalid. \(validationResult.message)"
        }
        return isFocused ? "Enter \(title)" : ""
    }
}

enum ValidationResult: Equatable {
    case valid
    case warning(String)
    case error(String)

    var message: String {
        switch self {
        case .valid: return ""
        case .warning(let msg): return msg
        case .error(let msg): return msg
        }
    }

    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .valid: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var accessibilityMessage: String {
        switch self {
        case .valid: return "Valid"
        case .warning(let msg): return "Warning: \(msg)"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// Usage with validation
struct BookSearchForm: View {
    @State private var searchQuery = ""

    var body: some View {
        AccessibleTextField(
            text: $searchQuery,
            title: "Search Books",
            placeholder: "Enter book title or author",
            validation: { query in
                if query.isEmpty {
                    return .error("Search query cannot be empty")
                } else if query.count < 3 {
                    return .warning("Enter at least 3 characters for better results")
                } else {
                    return .valid
                }
            }
        )
    }
}
```

### Search Field with Clear Button

```swift
struct AccessibleSearchField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .accessibilityLabel("Search")
                .accessibilityValue(text.isEmpty ? "Empty" : text)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 44, height: 44) // Minimum tap target
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// Usage
struct SearchView: View {
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack {
            AccessibleSearchField(
                text: $searchText,
                placeholder: "Search books",
                isFocused: $isSearchFocused
            )
            .padding()

            // Search results...
        }
    }
}
```

---

## 6. Navigation

### Accessible Tab Bar

```swift
struct AccessibleTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)
                .accessibilityLabel("Library")
                .accessibilityHint("Browse your book collection")
                .accessibilityIdentifier("library-tab")

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
                .accessibilityLabel("Search")
                .accessibilityHint("Find new books to read")
                .accessibilityIdentifier("search-tab")

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
                .accessibilityLabel("Profile")
                .accessibilityHint("View reading stats and settings")
                .accessibilityIdentifier("profile-tab")
        }
    }
}
```

### Navigation Links

```swift
struct AccessibleNavigationLink<Destination: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 30)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true) // Implicit in link
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "Navigate to \(title)")
        .accessibilityAddTraits(.isLink)
    }
}

// Usage
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    AccessibleNavigationLink(
                        title: "Theme",
                        subtitle: "Light, Dark, or Automatic",
                        icon: "paintbrush",
                        destination: ThemeSettingsView()
                    )

                    AccessibleNavigationLink(
                        title: "Font",
                        subtitle: "Customize reading text",
                        icon: "textformat",
                        destination: FontSettingsView()
                    )
                }

                Section("Accessibility") {
                    AccessibleNavigationLink(
                        title: "VoiceOver Settings",
                        subtitle: nil,
                        icon: "speaker.wave.2",
                        destination: VoiceOverSettingsView()
                    )
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

### Breadcrumb Navigation

```swift
struct BreadcrumbNavigation: View {
    let path: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, item in
                    Button {
                        navigateTo(index: index)
                    } label: {
                        Text(item)
                            .font(.subheadline)
                    }
                    .accessibilityLabel("Navigate to \(item)")
                    .accessibilityHint("Level \(index + 1) of \(path.count)")

                    if index < path.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation path")
    }

    func navigateTo(index: Int) {
        // Implementation
    }
}
```

---

## 7. Modals & Sheets

### Accessible Modal Sheet

```swift
struct AccessibleSheet<Content: View>: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .accessibilityLabel("Close \(title)")
                        .accessibilityHint("Returns to previous screen")
                    }
                }
        }
        // ✅ Mark as modal for VoiceOver
        .accessibilityAddTraits(.isModal)
        // ✅ Support escape gesture
        .accessibilityAction(.escape) {
            dismiss()
        }
    }
}

// Usage
struct BookDetailView: View {
    @State private var showingNotes = false

    var body: some View {
        Button("View Notes") {
            showingNotes = true
        }
        .sheet(isPresented: $showingNotes) {
            AccessibleSheet(title: "Notes") {
                NotesListView()
            }
        }
    }
}
```

### Confirmation Dialog

```swift
struct AccessibleConfirmationDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let destructiveAction: () -> Void

    var body: some View {
        VStack {
            // Trigger content
        }
        .confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                destructiveAction()
            }
            .accessibilityLabel("Delete book")
            .accessibilityHint("This action cannot be undone")

            Button("Cancel", role: .cancel) {}
                .accessibilityLabel("Cancel deletion")
        } message: {
            Text(message)
                .accessibilityLabel(message)
        }
    }
}

// Usage
struct BookOptionsView: View {
    @State private var showingDeleteConfirmation = false
    let book: Book

    var body: some View {
        Button("Delete Book", role: .destructive) {
            showingDeleteConfirmation = true
        }
        .accessibleConfirmationDialog(
            isPresented: $showingDeleteConfirmation,
            title: "Delete Book?",
            message: "This will remove \(book.title) from your library. This action cannot be undone.",
            destructiveAction: {
                deleteBook()
            }
        )
    }

    func deleteBook() {
        // Implementation
    }
}
```

### Alert with Accessibility

```swift
extension View {
    func accessibleAlert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        primaryButton: Alert.Button,
        secondaryButton: Alert.Button
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            primaryButton
            secondaryButton
        } message: {
            if let message = message {
                Text(message)
                    .accessibilityLabel(message)
            }
        }
    }
}

// Usage
struct ErrorHandlingView: View {
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            // Content
        }
        .accessibleAlert(
            "Error",
            isPresented: $showingError,
            message: errorMessage,
            primaryButton: .default(Text("Retry")) {
                retryAction()
            },
            secondaryButton: .cancel()
        )
    }

    func retryAction() {
        // Implementation
    }
}
```

---

## 8. Lists & Tables

### Accessible List

```swift
struct AccessibleBookList: View {
    let books: [Book]

    var body: some View {
        List {
            ForEach(books) { book in
                BookListRow(book: book)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: book))
                    .accessibilityHint("Double tap to open book")
                    .accessibilityIdentifier("book-\(book.id)")
            }
            .onDelete(perform: deleteBooks)
        }
        .accessibilityLabel("Books list")
        .accessibilityHint("\(books.count) books")
    }

    func accessibilityLabel(for book: Book) -> String {
        let progress = Int(book.progress * 100)
        return "\(book.title) by \(book.author), \(progress)% complete"
    }

    func deleteBooks(at offsets: IndexSet) {
        // Implementation
    }
}

struct BookListRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: book.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true) // Title provides context

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                AccessibleProgressView(
                    progress: book.progress,
                    label: "Progress"
                )
            }
        }
        .padding(.vertical, 4)
    }
}
```

### Swipe Actions with Accessibility

```swift
struct BookListWithActions: View {
    let books: [Book]

    var body: some View {
        List {
            ForEach(books) { book in
                BookListRow(book: book)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteBook(book)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete \(book.title)")
                        .accessibilityHint("Removes book from library")

                        Button {
                            archiveBook(book)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                        .accessibilityLabel("Archive \(book.title)")
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleFavorite(book)
                        } label: {
                            Label(
                                book.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: book.isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        .tint(.pink)
                        .accessibilityLabel(
                            book.isFavorite
                                ? "Remove \(book.title) from favorites"
                                : "Add \(book.title) to favorites"
                        )
                    }
                    // ✅ Provide custom actions for VoiceOver users
                    .accessibilityAction(named: "Delete") {
                        deleteBook(book)
                    }
                    .accessibilityAction(named: "Archive") {
                        archiveBook(book)
                    }
                    .accessibilityAction(
                        named: book.isFavorite ? "Unfavorite" : "Favorite"
                    ) {
                        toggleFavorite(book)
                    }
            }
        }
    }

    func deleteBook(_ book: Book) {}
    func archiveBook(_ book: Book) {}
    func toggleFavorite(_ book: Book) {}
}
```

### Sectioned List with Headers

```swift
struct SectionedBookList: View {
    let booksByStatus: [ReadingStatus: [Book]]

    var body: some View {
        List {
            ForEach(ReadingStatus.allCases, id: \.self) { status in
                if let books = booksByStatus[status], !books.isEmpty {
                    Section {
                        ForEach(books) { book in
                            BookListRow(book: book)
                        }
                    } header: {
                        Text(status.displayName)
                            // ✅ Mark as header for VoiceOver
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("\(status.displayName) section, \(books.count) books")
                    }
                }
            }
        }
    }
}
```

---

## 9. Reader-Specific Patterns

### EPUB Image with Alt Text

```swift
struct EPUBImageView: View {
    let imageURL: URL
    let altText: String?
    let longDescription: String?

    @State private var showingLongDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .accessibilityLabel("Loading image")
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Label("Failed to load image", systemImage: "photo")
                        .foregroundColor(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            // ✅ Use alt text for VoiceOver
            .accessibilityLabel(effectiveAltText)
            .accessibilityAddTraits(.isImage)
            .accessibilityHint(
                longDescription != nil
                    ? "Double tap for detailed description"
                    : ""
            )
            .onTapGesture {
                if longDescription != nil {
                    showingLongDescription = true
                }
            }

            // Visual caption
            if let altText = altText {
                Text(altText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true) // Already in image label
            }
        }
        .sheet(isPresented: $showingLongDescription) {
            if let longDescription = longDescription {
                NavigationStack {
                    ScrollView {
                        Text(longDescription)
                            .font(.body)
                            .padding()
                    }
                    .navigationTitle("Image Description")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingLongDescription = false
                            }
                        }
                    }
                }
            }
        }
    }

    var effectiveAltText: String {
        altText ?? "Image without description"
    }
}
```

### Reading Controls

```swift
struct ReadingControls: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric var buttonSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 16) {
            // Previous page
            Button {
                onPreviousPage()
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .labelStyle(
                        dynamicTypeSize.isAccessibilitySize
                            ? .titleAndIcon
                            : .iconOnly
                    )
            }
            .frame(minWidth: buttonSize, minHeight: buttonSize)
            .accessibilityLabel("Previous page")
            .accessibilityHint("Go to page \(max(1, currentPage - 1))")
            .disabled(currentPage <= 1)

            Spacer()

            // Page indicator
            Text("Page \(currentPage) of \(totalPages)")
                .font(.caption)
                .accessibilityLabel("Current page: \(currentPage) of \(totalPages)")

            Spacer()

            // Next page
            Button {
                onNextPage()
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(
                        dynamicTypeSize.isAccessibilitySize
                            ? .titleAndIcon
                            : .iconOnly
                    )
            }
            .frame(minWidth: buttonSize, minHeight: buttonSize)
            .accessibilityLabel("Next page")
            .accessibilityHint("Go to page \(min(totalPages, currentPage + 1))")
            .disabled(currentPage >= totalPages)
        }
        .padding()
        .background(.regularMaterial)
        // ✅ Provide VoiceOver rotor actions
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next page") {
            if currentPage < totalPages {
                onNextPage()
            }
        }
        .accessibilityAction(named: "Previous page") {
            if currentPage > 1 {
                onPreviousPage()
            }
        }
    }
}
```

### Table of Contents

```swift
struct TableOfContents: View {
    let chapters: [Chapter]
    let currentChapter: Int
    let onSelectChapter: (Int) -> Void

    var body: some View {
        List {
            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                Button {
                    onSelectChapter(index)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.headline)

                            if let subtitle = chapter.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if index == currentChapter {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel(
                    "\(chapter.title)\(chapter.subtitle.map { ", \($0)" } ?? "")"
                )
                .accessibilityHint(
                    index == currentChapter
                        ? "Currently reading this chapter"
                        : "Jump to this chapter"
                )
                .accessibilityAddTraits(index == currentChapter ? .isSelected : [])
            }
        }
        .navigationTitle("Table of Contents")
        .accessibilityLabel("Table of contents")
        .accessibilityHint("\(chapters.count) chapters")
    }
}

struct Chapter: Identifiable {
    let id: Int
    let title: String
    let subtitle: String?
}
```

### Bookmark Management

```swift
struct BookmarksList: View {
    let bookmarks: [Bookmark]
    let onSelectBookmark: (Bookmark) -> Void
    let onDeleteBookmark: (Bookmark) -> Void

    var body: some View {
        List {
            if bookmarks.isEmpty {
                Text("No bookmarks yet")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No bookmarks. Add bookmarks while reading to find them here.")
            } else {
                ForEach(bookmarks) { bookmark in
                    Button {
                        onSelectBookmark(bookmark)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(
                                    "Page \(bookmark.page)",
                                    systemImage: "bookmark.fill"
                                )
                                .font(.caption)
                                .foregroundColor(.accentColor)

                                Spacer()

                                Text(bookmark.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            if let note = bookmark.note {
                                Text(note)
                                    .font(.body)
                                    .lineLimit(2)
                            }

                            Text(bookmark.excerpt)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityLabel(
                        "Bookmark on page \(bookmark.page), \(bookmark.date.formatted(.relative(presentation: .named)))"
                    )
                    .accessibilityHint(
                        bookmark.note.map { "Note: \($0). " } ?? "" +
                        "Excerpt: \(bookmark.excerpt)"
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDeleteBookmark(bookmark)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete bookmark")
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .accessibilityLabel("Bookmarks list")
        .accessibilityHint("\(bookmarks.count) bookmarks")
    }
}

struct Bookmark: Identifiable {
    let id: UUID
    let page: Int
    let date: Date
    let note: String?
    let excerpt: String
}
```

---

## 10. Testing Utilities

### Accessibility Preview Helper

```swift
#if DEBUG
struct AccessibilityPreviewHelper: ViewModifier {
    @State private var dynamicTypeSize: DynamicTypeSize = .medium
    @State private var colorScheme: ColorScheme = .light
    @State private var colorSchemeContrast: ColorSchemeContrast = .standard
    @State private var reduceMotion = false

    func body(content: Content) -> some View {
        content
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.colorScheme, colorScheme)
            .environment(\.colorSchemeContrast, colorSchemeContrast)
            .environment(\.accessibilityReduceMotion, reduceMotion)
            .safeAreaInset(edge: .bottom) {
                controlPanel
            }
    }

    var controlPanel: some View {
        VStack(spacing: 8) {
            Picker("Text Size", selection: $dynamicTypeSize) {
                Text("XS").tag(DynamicTypeSize.xSmall)
                Text("S").tag(DynamicTypeSize.small)
                Text("M").tag(DynamicTypeSize.medium)
                Text("L").tag(DynamicTypeSize.large)
                Text("XL").tag(DynamicTypeSize.xLarge)
                Text("XXL").tag(DynamicTypeSize.xxLarge)
                Text("XXXL").tag(DynamicTypeSize.xxxLarge)
                Text("AX1").tag(DynamicTypeSize.accessibility1)
                Text("AX5").tag(DynamicTypeSize.accessibility5)
            }
            .pickerStyle(.segmented)

            HStack {
                Toggle("Dark Mode", isOn: Binding(
                    get: { colorScheme == .dark },
                    set: { colorScheme = $0 ? .dark : .light }
                ))

                Toggle("High Contrast", isOn: Binding(
                    get: { colorSchemeContrast == .increased },
                    set: { colorSchemeContrast = $0 ? .increased : .standard }
                ))

                Toggle("Reduce Motion", isOn: $reduceMotion)
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial)
    }
}

extension View {
    func accessibilityPreview() -> some View {
        self.modifier(AccessibilityPreviewHelper())
    }
}

// Usage in previews:
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
            .accessibilityPreview()
    }
}
#endif
```

### VoiceOver Testing Helper

```swift
#if DEBUG
/// Prints accessibility information about a view hierarchy
func printAccessibilityTree<V: View>(_ view: V) {
    print("=== Accessibility Tree ===")
    // This is a conceptual helper - actual implementation would require
    // introspection of the view hierarchy
    print("Note: Use Xcode Accessibility Inspector for actual tree inspection")
}

/// Validates that all interactive elements have accessibility labels
func validateAccessibilityLabels() {
    // Run in UI tests
    let app = XCUIApplication()
    let buttons = app.buttons.allElementsBoundByIndex

    for (index, button) in buttons.enumerated() {
        if button.label.isEmpty {
            print("⚠️ Warning: Button at index \(index) has no accessibility label")
            print("   Identifier: \(button.identifier)")
        }
    }
}
#endif
```

### Contrast Testing View

```swift
#if DEBUG
struct ContrastTestView: View {
    let foreground: Color
    let background: Color
    let fontSize: CGFloat
    let isBold: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Sample text
            Text("Sample Text")
                .font(.system(size: fontSize, weight: isBold ? .bold : .regular))
                .foregroundColor(foreground)
                .padding()
                .background(background)

            // Contrast information
            VStack(alignment: .leading, spacing: 8) {
                Text("Contrast Ratio: \(String(format: "%.2f", contrastRatio)):1")
                    .font(.headline)

                Text("Required: \(requiredRatio):1")

                Text("Status: \(meetsRequirement ? "✅ Pass" : "❌ Fail")")
                    .foregroundColor(meetsRequirement ? .green : .red)

                Text("WCAG Level: \(wcagLevel)")
            }
            .font(.caption)
            .padding()
        }
    }

    var contrastRatio: Double {
        ContrastChecker.contrastRatio(
            foreground: foreground,
            background: background
        )
    }

    var isLargeText: Bool {
        fontSize >= 18 || (fontSize >= 14 && isBold)
    }

    var requiredRatio: Double {
        isLargeText ? 3.0 : 4.5
    }

    var meetsRequirement: Bool {
        contrastRatio >= requiredRatio
    }

    var wcagLevel: String {
        if contrastRatio >= 7.0 {
            return "AAA"
        } else if contrastRatio >= requiredRatio {
            return "AA"
        } else {
            return "Fail"
        }
    }
}

struct ContrastTestView_Previews: PreviewProvider {
    static var previews: some View {
        ContrastTestView(
            foreground: .primary,
            background: .systemBackground,
            fontSize: 17,
            isBold: false
        )
    }
}
#endif
```

---

## Quick Reference Checklist

### For Every New View:

- [ ] All interactive elements have `.accessibilityLabel()`
- [ ] Decorative elements have `.accessibilityHidden(true)`
- [ ] Reading order is logical (test with VoiceOver)
- [ ] Dynamic Type tested at XXXL
- [ ] Minimum tap targets are 44x44pt
- [ ] Color contrast meets 4.5:1 (or 3:1 for large text)
- [ ] No information conveyed by color alone
- [ ] Animations respect Reduce Motion
- [ ] High Contrast mode works well

### For Every Button:

```swift
Button("Action") { }
    .accessibilityLabel("Descriptive label")
    .accessibilityHint("What happens")
    .accessibilityIdentifier("unique-id")
    .frame(minWidth: 44, minHeight: 44)
```

### For Every Form Field:

```swift
TextField("Placeholder", text: $text)
    .accessibilityLabel("Field name")
    .accessibilityValue(text.isEmpty ? "Empty" : text)
    .accessibilityHint("Purpose of field")
```

### For Every Modal:

```swift
.sheet(isPresented: $isPresented) {
    NavigationStack {
        Content()
            .toolbar {
                ToolbarItem {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close modal")
                }
            }
    }
    .accessibilityAddTraits(.isModal)
    .accessibilityAction(.escape) { dismiss() }
}
```

---

## Additional Resources

- [Apple Accessibility Documentation](https://developer.apple.com/documentation/accessibility)
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [SwiftUI Accessibility Modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- Epilogue-specific:
  - `ACCESSIBILITY_AUDIT_CHECKLIST.md`
  - `ACCESSIBILITY_IMPLEMENTATION_PLAN.md`

---

**Remember**: Accessibility is not a feature—it's a fundamental requirement. Test early, test often, and test with real assistive technologies!
