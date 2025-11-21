# Epilogue Accessibility Implementation Plan
**WCAG 2.1 AA Compliance Roadmap**

**Timeline**: 6 weeks to full compliance
**Estimated Effort**: 120-150 hours total
**Team**: 1-2 developers + 1 QA tester

---

## Overview

### Current State
- **Compliance Level**: ~60-70% AA compliant
- **Strengths**: Tab navigation, settings, library views
- **Critical Gaps**: Chat accessibility, Dynamic Type, formal testing
- **Accessibility Annotations**: 116+ existing (good foundation!)

### Target State
- **Compliance Level**: 100% WCAG 2.1 AA
- **All interactive elements labeled**
- **Full Dynamic Type support**
- **Comprehensive VoiceOver experience**
- **Automated testing in CI/CD**

### Success Criteria
- ✅ Pass WCAG 2.1 AA audit
- ✅ 0 critical Xcode Accessibility Inspector issues
- ✅ 90%+ SUS score from assistive tech users
- ✅ All interactive elements have minimum 44x44pt tap targets
- ✅ All text meets 4.5:1 contrast ratio (3:1 for large text)

---

## Week 1: Foundation & Critical Testing

**Goal**: Establish baseline, identify all gaps, fix critical VoiceOver issues

**Effort**: 20-25 hours

### Day 1-2: Comprehensive Audit (8 hours)

#### Tasks:
1. **Run Xcode Accessibility Inspector** (2 hours)
   - Contrast audit on all views
   - Hit target audit (44x44pt minimum)
   - Label audit (missing labels)
   - Trait audit (incorrect traits)
   - Document all findings in GitHub Issues

2. **Manual VoiceOver Testing** (4 hours)
   - Test complete app navigation with VoiceOver only
   - Document every unlabeled/mislabeled element
   - Test reading order in all major views
   - Record problematic flows

3. **Dynamic Type Testing** (2 hours)
   - Test at all sizes (XS → XXXL)
   - Document layout breaks
   - Document truncation issues
   - Screenshot failures

**Deliverable**: Complete issue list with priority tags

**Code Example - Audit Script**:
```swift
// Create accessibility audit view for debugging
struct AccessibilityAuditView: View {
    let view: AnyView
    @State private var issues: [AccessibilityIssue] = []

    var body: some View {
        VStack {
            view
            List(issues) { issue in
                VStack(alignment: .leading) {
                    Text(issue.title)
                        .font(.headline)
                    Text(issue.description)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            runAudit()
        }
    }

    func runAudit() {
        // Recursive view inspection
        // Check for missing labels, traits, etc.
        // Add issues to list
    }
}

struct AccessibilityIssue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let severity: Severity
    let location: String

    enum Severity {
        case critical, high, medium, low
    }
}
```

---

### Day 3-5: Fix Critical VoiceOver Issues (12 hours)

#### Priority 1: Chat Message Accessibility (6 hours)

**Issue**: 25+ chat files lack proper VoiceOver support

**Current State**:
```swift
// ❌ Current - Missing context
struct ChatMessageView: View {
    let message: Message

    var body: some View {
        HStack {
            Text(message.content)
            Text(message.timestamp, style: .relative)
        }
    }
}
```

**Fixed State**:
```swift
// ✅ Fixed - Full context
struct ChatMessageView: View {
    let message: Message
    let isFromUser: Bool

    var body: some View {
        HStack {
            Text(message.content)
            Text(message.timestamp, style: .relative)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isFromUser ? .isStaticText : .isStaticText)
        .accessibilityHint(isFromUser ? "Your message" : "Assistant response")
    }

    private var accessibilityDescription: String {
        let sender = isFromUser ? "You" : "Assistant"
        let time = message.timestamp.formatted(.relative(presentation: .named))
        return "\(sender), \(time): \(message.content)"
    }
}
```

**Files to Update** (Priority order):
1. `ChatMessageView.swift` - Core message display
2. `ChatBubbleView.swift` - Bubble container
3. `ChatInputView.swift` - Input field labels
4. `ChatThreadView.swift` - Thread navigation
5. `AmbientChatView.swift` - Ambient mode chat

**Estimated Impact**: 1000+ chat messages per user session

---

#### Priority 2: Modal Dismissal Hints (3 hours)

**Issue**: 71+ modal presentations lack dismissal hints

**Pattern to Apply**:
```swift
// ✅ Accessible modal presentation
struct BookDetailSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            BookDetailContent()
                .navigationTitle("Book Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .accessibilityLabel("Close book details")
                        .accessibilityHint("Returns to library")
                    }
                }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            dismiss()
        }
    }
}
```

**Implementation Strategy**:
1. Search for `.sheet(`, `.fullScreenCover(`, `.popover(`
2. Add explicit close buttons with labels
3. Add `.accessibilityAction(.escape)` for VoiceOver dismiss
4. Test each modal with VoiceOver

---

#### Priority 3: Minimum Tap Targets (3 hours)

**Issue**: Some interactive elements may be <44x44pt

**Audit Script**:
```bash
# Find small buttons/taps
grep -r "\.frame.*width.*height" Epilogue/*.swift | grep -v "44\|48\|50"
grep -r "\.font(.caption)\|\.font(.footnote)" Epilogue/*.swift # Small text buttons
```

**Fix Pattern**:
```swift
// ❌ Too small
Button {
    toggleFavorite()
} label: {
    Image(systemName: "heart")
        .font(.caption)
}

// ✅ Minimum size
Button {
    toggleFavorite()
} label: {
    Image(systemName: "heart")
        .font(.caption)
        .frame(minWidth: 44, minHeight: 44)
}
.accessibilityLabel("Add to favorites")

// ✅ Alternative - use larger hit area
Button {
    toggleFavorite()
} label: {
    Image(systemName: "heart")
        .font(.caption)
}
.accessibilityLabel("Add to favorites")
.buttonStyle(.plain)
.contentShape(Rectangle())
.frame(minWidth: 44, minHeight: 44)
```

---

**Week 1 Deliverables**:
- [ ] Complete accessibility audit report
- [ ] All critical VoiceOver issues fixed
- [ ] Chat messages fully accessible
- [ ] All modals have dismissal hints
- [ ] All interactive elements meet 44x44pt minimum
- [ ] Baseline metrics documented

---

## Week 2: Dynamic Type & Layout Adaptation

**Goal**: Full Dynamic Type support across all views

**Effort**: 25-30 hours

### Day 1-2: Library & Navigation (8 hours)

#### Task 1: Library Book Cards (4 hours)

**Current State**: Partial Dynamic Type support

**Implementation**:
```swift
// Enhanced LibraryBookCard with full Dynamic Type
struct LibraryBookCard: View {
    let book: Book
    @ScaledMetric(relativeTo: .title2) var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) var bodySize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) var captionSize: CGFloat = 12
    @ScaledMetric var imageSize: CGFloat = 120
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        adaptiveLayout
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    var adaptiveLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Vertical stack for large text
            VStack(alignment: .leading, spacing: 12) {
                bookCover
                bookInfo
            }
        } else {
            // Horizontal layout for normal sizes
            HStack(spacing: 16) {
                bookCover
                bookInfo
            }
        }
    }

    var bookCover: some View {
        AsyncImage(url: book.coverURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.gray
        }
        .frame(width: imageSize, height: imageSize * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true) // Title conveys cover info
    }

    var bookInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title)
                .font(.system(size: titleSize, weight: .bold))
                .lineLimit(nil) // Allow wrapping
                .fixedSize(horizontal: false, vertical: true)

            Text(book.author)
                .font(.system(size: bodySize))
                .foregroundColor(.secondary)
                .lineLimit(nil)

            ProgressView(value: book.progress)
                .tint(.accentColor)
                .accessibilityHidden(true)

            Text("\(Int(book.progress * 100))% complete")
                .font(.system(size: captionSize))
                .foregroundColor(.secondary)
        }
    }

    private var accessibilityDescription: String {
        "\(book.title) by \(book.author). \(Int(book.progress * 100))% complete"
    }
}
```

**Testing Checklist**:
- [ ] Test at XS, S, M, L, XL sizes
- [ ] Test at accessibility sizes (AX1-AX5)
- [ ] Verify no truncation
- [ ] Verify layout adapts (horizontal → vertical)
- [ ] Test in both light and dark mode

---

#### Task 2: Tab Navigation (2 hours)

**Implementation**:
```swift
struct MainTabView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .accessibilityLabel("Library")
                .accessibilityHint("Browse your book collection")
                .accessibilityIdentifier("library-tab")

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Search")
                .accessibilityHint("Find new books")
                .accessibilityIdentifier("search-tab")

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .accessibilityLabel("Profile")
                .accessibilityHint("View your reading stats and settings")
                .accessibilityIdentifier("profile-tab")
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .body : .caption)
    }
}

// Custom tab bar for extreme sizes
struct AccessibleTabBar: View {
    @Binding var selection: Tab
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    enum Tab {
        case library, search, profile
    }

    var body: some View {
        if dynamicTypeSize >= .accessibility3 {
            // Vertical tab bar for very large text
            VStack(spacing: 0) {
                ForEach([Tab.library, .search, .profile], id: \.self) { tab in
                    tabButton(for: tab)
                    Divider()
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            // Standard horizontal tab bar
            HStack(spacing: 0) {
                ForEach([Tab.library, .search, .profile], id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
        }
    }

    func tabButton(for tab: Tab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                Text(tab.title)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 8)
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}

extension AccessibleTabBar.Tab {
    var title: String {
        switch self {
        case .library: return "Library"
        case .search: return "Search"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .library: return "books.vertical"
        case .search: return "magnifyingglass"
        case .profile: return "person.circle"
        }
    }
}
```

---

#### Task 3: Navigation Headers (2 hours)

**Implementation**:
```swift
struct AdaptiveNavigationHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) var titleSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) var subtitleSize: CGFloat = 17
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .bold))
                        .lineLimit(nil)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: subtitleSize))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                }

                Spacer()

                if let action = action, !dynamicTypeSize.isAccessibilitySize {
                    actionButton
                }
            }

            if dynamicTypeSize.isAccessibilitySize, action != nil {
                actionButton
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }

    @ViewBuilder
    var actionButton: some View {
        if let action = action {
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.title2)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Add item")
        }
    }
}
```

---

### Day 3-4: Chat & Reading Views (10 hours)

#### Task 1: Chat Messages with Dynamic Type (5 hours)

**Implementation**:
```swift
struct AccessibleChatMessage: View {
    let message: ChatMessage
    let isFromUser: Bool

    @ScaledMetric(relativeTo: .body) var fontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) var metadataSize: CGFloat = 12
    @ScaledMetric var bubblePadding: CGFloat = 12
    @ScaledMetric var maxBubbleWidth: CGFloat = 280
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        HStack {
            if isFromUser { Spacer(minLength: 40) }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: fontSize))
                    .padding(bubblePadding)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled) // Allow text selection
                    .frame(
                        maxWidth: dynamicTypeSize.isAccessibilitySize
                            ? .infinity
                            : maxBubbleWidth,
                        alignment: isFromUser ? .trailing : .leading
                    )

                Text(message.timestamp, style: .relative)
                    .font(.system(size: metadataSize))
                    .foregroundColor(.secondary)
            }

            if !isFromUser { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isFromUser ? "Your message" : "Assistant message")
    }

    var bubbleBackground: some ShapeStyle {
        isFromUser
            ? AnyShapeStyle(Color.accentColor)
            : AnyShapeStyle(.regularMaterial)
    }

    var accessibilityLabel: String {
        let sender = isFromUser ? "You" : "Assistant"
        let time = message.timestamp.formatted(.relative(presentation: .named))
        return "\(sender), \(time): \(message.content)"
    }
}
```

---

#### Task 2: Reading View with Dynamic Type (5 hours)

**Implementation**:
```swift
struct AdaptiveReadingView: View {
    @StateObject var viewModel: ReadingViewModel
    @ScaledMetric(relativeTo: .body) var readerFontSize: CGFloat = 17
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        ZStack {
            // Book content
            ScrollView {
                Text(viewModel.currentPageContent)
                    .font(.system(size: effectiveFontSize))
                    .lineSpacing(lineSpacing)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Book content")
            .accessibilityAddTraits(.isStaticText)
            .accessibilityAction(named: "Next page") {
                viewModel.nextPage()
            }
            .accessibilityAction(named: "Previous page") {
                viewModel.previousPage()
            }

            // Reading controls
            VStack {
                Spacer()
                readingControls
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                toolbarButtons
            }
        }
    }

    var effectiveFontSize: CGFloat {
        // Respect both system Dynamic Type and user's reader font size preference
        let baseFontSize = viewModel.readerFontSize ?? readerFontSize
        return baseFontSize
    }

    var lineSpacing: CGFloat {
        // Increase line spacing for larger text
        dynamicTypeSize >= .accessibility1 ? 8 : 4
    }

    @ViewBuilder
    var readingControls: some View {
        if !viewModel.isFullScreen {
            HStack(spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 16) {
                Button {
                    viewModel.previousPage()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .labelStyle(dynamicTypeSize.isAccessibilitySize ? .titleAndIcon : .iconOnly)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Previous page")

                Spacer()

                Text("Page \(viewModel.currentPage) of \(viewModel.totalPages)")
                    .font(.caption)
                    .accessibilityLabel("Page \(viewModel.currentPage) of \(viewModel.totalPages)")

                Spacer()

                Button {
                    viewModel.nextPage()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(dynamicTypeSize.isAccessibilitySize ? .titleAndIcon : .iconOnly)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Next page")
            }
            .padding()
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    var toolbarButtons: some View {
        Button {
            viewModel.toggleBookmark()
        } label: {
            Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
        }
        .accessibilityLabel(viewModel.isBookmarked ? "Remove bookmark" : "Add bookmark")

        Button {
            viewModel.showSettings()
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel("Reading settings")
        .accessibilityHint("Adjust font size, theme, and more")
    }
}
```

---

### Day 5: Settings & Forms (7-10 hours)

#### Task 1: Settings View with Dynamic Type (4 hours)

**Implementation**:
```swift
struct AccessibleSettingsView: View {
    @ScaledMetric(relativeTo: .headline) var sectionHeaderSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) var bodySize: CGFloat = 17
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        Form {
            Section {
                appearanceSettings
            } header: {
                Text("Appearance")
                    .font(.system(size: sectionHeaderSize, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                readingSettings
            } header: {
                Text("Reading")
                    .font(.system(size: sectionHeaderSize, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                accessibilitySettings
            } header: {
                Text("Accessibility")
                    .font(.system(size: sectionHeaderSize, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    var appearanceSettings: some View {
        ThemePicker()
            .accessibilityElement(children: .contain)

        Toggle("Reduce Motion", isOn: $settings.reduceMotion)
            .font(.system(size: bodySize))
            .accessibilityLabel("Reduce motion")
            .accessibilityValue(settings.reduceMotion ? "On" : "Off")
            .accessibilityHint("Reduces animations throughout the app")

        Toggle("Increase Contrast", isOn: $settings.increaseContrast)
            .font(.system(size: bodySize))
            .accessibilityLabel("Increase contrast")
            .accessibilityValue(settings.increaseContrast ? "On" : "Off")
    }

    @ViewBuilder
    var readingSettings: some View {
        Stepper(value: $settings.fontSize, in: 12...32, step: 2) {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(settings.fontSize))pt")
                    .foregroundColor(.secondary)
            }
            .font(.system(size: bodySize))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading font size")
        .accessibilityValue("\(Int(settings.fontSize)) points")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                settings.fontSize = min(32, settings.fontSize + 2)
            case .decrement:
                settings.fontSize = max(12, settings.fontSize - 2)
            @unknown default:
                break
            }
        }

        Picker("Line Spacing", selection: $settings.lineSpacing) {
            Text("Compact").tag(LineSpacing.compact)
            Text("Normal").tag(LineSpacing.normal)
            Text("Relaxed").tag(LineSpacing.relaxed)
        }
        .font(.system(size: bodySize))
        .accessibilityLabel("Line spacing")
        .accessibilityValue(settings.lineSpacing.displayName)
    }

    @ViewBuilder
    var accessibilitySettings: some View {
        NavigationLink {
            VoiceOverTutorialView()
        } label: {
            Label("VoiceOver Tutorial", systemImage: "speaker.wave.2")
                .font(.system(size: bodySize))
        }
        .accessibilityLabel("VoiceOver tutorial")
        .accessibilityHint("Learn how to use Epilogue with VoiceOver")

        Toggle("Enable Haptic Feedback", isOn: $settings.haptics)
            .font(.system(size: bodySize))
            .accessibilityLabel("Haptic feedback")
            .accessibilityValue(settings.haptics ? "On" : "Off")
    }
}

// Accessible theme picker
struct ThemePicker: View {
    @AppStorage("theme") var theme: Theme = .auto
    @ScaledMetric(relativeTo: .body) var fontSize: CGFloat = 17

    var body: some View {
        Picker("Theme", selection: $theme) {
            ForEach(Theme.allCases) { theme in
                HStack {
                    Image(systemName: theme.icon)
                    Text(theme.displayName)
                }
                .tag(theme)
            }
        }
        .font(.system(size: fontSize))
        .accessibilityLabel("App theme")
        .accessibilityValue(theme.displayName)
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case light, dark, auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Automatic"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .auto: return "circle.lefthalf.filled"
        }
    }
}

enum LineSpacing: String, CaseIterable {
    case compact, normal, relaxed

    var displayName: String {
        rawValue.capitalized
    }

    var value: CGFloat {
        switch self {
        case .compact: return 2
        case .normal: return 4
        case .relaxed: return 8
        }
    }
}
```

---

**Week 2 Deliverables**:
- [ ] All views support Dynamic Type at all sizes
- [ ] Layouts adapt for accessibility sizes (vertical stacking)
- [ ] No text truncation at XXXL
- [ ] All minimum tap targets maintained at all sizes
- [ ] Settings fully accessible with descriptive labels

---

## Week 3: Visual Accessibility & Contrast

**Goal**: Meet all WCAG contrast requirements, non-color indicators

**Effort**: 20-25 hours

### Day 1-2: Color Contrast Audit & Fixes (10 hours)

#### Task 1: Automated Contrast Testing (3 hours)

**Implementation**:
```swift
// Contrast checker utility
struct ContrastChecker {
    /// WCAG 2.1 AA Requirements:
    /// - Normal text (<18pt or <14pt bold): 4.5:1 minimum
    /// - Large text (≥18pt or ≥14pt bold): 3:1 minimum
    /// - UI components: 3:1 minimum

    static func contrastRatio(between color1: Color, and color2: Color) -> Double {
        let rgb1 = color1.rgbComponents
        let rgb2 = color2.rgbComponents

        let l1 = relativeLuminance(rgb1)
        let l2 = relativeLuminance(rgb2)

        let lighter = max(l1, l2)
        let darker = min(l1, l2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    static func meetsWCAG_AA(
        foreground: Color,
        background: Color,
        fontSize: CGFloat,
        isBold: Bool = false
    ) -> Bool {
        let ratio = contrastRatio(between: foreground, and: background)
        let isLargeText = fontSize >= 18 || (fontSize >= 14 && isBold)
        let requiredRatio: Double = isLargeText ? 3.0 : 4.5

        return ratio >= requiredRatio
    }

    private static func relativeLuminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        let transform: (Double) -> Double = { channel in
            channel <= 0.03928
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        let r = transform(rgb.r)
        let g = transform(rgb.g)
        let b = transform(rgb.b)

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

extension Color {
    var rgbComponents: (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else {
            return (0, 0, 0)
        }
        return (
            r: Double(components[0]),
            g: Double(components[1]),
            b: Double(components[2])
        )
        #else
        return (0, 0, 0)
        #endif
    }

    /// Checks if this color meets WCAG AA contrast when used as foreground
    func meetsContrastRequirement(
        on background: Color,
        fontSize: CGFloat,
        isBold: Bool = false
    ) -> Bool {
        ContrastChecker.meetsWCAG_AA(
            foreground: self,
            background: background,
            fontSize: fontSize,
            isBold: isBold
        )
    }
}

// Unit tests
class ContrastTests: XCTestCase {
    func testBlackOnWhite() {
        let ratio = ContrastChecker.contrastRatio(
            between: .black,
            and: .white
        )
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1) // Perfect contrast
    }

    func testBodyTextContrast() {
        let meets = ContrastChecker.meetsWCAG_AA(
            foreground: .primary,
            background: .systemBackground,
            fontSize: 17
        )
        XCTAssertTrue(meets, "Body text must meet 4.5:1 ratio")
    }

    func testLargeTitleContrast() {
        let meets = ContrastChecker.meetsWCAG_AA(
            foreground: .primary,
            background: .systemBackground,
            fontSize: 34,
            isBold: true
        )
        XCTAssertTrue(meets, "Large title must meet 3:1 ratio")
    }
}
```

**Audit Script**:
```swift
// Run in Debug menu or test suite
struct ContrastAuditReport: View {
    @State private var failures: [ContrastFailure] = []

    var body: some View {
        List(failures) { failure in
            VStack(alignment: .leading, spacing: 8) {
                Text(failure.location)
                    .font(.headline)

                HStack {
                    Rectangle()
                        .fill(failure.foreground)
                        .frame(width: 30, height: 30)
                    Text("on")
                    Rectangle()
                        .fill(failure.background)
                        .frame(width: 30, height: 30)
                }

                Text("Ratio: \(String(format: "%.2f", failure.ratio)):1")
                    .foregroundColor(.red)
                Text("Required: \(String(format: "%.1f", failure.required)):1")
            }
        }
        .navigationTitle("Contrast Failures")
        .onAppear {
            runAudit()
        }
    }

    func runAudit() {
        // Audit all views
        failures = auditAllViews()
    }

    func auditAllViews() -> [ContrastFailure] {
        var failures: [ContrastFailure] = []

        // Check library view
        failures += auditLibraryView()

        // Check chat views
        failures += auditChatViews()

        // Check settings
        failures += auditSettingsView()

        // Check reading view
        failures += auditReadingView()

        return failures
    }

    func auditLibraryView() -> [ContrastFailure] {
        // Implementation specific to your views
        []
    }

    // ... other audit methods
}

struct ContrastFailure: Identifiable {
    let id = UUID()
    let location: String
    let foreground: Color
    let background: Color
    let fontSize: CGFloat
    let ratio: Double
    let required: Double
}
```

---

#### Task 2: Fix Contrast Issues (7 hours)

**Common Issues & Fixes**:

**Issue 1: Secondary Text on Gradients**
```swift
// ❌ BEFORE: Gray text on gradient (may fail contrast)
Text("Secondary info")
    .foregroundColor(.secondary)
    .background(
        LinearGradient(...)
    )

// ✅ AFTER: Ensure background or add shadow
Text("Secondary info")
    .foregroundColor(.primary) // Use primary for better contrast
    .padding(8)
    .background(.regularMaterial) // Material provides guaranteed contrast
    .clipShape(RoundedRectangle(cornerRadius: 8))

// ✅ ALTERNATIVE: Shadow for text on gradients
Text("Secondary info")
    .foregroundColor(.white)
    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
```

**Issue 2: Status Indicators**
```swift
// ❌ BEFORE: Colored text may not meet contrast
Text(book.status)
    .foregroundColor(book.statusColor)

// ✅ AFTER: Check and adjust
Text(book.status)
    .foregroundColor(accessibleStatusColor)

var accessibleStatusColor: Color {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.colorSchemeContrast) var contrast

    let baseColor = book.statusColor

    // Ensure sufficient contrast
    if contrast == .increased {
        return colorScheme == .dark ? baseColor.lighter() : baseColor.darker()
    }

    // Check if current color meets requirements
    let background = colorScheme == .dark ? Color.black : Color.white
    if baseColor.meetsContrastRequirement(on: background, fontSize: 17) {
        return baseColor
    }

    // Fallback to semantic color
    return .primary
}
```

**Issue 3: Link Colors**
```swift
// Accessible link styling
struct AccessibleLink: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(linkColor)
                .underline(true) // Always underline links (non-color indicator!)
        }
        .accessibilityAddTraits(.isLink)
        .accessibilityLabel(title)
        .accessibilityHint("Opens link")
    }

    var linkColor: Color {
        // Use system accent color (guaranteed accessible)
        // or custom color that meets 4.5:1 ratio
        .accentColor
    }
}
```

---

### Day 3: Non-Color Indicators (5 hours)

#### Task 1: Reading Status Indicators (2 hours)

**Current**: May use color only
**Goal**: Color + icon + text

**Implementation**:
```swift
struct AccessibleReadingStatus: View {
    let status: ReadingStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .accessibilityHidden(true)

            Text(status.displayName)
                .font(.caption)
                .foregroundColor(status.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading status: \(status.displayName)")
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
        case .reading: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: return .secondary
        case .reading: return .accentColor
        case .completed: return .green
        }
    }
}
```

---

#### Task 2: Form Validation (2 hours)

**Implementation**:
```swift
struct AccessibleTextField: View {
    let title: String
    @Binding var text: String
    let validation: (String) -> ValidationResult

    @State private var validationResult: ValidationResult = .valid
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    validationResult = validation(newValue)
                }
                .accessibilityLabel(title)
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .accessibilityHint(validationHint)

            // Validation indicator
            if validationResult != .valid {
                HStack(spacing: 6) {
                    Image(systemName: validationResult.icon)
                        .foregroundColor(validationResult.color)

                    Text(validationResult.message)
                        .font(.caption)
                        .foregroundColor(validationResult.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(validationResult.accessibilityLabel)
            }
        }
    }

    var validationHint: String {
        switch validationResult {
        case .valid:
            return isFocused ? "Enter \(title)" : ""
        case .error:
            return "Invalid. \(validationResult.message)"
        case .warning:
            return "Warning. \(validationResult.message)"
        }
    }
}

enum ValidationResult: Equatable {
    case valid
    case error(String)
    case warning(String)

    var message: String {
        switch self {
        case .valid: return ""
        case .error(let msg): return msg
        case .warning(let msg): return msg
        }
    }

    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .valid: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .valid: return "Valid"
        case .error(let msg): return "Error: \(msg)"
        case .warning(let msg): return "Warning: \(msg)"
        }
    }
}
```

---

### Day 4-5: Reduce Motion & High Contrast (5-10 hours)

#### Task 1: Reduce Motion Support (3-5 hours)

**Audit Animation Files**:
```bash
# Find all animation usage
grep -r "withAnimation\|\.animation\|\.transition" Epilogue/*.swift > animations_audit.txt

# Priority files (25+ animation files identified)
# Focus on:
# - Page transitions
# - Loading indicators
# - Modal presentations
# - Gesture feedback
```

**Implementation Pattern**:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Page transition
.transition(
    reduceMotion
        ? .opacity
        : .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
          )
)

// Animated state change
withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
    isExpanded.toggle()
}

// Loading indicator
if reduceMotion {
    // Simple fade
    ProgressView()
        .progressViewStyle(.circular)
} else {
    // Animated loading
    LoadingAnimationView()
}

// Scroll effects
ScrollView {
    content
        .visualEffect { content, geometryProxy in
            content
                .offset(
                    y: reduceMotion
                        ? 0
                        : parallaxOffset(geometryProxy)
                )
        }
}
```

---

#### Task 2: High Contrast Mode (2-5 hours)

**Implementation**:
```swift
@Environment(\.colorSchemeContrast) var contrast

// Border enhancement
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .strokeBorder(
            Color.primary.opacity(contrast == .increased ? 0.3 : 0.1),
            lineWidth: contrast == .increased ? 2 : 1
        )
)

// Button prominence
Button("Action") { }
    .buttonStyle(.bordered)
    .controlSize(contrast == .increased ? .large : .regular)
    .controlProminence(contrast == .increased ? .increased : .standard)

// Icon variants
Image(systemName: contrast == .increased ? "heart.fill" : "heart")
    .symbolRenderingMode(contrast == .increased ? .monochrome : .hierarchical)

// Material backgrounds
.background(
    contrast == .increased
        ? Color(.secondarySystemBackground)
        : Color.clear
)
.backgroundStyle(contrast == .increased ? .regular : .thin)
```

---

**Week 3 Deliverables**:
- [ ] All text meets 4.5:1 contrast (3:1 for large text)
- [ ] All UI components meet 3:1 contrast
- [ ] No information conveyed by color alone
- [ ] Reduce Motion respected in all animations
- [ ] High Contrast mode enhances visibility

---

## Week 4: Reader-Specific Features

**Goal**: EPUB accessibility, book content handling

**Effort**: 15-20 hours

### Day 1-2: EPUB Accessibility Metadata (6-8 hours)

**Task**: Parse and display EPUB accessibility metadata

**Implementation**:
```swift
import ZIPFoundation // or your EPUB parser

struct EPUBAccessibilityMetadata {
    let accessModes: [AccessMode]
    let accessibilityFeatures: [AccessibilityFeature]
    let accessibilityHazards: [AccessibilityHazard]
    let accessibilitySummary: String?

    enum AccessMode: String {
        case textual, visual, auditory, tactile

        var displayName: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .textual: return "text.alignleft"
            case .visual: return "eye"
            case .auditory: return "speaker.wave.2"
            case .tactile: return "hand.tap"
            }
        }
    }

    enum AccessibilityFeature: String, CaseIterable {
        case alternativeText = "alternativeText"
        case longDescription = "longDescription"
        case tableOfContents = "tableOfContents"
        case structuralNavigation = "structuralNavigation"
        case MathML = "MathML"
        case describedMath = "describedMath"
        case highContrastDisplay = "highContrastDisplay"
        case resizeText = "resizeText"

        var displayName: String {
            switch self {
            case .alternativeText: return "Image descriptions"
            case .longDescription: return "Detailed descriptions"
            case .tableOfContents: return "Table of contents"
            case .structuralNavigation: return "Headings & landmarks"
            case .MathML: return "Math equations"
            case .describedMath: return "Math descriptions"
            case .highContrastDisplay: return "High contrast support"
            case .resizeText: return "Resizable text"
            }
        }

        var icon: String {
            switch self {
            case .alternativeText: return "text.below.photo"
            case .longDescription: return "doc.text"
            case .tableOfContents: return "list.bullet"
            case .structuralNavigation: return "list.bullet.indent"
            case .MathML, .describedMath: return "function"
            case .highContrastDisplay: return "circle.lefthalf.filled"
            case .resizeText: return "textformat.size"
            }
        }
    }

    enum AccessibilityHazard: String {
        case flashing, motionSimulation, sound, noFlashingHazard, noMotionSimulationHazard, noSoundHazard, none

        var displayName: String {
            switch self {
            case .flashing: return "Contains flashing content"
            case .motionSimulation: return "Contains motion simulation"
            case .sound: return "Contains sound"
            case .noFlashingHazard: return "No flashing hazard"
            case .noMotionSimulationHazard: return "No motion hazard"
            case .noSoundHazard: return "No sound hazard"
            case .none: return "No known hazards"
            }
        }

        var icon: String {
            switch self {
            case .flashing, .noFlashingHazard: return "bolt"
            case .motionSimulation, .noMotionSimulationHazard: return "figure.walk.motion"
            case .sound, .noSoundHazard: return "speaker.wave.3"
            case .none: return "checkmark.shield"
            }
        }

        var isWarning: Bool {
            switch self {
            case .flashing, .motionSimulation, .sound: return true
            default: return false
            }
        }
    }
}

// EPUB Parser extension
extension EPUBDocument {
    func parseAccessibilityMetadata() -> EPUBAccessibilityMetadata {
        // Parse OPF metadata
        let opfData = getOPFContent()

        // Extract schema.org accessibility metadata
        let accessModes = parseAccessModes(from: opfData)
        let features = parseAccessibilityFeatures(from: opfData)
        let hazards = parseAccessibilityHazards(from: opfData)
        let summary = parseAccessibilitySummary(from: opfData)

        return EPUBAccessibilityMetadata(
            accessModes: accessModes,
            accessibilityFeatures: features,
            accessibilityHazards: hazards,
            accessibilitySummary: summary
        )
    }

    private func parseAccessModes(from opf: Data) -> [EPUBAccessibilityMetadata.AccessMode] {
        // Parse <meta property="schema:accessMode">textual</meta>
        // Implementation depends on your XML parser
        []
    }

    private func parseAccessibilityFeatures(from opf: Data) -> [EPUBAccessibilityMetadata.AccessibilityFeature] {
        // Parse <meta property="schema:accessibilityFeature">alternativeText</meta>
        []
    }

    private func parseAccessibilityHazards(from opf: Data) -> [EPUBAccessibilityMetadata.AccessibilityHazard] {
        // Parse <meta property="schema:accessibilityHazard">noFlashingHazard</meta>
        []
    }

    private func parseAccessibilitySummary(from opf: Data) -> String? {
        // Parse <meta property="schema:accessibilitySummary">Description...</meta>
        nil
    }
}

// Display in UI
struct BookAccessibilityInfoView: View {
    let metadata: EPUBAccessibilityMetadata

    var body: some View {
        List {
            if !metadata.accessibilityFeatures.isEmpty {
                Section("Accessibility Features") {
                    ForEach(metadata.accessibilityFeatures, id: \.self) { feature in
                        Label(feature.displayName, systemImage: feature.icon)
                            .accessibilityLabel(feature.displayName)
                    }
                }
            }

            if !metadata.accessibilityHazards.isEmpty {
                Section("Content Warnings") {
                    ForEach(metadata.accessibilityHazards, id: \.self) { hazard in
                        Label(hazard.displayName, systemImage: hazard.icon)
                            .foregroundColor(hazard.isWarning ? .red : .secondary)
                            .accessibilityLabel(hazard.displayName)
                    }
                }
            }

            if let summary = metadata.accessibilitySummary {
                Section("Accessibility Summary") {
                    Text(summary)
                        .font(.body)
                }
            }
        }
        .navigationTitle("Accessibility Info")
    }
}
```

---

### Day 3-4: Image Alt Text Handling (6-8 hours)

**Implementation**:
```swift
// EPUB image rendering with alt text
struct EPUBImageView: View {
    let imageURL: URL
    let altText: String?
    let longDescription: String?

    @State private var showingLongDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .accessibilityLabel("Loading image")
            }
            .accessibilityLabel(effectiveAltText)
            .accessibilityAddTraits(.isImage)
            .accessibilityHint(longDescription != nil ? "Double tap for detailed description" : "")
            .onTapGesture {
                if longDescription != nil {
                    showingLongDescription = true
                }
            }

            // Caption with alt text
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
        if let altText = altText {
            return altText
        } else {
            return "Image without description"
        }
    }
}

// HTML parser for EPUB content
extension String {
    func parseImageAltText() -> [(url: String, alt: String?, longdesc: String?)] {
        // Parse HTML img tags
        // <img src="image.jpg" alt="Description" longdesc="details.html"/>
        // Implementation depends on your HTML parser
        []
    }
}
```

---

### Day 5: Table Navigation (4 hours)

**Implementation**:
```swift
// Accessible table rendering for EPUB content
struct EPUBTableView: View {
    let tableData: TableData

    var body: some View {
        Table(of: TableRow.self) {
            ForEach(tableData.columns) { column in
                TableColumn(column.header) { row in
                    Text(row.cellContent(for: column.id))
                }
            }
        } rows: {
            ForEach(tableData.rows) { row in
                TableRow(row)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Table: \(tableData.caption ?? "Data table")")
        .accessibilityHint("\(tableData.rows.count) rows, \(tableData.columns.count) columns")
    }
}

struct TableData {
    let caption: String?
    let columns: [ColumnData]
    let rows: [TableRow]
}

struct ColumnData: Identifiable {
    let id: String
    let header: String
}

struct TableRow: Identifiable {
    let id = UUID()
    let cells: [String: String]

    func cellContent(for columnID: String) -> String {
        cells[columnID] ?? ""
    }
}
```

---

**Week 4 Deliverables**:
- [ ] EPUB accessibility metadata parsed and displayed
- [ ] Image alt text properly announced by VoiceOver
- [ ] Long descriptions accessible for complex images
- [ ] Tables properly structured for screen readers
- [ ] Content warnings displayed for accessibility hazards

---

## Week 5: Automated Testing & CI/CD

**Goal**: Automated accessibility testing integrated into development workflow

**Effort**: 15-20 hours

### Day 1-2: Unit & UI Tests (8-10 hours)

**See Week 1 testing examples**

Additional tests to implement:

```swift
// Accessibility trait tests
class AccessibilityTraitTests: XCTestCase {
    func testButtonsHaveButtonTrait() {
        let app = XCUIApplication()
        app.launch()

        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertTrue(
                button.elementType == .button,
                "Element labeled as button should have button trait: \(button.label)"
            )
        }
    }

    func testHeadingsHaveHeaderTrait() {
        let app = XCUIApplication()
        app.launch()

        // Check section headers
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        let headers = staticTexts.filter { $0.identifier.contains("header") }

        for header in headers {
            XCTAssertTrue(
                header.traits.contains(.header),
                "Section headers should have header trait: \(header.label)"
            )
        }
    }
}

// Dynamic Type tests
class DynamicTypeTests: XCTestCase {
    func testLayoutAtAccessibilitySizes() throws {
        let app = XCUIApplication()

        // Test at XXXL
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        // Verify layouts don't break
        let libraryView = app.scrollViews["library"]
        XCTAssertTrue(libraryView.exists)

        // Check that text is visible (not clipped)
        let bookTitles = app.staticTexts.matching(identifier: "book-title")
        XCTAssertGreaterThan(bookTitles.count, 0)

        for i in 0..<min(bookTitles.count, 5) {
            let title = bookTitles.element(boundBy: i)
            XCTAssertTrue(title.isHittable, "Book title should be fully visible at XXXL")
        }
    }
}

// Contrast tests
class ContrastRatioTests: XCTestCase {
    func testPrimaryTextContrast() {
        let textColor = Color.primary
        let backgroundColor = Color(.systemBackground)

        let ratio = ContrastChecker.contrastRatio(
            between: textColor,
            and: backgroundColor
        )

        XCTAssertGreaterThanOrEqual(
            ratio,
            4.5,
            "Primary text must meet 4.5:1 contrast ratio"
        )
    }

    func testAccentColorContrast() {
        let accentColor = Color.accentColor
        let backgroundColor = Color(.systemBackground)

        let ratio = ContrastChecker.contrastRatio(
            between: accentColor,
            and: backgroundColor
        )

        XCTAssertGreaterThanOrEqual(
            ratio,
            3.0,
            "Accent color (UI component) must meet 3:1 contrast ratio"
        )
    }
}
```

---

### Day 3-4: CI/CD Integration (6-8 hours)

**GitHub Actions Workflow**:
```yaml
# .github/workflows/accessibility_tests.yml
name: Accessibility Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  accessibility-tests:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Run Accessibility Unit Tests
      run: |
        xcodebuild test \
          -scheme Epilogue \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
          -only-testing:EpilogueTests/AccessibilityTests \
          | xcpretty

    - name: Run Accessibility UI Tests
      run: |
        xcodebuild test \
          -scheme Epilogue \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
          -only-testing:EpilogueUITests/VoiceOverUITests \
          -only-testing:EpilogueUITests/DynamicTypeTests \
          | xcpretty

    - name: Run Accessibility Inspector Audit
      run: |
        # Launch simulator
        xcrun simctl boot "iPhone 15 Pro" || true

        # Build and install app
        xcodebuild build \
          -scheme Epilogue \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
          -derivedDataPath build

        # Run accessibility inspector audit
        # (This requires additional scripting - see below)

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: accessibility-test-results
        path: |
          build/Logs/Test/*.xcresult
          accessibility-audit-report.json
```

**Accessibility Audit Script**:
```bash
#!/bin/bash
# scripts/run_accessibility_audit.sh

# Run Xcode's Accessibility Inspector programmatically
# Note: This is a simplified example - actual implementation requires
# using Accessibility Inspector's command-line interface or API

set -e

SIMULATOR_NAME="iPhone 15 Pro"
SCHEME="Epilogue"

echo "Starting accessibility audit..."

# Boot simulator
xcrun simctl boot "$SIMULATOR_NAME" || true

# Install app
xcodebuild build \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath build

# Get app bundle ID
BUNDLE_ID=$(xcodebuild -showBuildSettings -scheme "$SCHEME" | grep PRODUCT_BUNDLE_IDENTIFIER | awk '{print $3}')

# Launch app
xcrun simctl launch "$SIMULATOR_NAME" "$BUNDLE_ID"

# Run accessibility inspector audits
# (Replace with actual Accessibility Inspector API calls)
echo "Running contrast audit..."
echo "Running label audit..."
echo "Running hit target audit..."

# Generate report
cat > accessibility-audit-report.json <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "simulator": "$SIMULATOR_NAME",
  "bundle_id": "$BUNDLE_ID",
  "audits": {
    "contrast": {
      "passed": true,
      "issues": []
    },
    "labels": {
      "passed": false,
      "issues": [
        {
          "severity": "warning",
          "element": "Button",
          "issue": "Missing accessibility label"
        }
      ]
    },
    "hit_targets": {
      "passed": true,
      "issues": []
    }
  }
}
EOF

echo "Audit complete. Report saved to accessibility-audit-report.json"

# Fail if critical issues found
CRITICAL_ISSUES=$(jq '[.audits[] | select(.passed == false and .severity == "error")] | length' accessibility-audit-report.json)

if [ "$CRITICAL_ISSUES" -gt 0 ]; then
    echo "❌ Found $CRITICAL_ISSUES critical accessibility issues"
    exit 1
else
    echo "✅ Accessibility audit passed"
    exit 0
fi
```

---

### Day 5: Documentation & Code Review Checklist (2 hours)

**PR Template Addition**:
```markdown
# .github/pull_request_template.md

## Accessibility Checklist

For UI changes, verify:

- [ ] All new interactive elements have accessibility labels
- [ ] Tested with VoiceOver (at minimum: navigate to new features)
- [ ] Tested at largest Dynamic Type size (XXXL)
- [ ] Verified minimum tap targets (44x44pt)
- [ ] Checked color contrast ratios
- [ ] Tested with Reduce Motion enabled (if animations added)
- [ ] Screenshots/recordings of accessibility testing (optional)

### Accessibility Testing Evidence

<!-- Paste screenshots or describe testing performed -->

```

**Code Review Checklist**:
```markdown
# ACCESSIBILITY_CODE_REVIEW.md

## Accessibility Code Review Checklist

### VoiceOver Support
- [ ] All Buttons have `.accessibilityLabel()`
- [ ] All Images (non-decorative) have `.accessibilityLabel()`
- [ ] Decorative elements have `.accessibilityHidden(true)`
- [ ] Interactive elements have appropriate traits (`.accessibilityAddTraits()`)
- [ ] Custom controls have `.accessibilityAction()` alternatives
- [ ] Reading order is logical (test with VoiceOver)
- [ ] Modals have `.accessibilityAction(.escape)`

### Dynamic Type
- [ ] Text uses system fonts or `@ScaledMetric`
- [ ] No hardcoded font sizes without scaling
- [ ] Layouts adapt for accessibility sizes
- [ ] HStacks become VStacks at large sizes (when appropriate)
- [ ] No text truncation at XXXL
- [ ] Minimum tap targets maintained at all sizes

### Visual Accessibility
- [ ] Color contrast meets 4.5:1 for text (3:1 for large text)
- [ ] No information conveyed by color alone
- [ ] Links are underlined (or have non-color indicator)
- [ ] Status indicators use icon + color + text
- [ ] Reduce Motion alternatives provided
- [ ] High Contrast mode considered

### Reader Features
- [ ] EPUB images use alt text when available
- [ ] Tables are properly structured
- [ ] Page navigation works with VoiceOver
- [ ] Reading controls accessible

### Testing
- [ ] Unit tests for new accessibility features
- [ ] UI tests updated if interaction patterns changed
- [ ] Manual testing performed (see PR template)

```

---

**Week 5 Deliverables**:
- [ ] Comprehensive test suite for accessibility
- [ ] CI/CD pipeline includes accessibility checks
- [ ] PR template requires accessibility verification
- [ ] Code review checklist created
- [ ] All tests passing

---

## Week 6: User Testing & Final Polish

**Goal**: Real user validation, address feedback, document features

**Effort**: 15-20 hours

### Day 1-2: User Testing Sessions (8-10 hours)

**Recruiting**: 5-10 users with diverse accessibility needs

**Test Plan**:
```markdown
# Accessibility User Testing Plan

## Participants (5-10 total)

1. **VoiceOver User** (blind or low vision)
   - Primary assistive tech: VoiceOver
   - iOS experience level: Advanced
   - Reading habits: Audiobooks + screen reader

2. **Low Vision User** (not using screen reader)
   - Primary assistive tech: Large text, zoom, high contrast
   - iOS experience level: Intermediate
   - Reading habits: E-books with large fonts

3. **Motor Disability User**
   - Primary assistive tech: Switch Control or Voice Control
   - iOS experience level: Advanced
   - Reading habits: E-books with hands-free controls

4. **Cognitive Disability User**
   - Primary assistive tech: Reduce Motion, simplified interfaces
   - iOS experience level: Basic to intermediate
   - Reading habits: E-books, audiobooks

5. **Elderly User** (65+)
   - Primary assistive tech: Large text, hearing aids
   - iOS experience level: Basic
   - Reading habits: E-books

## Testing Scenarios (30-45 min per participant)

### Scenario 1: Browse Library (5-7 min)
**Task**: Browse your book library and find a book you're currently reading.

**Success Criteria**:
- User can navigate to Library tab
- User can browse book list
- User can identify current reading status
- User can understand book information (title, author, progress)

**Observations**:
- Time to complete: _____
- Errors/confusion: _____
- Ease of use (1-5): _____
- Comments: _____

### Scenario 2: Start Reading (7-10 min)
**Task**: Open a book and start reading from where you left off.

**Success Criteria**:
- User can open book details
- User can start reading
- User can navigate pages (next/previous)
- User can adjust reading settings if desired

**Observations**:
- Time to complete: _____
- Errors/confusion: _____
- Ease of use (1-5): _____
- Comments: _____

### Scenario 3: Use Chat Feature (7-10 min)
**Task**: Ask the assistant a question about the book you're reading.

**Success Criteria**:
- User can find chat feature
- User can compose and send message
- User can read assistant response
- User understands conversation flow

**Observations**:
- Time to complete: _____
- Errors/confusion: _____
- Ease of use (1-5): _____
- Comments: _____

### Scenario 4: Adjust Settings (5-7 min)
**Task**: Go to settings and adjust the app theme to your preference.

**Success Criteria**:
- User can navigate to settings
- User can find theme option
- User can change theme
- User understands effect of change

**Observations**:
- Time to complete: _____
- Errors/confusion: _____
- Ease of use (1-5): _____
- Comments: _____

### Scenario 5: Search for New Book (5-7 min)
**Task**: Search for a book you'd like to read and add it to your library.

**Success Criteria**:
- User can access search
- User can enter search term
- User can browse results
- User can add book to library

**Observations**:
- Time to complete: _____
- Errors/confusion: _____
- Ease of use (1-5): _____
- Comments: _____

## Post-Test Questionnaire

### System Usability Scale (SUS)

Rate each statement from 1 (Strongly Disagree) to 5 (Strongly Agree):

1. I think that I would like to use this app frequently. ___
2. I found the app unnecessarily complex. ___
3. I thought the app was easy to use. ___
4. I think that I would need the support of a technical person to be able to use this app. ___
5. I found the various functions in this app were well integrated. ___
6. I thought there was too much inconsistency in this app. ___
7. I would imagine that most people would learn to use this app very quickly. ___
8. I found the app very cumbersome to use. ___
9. I felt very confident using the app. ___
10. I needed to learn a lot of things before I could get going with this app. ___

**SUS Score Calculation**: [(Sum of odd items - 5) + (25 - sum of even items)] × 2.5
- 68+: Above average
- 80+: Good
- 90+: Excellent

### Accessibility-Specific Questions

1. **VoiceOver Experience** (if applicable):
   - Were all elements properly labeled? Yes / No / Mostly
   - Was the reading order logical? Yes / No / Mostly
   - Comments: _____

2. **Visual Experience**:
   - Was text readable at your preferred size? Yes / No
   - Was contrast sufficient? Yes / No
   - Comments: _____

3. **Navigation**:
   - Could you easily navigate to all features? Yes / No
   - Were controls easy to activate? Yes / No
   - Comments: _____

4. **Overall Accessibility Rating** (1-5):
   - 5: Excellent accessibility
   - 4: Good, minor issues
   - 3: Adequate, some barriers
   - 2: Poor, significant barriers
   - 1: Unusable

5. **Most Significant Issue**: _____

6. **Most Impressive Feature**: _____

7. **Would you recommend this app to other users with similar needs?** Yes / No / Maybe

8. **Additional Comments**: _____

## Data Collection

- Video recording (with permission)
- Screen recording
- Think-aloud protocol
- Observer notes
- Post-test questionnaire

## Success Metrics

- [ ] Average SUS score > 80
- [ ] Average accessibility rating > 4
- [ ] <2 critical issues per session
- [ ] 80%+ would recommend to others
- [ ] All P0 issues identified and documented
```

---

### Day 3-4: Address User Feedback (6-8 hours)

**Process**:
1. Compile all findings from user testing
2. Categorize issues by severity (P0, P1, P2)
3. Fix all P0 issues immediately
4. Plan P1/P2 fixes for future releases

**Example Issues & Fixes**:

```swift
// Issue: "VoiceOver announces book progress as '0.75' instead of '75%'"
// Before:
Text("\(book.progress)")
    .accessibilityLabel("Progress: \(book.progress)")

// After:
Text("\(Int(book.progress * 100))%")
    .accessibilityLabel("Progress: \(Int(book.progress * 100)) percent complete")

// Issue: "Can't dismiss modal with VoiceOver escape gesture"
// Fix: Add escape action to all modals
.accessibilityAction(.escape) {
    dismiss()
}

// Issue: "Reading controls too small at default size"
// Fix: Increase minimum size
.frame(minWidth: 44, minHeight: 44)
```

---

### Day 5: Documentation & Launch (3-5 hours)

**User-Facing Documentation**:
```markdown
# Epilogue Accessibility Features

Epilogue is designed to be accessible to all readers. We support:

## VoiceOver

Full VoiceOver support throughout the app:
- Browse your library with complete book information
- Navigate while reading with custom page turning actions
- Chat with AI assistant using fully labeled conversation interface
- Adjust all settings via VoiceOver

**Getting Started with VoiceOver**:
1. Enable: Settings > Accessibility > VoiceOver
2. Open Epilogue
3. Swipe right/left to navigate
4. Double-tap to activate
5. Three-finger swipe to turn pages while reading

## Dynamic Type

All text scales to your preferred size:
- Set size: Settings > Display & Brightness > Text Size
- Epilogue supports all sizes including accessibility sizes (AX1-AX5)
- Layouts automatically adapt for larger text

## Visual Accommodations

- **High Contrast Mode**: Enhanced borders and controls
- **Reduce Motion**: Simplified animations
- **Color Filters**: Works with all iOS color blindness filters
- **Dark Mode**: Full support with accessible contrast ratios

## Reading Accessibility

- **EPUB Accessibility**: Displays publisher accessibility metadata
- **Image Descriptions**: Alt text for images (when provided by publisher)
- **Adjustable Reading Settings**: Font size, line spacing, themes
- **Text Selection**: Select and look up words while reading

## Keyboard Navigation

Use external keyboard with:
- Tab to navigate
- Space/Enter to activate
- Arrow keys to adjust values
- Esc to dismiss modals

## Need Help?

Contact us at support@epilogue.app for accessibility assistance.
We're committed to making Epilogue accessible to everyone.
```

**Developer Documentation**:
```markdown
# Epilogue Accessibility Development Guide

## Standards

We comply with:
- **WCAG 2.1 Level AA**
- **iOS Human Interface Guidelines - Accessibility**
- **EPUB Accessibility 1.1**

## Quick Reference

### Adding New UI Elements

Every new interactive element must have:
```swift
Button("Action") { }
    .accessibilityLabel("Descriptive label")
    .accessibilityHint("What happens when activated")
    .accessibilityIdentifier("unique-id") // For testing

// Images
Image("icon")
    .accessibilityLabel("Description")
    .accessibilityHidden(true) // if decorative

// Custom controls
CustomControl()
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Action") { }
```

### Dynamic Type

Use scaled fonts:
```swift
@ScaledMetric(relativeTo: .body) var fontSize: CGFloat = 17

Text("Content")
    .font(.system(size: fontSize))
```

### Testing Checklist

Before every PR:
- [ ] VoiceOver test
- [ ] XXXL Dynamic Type test
- [ ] Reduce Motion test
- [ ] Run accessibility unit tests

## Resources

- [WCAG Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [Apple Accessibility](https://developer.apple.com/accessibility/)
- Internal: `ACCESSIBILITY_CODE_REVIEW.md`
```

---

**Week 6 Deliverables**:
- [ ] User testing complete with 5-10 participants
- [ ] All critical issues from testing addressed
- [ ] User-facing accessibility documentation published
- [ ] Developer accessibility guide created
- [ ] Final WCAG audit passed
- [ ] Ready for accessibility-focused launch

---

## Summary Timeline

| Week | Focus | Effort | Key Deliverables |
|------|-------|--------|------------------|
| **1** | Foundation & Critical Fixes | 20-25h | Audit, VoiceOver labels, chat accessibility, tap targets |
| **2** | Dynamic Type | 25-30h | Full scaling, layout adaptation, settings |
| **3** | Visual Accessibility | 20-25h | Contrast, non-color indicators, Reduce Motion, High Contrast |
| **4** | Reader Features | 15-20h | EPUB metadata, alt text, tables |
| **5** | Testing & CI/CD | 15-20h | Automated tests, CI integration, documentation |
| **6** | User Testing & Polish | 15-20h | Real user validation, fixes, launch prep |
| **Total** | **6 weeks** | **120-150h** | **WCAG 2.1 AA Compliance** |

## Next Steps

1. **Review** this plan with team
2. **Prioritize** if timeline needs adjustment
3. **Assign** tasks to developers
4. **Schedule** user testing participants
5. **Begin Week 1** audit immediately

## Success Metrics

At the end of 6 weeks:
- ✅ 100% WCAG 2.1 Level AA compliance
- ✅ SUS score > 80 from assistive tech users
- ✅ 0 critical accessibility bugs
- ✅ Automated testing in CI/CD
- ✅ Documentation complete
- ✅ Ready for accessible app launch

---

**Questions or need clarification?** See `ACCESSIBILITY_AUDIT_CHECKLIST.md` for detailed requirements and `ACCESSIBILITY_CODE_EXAMPLES.md` for implementation patterns.
