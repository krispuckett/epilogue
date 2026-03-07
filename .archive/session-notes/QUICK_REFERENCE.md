# Epilogue Book View Architecture - Quick Reference

## Core Data Models

### Book Struct (Display/API)
```swift
// Location: Models/GoogleBooksAPI.swift (lines 164-300)
struct Book: Identifiable, Codable {
    let id: String                  // Google Books ID
    let localId: UUID               // Local linking
    let title: String
    let author: String
    var coverImageURL: String?      // Mutable
    let pageCount: Int?
    
    var isInLibrary: Bool           // Default: false
    var readingStatus: ReadingStatus // wantToRead | currentlyReading | read
    var currentPage: Int
    var userRating: Double?         // Half-star ratings
    var dateAdded: Date
}
```

### BookModel (SwiftData/Enrichment)
```swift
// Location: Models/BookModel.swift (lines 1-166)
@Model
final class BookModel {
    var id: String                  // Google Books ID (same as Book)
    var title: String
    var author: String
    var coverImageURL: String?
    
    // Enrichment (AI-generated)
    var smartSynopsis: String?      // Spoiler-free summary
    var keyThemes: [String]?
    var seriesName: String?
    var seriesOrder: Int?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedNote.book)
    var notes: [CapturedNote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuote.book)
    var quotes: [CapturedQuote]?
}
```

## Display Components (Smallest to Largest)

### BookCard (Grid Item)
- **File**: Views/Library/BookCard.swift
- **Size**: 170x255 pt cover + text
- **Use**: Grid view (2 columns)
- **Features**: 
  - "Currently Reading" badge
  - Normalized author spacing
  - Accessible labels
  - Press animation (0.96x scale)

```swift
BookCard(book: book)
    .frame(width: 170, height: 255)
```

### LibraryBookListItem (List Row)
- **File**: Views/Library/LibraryView.swift (lines 1115-1357)
- **Size**: 60x90 thumbnail + details (104pt height)
- **Use**: List view (full width)
- **Features**:
  - Status pill (glass effect)
  - Progress bar for reading books
  - Context menu

### OptimizedLibraryGrid (Grid Container)
- **File**: Views/Library/OptimizedLibraryGrid.swift
- **Layout**: 2 columns, 16pt spacing, 32pt row spacing
- **Virtualization**: LazyVGrid for efficient rendering
- **Navigation**: NavigationLink to BookDetailView

### LibraryView (Main Container)
- **File**: Views/Library/LibraryView.swift (1-2479 lines)
- **Modes**: Grid (default) or List view
- **Filters**: All, Reading, Unread, Read
- **Features**:
  - View mode toggle (AppStorage)
  - Read filter picker
  - Reorder mode for grid
  - Pull-to-refresh
  - Book cover preloading

## Key Algorithms

### Filtering & Sorting
```swift
var filteredBooks: [Book] {
    var books = viewModel.books
    
    // Apply reading status filter
    switch readFilter {
    case .reading:
        books = books.filter { $0.readingStatus == .currentlyReading }
    // ... etc
    }
    
    // Sort: Currently reading first, then by dateAdded (newest)
    books.sort { book1, book2 in
        if book1.readingStatus == .currentlyReading && 
           book2.readingStatus != .currentlyReading {
            return true
        }
        return book1.dateAdded > book2.dateAdded
    }
    
    return books
}
```

### Book Addition (Unified)
```swift
func addBookUnified(_ book: Book, context: ModelContext) {
    // 1. Add to UserDefaults (legacy)
    viewModel.addBook(book)
    
    // 2. Add to SwiftData (modern) + enrich
    Task { @MainActor in
        let bookModel = BookModel(from: book)
        context.insert(bookModel)
        try context.save()
        await BookEnrichmentService.shared.enrichBook(bookModel)
    }
}
```

## Navigation Patterns

### Deep Link (Tap Book Card)
```swift
NavigationLink(destination: BookDetailView(book: book)) {
    BookCard(book: book)
}
```

### Sheet Navigation (Modals)
```swift
// Add new book
.sheet(isPresented: $appState.showingBookSearch) {
    BookSearchSheet(onBookSelected: { book in
        addBookUnified(book, context: modelContext)
    })
}

// Change cover
.sheet(isPresented: $showingCoverPicker) {
    BookSearchSheet(mode: .replace)
}

// Barcode scanner
.sheet(isPresented: $appState.showingEnhancedScanner) {
    PerfectBookScanner { book in
        addBookUnified(book, context: modelContext)
    }
}
```

### Notification-Based Navigation
```swift
// Navigate to book detail from elsewhere
NotificationCenter.default.post(
    name: Notification.Name("NavigateToBook"),
    object: book
)

// Show book search from elsewhere
NotificationCenter.default.post(
    name: Notification.Name("ShowBookSearch"),
    object: "optional query"
)
```

## Styling Constants

### Colors
```swift
Color(red: 0.98, green: 0.97, blue: 0.96)  // Warm white (#FAF8F5)
Color(red: 0.15, green: 0.145, blue: 0.14) // Dark charcoal (#262524)
DesignSystem.Colors.primaryAccent           // Warm amber (#FF8C42)
```

### Typography
```swift
// Title
.font(.system(size: 16, weight: .semibold, design: .serif))

// Author
.font(.system(size: 13, weight: .regular, design: .monospaced))
.kerning(0.8)

// List title
.font(.system(size: 17, weight: .semibold, design: .serif))

// List author
.font(.system(size: 14, design: .monospaced))
```

## File Locations Quick Map

```
📁 Models/
   └── GoogleBooksAPI.swift          Book struct, ReadingStatus enum
   └── BookModel.swift               SwiftData enrichment model
   └── ReadingSession.swift          Session tracking

📁 Views/Library/
   └── LibraryView.swift             Main container (2479 lines!)
   └── BookDetailView.swift          Detail view (lines 71+)
   └── BookCard.swift                Grid item (card)
   └── OptimizedLibraryGrid.swift    Grid container
   └── SharedBookCoverView.swift     Image loading logic
   └── EditBookSheet.swift           Replace book dialog
   └── BookSearchSheet.swift         Search dialog
   └── PerfectBookScanner.swift      Barcode scanner
   └── CleanGoodreadsImportView.swift Import dialog

📁 Services/
   └── GoogleBooksService.swift      API client
   └── BookEnrichmentService.swift   AI enrichment
   └── SharedBookCoverManager.swift  Image caching
```

## Common Tasks

### Add a Filter
1. Add case to `ReadFilter` enum (LibraryView.swift)
2. Update `filteredBooks` switch statement
3. Update toolbar filter picker

### Add Sorting Option
1. Update `filteredBooks` sorting logic
2. Add sort picker to toolbar menu
3. Save preference to @AppStorage

### Add Book Display Style
1. Create new view component (e.g., BookCompactCard)
2. Add view mode to enum
3. Update toolbar and main content
4. Handle navigation same way

### Modify Book Detail
1. Update BookDetailView.swift section tabs
2. Add query for related data (notes, quotes)
3. Update section view builder

## Performance Tips

- Use `LazyVGrid` for book lists (not ForEach directly)
- Preload neighbor covers: `preloadNeighboringCovers(for:)`
- Cache images: `SharedBookCoverManager` (max 30, 20MB)
- Async enrichment: `BookEnrichmentService.shared.enrichBook()`
- Background tasks: `Task(priority: .background) { ... }`

## Important Rules

1. **Don't modify .pbxproj** - Let Xcode handle it
2. **No .background() before .glassEffect()** - Breaks glass effects
3. **Two data models**: Book (display) + BookModel (enrichment)
4. **Dual persistence**: UserDefaults (legacy) + SwiftData (modern)
5. **Always update both** when adding/removing books

