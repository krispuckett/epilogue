import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
class GoodreadsCleanImporter: ObservableObject {
    // MARK: - Simple Data Structures
    struct CSVBook {
        let title: String
        let author: String
        let isbn: String
        let isbn13: String
        let myRating: Int
        let dateRead: String
        let dateAdded: String
        let exclusiveShelf: String
        let privateNotes: String
        
        var primaryISBN: String? {
            if !isbn13.isEmpty { return isbn13 }
            if !isbn.isEmpty { return isbn }
            return nil
        }
        
        var readingStatus: ReadingStatus {
            switch exclusiveShelf.lowercased() {
            case "read":
                return .read
            case "currently-reading":
                return .currentlyReading
            default:
                return .wantToRead
            }
        }
    }
    
    struct ImportProgress {
        let current: Int
        let total: Int
        let currentBookTitle: String
        let phase: ImportPhase
        
        enum ImportPhase {
            case parsing
            case importing
            case complete
        }
    }
    
    // MARK: - Properties
    @Published var progress: ImportProgress?
    @Published var isImporting = false
    @Published var importedBooks: [Book] = []
    @Published var failedBooks: [(CSVBook, String)] = []
    
    private let googleBooksService = GoogleBooksService()
    private let enhancedService = EnhancedGoogleBooksService()
    private let bookAdditionService = BookAdditionService.shared
    
    // MARK: - Main Import Function
    func importCSV(from url: URL, libraryViewModel: LibraryViewModel) async {
        print("\n📚 Starting clean Goodreads import from: \(url.lastPathComponent)")
        isImporting = true
        importedBooks = []
        failedBooks = []
        
        // Parse CSV
        guard let csvBooks = parseCSV(from: url) else {
            print("❌ Failed to parse CSV")
            isImporting = false
            return
        }
        
        print("✅ Parsed \(csvBooks.count) books from CSV")
        
        // Import each book
        for (index, csvBook) in csvBooks.enumerated() {
            progress = ImportProgress(
                current: index + 1,
                total: csvBooks.count,
                currentBookTitle: csvBook.title,
                phase: .importing
            )
            
            print("\n[\(index + 1)/\(csvBooks.count)] Importing: \(csvBook.title)")
            
            // Search Google Books
            if var book = await searchGoogleBooks(for: csvBook) {
                // Add Goodreads data to the book
                var enrichedBook = book

                // Resolve canonical display cover URL before saving
                if let resolved = await DisplayCoverURLResolver.resolveDisplayURL(
                    googleID: book.id,
                    isbn: csvBook.primaryISBN,
                    thumbnailURL: book.coverImageURL
                ) {
                    enrichedBook.coverImageURL = resolved
                }
                
                enrichedBook.userRating = csvBook.myRating > 0 ? csvBook.myRating : nil
                enrichedBook.userNotes = csvBook.privateNotes.isEmpty ? nil : csvBook.privateNotes
                enrichedBook.readingStatus = csvBook.readingStatus
                
                // Parse and set dateAdded if available
                if let date = parseGoodreadsDate(csvBook.dateAdded) {
                    enrichedBook.dateAdded = date
                }
                
                print("  ✅ Found on Google Books: \(book.title)")
                print("  📖 Cover URL: \(book.coverImageURL ?? "NO COVER")")
                print("  🆔 Book LocalID: \(enrichedBook.localId.uuidString)")
                
                print("  ⭐ Rating: \(enrichedBook.userRating ?? 0)")
                print("  📝 Notes: \(enrichedBook.userNotes ?? "None")")
                print("  📚 Status: \(enrichedBook.readingStatus.rawValue)")
                
                // (Verbose debug removed)
                
                // Add to library using EXACT same method as manual addition
                await MainActor.run {
                    libraryViewModel.addBook(enrichedBook, overwriteIfExists: true)
                }
                
                // Add a small delay like a human would between selections
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // (Post-save debug removed)
                
                // (Post-addBook verbose check removed)
                
                importedBooks.append(enrichedBook)
                
                // Pre-load high-quality cover to match manual addition behavior (silent)
                if let coverURL = enrichedBook.coverImageURL {
                    _ = await SharedBookCoverManager.shared.loadFullImage(from: coverURL)
                }
                
                // Small delay to not overwhelm the API
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            } else {
                print("  ❌ Not found on Google Books")
                failedBooks.append((csvBook, "Not found on Google Books"))
            }
        }
        
        progress = ImportProgress(
            current: csvBooks.count,
            total: csvBooks.count,
            currentBookTitle: "Complete",
            phase: .complete
        )
        
        print("\n✅ Import complete!")
        print("  Imported: \(importedBooks.count)")
        print("  Failed: \(failedBooks.count)")
        
        isImporting = false
        
        // Don't post RefreshLibrary - let each book addition handle itself
        // Just like manual addition doesn't trigger a full refresh
    }
    
    // MARK: - CSV Parsing
    private func parseCSV(from url: URL) -> [CSVBook]? {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security scoped resource")
            return nil
        }
        
        // Ensure we stop accessing when done
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            let rows = data.components(separatedBy: .newlines)
            
            guard rows.count > 1 else { return nil }
            
            // Parse header to find column indices
            let headers = parseCSVRow(rows[0])
            guard let titleIndex = headers.firstIndex(of: "Title"),
                  let authorIndex = headers.firstIndex(of: "Author") else {
                print("❌ Required columns not found in CSV")
                return nil
            }
            
            // Optional columns
            let isbnIndex = headers.firstIndex(of: "ISBN")
            let isbn13Index = headers.firstIndex(of: "ISBN13")
            let ratingIndex = headers.firstIndex(of: "My Rating")
            let dateReadIndex = headers.firstIndex(of: "Date Read")
            let dateAddedIndex = headers.firstIndex(of: "Date Added")
            let shelfIndex = headers.firstIndex(of: "Exclusive Shelf")
            let notesIndex = headers.firstIndex(of: "Private Notes")
            
            var books: [CSVBook] = []
            
            // Parse each row
            for i in 1..<rows.count {
                let row = rows[i]
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                
                let columns = parseCSVRow(row)
                guard columns.count > authorIndex else { continue }
                
                let book = CSVBook(
                    title: cleanCSVValue(columns[titleIndex]),
                    author: cleanCSVValue(columns[authorIndex]),
                    isbn: isbnIndex != nil && columns.count > isbnIndex! ? cleanCSVValue(columns[isbnIndex!]) : "",
                    isbn13: isbn13Index != nil && columns.count > isbn13Index! ? cleanCSVValue(columns[isbn13Index!]) : "",
                    myRating: ratingIndex != nil && columns.count > ratingIndex! ? Int(cleanCSVValue(columns[ratingIndex!])) ?? 0 : 0,
                    dateRead: dateReadIndex != nil && columns.count > dateReadIndex! ? cleanCSVValue(columns[dateReadIndex!]) : "",
                    dateAdded: dateAddedIndex != nil && columns.count > dateAddedIndex! ? cleanCSVValue(columns[dateAddedIndex!]) : "",
                    exclusiveShelf: shelfIndex != nil && columns.count > shelfIndex! ? cleanCSVValue(columns[shelfIndex!]) : "to-read",
                    privateNotes: notesIndex != nil && columns.count > notesIndex! ? cleanCSVValue(columns[notesIndex!]) : ""
                )
                
                books.append(book)
            }
            
            return books
        } catch {
            print("❌ Error reading CSV: \(error)")
            return nil
        }
    }
    
    // Parse a CSV row handling quoted values
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var i = row.startIndex
        
        while i < row.endIndex {
            let char = row[i]
            
            if char == "\"" {
                if insideQuotes && i < row.index(before: row.endIndex) && row[row.index(after: i)] == "\"" {
                    // Escaped quote
                    currentColumn.append("\"")
                    i = row.index(after: i)
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // End of column
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
            
            i = row.index(after: i)
        }
        
        // Add last column
        columns.append(currentColumn)
        
        return columns
    }
    
    private func cleanCSVValue(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove surrounding quotes if present
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // Remove equals sign prefix (Excel formula protection)
        if cleaned.hasPrefix("=") {
            cleaned = String(cleaned.dropFirst())
        }
        
        // Unescape double quotes
        cleaned = cleaned.replacingOccurrences(of: "\"\"", with: "\"")
        
        return cleaned
    }
    
    // MARK: - Google Books Search
    private func searchGoogleBooks(for csvBook: CSVBook) async -> Book? {
        // 1) Try ISBN first via enhanced service
        if let isbn = csvBook.primaryISBN, !isbn.isEmpty {
            print("  🔍 Searching by ISBN: \(isbn)")
            if let byIsbn = await googleBooksService.searchBookByISBN(isbn) {
                if await isColorful(byIsbn) { return byIsbn }
                print("  ⚠️ ISBN result appears grayscale, trying ranked search…")
            }
        }

        // 2) Ranked search like manual add
        let searchQuery = "\(csvBook.title) by \(csvBook.author)"
        print("  🔍 Searching by title/author: \(searchQuery)")
        let results = await enhancedService.searchBooksWithRanking(query: searchQuery, preferISBN: csvBook.primaryISBN)
        if let picked = await pickBestNonGrayscale(from: results) ?? results.first {
            return picked
        }

        // 3) Open Library fallback for a cover if ISBN exists
        if let isbn = csvBook.primaryISBN {
            let stub = Book(id: UUID().uuidString,
                            title: csvBook.title,
                            author: csvBook.author,
                            publishedYear: nil,
                            coverImageURL: nil,
                            isbn: isbn,
                            description: nil,
                            pageCount: nil)
            if let fallbackURL = await BookCoverFallbackService.shared.getFallbackCoverURL(for: stub) {
                var book = stub
                book.coverImageURL = fallbackURL
                return book
            }
        }

        return nil
    }

    private func isColorful(_ book: Book) async -> Bool {
        guard let url = book.coverImageURL,
              let image = await SharedBookCoverManager.shared.loadThumbnail(from: url) else { return false }
        return !ImageQualityEvaluator.isLikelyGrayscale(image)
    }

    private func pickBestNonGrayscale(from results: [Book], maxCheck: Int = 5) async -> Book? {
        for (idx, book) in results.prefix(maxCheck).enumerated() {
            if await isColorful(book) {
                print("✅ Using result #\(idx + 1) with colorful cover: \(book.id)")
                return book
            } else {
                print("⚠️ Result #\(idx + 1) appears grayscale, trying next…")
            }
        }
        return nil
    }
    
    // MARK: - Date Parsing
    private func parseGoodreadsDate(_ dateString: String) -> Date? {
        if dateString.isEmpty { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different date formats Goodreads might use
        let formats = [
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}
