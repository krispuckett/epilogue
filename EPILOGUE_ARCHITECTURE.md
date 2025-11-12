# Epilogue iOS App - Book View & Library Architecture Report

## EXECUTIVE SUMMARY

The Epilogue app manages a personal library of books with reading progress tracking and AI-powered discussions. The architecture uses SwiftUI with two main book data models, a filtering/sorting system, and card-based display with navigation to detailed views.

---

## 1. BOOK MODEL STRUCTURE

### 1.1 Primary Book Struct (Display/API Model)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Models/GoogleBooksAPI.swift` (Lines 164-300+)

```swift
struct Book: Identifiable, Codable, Equatable, Transferable {
    // Google Books API Integration
    let id: String                    // Google Books ID (primary identifier)
    let localId: UUID                 // Local UUID for linking to notes/sessions
    let title: String
    let author: String
    var authors: [String]             // Computed property: splits author by comma
    let publishedYear: String?
    var coverImageURL: String?        // Mutable, can be updated by user
    let isbn: String?
    let description: String?
    let pageCount: Int?
    
    // Reading Status & User Data
    var isInLibrary: Bool             // Default: false
    var readingStatus: ReadingStatus  // enum: wantToRead, currentlyReading, read
    var currentPage: Int              // Progress tracking
    var userRating: Double?           // Half-star ratings (1.0, 1.5, 2.0, etc.)
    var userNotes: String?
    var dateAdded: Date               // Timestamp when book was added to library
}

enum ReadingStatus: String, Codable, CaseIterable {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case read = "Read"
    
    var icon: String
    var displayName: String
    var color: Color
}
```

**Key Properties:**
- **id**: Unique Google Books identifier (required for API calls)
- **localId**: UUID for local relationships (links to quotes, notes, sessions)
- **coverImageURL**: Mutable property for user-selected cover changes
- **readingStatus**: Enum with 3 states (default: wantToRead)
- **currentPage**: Integer tracking current reading progress

### 1.2 SwiftData Model (BookModel)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Models/BookModel.swift` (Lines 1-166)

```swift
@Model
final class BookModel {
    var id: String                    // Google Books ID
    var localId: String               // UUID string for CloudKit compatibility
    var title: String
    var author: String
    var publishedYear: String?
    var coverImageURL: String?
    var isbn: String?
    var desc: String                  // 'description' is reserved keyword
    var pageCount: Int?
    
    @Attribute(.externalStorage)
    var coverImageData: Data?         // Offline cover image caching
    
    // Smart Enrichment (Spoiler-Free AI Context)
    var smartSynopsis: String?        // 2-3 sentences, NO spoilers
    var keyThemes: [String]?          // e.g., ["friendship", "courage"]
    var majorCharacters: [String]?    // Just names, no context
    var setting: String?              // Location/universe
    var tone: [String]?               // e.g., ["epic", "dark", "hopeful"]
    var literaryStyle: String?        // e.g., "High fantasy, allegorical"
    var enrichedAt: Date?             // When enrichment was fetched
    
    // Series Information
    var seriesName: String?           // e.g., "Harry Potter"
    var seriesOrder: Int?             // Book number in series
    var totalBooksInSeries: Int?
    
    // Color Extraction (for gradients)
    var extractedColors: [String]?    // Hex color strings
    
    // Reading Status (mirrors Book struct)
    var isInLibrary: Bool
    var readingStatus: String         // Stored as string (ReadingStatus.rawValue)
    var currentPage: Int
    var userRating: Double?           // Half-star ratings
    var userNotes: String?
    var dateAdded: Date
    
    // Relationships (Cascade Delete)
    @Relationship(deleteRule: .cascade, inverse: \CapturedNote.book)
    var notes: [CapturedNote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuote.book)
    var quotes: [CapturedQuote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuestion.book)
    var questions: [CapturedQuestion]?
    
    @Relationship(deleteRule: .cascade, inverse: \AmbientSession.bookModel)
    var sessions: [AmbientSession]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.bookModel)
    var readingSessions: [ReadingSession]?
    
    var isEnriched: Bool { smartSynopsis != nil }
}
```

**Purpose:**
- Primary persistence model using SwiftData
- Stores enriched metadata from BookEnrichmentService
- CloudKit synchronization (uses String for localId, default values)

### 1.3 SwiftData Model (Book - Legacy)
**Location:** `/Users/kris/Epilogue/Epilogue/Models/SwiftData/Book.swift` (Lines 1-83)

```swift
@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var isbn: String?
    var coverImageData: Data?
    var dateAdded: Date
    var lastOpened: Date?
    var readingProgress: Double       // 0.0 to 1.0 (normalized)
    var totalPages: Int?
    var currentPage: Int?
    var genre: String?
    var publicationYear: Int?
    var publisher: String?
    var bookDescription: String?
    var rating: Int?                  // 1-5 stars (LEGACY - replaced by userRating)
    
    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]?
    
    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]?
    
    @Relationship(deleteRule: .cascade, inverse: \AISession.book)
    var aiSessions: [AISession]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]?
    
    var progressPercentage: Int { Int(readingProgress * 100) }
}
```

**Status:** LEGACY model - BookModel is the current primary model

---

## 2. BOOK DISPLAY COMPONENTS

### 2.1 LibraryView (Main Container)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/LibraryView.swift` (1-2479 lines)

**Architecture:**
```
LibraryView (NavigationStack)
├── Ambient Gradient Background
├── Main Content (with refresh support)
│   ├── Skeleton Loading (while loading)
│   ├── Empty State (when books.isEmpty)
│   └── Books Display
│       ├── GridView (2 columns) - default
│       └── ListView (detailed rows)
├── Toolbar
│   ├── View Mode Picker (grid/list)
│   ├── Read Filter Picker
│   ├── Reorder Mode Toggle
│   └── Web Search
├── Sheets
│   ├── Cover Picker (BookSearchSheet)
│   ├── Book Search (add new)
│   ├── Scanner (PerfectBookScanner / EnhancedBookScannerView)
│   ├── Goodreads Import
│   └── Settings
└── Notifications (NavigateToBook, ShowBookSearch, etc.)
```

**View Modes:**
```swift
enum ViewMode: String {
    case grid  // 2-column layout, BookCard
    case list  // Full-width rows, LibraryBookListItem
}
```

**Read Filters:**
```swift
enum ReadFilter: String, CaseIterable {
    case all = "All Books"
    case reading = "Currently Reading"
    case unread = "Unread"
    case read = "Finished"
}
```

**Key Methods:**
- `filteredBooks` (computed): Applies filter + sorting (Currently Reading first, then by dateAdded)
- `addBookUnified(_:context:)`: Syncs UserDefaults (legacy) + SwiftData (modern)
- `refreshLibrary()`: Posts RefreshLibrary notification
- `preloadAllBookCovers()`: Async image preloading
- `updateBookCoverURLsToHigherQuality()`: Removes edge=curl, converts HTTP→HTTPS

### 2.2 BookCard (Grid View Item)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/BookCard.swift` (Lines 1-390)

```swift
struct BookCard: View {
    let book: Book
    @EnvironmentObject var viewModel: LibraryViewModel
    @State private var isPressed: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book Cover (170x255 or responsive)
            ZStack(alignment: .topTrailing) {
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 170,
                    height: 255,
                    loadFullImage: false,
                    isLibraryView: true
                )
                
                // "Currently Reading" Badge (animated bookmark)
                if book.readingStatus == .currentlyReading {
                    CurrentlyReadingBadge()
                        .padding(8)
                }
            }
            .shadow(radius: 12, y: 6)
            
            // Title & Author Section
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineLimit(2)
                
                Text(normalizeAuthorSpacing(book.author))
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(Color(...).opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
}
```

**Features:**
- 170x255 pt book cover image
- "Currently Reading" animated badge (bookmark icon)
- 2-line title with serif font (warm white: #FAF8F5)
- Normalized author spacing (J.R.R. instead of J. R. R.)
- Smooth scaling on press (0.96x)
- Accessibility support

### 2.3 LibraryBookListItem (List View Item)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/LibraryView.swift` (Lines 1115-1357)

```swift
struct LibraryBookListItem: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 0) {
            // Cover (60x90)
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 60,
                height: 90,
                loadFullImage: false,
                isLibraryView: true
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(radius: 4, y: 2)
            
            // Details Section
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)          // 17pt, semibold, serif
                Text(book.author)         // 14pt, monospaced
                
                Spacer()
                
                // Status Pill (glass effect)
                HStack(spacing: 4) {
                    Circle().fill(statusColor(for: book.readingStatus))
                        .frame(width: 5, height: 5)
                    Text(book.readingStatus.rawValue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial).opacity(0.8))
                
                // Progress Bar (if currently reading)
                if book.readingStatus == .currentlyReading {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(
                            LinearGradient(colors: [.green.opacity(0.8), .green], ...)
                        ).frame(width: geometry.size.width * progress)
                    }
                }
            }
        }
        .frame(height: 104)
        .background(RoundedRectangle(...).fill(Color.black.opacity(0.2)))
        .overlay(RoundedRectangle(...).strokeBorder(.white.opacity(0.10)))
    }
}
```

**Features:**
- 60x90 pt thumbnail cover
- 104pt fixed height
- Reading status pill with glass effect
- Progress bar for "Currently Reading" books
- Context menu (mark read, share, change cover, delete)

### 2.4 OptimizedLibraryGrid
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/OptimizedLibraryGrid.swift` (Lines 1-150+)

```swift
struct OptimizedLibraryGrid: View {
    let books: [Book]
    let viewModel: LibraryViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(Array(books.enumerated()), id: \.element.localId) { index, book in
                    OptimizedGridItem(book: book, ...)
                }
            }
        }
    }
}

struct OptimizedGridItem: View {
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book)) {
            BookCard(book: book)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
    }
}
```

**Features:**
- 2-column grid with 16pt spacing
- 32pt vertical spacing between rows
- LazyVGrid for virtualization (efficient rendering)
- Haptic feedback on tap
- Navigation to BookDetailView

### 2.5 SharedBookCoverView (Image Loading)
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/SharedBookCoverView.swift` (Lines 1-150+)

```swift
struct SharedBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    let loadFullImage: Bool
    let isLibraryView: Bool
    
    // In-memory cache
    private static let quickImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 20 * 1024 * 1024  // 20MB
        return cache
    }()
    
    var body: some View {
        // Handles:
        // 1. Quick cache lookup
        // 2. SharedBookCoverManager loading
        // 3. Fallback placeholder
        // 4. Progressive loading (thumbnail → full image)
    }
}
```

**URL Cleaning Rules:**
- Convert HTTP → HTTPS
- Preserve zoom parameters for Google Books URLs
- Remove &edge=curl parameter
- Clean double ampersands

---

## 3. BOOK DETAIL VIEW

### 3.1 BookDetailView Structure
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Views/Library/BookDetailView.swift` (Lines 71-200+)

```swift
struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    @State private var selectedSection: BookSection = .notes
    
    enum BookSection {
        case notes
        case quotes
        case questions
        case reading
    }
    
    var body: some View {
        // Header: Book Cover + Title/Author/Rating
        // Scroll Content:
        // ├── Smart Synopsis (enriched AI context)
        // ├── Metadata (year, pages, genre)
        // ├── Reading Progress
        // ├── Section Tabs (Notes/Quotes/Questions/Reading)
        // └── Section Content
        //     ├── CapturedNote List
        //     ├── CapturedQuote List
        //     ├── CapturedQuestion List
        //     └── ReadingSession List
    }
}
```

**Key States:**
- `selectedSection`: Tab navigation
- `scrollOffset`: Parallax gradient opacity
- `coverImage`: Cached book cover UIImage
- `colorPalette`: Extracted colors from cover
- `isExtractingColors`: Loading state

**Color System:**
- Fixed white text on dark background (Claude voice mode style)
- Dynamic accent color based on extracted book colors
- Fallback to amber if colors are unreadable

---

## 4. NAVIGATION & ROUTING

### 4.1 Navigation Flow
```
ContentView (Root)
└── LibraryView (NavigationStack)
    └── Book Tap
        └── NavigationLink → BookDetailView
```

### 4.2 Navigation Link Pattern
```swift
NavigationLink(
    destination: BookDetailView(book: book).environmentObject(viewModel)
) {
    BookCard(book: book)
        .environmentObject(viewModel)
}
.buttonStyle(PlainButtonStyle())
```

### 4.3 Sheet Navigation
```swift
LibraryView
├── .sheet(isPresented: $showingCoverPicker)
│   └── BookSearchSheet (for cover replacement)
├── .sheet(isPresented: $appState.showingBookSearch)
│   └── BookSearchSheet (to add new book)
├── .sheet(isPresented: $appState.showingEnhancedScanner)
│   └── PerfectBookScanner (barcode scanning)
├── .sheet(isPresented: $appState.showingGoodreadsImport)
│   └── CleanGoodreadsImportView
└── .sheet(isPresented: $showingWebSearch)
    └── WebSearchView
```

### 4.4 Notification-Based Navigation
```swift
// Navigate to book detail
NotificationCenter.default.post(name: Notification.Name("NavigateToBook"), object: book)

// Show book search with query
NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: "query string")

// Show scanner
NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"))

// Show Goodreads import
NotificationCenter.default.post(name: Notification.Name("ShowGoodreadsImport"))
```

---

## 5. BOOK ORGANIZATION & FILTERING

### 5.1 Reading Status Hierarchy
```swift
ReadingStatus
├── .wantToRead (default)
│   └── icon: "bookmark"
│   └── color: .blue
├── .currentlyReading
│   └── icon: "book"
│   └── color: .orange
│   └── Special: Displays progress bar, "Currently Reading" badge
└── .read
    └── icon: "checkmark.circle"
    └── color: .green
```

### 5.2 Filtering System (LibraryView)
**Location:** LibraryView.swift, Lines 45-90

```swift
enum ReadFilter: String, CaseIterable {
    case all = "All Books"
    case reading = "Currently Reading"
    case unread = "Unread"
    case read = "Finished"
}

var filteredBooks: [Book] {
    var books = viewModel.books
    
    // 1. Apply reading status filter
    switch readFilter {
    case .all: break
    case .reading: books = books.filter { $0.readingStatus == .currentlyReading }
    case .unread: books = books.filter { $0.readingStatus == .wantToRead }
    case .read: books = books.filter { $0.readingStatus == .read }
    }
    
    // 2. Sort: Currently reading first, then by dateAdded (newest first)
    books.sort { book1, book2 in
        if book1.readingStatus == .currentlyReading && book2.readingStatus != .currentlyReading {
            return true
        } else if book1.readingStatus != .currentlyReading && book2.readingStatus == .currentlyReading {
            return false
        }
        return book1.dateAdded > book2.dateAdded
    }
    
    return books
}
```

### 5.3 Sorting System
**Rules:**
1. Currently Reading books appear first (always)
2. Within each status: sort by dateAdded (most recent first)
3. No series grouping
4. No alphabetical sorting option

### 5.4 Book Matching System
**Location:** LibraryViewModel.swift, Lines 2254-2436

```swift
func findMatchingBook(title: String, author: String?) -> Book? {
    // Fuzzy matching using:
    // 1. Exact title match (score: 1.0)
    // 2. Acronym match (LOTR → Lord of the Rings)
    // 3. Series match (specialized for LOTR)
    // 4. Partial word matching
    // 5. Levenshtein distance for typos
    // 6. Author bonus (+0.2)
    // Returns best match if score > 0.6
}
```

**Features:**
- Case-insensitive
- Ignores common prefixes (the, a, an)
- Removes parenthetical content and colons
- Handles series indicators

---

## 6. DATA MANAGEMENT

### 6.1 Storage Architecture
```
LibraryViewModel (UserDefaults)
├── books: [Book]                    // JSON encoded, synced with UserDefaults
├── bookOrderKey: [String: ID]       // Custom reorder persistence
└── (Legacy - being replaced by SwiftData)

SwiftData (Modern)
├── BookModel (primary for enrichment)
├── CapturedNote
├── CapturedQuote
├── CapturedQuestion
├── AmbientSession
└── ReadingSession
```

### 6.2 Book Addition Flow
**Location:** LibraryView.swift, Lines 112-266

```swift
func addBookUnified(_ book: Book, context: ModelContext) {
    // 1. Add to UserDefaults (legacy display layer)
    viewModel.addBook(book)
    
    // 2. Create/update BookModel in SwiftData (modern)
    Task { @MainActor in
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate<BookModel> { $0.id == book.id }
        )
        
        if let existingModel = try context.fetch(descriptor).first {
            // Update existing (enrich if needed)
            if !existingModel.isEnriched {
                await BookEnrichmentService.shared.enrichBook(existingModel)
            }
        } else {
            // Create new
            let bookModel = BookModel(from: book)
            context.insert(bookModel)
            try context.save()
            await BookEnrichmentService.shared.enrichBook(bookModel)
        }
    }
}
```

### 6.3 Book Deletion
**Location:** LibraryViewModel.swift, Lines 2036-2104

```swift
func deleteBook(_ book: Book) {
    // 1. Remove from Spotlight index
    Task { await SpotlightIndexingService.shared.deindexBook(book.id) }
    
    // 2. Remove from array
    books.remove(at: index)
    
    // 3. Save to UserDefaults
    saveBooks()
    
    // 4. Force UI update
    objectWillChange.send()
    
    // 5. Reload to ensure consistency
}
```

### 6.4 Book Update Operations
```swift
// Update progress
updateBookProgress(_ book: Book, currentPage: Int)

// Update reading status
updateReadingStatus(for: String, status: ReadingStatus)

// Update cover
updateBookCover(_ book: Book, newCoverURL: String?)

// Replace book (preserve user data)
replaceBook(originalBook: Book, with: Book, preserveCover: Bool)
```

---

## 7. BOOK RELATIONSHIPS

### 7.1 Related Data Models
```
Book (Google Books display)
├── CapturedNote (many)
│   └── text: String, timestamp: Date
├── CapturedQuote (many)
│   └── text: String, page: Int?
├── CapturedQuestion (many)
│   └── question: String, answer: String?
├── AmbientSession (many)
│   ├── sessionType: String
│   └── AIMessage[] (chat history)
└── ReadingSession (many)
    ├── startDate: Date
    ├── endDate: Date?
    ├── startPage: Int
    ├── endPage: Int
    └── duration: TimeInterval
```

### 7.2 ReadingSession Model
**Location:** `/Users/kris/Epilogue/Epilogue/Epilogue/Models/ReadingSession.swift`

```swift
@Model
final class ReadingSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var startPage: Int
    var endPage: Int
    var pagesRead: Int
    var isAmbientSession: Bool
    var lastInteraction: Date
    
    var bookModel: BookModel?
    
    var formattedDuration: String       // "1:23:45"
    var readingSpeed: Double            // pages per minute
}
```

---

## 8. EXISTING PATTERNS & BEST PRACTICES

### 8.1 Book Display Pattern
Every book display follows this pattern:
1. **Cover Image**: SharedBookCoverView (width varies)
2. **Title**: Serif font, 2-line max, warm white
3. **Author**: Monospaced, normalized spacing
4. **Status Indicator**: For "Currently Reading" books

### 8.2 Color & Design
- **Background**: #1C1B1A (warm charcoal)
- **Text**: #FAF8F5 (warm white)
- **Accent**: Orange/Amber (#FF8C42) default
- **Highlight**: Blue, Green, Purple per status
- **Glass Effects**: Ultra-thin material with 0.1 opacity borders

### 8.3 State Management
- **EnvironmentObject**: LibraryViewModel (singleton, contains all books)
- **@Published**: books array triggers UI updates
- **@AppStorage**: viewMode, readFilter, gradientIntensity
- **Notifications**: For cross-view communication (NavigateToBook, ShowBookSearch, etc.)

### 8.4 Performance Optimizations
- **LazyVGrid**: Virtualized grid rendering
- **Preloading**: Neighbor covers loaded based on visible books
- **Cache**: QuickImageCache (30 images max, 20MB limit)
- **Async Tasks**: All network calls in background
- **Task(priority: .background)**: For non-critical operations

---

## 9. COMPONENT HIERARCHY

```
LibraryView
├── Navigation Stack wrapper
├── Ambient gradient background
├── Main content scroll view
│   ├── SkeletonLoading (while loading)
│   ├── EmptyState (no books)
│   └── Book display
│       ├── OptimizedLibraryGrid
│       │   └── ForEach books
│       │       └── OptimizedGridItem
│       │           └── NavigationLink
│       │               └── BookCard
│       │                   ├── SharedBookCoverView
│       │                   ├── CurrentlyReadingBadge
│       │                   ├── Title
│       │                   └── Author
│       └── LibraryBookListView
│           └── LazyVStack books
│               └── LibraryBookListRow
│                   ├── SharedBookCoverView
│                   ├── VStack details
│                   │   ├── Title
│                   │   ├── Author
│                   │   ├── Status pill
│                   │   └── Progress bar
│                   └── Context menu
├── Toolbar (view mode, filter, reorder)
└── Sheets
    ├── BookSearchSheet
    ├── PerfectBookScanner
    ├── CleanGoodreadsImportView
    └── SettingsView
```

---

## 10. KEY FILES REFERENCE

| Purpose | File Location | Lines |
|---------|--------------|-------|
| Main library display | `/Views/Library/LibraryView.swift` | 1-2479 |
| Book struct (API) | `/Models/GoogleBooksAPI.swift` | 164-300+ |
| BookModel (SwiftData) | `/Models/BookModel.swift` | 1-166 |
| Grid display | `/Views/Library/OptimizedLibraryGrid.swift` | 1-150+ |
| Card item | `/Views/Library/BookCard.swift` | 1-390 |
| Detail view | `/Views/Library/BookDetailView.swift` | 71-200+ |
| Image loading | `/Views/Library/SharedBookCoverView.swift` | 1-150+ |
| Reading status | `/Models/GoogleBooksAPI.swift` | 167-198 |
| Reading sessions | `/Models/ReadingSession.swift` | 1-76 |
| Library view model | `/Views/Library/LibraryView.swift` | 1659-2478 |

---

## 11. CURRENT LIMITATIONS

1. **No Series Grouping**: Books not organized by series
2. **No Shelf System**: Only reading status-based organization
3. **No Categories/Tags**: Beyond reading status
4. **No Search**: Filtering only, no text search in LibraryView
5. **No Custom Sorting**: Only by date added
6. **No Bulk Operations**: Can't multi-select books for actions
7. **No Reading Goals**: No target pages or deadlines
8. **No Social Features**: No sharing/reviews beyond basic share button

---

## 12. EXTENSION POINTS

### Easy Additions:
1. **Sort Options**: Add sort picker to toolbar
2. **Search**: Add text search field to filter books
3. **Favorites**: Add favorite flag and filter
4. **Custom Notes**: User-editable notes per book
5. **Reading Goals**: Page targets with progress

### Medium Complexity:
1. **Series Grouping**: Group by seriesName in display
2. **Smart Playlists**: Saved filter combinations
3. **Book Collections**: User-defined categories
4. **Export**: PDF export of library with metadata

### Complex:
1. **Advanced Search**: Full-text search across titles/authors/genres
2. **Recommendations**: AI-suggested books based on reading history
3. **Social Integration**: Goodreads integration (already exists!)
4. **Analytics**: Reading stats, favorite genres, etc.

