# Epilogue WCAG 2.1 AA Accessibility Audit Checklist

**App**: Epilogue - iOS Reading App
**Standard**: WCAG 2.1 Level AA
**Platform**: iOS 18+ / SwiftUI
**Last Updated**: 2025-11-21

---

## Executive Summary

**Current Compliance**: ~60-70% AA compliant
**Critical Gaps**: Chat accessibility, Dynamic Type expansion, formal testing
**Estimated to Full Compliance**: 2-3 weeks focused effort

---

## 1. VoiceOver Support (WCAG 1.1, 1.3, 2.4, 4.1)

### 1.1 Interactive Element Labeling

| Component | Current State | Priority | Status |
|-----------|--------------|----------|---------|
| **Tab Bar Navigation** | ✅ All 3 tabs labeled with hints | P0 | Complete |
| **Library Book Cards** | ✅ Title, author, progress announced | P0 | Complete |
| **Reading Controls** | ✅ Play/pause, speed controls labeled | P0 | Complete |
| **Settings Toggles** | ✅ All toggles with state announcements | P0 | Complete |
| **Chat Messages** | ⚠️ Missing context, sender identification | P0 | **Critical** |
| **Note/Quote Cards** | ✅ Content + timestamp accessible | P1 | Complete |
| **Search Fields** | ⚠️ Need verification | P1 | **Needs Testing** |
| **Filter Buttons** | ✅ Labeled with current filter state | P1 | Complete |
| **Modal Dialogs** | ⚠️ 71+ modals need dismissal hints | P1 | **Needs Work** |
| **Custom Controls** | ⚠️ Book cover taps, gesture controls | P2 | **Needs Testing** |

**Testing Checklist:**
- [ ] Enable VoiceOver (Settings > Accessibility > VoiceOver)
- [ ] Navigate entire app using only VoiceOver gestures
- [ ] Verify every interactive element is:
  - [ ] Discoverable (VoiceOver focuses on it)
  - [ ] Identifiable (clear label describes purpose)
  - [ ] Actionable (hints explain how to activate)
- [ ] Test with VoiceOver Rotor for headings, links, buttons
- [ ] Verify reading order follows visual hierarchy
- [ ] Test all modal presentations and dismissals

**Code Review:**
```bash
# Search for unlabeled interactive elements
grep -r "Button\|Toggle\|Picker" --include="*.swift" | grep -v "accessibilityLabel"
grep -r "\.onTapGesture" --include="*.swift" | grep -v "accessibilityAction"
```

---

### 1.2 Reading Order Optimization

| View | Current State | Priority | Status |
|------|--------------|----------|---------|
| **Library Grid/List** | ✅ Logical top-to-bottom order | P0 | Complete |
| **Book Detail Tabs** | ⚠️ Tab order needs verification | P1 | **Needs Testing** |
| **Chat Interface** | ⚠️ Message order (oldest→newest?) | P0 | **Needs Testing** |
| **Settings Sections** | ✅ Grouped sections with headers | P1 | Complete |
| **Reading View** | ⚠️ Content vs. controls order | P0 | **Needs Testing** |

**Testing Checklist:**
- [ ] Navigate each view with VoiceOver
- [ ] Verify focus order matches visual layout
- [ ] Test with VoiceOver rotor set to "Containers"
- [ ] Verify section headers properly group content
- [ ] Test landscape and portrait orientations

**Implementation:**
```swift
// Use accessibilityElement(children:) to control order
VStack {
    header
    content
    footer
}
.accessibilityElement(children: .contain) // Reads top to bottom

// Or manually order with sortPriority
Text("Title").accessibilitySortPriority(3)
Text("Subtitle").accessibilitySortPriority(2)
Button("Action").accessibilitySortPriority(1)
```

---

### 1.3 Custom Control Accessibility

| Control | Current State | Priority | Status |
|---------|--------------|----------|---------|
| **Book Cover Tap** | ⚠️ Needs custom action | P1 | **Needs Work** |
| **Swipe Gestures** | ⚠️ Alternative VoiceOver actions? | P2 | **Needs Work** |
| **Reading Progress Slider** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Theme Selector** | ✅ Picker with labels | P1 | Complete |
| **Star Rating** | ⚠️ If exists, needs custom actions | P2 | **Needs Testing** |

**Testing Checklist:**
- [ ] Test all custom gestures with VoiceOver on
- [ ] Verify VoiceOver custom actions menu (swipe up/down)
- [ ] Test adjustable controls (increment/decrement)
- [ ] Verify alternative interaction methods exist

**Implementation:**
```swift
// Custom actions for complex gestures
BookCoverView()
    .accessibilityLabel("Book cover: \(book.title)")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Open book") {
        openBook()
    }
    .accessibilityAction(named: "View details") {
        showDetails()
    }
    .accessibilityAction(named: "Add to favorites") {
        toggleFavorite()
    }

// Adjustable controls
Slider(value: $progress, in: 0...1)
    .accessibilityLabel("Reading progress")
    .accessibilityValue("\(Int(progress * 100))%")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: progress += 0.05
        case .decrement: progress -= 0.05
        @unknown default: break
        }
    }
```

---

### 1.4 Page Turning & Navigation

| Feature | Current State | Priority | Status |
|---------|--------------|----------|---------|
| **Page Turn Gestures** | ⚠️ VoiceOver alternative needed | P0 | **Needs Work** |
| **Chapter Navigation** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Bookmark Management** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Search in Book** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Table of Contents** | ⚠️ Needs testing | P1 | **Needs Testing** |

**Testing Checklist:**
- [ ] Test reading a book with VoiceOver enabled
- [ ] Verify page turn alternatives (buttons, swipe actions)
- [ ] Test chapter-to-chapter navigation
- [ ] Test bookmark creation and navigation
- [ ] Verify reading position is maintained
- [ ] Test "Read from here" functionality

**Implementation:**
```swift
// Reading view with VoiceOver support
struct ReadingView: View {
    var body: some View {
        ScrollView {
            Text(bookContent)
                .accessibilityLabel("Book content")
                .accessibilityAddTraits(.isStaticText)
        }
        .accessibilityAction(named: "Next page") {
            turnPage(.forward)
        }
        .accessibilityAction(named: "Previous page") {
            turnPage(.backward)
        }
        .accessibilityAction(named: "Go to chapter") {
            showChapterMenu()
        }
        .overlay(alignment: .bottom) {
            HStack {
                Button("Previous") { turnPage(.backward) }
                    .accessibilityLabel("Previous page")
                Spacer()
                Button("Next") { turnPage(.forward) }
                    .accessibilityLabel("Next page")
            }
            .accessibilityHidden(true) // Redundant with actions above
        }
    }
}
```

---

## 2. Dynamic Type (WCAG 1.4.4, 1.4.12)

### 2.1 Text Scaling Support

| View Category | Current State | Priority | Status |
|---------------|--------------|----------|---------|
| **Navigation & Tabs** | ⚠️ Needs testing at largest sizes | P0 | **Needs Testing** |
| **Library Book List** | ⚠️ Only 4 files use scaledMetric | P0 | **Needs Work** |
| **Chat Messages** | ⚠️ Fixed fonts used | P0 | **Critical** |
| **Book Content** | ⚠️ Reader font likely scalable | P0 | **Needs Testing** |
| **Settings UI** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Notes & Quotes** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Buttons & Controls** | ⚠️ Minimum tap target size | P0 | **Needs Testing** |

**Testing Checklist:**
- [ ] Set text size to "Largest" (Settings > Display & Brightness > Text Size)
- [ ] Enable "Larger Accessibility Sizes" for XXXL testing
- [ ] Navigate through all app views
- [ ] Verify no text truncation at large sizes
- [ ] Verify layouts adapt (stack vertically if needed)
- [ ] Test with Dynamic Type Previews in Xcode

**Size Requirements:**
- Minimum readable: 12pt (16pt preferred)
- WCAG AA Large text: 18pt+ or 14pt+ bold
- iOS accessibility sizes: Up to ~53pt (XXXL)
- Must support 200% zoom without loss of functionality

**Implementation Status:**
```bash
# Current Dynamic Type usage (only 4 files!)
- BookDetailsViewModel.swift
- ReadingSessionProgressView.swift
- ChapterProgressView.swift
- LibraryBookCard.swift (partial)
```

---

### 2.2 Layout Adaptation

| Pattern | Current State | Priority | Status |
|---------|--------------|----------|---------|
| **Horizontal Stacks** | ⚠️ Need @ViewBuilder for dynamic layout | P0 | **Needs Work** |
| **Button Groups** | ⚠️ May need vertical stacking | P0 | **Needs Work** |
| **Multi-Column Layouts** | ⚠️ Need to collapse at large sizes | P1 | **Needs Work** |
| **Fixed Heights** | ⚠️ Need to become dynamic | P0 | **Needs Work** |
| **Tab Bar Icons** | ⚠️ May need text-only mode | P2 | **Needs Testing** |

**Testing Checklist:**
- [ ] Test all HStack layouts at XXXL sizes
- [ ] Verify buttons don't overlap or truncate
- [ ] Check that scrolling enables when content exceeds screen
- [ ] Test multi-line button labels
- [ ] Verify minimum tap targets (44x44pt)

**Implementation:**
```swift
// Adaptive layout for Dynamic Type
struct AdaptiveButtonRow: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize

        Group {
            if isAccessibilitySize {
                VStack(spacing: 12) { buttonContent }
            } else {
                HStack(spacing: 12) { buttonContent }
            }
        }
    }

    @ViewBuilder
    var buttonContent: some View {
        Button("Action 1") { }
            .frame(minHeight: 44) // Minimum tap target
        Button("Action 2") { }
            .frame(minHeight: 44)
    }
}

// Scaled font metric
struct BookTitleView: View {
    @ScaledMetric(relativeTo: .title) var titleSize: CGFloat = 24

    var body: some View {
        Text(book.title)
            .font(.system(size: titleSize, weight: .bold))
            .lineLimit(nil) // Allow wrapping
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

---

### 2.3 Typography Hierarchy Preservation

| Element | Base Size | Scaled Size | Priority | Status |
|---------|-----------|-------------|----------|---------|
| **Large Title** | 34pt | ~68pt (200%) | P1 | **Needs Testing** |
| **Title 1** | 28pt | ~56pt | P1 | **Needs Testing** |
| **Title 2** | 22pt | ~44pt | P1 | **Needs Testing** |
| **Headline** | 17pt | ~34pt | P1 | **Needs Testing** |
| **Body** | 17pt | ~34pt | P0 | **Needs Testing** |
| **Callout** | 16pt | ~32pt | P1 | **Needs Testing** |
| **Footnote** | 13pt | ~26pt | P1 | **Needs Testing** |
| **Caption** | 12pt | ~24pt | P2 | **Needs Testing** |

**Testing Checklist:**
- [ ] Verify font hierarchy remains clear at all sizes
- [ ] Test with system text styles (.body, .headline, etc.)
- [ ] Verify custom fonts scale appropriately
- [ ] Test reading flow with scaled text

**Implementation:**
```swift
// Use system text styles (auto-scaling)
Text("Heading")
    .font(.headline)  // Auto scales

Text("Body content")
    .font(.body)      // Auto scales

// Custom fonts with scaling
Text("Custom heading")
    .font(.custom("YourFont", size: 24, relativeTo: .headline))

// Manual scaling for precise control
@ScaledMetric(relativeTo: .body) var customSize: CGFloat = 17
Text("Custom text")
    .font(.custom("YourFont", size: customSize))
```

---

## 3. Visual Accessibility (WCAG 1.4.3, 1.4.6, 1.4.11, 2.3.3)

### 3.1 Color Contrast Ratios

**WCAG AA Requirements:**
- Normal text (<18pt): 4.5:1 minimum
- Large text (18pt+ or 14pt+ bold): 3:1 minimum
- UI components & graphics: 3:1 minimum
- Incidental text (logos, decorative): No requirement

| Component | Contrast | Required | Priority | Status |
|-----------|----------|----------|----------|---------|
| **Body Text on Background** | ⚠️ TBD | 4.5:1 | P0 | **Needs Testing** |
| **Book Titles** | ⚠️ TBD | 3:1 (large) | P0 | **Needs Testing** |
| **Button Labels** | ⚠️ TBD | 4.5:1 | P0 | **Needs Testing** |
| **Tab Bar Icons** | ⚠️ TBD | 3:1 | P0 | **Needs Testing** |
| **Reading Progress** | ⚠️ TBD | 3:1 | P1 | **Needs Testing** |
| **Status Indicators** | ⚠️ TBD | 3:1 | P1 | **Needs Testing** |
| **Chat Bubbles** | ⚠️ TBD | 4.5:1 | P0 | **Needs Testing** |
| **Link Text** | ⚠️ TBD | 4.5:1 | P1 | **Needs Testing** |
| **Form Inputs** | ⚠️ TBD | 3:1 (border) | P1 | **Needs Testing** |
| **Error Messages** | ⚠️ TBD | 4.5:1 | P0 | **Needs Testing** |

**Testing Tools:**
- [ ] Xcode Accessibility Inspector (contrast audit)
- [ ] Online: WebAIM Contrast Checker
- [ ] Online: Stark plugin / Color Oracle
- [ ] iOS: Color Contrast Analyzer app
- [ ] Test in both light and dark modes

**Known Color Systems to Audit:**
```swift
// Check these files:
- BookAtmosphericGradientView.swift (gradient backgrounds)
- ColorCube extraction (OKLABColorExtractor.swift)
- Theme system (if custom colors used)
- Status colors (reading/completed indicators)
- Chat message colors
```

**Remediation:**
```swift
// Ensure sufficient contrast
Color.primary      // Auto-adapts to theme (good!)
Color.secondary    // Auto-adapts to theme (good!)

// Custom colors - check contrast
Color(red: 0.2, green: 0.3, blue: 0.8)  // Must verify!

// Use semantic colors when possible
Color.accentColor
Color.label        // UIKit equivalent
Color.secondaryLabel

// High Contrast mode support
@Environment(\.colorSchemeContrast) var contrast

var textColor: Color {
    contrast == .increased ? .primary : .secondary
}
```

---

### 3.2 Non-Color Visual Indicators

| Information | Color Only? | Additional Indicator | Priority | Status |
|-------------|-------------|---------------------|----------|---------|
| **Reading Status** | ⚠️ Check | Need icon/text | P0 | **Needs Testing** |
| **Error States** | ⚠️ Check | Need icon/text | P0 | **Needs Testing** |
| **Form Validation** | ⚠️ Check | Need icon/text | P1 | **Needs Testing** |
| **Link vs Text** | ⚠️ Check | Underline needed | P1 | **Needs Testing** |
| **Active Tab** | ⚠️ Check | Icon fill/bold text | P0 | **Needs Testing** |
| **Selected Items** | ⚠️ Check | Checkmark/border | P1 | **Needs Testing** |
| **Progress Bars** | ⚠️ Check | Percentage text | P1 | **Needs Testing** |

**Testing Checklist:**
- [ ] Enable Color Filters > Grayscale (Settings > Accessibility)
- [ ] Navigate app in grayscale mode
- [ ] Verify all statuses are distinguishable
- [ ] Check that interactive elements are identifiable
- [ ] Test with different color blindness filters

**Implementation:**
```swift
// ❌ BAD: Color only
Text(book.status)
    .foregroundColor(book.isComplete ? .green : .orange)

// ✅ GOOD: Color + icon
HStack {
    Image(systemName: book.isComplete ? "checkmark.circle.fill" : "circle.dotted")
    Text(book.status)
}
.foregroundColor(book.isComplete ? .green : .orange)

// ✅ GOOD: Color + shape + text
HStack {
    Circle()
        .fill(book.isComplete ? Color.green : Color.orange)
        .frame(width: 8, height: 8)
    Text(book.isComplete ? "Complete" : "Reading")
        .font(.caption)
}
```

---

### 3.3 Reduce Motion Support

| Animation | Current State | Alternative | Priority | Status |
|-----------|--------------|-------------|----------|---------|
| **Ambient Mode** | ✅ Respects reduce motion | Static gradient | P1 | Complete |
| **Page Transitions** | ⚠️ 25+ animation files | Crossfade | P1 | **Needs Work** |
| **Loading Indicators** | ⚠️ Check | Simple fade | P1 | **Needs Testing** |
| **Scroll Animations** | ⚠️ Check | Instant scroll | P2 | **Needs Testing** |
| **Modal Presentations** | ⚠️ Check | Fade only | P2 | **Needs Testing** |
| **Gesture Feedback** | ⚠️ Check | Haptics only | P2 | **Needs Testing** |

**Testing Checklist:**
- [ ] Enable Reduce Motion (Settings > Accessibility > Motion)
- [ ] Navigate through all app screens
- [ ] Verify no motion sickness triggers
- [ ] Test all animated transitions
- [ ] Verify alternative animations are smooth

**Implementation:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .spring(response: 0.3)
}

// Conditional animations
withAnimation(reduceMotion ? nil : .easeInOut) {
    showDetail = true
}

// Alternative effects
if reduceMotion {
    content
        .transition(.opacity)
} else {
    content
        .transition(.move(edge: .trailing).combined(with: .opacity))
}

// ParallaxEffect replacement
if reduceMotion {
    image // Static
} else {
    image
        .offset(y: scrollOffset * 0.5) // Parallax
}
```

---

### 3.4 High Contrast Mode Support

| Element | Current State | Priority | Status |
|---------|--------------|----------|---------|
| **Text Rendering** | ⚠️ Needs testing | P1 | **Needs Testing** |
| **Border Weights** | ⚠️ Should increase | P1 | **Needs Work** |
| **Icon Clarity** | ⚠️ May need filled variants | P1 | **Needs Testing** |
| **Button Outlines** | ⚠️ Should become prominent | P1 | **Needs Work** |
| **Separator Lines** | ⚠️ Should increase opacity | P2 | **Needs Work** |

**Testing Checklist:**
- [ ] Enable Increase Contrast (Settings > Accessibility > Display)
- [ ] Navigate app in high contrast mode
- [ ] Verify all elements remain visible
- [ ] Check that gradients don't wash out text
- [ ] Test with dark mode + high contrast

**Implementation:**
```swift
@Environment(\.colorSchemeContrast) var contrast

var borderWidth: CGFloat {
    contrast == .increased ? 2 : 1
}

var buttonStyle: some View {
    Button("Action") { }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .controlSize(contrast == .increased ? .large : .regular)
}

// Adaptive separator
Divider()
    .opacity(contrast == .increased ? 1.0 : 0.3)

// Adaptive backgrounds
.background(
    contrast == .increased
        ? Color.secondarySystemBackground
        : Color.clear
)
```

---

## 4. Reader-Specific Concerns

### 4.1 Book Content vs UI Accessibility

| Aspect | Responsibility | Priority | Status |
|--------|---------------|----------|---------|
| **UI Controls** | Epilogue (App) | P0 | **In Progress** |
| **Book Text Content** | Publisher (EPUB) | P1 | **Needs Handling** |
| **Book Images** | Publisher (alt text) | P1 | **Needs Handling** |
| **Book Structure** | Publisher (semantics) | P2 | **Needs Handling** |
| **Reading Experience** | Epilogue (Presentation) | P0 | **Needs Testing** |

**Key Considerations:**
- App UI must be fully accessible (Epilogue's responsibility)
- Book content accessibility depends on publisher metadata
- App should surface available accessibility features
- Fallback handling for inaccessible content

**Testing Checklist:**
- [ ] Test with EPUB files that have accessibility metadata
- [ ] Test with EPUBs lacking accessibility features
- [ ] Verify image alt text is announced by VoiceOver
- [ ] Test table navigation in books
- [ ] Verify heading navigation works
- [ ] Test footnote/endnote access

---

### 4.2 EPUB Accessibility Metadata Handling

**EPUB Accessibility Spec**: EPUB Accessibility 1.1 / WCAG 2.x

| Metadata Field | Use in Epilogue | Priority | Status |
|----------------|----------------|----------|---------|
| **schema:accessMode** | Display in book info | P2 | **Not Implemented** |
| **schema:accessModeSufficient** | Feature detection | P2 | **Not Implemented** |
| **schema:accessibilityFeature** | Feature list | P2 | **Not Implemented** |
| **schema:accessibilityHazard** | Warning display | P1 | **Not Implemented** |
| **schema:accessibilitySummary** | User-facing info | P2 | **Not Implemented** |

**Potential Implementation:**
```swift
// Parse EPUB metadata
struct EPUBAccessibility {
    let accessModes: [String]           // textual, visual, auditory
    let accessibilityFeatures: [String] // alternativeText, tableOfContents, etc.
    let accessibilityHazards: [String]  // flashing, motionSimulation, sound, noHazard
    let accessibilitySummary: String?
}

// Display in book details
Section("Accessibility Features") {
    if epub.hasAlternativeText {
        Label("Image descriptions available", systemImage: "text.below.photo")
    }
    if epub.hasStructuralNavigation {
        Label("Table of contents", systemImage: "list.bullet")
    }
    if epub.accessibilityHazards.contains("flashing") {
        Label("Warning: Flashing content", systemImage: "exclamationmark.triangle")
            .foregroundColor(.red)
    }
}
```

---

### 4.3 Image Descriptions & Alt Text

| Scenario | Current Handling | Should Handle | Priority | Status |
|----------|-----------------|---------------|----------|---------|
| **Images with alt text** | ⚠️ Check EPUB parser | Announce in VoiceOver | P1 | **Needs Testing** |
| **Images without alt text** | ⚠️ Check | "Image" placeholder | P1 | **Needs Testing** |
| **Decorative images** | ⚠️ Check | Hidden from VoiceOver | P2 | **Needs Testing** |
| **Complex diagrams** | ⚠️ Check | Long description access | P2 | **Needs Work** |
| **Book covers** | ✅ Likely labeled | Title + author | P1 | **Needs Testing** |

**Testing Checklist:**
- [ ] Open EPUB with images and alt text
- [ ] Enable VoiceOver and navigate to images
- [ ] Verify alt text is announced
- [ ] Test with images lacking alt text
- [ ] Test decorative images are skipped

**Implementation:**
```swift
// Book content image rendering
AsyncImage(url: imageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .accessibilityLabel(altText ?? "Image without description")
        .accessibilityAddTraits(altText == nil ? .isImage : [.isImage])
} placeholder: {
    ProgressView()
        .accessibilityLabel("Loading image")
}

// Decorative images
Image("decorative-pattern")
    .accessibilityHidden(true)

// Complex images with long descriptions
Image("complex-diagram")
    .accessibilityLabel("Diagram: \(shortDescription)")
    .accessibilityHint("Double tap for detailed description")
    .onTapGesture {
        showLongDescription()
    }
```

---

### 4.4 Table Navigation

| Feature | Current State | Priority | Status |
|---------|--------------|----------|---------|
| **Table Detection** | ⚠️ EPUB parser | P2 | **Needs Testing** |
| **Header Announcement** | ⚠️ Check | P2 | **Needs Testing** |
| **Row/Column Navigation** | ⚠️ Check | P2 | **Needs Work** |
| **Cell Content Reading** | ⚠️ Check | P2 | **Needs Testing** |
| **Summary Statistics** | ⚠️ Not implemented | P3 | **Not Implemented** |

**Testing Checklist:**
- [ ] Open EPUB with tables
- [ ] Enable VoiceOver and navigate to table
- [ ] Verify table is announced as table
- [ ] Test row-by-row navigation
- [ ] Verify headers are properly associated
- [ ] Test column navigation if supported

**Implementation:**
```swift
// Native SwiftUI table (for app UI)
Table(of: BookData.self) {
    TableColumn("Title") { book in Text(book.title) }
    TableColumn("Author") { book in Text(book.author) }
    TableColumn("Progress") { book in Text("\(book.progress)%") }
}
.accessibilityElement(children: .contain)
.accessibilityLabel("Books table")

// HTML table in EPUB content
// Ensure proper semantic HTML is preserved:
// <table>, <thead>, <tbody>, <th scope="col">, <td>
// iOS WKWebView should handle this automatically if properly marked up
```

---

## 5. Testing Methodology

### 5.1 Manual Testing Protocol

**Phase 1: Core Functionality (Week 1)**
- [ ] VoiceOver full app navigation (2 hours)
- [ ] Dynamic Type at all sizes (1 hour)
- [ ] Reduce Motion enabled (30 min)
- [ ] High Contrast mode (30 min)
- [ ] Color blindness filters (30 min)

**Phase 2: Deep Testing (Week 2)**
- [ ] Reading experience with assistive tech (2 hours)
- [ ] Chat functionality with VoiceOver (1 hour)
- [ ] Form inputs and validation (1 hour)
- [ ] Search and filtering (30 min)
- [ ] Settings and preferences (30 min)

**Phase 3: Edge Cases (Week 3)**
- [ ] Multiple assistive features enabled (1 hour)
- [ ] Extreme text sizes (XXXL) (1 hour)
- [ ] Low vision scenarios (1 hour)
- [ ] Motor disability scenarios (1 hour)

### 5.2 Automated Testing

**Xcode Accessibility Inspector**
```bash
# Enable in Xcode
Xcode > Open Developer Tool > Accessibility Inspector

# Run audits:
1. Contrast audit
2. Hit target audit (44x44pt minimum)
3. Label audit (missing labels)
4. Trait audit (incorrect traits)
```

**Unit Tests for Accessibility**
```swift
import XCTest
@testable import Epilogue

class AccessibilityTests: XCTestCase {

    func testBookCardHasAccessibilityLabel() {
        let book = Book(title: "Test Book", author: "Test Author")
        let card = LibraryBookCard(book: book)

        // Verify accessibility label exists and is descriptive
        XCTAssertNotNil(card.accessibilityLabel)
        XCTAssertTrue(card.accessibilityLabel?.contains("Test Book") ?? false)
    }

    func testAllButtonsHaveLabels() {
        // Iterate through all views and check buttons
        // This is pseudo-code - adapt to your architecture
        let views = [LibraryView(), SettingsView(), BookDetailView()]
        for view in views {
            let buttons = view.findAllButtons()
            for button in buttons {
                XCTAssertNotNil(button.accessibilityLabel,
                               "Button missing accessibility label in \(type(of: view))")
            }
        }
    }

    func testMinimumTapTargets() {
        let buttons = getAllInteractiveElements()
        for button in buttons {
            let size = button.frame.size
            XCTAssertGreaterThanOrEqual(size.width, 44, "Tap target too small")
            XCTAssertGreaterThanOrEqual(size.height, 44, "Tap target too small")
        }
    }
}
```

**UI Tests for VoiceOver**
```swift
import XCTest

class VoiceOverUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().launch()
    }

    func testVoiceOverNavigationInLibrary() throws {
        let app = XCUIApplication()

        // Enable accessibility in test
        let tablesQuery = app.tables
        XCTAssertTrue(tablesQuery.firstMatch.waitForExistence(timeout: 5))

        // Verify accessibility identifiers
        XCTAssertTrue(app.buttons["library-tab"].exists)
        XCTAssertTrue(app.buttons["library-tab"].isAccessibilityElement)

        // Navigate to book
        let firstBook = app.buttons.matching(identifier: "book-card").firstMatch
        XCTAssertTrue(firstBook.exists)
        XCTAssertNotNil(firstBook.label)
    }
}
```

### 5.3 User Testing with Assistive Technology Users

**Recruitment:**
- [ ] Contact local accessibility advocacy groups
- [ ] Post on accessibility forums
- [ ] Reach out to beta testers with disabilities
- [ ] Aim for 5-10 users with diverse needs

**Testing Scenarios:**
1. **VoiceOver user**: Browse library, start reading book
2. **Low vision user**: Use with large text, high contrast
3. **Motor disability user**: Use with Switch Control
4. **Cognitive disability user**: Navigate settings, use chat

**Feedback Collection:**
- [ ] Record sessions (with permission)
- [ ] Use think-aloud protocol
- [ ] Post-session questionnaire
- [ ] System Usability Scale (SUS)
- [ ] WCAG compliance verification

---

## 6. Priority Matrix

### P0 - Critical (Must Fix Before Shipping)
- [ ] All interactive elements have VoiceOver labels
- [ ] Minimum contrast ratios met (4.5:1 for text, 3:1 for UI)
- [ ] Minimum tap targets (44x44pt)
- [ ] Dynamic Type support for all text
- [ ] Keyboard navigation functional
- [ ] No motion sickness triggers with Reduce Motion on

### P1 - High (Fix Within 1 Month)
- [ ] Chat message accessibility complete
- [ ] Reading order optimized
- [ ] High contrast mode support
- [ ] EPUB accessibility metadata handling
- [ ] Modal dismissal hints
- [ ] Form validation accessible

### P2 - Medium (Fix Within 1 Quarter)
- [ ] Custom VoiceOver rotor
- [ ] Table navigation in books
- [ ] Advanced gesture alternatives
- [ ] Accessibility documentation
- [ ] User testing with disabled users

### P3 - Low (Future Enhancement)
- [ ] WCAG AAA compliance
- [ ] Advanced screen reader features
- [ ] Braille display support
- [ ] Voice control optimization

---

## 7. Success Metrics

### Compliance Metrics
- [ ] 100% of interactive elements labeled
- [ ] 100% minimum contrast ratios met
- [ ] 100% minimum tap target sizes met
- [ ] 0 critical Xcode Accessibility Inspector issues
- [ ] Pass manual WCAG 2.1 AA audit

### User Metrics
- [ ] 90%+ SUS score from assistive tech users
- [ ] <2 critical issues per user testing session
- [ ] 5/5 user rating for accessibility
- [ ] Zero App Store reviews mentioning accessibility problems

### Technical Metrics
- [ ] 100% of views have accessibility tests
- [ ] CI/CD includes accessibility checks
- [ ] Monthly accessibility regression testing
- [ ] Accessibility included in code review checklist

---

## 8. Maintenance & Ongoing Compliance

### Code Review Checklist
Every PR must verify:
- [ ] New UI elements have accessibility labels
- [ ] Dynamic Type tested at XXXL
- [ ] VoiceOver tested if interaction changed
- [ ] Contrast verified if colors added
- [ ] Reduce Motion alternative provided if animations added

### Quarterly Audits
- [ ] Run full WCAG 2.1 AA checklist
- [ ] Test with latest iOS accessibility features
- [ ] Update to new WCAG guidelines (2.2, 3.0)
- [ ] Review user feedback and App Store reviews

### Documentation
- [ ] Accessibility guidelines in README
- [ ] SwiftUI accessibility pattern library
- [ ] Testing protocol documentation
- [ ] User-facing accessibility features page

---

## Resources

### Apple Documentation
- [Accessibility - Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [SwiftUI Accessibility Modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [VoiceOver Testing Guide](https://developer.apple.com/library/archive/technotes/TestingAccessibilityOfiOSApps/TestAccessibilityonYourDevicewithVoiceOver/TestAccessibilityonYourDevicewithVoiceOver.html)

### WCAG Resources
- [WCAG 2.1 Quick Reference](https://www.w3.org/WAI/WCAG21/quickref/)
- [Mobile Accessibility at W3C](https://www.w3.org/WAI/standards-guidelines/mobile/)
- [EPUB Accessibility 1.1](http://www.idpf.org/epub/a11y/accessibility-20170105.html)

### Testing Tools
- [Color Contrast Analyzer (app)](https://apps.apple.com/us/app/color-contrast-analyser-cca/id1111248497)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [Sim Daltonism (color blind simulator)](https://apps.apple.com/us/app/sim-daltonism/id693112260)

---

**Next Steps**: See `ACCESSIBILITY_IMPLEMENTATION_PLAN.md` for week-by-week execution plan.
