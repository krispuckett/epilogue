import Foundation
import SwiftData
import Combine
import UIKit
import os.log

// Service for importing Goodreads CSV exports
@MainActor
class GoodreadsImportService: ObservableObject {
    // Reduce console noise unless explicitly enabled
    private let verboseLogging = false
    
    // MARK: - Data Structures
    
    struct GoodreadsBook {
        let bookId: String
        let title: String
        let author: String
        let authorLF: String
        let additionalAuthors: String
        let isbn: String
        let isbn13: String
        let myRating: String
        let averageRating: String
        let publisher: String
        let binding: String
        let numberOfPages: String
        let yearPublished: String
        let originalPublicationYear: String
        let dateRead: String
        let dateAdded: String
        let bookshelves: String
        let bookshelvesWithPositions: String
        let exclusiveShelf: String
        let myReview: String
        let spoiler: String
        let privateNotes: String
        let readCount: String
        let ownedCopies: String
        
        var hasISBN: Bool {
            !isbn.isEmpty || !isbn13.isEmpty
        }
        
        var primaryISBN: String? {
            if !isbn13.isEmpty { return cleanISBN(isbn13) }
            if !isbn.isEmpty { return cleanISBN(isbn) }
            return nil
        }
        
        private func cleanISBN(_ isbn: String) -> String {
            isbn.replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    struct ImportResult {
        let successful: [ProcessedBook]
        let needsMatching: [UnmatchedBook]
        let duplicates: [DuplicateBook]
        let failed: [FailedBook]
        
        var totalProcessed: Int {
            successful.count + needsMatching.count + duplicates.count + failed.count
        }
        
        var successRate: Double {
            guard totalProcessed > 0 else { return 0 }
            return Double(successful.count) / Double(totalProcessed)
        }
    }
    
    class ProcessedBook {
        let goodreadsBook: GoodreadsBook
        var bookModel: BookModel
        let matchMethod: MatchMethod
        
        init(goodreadsBook: GoodreadsBook, bookModel: BookModel, matchMethod: MatchMethod) {
            self.goodreadsBook = goodreadsBook
            self.bookModel = bookModel
            self.matchMethod = matchMethod
        }
        
        enum MatchMethod {
            case isbn
            case titleAuthor
            case manual
        }
    }
    
    struct UnmatchedBook {
        let goodreadsBook: GoodreadsBook
        let searchAttempts: [String]
        let reason: String
    }
    
    struct DuplicateBook {
        let goodreadsBook: GoodreadsBook
        let existingBook: BookModel
    }
    
    struct FailedBook {
        let goodreadsBook: GoodreadsBook
        let error: Error
    }
    
    struct ImportProgress {
        let current: Int
        let total: Int
        let phase: ImportPhase
        let timeRemaining: TimeInterval?
        let currentBook: String?
        let batchNumber: Int
        let totalBatches: Int
        
        var percentComplete: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
        
        enum ImportPhase {
            case preparing
            case parsing
            case matching
            case saving
            case fetchingCovers
            case complete
            case paused
            case failed(String)
            
            var description: String {
                switch self {
                case .preparing: return "Preparing import..."
                case .parsing: return "Reading your Goodreads library..."
                case .matching: return "Finding books in Google Books..."
                case .saving: return "Adding books to your library..."
                case .fetchingCovers: return "Loading book covers..."
                case .complete: return "Import complete!"
                case .paused: return "Import paused"
                case .failed(let reason): return "Import failed: \(reason)"
                }
            }
            
            var icon: String {
                switch self {
                case .preparing: return "gear"
                case .parsing: return "doc.text"
                case .matching: return "magnifyingglass"
                case .saving: return "square.and.arrow.down"
                case .fetchingCovers: return "photo"
                case .complete: return "checkmark.circle.fill"
                case .paused: return "pause.circle"
                case .failed: return "exclamationmark.triangle"
                }
            }
        }
    }
    
    enum ImportSpeed: String, CaseIterable {
        case fast = "Fast"
        case balanced = "Balanced"
        case careful = "Careful"
        
        var batchSize: Int {
            switch self {
            case .fast: return 20
            case .balanced: return 10
            case .careful: return 5
            }
        }
        
        var delayBetweenBatches: TimeInterval {
            switch self {
            case .fast: return 0.5
            case .balanced: return 1.0
            case .careful: return 2.0
            }
        }
        
        var apiRequestDelay: TimeInterval {
            switch self {
            case .fast: return 0.1
            case .balanced: return 0.25
            case .careful: return 0.5
            }
        }
        
        var description: String {
            switch self {
            case .fast: return "Fast (may hit rate limits)"
            case .balanced: return "Balanced (recommended)"
            case .careful: return "Careful (slower but safer)"
            }
        }
    }
    
    struct BatchResult {
        let successful: [ProcessedBook]
        let needsMatching: [UnmatchedBook]
        let duplicates: [DuplicateBook]
        let failed: [FailedBook]
        let timeElapsed: TimeInterval
        let cacheHits: Int
        let apiCalls: Int
        
        static func empty() -> BatchResult {
            BatchResult(
                successful: [],
                needsMatching: [],
                duplicates: [],
                failed: [],
                timeElapsed: 0,
                cacheHits: 0,
                apiCalls: 0
            )
        }
        
        func merged(with other: BatchResult) -> BatchResult {
            BatchResult(
                successful: successful + other.successful,
                needsMatching: needsMatching + other.needsMatching,
                duplicates: duplicates + other.duplicates,
                failed: failed + other.failed,
                timeElapsed: max(timeElapsed, other.timeElapsed),
                cacheHits: cacheHits + other.cacheHits,
                apiCalls: apiCalls + other.apiCalls
            )
        }
    }
    
    struct CacheEntry {
        let book: GoogleBookItem
        let confidence: Double
        let timestamp: Date
    }
    
    // MARK: - Properties
    
    @Published private(set) var currentProgress: ImportProgress?
    @Published private(set) var isImporting = false
    @Published private(set) var isPaused = false
    
    private let googleBooksService: GoogleBooksService
    private let enhancedService: EnhancedGoogleBooksService
    private let modelContext: ModelContext
    
    private var importTask: Task<ImportResult, Error>?
    private var startTime: Date?
    private var processedCount = 0
    private var averageProcessingTime: TimeInterval = 0
    
    // Caching
    private var isbnCache: [String: GoogleBookItem] = [:]
    private var titleAuthorCache: [String: GoogleBookItem] = [:]
    private var existingBooksCache: Set<String> = []

    // Progressive import callback: emits each processed batch
    var onBatchProcessed: ((BatchResult, Int, Int) -> Void)? = nil

    // Cover selection stats for a run
    struct ImportCoverStats {
        var selectedGoogleColorful: Int = 0
        var grayscaleGoogleSkipped: Int = 0
        var openLibraryFallback: Int = 0
    }
    private var coverStats = ImportCoverStats()
    
    // MARK: - Initialization
    
    init(googleBooksService: GoogleBooksService, modelContext: ModelContext) {
        self.googleBooksService = googleBooksService
        self.enhancedService = EnhancedGoogleBooksService()
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Import CSV with optional async cover fetching
    func importCSV(from url: URL, speed: ImportSpeed = .balanced, fetchCoversAsync: Bool = true) async throws -> ImportResult {
        // Reset stats per run
        coverStats = ImportCoverStats()
        isImporting = true
        isPaused = false
        currentProgress = ImportProgress(
            current: 0,
            total: 0,
            phase: .preparing,
            timeRemaining: nil,
            currentBook: nil,
            batchNumber: 0,
            totalBatches: 0
        )
        
        startTime = Date()
        processedCount = 0
        
        do {
            // Load existing books for duplicate detection
            await loadExistingBooks()
            
            // Parse CSV
            let goodreadsBooks = try await parseCSV(from: url)
            let totalBooks = goodreadsBooks.count
            
            // Optimize for large libraries
            let optimizedSpeed = totalBooks > 500 ? .fast : speed
            let totalBatches = (totalBooks + optimizedSpeed.batchSize - 1) / optimizedSpeed.batchSize
            
            currentProgress = ImportProgress(
                current: 0,
                total: totalBooks,
                phase: .matching,
                timeRemaining: nil,
                currentBook: "Starting import...",
                batchNumber: 0,
                totalBatches: totalBatches
            )
            
            // Process books in optimized batches
            let result = try await processBooksInBatches(
                goodreadsBooks,
                speed: optimizedSpeed,
                totalBatches: totalBatches
            )
            
            // Save in batches with memory management
            currentProgress = ImportProgress(
                current: processedCount,
                total: totalBooks,
                phase: .saving,
                timeRemaining: nil,
                currentBook: "Saving to library...",
                batchNumber: totalBatches,
                totalBatches: totalBatches
            )
            
            try await saveBooksInBatches(result.successful)
            
            // Clean up caches for memory
            clearCaches()
            
            currentProgress = ImportProgress(
                current: totalBooks,
                total: totalBooks,
                phase: .complete,
                timeRemaining: 0,
                currentBook: "Import complete!",
                batchNumber: totalBatches,
                totalBatches: totalBatches
            )
            isImporting = false
            #if DEBUG
            print("\n📊 Cover Selection Stats:")
            print("  🎯 Google colorful: \(coverStats.selectedGoogleColorful)")
            print("  🚫 Google grayscale skipped: \(coverStats.grayscaleGoogleSkipped)")
            print("  🔄 Open Library fallback used: \(coverStats.openLibraryFallback)")
            #endif
            
            return result
            
        } catch {
            currentProgress = ImportProgress(
                current: processedCount,
                total: processedCount,
                phase: .failed(error.localizedDescription),
                timeRemaining: nil,
                currentBook: nil,
                batchNumber: 0,
                totalBatches: 0
            )
            isImporting = false
            clearCaches()
            throw error
        }
    }
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        isPaused = false
    }
    
    func cancel() {
        importTask?.cancel()
        isImporting = false
        isPaused = false
        currentProgress = nil
    }
    
    // MARK: - Private Methods
    
    private func processBooksInBatches(
        _ books: [GoodreadsBook],
        speed: ImportSpeed,
        totalBatches: Int
    ) async throws -> ImportResult {
        var combinedResult = ImportResult(
            successful: [],
            needsMatching: [],
            duplicates: [],
            failed: []
        )
        
        let batches = books.chunked(into: speed.batchSize)
        var totalCacheHits = 0
        var totalAPICalls = 0
        
        for (index, batch) in batches.enumerated() {
            // Check for pause
            while isPaused {
                currentProgress = ImportProgress(
                    current: processedCount,
                    total: books.count,
                    phase: .paused,
                    timeRemaining: nil,
                    currentBook: "Import paused",
                    batchNumber: index + 1,
                    totalBatches: totalBatches
                )
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // Update progress for batch
            currentProgress = ImportProgress(
                current: processedCount,
                total: books.count,
                phase: .matching,
                timeRemaining: calculateTimeRemaining(processedCount: processedCount, total: books.count),
                currentBook: "Processing batch \(index + 1) of \(totalBatches)",
                batchNumber: index + 1,
                totalBatches: totalBatches
            )
            
            // Process batch concurrently
            let batchStart = Date()
            let batchResult = try await processBatchConcurrently(
                batch,
                batchNumber: index + 1,
                totalBatches: totalBatches,
                speed: speed
            )
            
            // Update statistics
            totalCacheHits += batchResult.cacheHits
            totalAPICalls += batchResult.apiCalls
            
            // Merge results
            combinedResult = ImportResult(
                successful: combinedResult.successful + batchResult.successful,
                needsMatching: combinedResult.needsMatching + batchResult.needsMatching,
                duplicates: combinedResult.duplicates + batchResult.duplicates,
                failed: combinedResult.failed + batchResult.failed
            )

            // Emit progressive update to UI
            await MainActor.run {
                self.onBatchProcessed?(batchResult, index + 1, totalBatches)
            }
            
            processedCount += batch.count

            // Calculate batch time for adaptive delay
            let batchTime = Date().timeIntervalSince(batchStart)

            #if DEBUG
            // Log progress
            print("📚 Batch \(index + 1)/\(totalBatches): \(batch.count) books in \(String(format: "%.1f", batchTime))s")
            print("   Cache hits: \(batchResult.cacheHits), API calls: \(batchResult.apiCalls)")
            #endif

            // Adaptive delay between batches
            if index < batches.count - 1 {
                let delay = calculateAdaptiveDelay(
                    batchTime: batchTime,
                    baseDelay: speed.delayBetweenBatches,
                    cacheHitRate: Double(batchResult.cacheHits) / Double(batch.count)
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            // Memory cleanup every 10 batches for large imports
            if index > 0 && index % 10 == 0 && books.count > 500 {
                cleanupMemory()
            }
        }
        
        #if DEBUG
        print("✅ Import complete: \(totalCacheHits) cache hits, \(totalAPICalls) API calls")
        #endif
        return combinedResult
    }
    
    private func processBatchConcurrently(
        _ batch: [GoodreadsBook],
        batchNumber: Int,
        totalBatches: Int,
        speed: ImportSpeed
    ) async throws -> BatchResult {
        let batchStart = Date()
        var successful: [ProcessedBook] = []
        var needsMatching: [UnmatchedBook] = []
        var duplicates: [DuplicateBook] = []
        var failed: [FailedBook] = []
        var cacheHits = 0
        var apiCalls = 0
        
        // Adaptive concurrency window to reduce heat/usage
        let baseLimit = 6
        let thermal = ProcessInfo.processInfo.thermalState
        let limit: Int = (thermal == .serious || thermal == .critical) ? 3 : baseLimit
        var iterator = batch.makeIterator()

        await withTaskGroup(of: (GoodreadsBook, Result<(ProcessedBook?, Bool), Error>).self) { group in
            // Prime the group
            for _ in 0..<min(limit, batch.count) {
                if let b = iterator.next() {
                    group.addTask {
                        try? await Task.sleep(nanoseconds: UInt64(speed.apiRequestDelay * 1_000_000_000))
                        do {
                            let (result, fromCache) = try await self.matchBookWithCache(b)
                            return (b, .success((result, fromCache)))
                        } catch {
                            return (b, .failure(error))
                        }
                    }
                }
            }

            while let (book, result) = await group.next() {
                switch result {
                case .success(let (processedBook, fromCache)):
                    if fromCache {
                        cacheHits += 1
                    } else {
                        apiCalls += 1
                    }
                    
                    if let processed = processedBook {
                        successful.append(processed)
                    } else {
                        needsMatching.append(UnmatchedBook(
                            goodreadsBook: book,
                            searchAttempts: [book.primaryISBN ?? "", "\(book.title) \(book.author)"],
                            reason: "No matches found"
                        ))
                    }
                    
                case .failure(let error):
                    if let importError = error as? ImportError,
                       case .duplicateBook(let existing) = importError {
                        duplicates.append(DuplicateBook(
                            goodreadsBook: book,
                            existingBook: existing
                        ))
                    } else {
                        failed.append(FailedBook(
                            goodreadsBook: book,
                            error: error
                        ))
                    }
                }
                
                // Update progress for individual book
                await MainActor.run {
                    currentProgress = ImportProgress(
                        current: processedCount,
                        total: currentProgress?.total ?? 0,
                        phase: .matching,
                        timeRemaining: currentProgress?.timeRemaining,
                        currentBook: book.title,
                        batchNumber: batchNumber,
                        totalBatches: totalBatches
                    )
                }

                 // Feed next task to maintain window
                 if let next = iterator.next() {
                     group.addTask {
                         try? await Task.sleep(nanoseconds: UInt64(speed.apiRequestDelay * 1_000_000_000))
                         do {
                             let (result, fromCache) = try await self.matchBookWithCache(next)
                             return (next, .success((result, fromCache)))
                         } catch {
                             return (next, .failure(error))
                         }
                     }
                 }
            }
        }
        
        let timeElapsed = Date().timeIntervalSince(batchStart)
        return BatchResult(
            successful: successful,
            needsMatching: needsMatching,
            duplicates: duplicates,
            failed: failed,
            timeElapsed: timeElapsed,
            cacheHits: cacheHits,
            apiCalls: apiCalls
        )
    }
    
    private func calculateAdaptiveDelay(batchTime: TimeInterval, baseDelay: TimeInterval, cacheHitRate: Double) -> TimeInterval {
        // Reduce delay if we're getting lots of cache hits
        if cacheHitRate > 0.7 {
            return baseDelay * 0.5
        } else if cacheHitRate > 0.4 {
            return baseDelay * 0.75
        }
        
        // Increase delay if batch took too long (likely rate limiting)
        if batchTime > 10 {
            return baseDelay * 1.5
        }
        
        return baseDelay
    }
    
    private func calculateTimeRemaining(processedCount: Int, total: Int) -> TimeInterval? {
        guard let startTime = startTime, processedCount > 0 else { return nil }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let averageTimePerBook = elapsed / Double(processedCount)
        let remaining = Double(total - processedCount) * averageTimePerBook
        
        return remaining
    }
    
    private func cleanupMemory() {
        // Trim caches if they're getting too large
        if isbnCache.count > 500 {
            let keysToKeep = isbnCache.keys.sorted().prefix(300)
            var newCache: [String: GoogleBookItem] = [:]
            for key in keysToKeep {
                if let value = isbnCache[key] {
                    newCache[key] = value
                }
            }
            isbnCache = newCache
        }
        
        if titleAuthorCache.count > 500 {
            let keysToKeep = titleAuthorCache.keys.sorted().prefix(300)
            var newCache: [String: GoogleBookItem] = [:]
            for key in keysToKeep {
                if let value = titleAuthorCache[key] {
                    newCache[key] = value
                }
            }
            titleAuthorCache = newCache
        }
    }
    
    // MARK: - Private Methods
    
    // MARK: - CSV Parsing
    
    private func parseCSV(from url: URL) async throws -> [GoodreadsBook] {
        currentProgress = ImportProgress(
            current: 0,
            total: 0,
            phase: .parsing,
            timeRemaining: nil,
            currentBook: "Reading CSV file...",
            batchNumber: 0,
            totalBatches: 0
        )
        
        // Read file with UTF-8 encoding, fallback to Latin-1 if needed
        let csvContent: String
        do {
            csvContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Try Latin-1 encoding as fallback for older exports
            csvContent = try String(contentsOf: url, encoding: .isoLatin1)
        }
        
        // Split into lines, handling both Unix and Windows line endings
        let lines = csvContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            throw ImportError.emptyCSV
        }
        
        // Parse headers and create case-insensitive column map
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)
        let columnMap = createColumnMap(from: headers)
        
        #if DEBUG
        print("📚 Found \(headers.count) columns in CSV")
        print("📚 Processing \(lines.count - 1) rows")
        #endif
        
        var books: [GoodreadsBook] = []
        var skippedRows = 0
        
        // Parse each row
        for (index, line) in lines.dropFirst().enumerated() {
            // Skip empty lines
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            if let book = parseGoodreadsRow(from: line, columnMap: columnMap) {
                books.append(book)
            } else {
                skippedRows += 1
                #if DEBUG
                print("⚠️ Skipped invalid row \(index + 1)")
                #endif
            }
            
            // Update progress every 25 rows
            if index % 25 == 0 {
                let progress = index + 1
                currentProgress = ImportProgress(
                    current: progress,
                    total: lines.count - 1,
                    phase: .parsing,
                    timeRemaining: nil,
                    currentBook: "Parsing row \(progress) of \(lines.count - 1)",
                    batchNumber: 0,
                    totalBatches: 0
                )
            }
        }
        
        #if DEBUG
        print("✅ Parsed \(books.count) books, skipped \(skippedRows) invalid rows")
        #endif
        return books
    }
    
    private func createColumnMap(from headers: [String]) -> [String: Int] {
        var columnMap: [String: Int] = [:]
        
        // Create case-insensitive mapping with variations
        for (index, header) in headers.enumerated() {
            let cleanHeader = header.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Store exact match
            columnMap[cleanHeader] = index
            
            // Store lowercase version
            columnMap[cleanHeader.lowercased()] = index
            
            // Handle common variations
            let variations = getHeaderVariations(for: cleanHeader)
            for variation in variations {
                columnMap[variation] = index
            }
        }
        
        return columnMap
    }
    
    private func getHeaderVariations(for header: String) -> [String] {
        // Map common header variations
        let variations: [String: [String]] = [
            "Book Id": ["BookId", "book_id", "id"],
            "Title": ["Book Title", "book_title", "name"],
            "Author": ["Authors", "Primary Author", "author_name"],
            "Author l-f": ["Author (Last, First)", "author_lf"],
            "ISBN": ["isbn10", "ISBN-10"],
            "ISBN13": ["isbn-13", "isbn_13"],
            "My Rating": ["Rating", "User Rating", "my_rating"],
            "Average Rating": ["Avg Rating", "average_rating"],
            "Number of Pages": ["Page Count", "Pages", "num_pages"],
            "Year Published": ["Publication Year", "Pub Year", "year"],
            "Date Read": ["Read Date", "date_read", "finished"],
            "Date Added": ["Added", "date_added"],
            "Exclusive Shelf": ["Shelf", "exclusive_shelf"],
            "Private Notes": ["Notes", "My Notes", "private_notes"]
        ]
        
        return variations[header] ?? []
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var escapeNext = false
        
        for char in line {
            if escapeNext {
                current.append(char)
                escapeNext = false
                continue
            }
            
            switch char {
            case "\\":
                // Handle escaped characters
                escapeNext = true
                
            case "\"":
                if inQuotes {
                    // Check if this is an escaped quote (doubled)
                    let nextIndex = line.index(after: line.firstIndex(of: char)!)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        current.append("\"")
                        escapeNext = true
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
                
            case ",":
                if !inQuotes {
                    result.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
                
            default:
                current.append(char)
            }
        }
        
        // Add the last field
        result.append(current)
        
        // Clean all values
        return result.map { cleanCSVValue($0) }
    }
    
    private func cleanCSVValue(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle Excel formula format ="value" or =("value")
        if cleaned.hasPrefix("=\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst(2).dropLast(1))
        } else if cleaned.hasPrefix("=(\"") && cleaned.hasSuffix("\")") {
            cleaned = String(cleaned.dropFirst(3).dropLast(2))
        } else if cleaned.hasPrefix("='") && cleaned.hasSuffix("'") {
            cleaned = String(cleaned.dropFirst(2).dropLast(1))
        }
        
        // Remove surrounding quotes
        while cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 1 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // Replace doubled quotes with single quotes
        cleaned = cleaned.replacingOccurrences(of: "\"\"", with: "\"")
        
        // Clean up common Excel artifacts
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        
        // Trim again after all replacements
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func parseGoodreadsRow(from line: String, columnMap: [String: Int]) -> GoodreadsBook? {
        let values = parseCSVLine(line)
        
        // Helper to safely get value by column name
        func getValue(for keys: [String]) -> String {
            for key in keys {
                if let index = columnMap[key], index < values.count {
                    return values[index]
                }
            }
            return ""
        }
        
        // Extract all fields with fallbacks
        let bookId = getValue(for: ["Book Id", "BookId", "book_id", "id"])
        let title = getValue(for: ["Title", "Book Title", "book_title", "name"])
        
        // Skip rows without a title
        guard !title.isEmpty else { return nil }
        
        let author = getValue(for: ["Author", "Authors", "Primary Author", "author_name"])
        let authorLF = getValue(for: ["Author l-f", "Author (Last, First)", "author_lf"])
        let additionalAuthors = getValue(for: ["Additional Authors", "Other Authors", "additional_authors"])
        
        // ISBNs - clean any formatting including Excel formulas
        let isbn = cleanCSVValue(getValue(for: ["ISBN", "isbn10", "ISBN-10", "isbn"]))
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        let isbn13 = cleanCSVValue(getValue(for: ["ISBN13", "isbn-13", "isbn_13"]))
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        // Ratings
        let myRating = getValue(for: ["My Rating", "Rating", "User Rating", "my_rating"])
        let averageRating = getValue(for: ["Average Rating", "Avg Rating", "average_rating"])
        
        // Publication info
        let publisher = getValue(for: ["Publisher", "publisher"])
        let binding = getValue(for: ["Binding", "Format", "binding"])
        let numberOfPages = getValue(for: ["Number of Pages", "Page Count", "Pages", "num_pages"])
        let yearPublished = getValue(for: ["Year Published", "Publication Year", "Pub Year", "year"])
        let originalYear = getValue(for: ["Original Publication Year", "Original Year", "original_publication_year"])
        
        // Dates - will be parsed later
        let dateRead = getValue(for: ["Date Read", "Read Date", "date_read", "finished"])
        let dateAdded = getValue(for: ["Date Added", "Added", "date_added"])
        
        // Shelves
        let bookshelves = getValue(for: ["Bookshelves", "Shelves", "bookshelves"])
        let bookshelvesWithPos = getValue(for: ["Bookshelves with positions", "bookshelves_with_positions"])
        let exclusiveShelf = getValue(for: ["Exclusive Shelf", "Shelf", "exclusive_shelf"])
        
        // User content
        let myReview = getValue(for: ["My Review", "Review", "my_review"])
        let spoiler = getValue(for: ["Spoiler", "spoiler"])
        let privateNotes = getValue(for: ["Private Notes", "Notes", "My Notes", "private_notes"])
        
        // Reading stats
        let readCount = getValue(for: ["Read Count", "Times Read", "read_count"])
        let ownedCopies = getValue(for: ["Owned Copies", "Copies Owned", "owned_copies"])
        
        return GoodreadsBook(
            bookId: bookId,
            title: title,
            author: author.isEmpty ? authorLF : author,  // Fallback to author l-f if author is empty
            authorLF: authorLF,
            additionalAuthors: additionalAuthors,
            isbn: isbn,
            isbn13: isbn13,
            myRating: myRating,
            averageRating: averageRating,
            publisher: publisher,
            binding: binding,
            numberOfPages: numberOfPages,
            yearPublished: yearPublished,
            originalPublicationYear: originalYear,
            dateRead: dateRead,
            dateAdded: dateAdded,
            bookshelves: bookshelves,
            bookshelvesWithPositions: bookshelvesWithPos,
            exclusiveShelf: exclusiveShelf,
            myReview: myReview,
            spoiler: spoiler,
            privateNotes: privateNotes,
            readCount: readCount,
            ownedCopies: ownedCopies
        )
    }
    
    private func processBatch(
        _ books: [GoodreadsBook],
        batchNumber: Int,
        totalBatches: Int,
        speed: ImportSpeed
    ) async throws -> BatchResult {
        let batchStart = Date()
        var successful: [ProcessedBook] = []
        var needsMatching: [UnmatchedBook] = []
        var duplicates: [DuplicateBook] = []
        var failed: [FailedBook] = []
        
        await withTaskGroup(of: (GoodreadsBook, Result<ProcessedBook?, Error>).self) { group in
            for book in books {
                group.addTask {
                    // Update progress
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.currentProgress = ImportProgress(
                            current: self.processedCount,
                            total: self.currentProgress?.total ?? 0,
                            phase: .matching,
                            timeRemaining: self.currentProgress?.timeRemaining,
                            currentBook: book.title,
                            batchNumber: batchNumber,
                            totalBatches: totalBatches
                        )
                    }
                    
                    // Add delay between API requests
                    try? await Task.sleep(nanoseconds: UInt64(speed.apiRequestDelay * 1_000_000_000))
                    
                    do {
                        let googleBooksService = await MainActor.run { self.googleBooksService }
                        let result = try await self.matchBook(book, googleBooksService: googleBooksService)
                        return (book, .success(result))
                    } catch {
                        return (book, .failure(error))
                    }
                }
            }
            
            for await (book, result) in group {
                switch result {
                case .success(let processedBook):
                    if let processed = processedBook {
                        successful.append(processed)
                    } else {
                        needsMatching.append(UnmatchedBook(
                            goodreadsBook: book,
                            searchAttempts: [book.primaryISBN ?? "", "\(book.title) \(book.author)"],
                            reason: "No matches found"
                        ))
                    }
                case .failure(let error):
                    if let importError = error as? ImportError,
                       case .duplicateBook(let existing) = importError {
                        duplicates.append(DuplicateBook(
                            goodreadsBook: book,
                            existingBook: existing
                        ))
                    } else {
                        failed.append(FailedBook(
                            goodreadsBook: book,
                            error: error
                        ))
                    }
                }
            }
        }
        
        let timeElapsed = Date().timeIntervalSince(batchStart)
        return BatchResult(
            successful: successful,
            needsMatching: needsMatching,
            duplicates: duplicates,
            failed: failed,
            timeElapsed: timeElapsed,
            cacheHits: 0,  // This old method doesn't track cache hits
            apiCalls: successful.count + needsMatching.count  // Approximate API calls
        )
    }
    
    private func matchBook(_ goodreadsBook: GoodreadsBook, googleBooksService: GoogleBooksService) async throws -> ProcessedBook? {
        // Check for duplicates
        if let existing = try await checkForDuplicate(goodreadsBook) {
            throw ImportError.duplicateBook(existing)
        }
        
        // Try ISBN match first (most reliable)
        if let isbn = goodreadsBook.primaryISBN {
            // If the raw ISBN item is not English, skip straight to ranked English search
            if let rawItem = await enhancedService.fetchRawByISBN(isbn),
               let lang = rawItem.volumeInfo.language, lang.lowercased() != "en" {
                // Bypass ISBN path for non-English editions
            } else {
            if let cachedBook = isbnCache[isbn] {
                let bookModel = await createBookModel(from: cachedBook, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .isbn
                )
            }
            
            // Use enhanced service for better matching with cover priority
            if let initialBook = await enhancedService.findBestMatch(
                title: goodreadsBook.title,
                author: goodreadsBook.author,
                isbn: isbn,
                publishedYear: String(goodreadsBook.yearPublished),
                preferredPublisher: goodreadsBook.publisher
            ) {
                // Color gate: if initial pick is grayscale, try alternates via ranked search
                let book: Book
                if await isBookCoverGrayscale(initialBook) {
                    coverStats.grayscaleGoogleSkipped += 1
                    let alternates = await enhancedService.searchBooksWithRanking(
                        query: "\(goodreadsBook.title) by \(goodreadsBook.author)",
                        preferISBN: isbn
                    )
                    if let nonGray = await pickBestNonGrayscale(from: alternates) {
                        coverStats.selectedGoogleColorful += 1
                        book = nonGray
                    } else {
                        // Try Open Library cover fallback before giving up
                        if let fallbackURL = await BookCoverFallbackService.shared.getFallbackCoverURL(for: initialBook) {
                            var patched = initialBook
                            patched.coverImageURL = fallbackURL
                            coverStats.openLibraryFallback += 1
                            book = patched
                        } else {
                            book = initialBook
                        }
                    }
                } else {
                    coverStats.selectedGoogleColorful += 1
                    book = initialBook
                }
                // Convert Book to GoogleBookItem structure  
                let bookItem = GoogleBookItem(
                    id: book.id,
                    volumeInfo: VolumeInfo(
                        title: book.title,
                        authors: book.authors,
                        publishedDate: book.publishedYear,
                        description: book.description,
                        pageCount: book.pageCount,
                        imageLinks: book.coverImageURL != nil ? ImageLinks(
                            thumbnail: book.coverImageURL,
                            small: nil,
                            medium: nil,
                            large: nil,
                            extraLarge: nil
                        ) : nil,
                        industryIdentifiers: book.isbn != nil ? [IndustryIdentifier(type: "ISBN", identifier: book.isbn!)] : nil
                    )
                )
                
                isbnCache[isbn] = bookItem
                let bookModel = await createBookModel(from: bookItem, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .isbn
                )
            }
            }
        }
        
        // Try title/author match as fallback
        let searchKey = "\(goodreadsBook.title) \(goodreadsBook.author)"
        
        if let cachedBook = titleAuthorCache[searchKey] {
            let bookModel = await createBookModel(from: cachedBook, goodreadsBook: goodreadsBook)
            return ProcessedBook(
                goodreadsBook: goodreadsBook,
                bookModel: bookModel,
                matchMethod: .titleAuthor
            )
        }
        
        // Use enhanced service with better query parsing
        let searchQuery = "\(goodreadsBook.title) by \(goodreadsBook.author)"
        #if DEBUG
        print("🔍 Searching Google Books for: \(searchQuery)")
        #endif
        let results = await enhancedService.searchBooksWithRanking(query: searchQuery, preferISBN: nil, publisherHint: goodreadsBook.publisher)
        #if DEBUG
        print("   Found \(results.count) results")
        #endif
        
        // Pick the first non-grayscale cover among top results
        if let book = await pickBestNonGrayscale(from: results) ?? results.first {
            if await isBookCoverGrayscale(book) {
                // If first is grayscale but pickBestNonGrayscale returned nil, count skip implicitly later
            } else {
                coverStats.selectedGoogleColorful += 1
            }
            // Convert Book to GoogleBookItem
            let bookItem = GoogleBookItem(
                id: book.id,
                volumeInfo: VolumeInfo(
                    title: book.title,
                    authors: book.authors,
                    publishedDate: book.publishedYear,
                    description: book.description,
                    pageCount: book.pageCount,
                    imageLinks: book.coverImageURL != nil ? ImageLinks(
                        thumbnail: book.coverImageURL,
                        small: nil,
                        medium: nil,
                        large: nil,
                        extraLarge: nil
                    ) : nil,
                    industryIdentifiers: book.isbn != nil ? [IndustryIdentifier(type: "ISBN", identifier: book.isbn!)] : nil
                )
            )
            
            // Verify it's a good match
            if isGoodMatch(googleBook: bookItem, goodreadsBook: goodreadsBook) {
                titleAuthorCache[searchKey] = bookItem
                let bookModel = await createBookModel(from: bookItem, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .titleAuthor
                )
            }
        }
        
        // As a last resort, try Open Library for a cover if we have at least a basic Book
        if let isbn = goodreadsBook.primaryISBN {
            // Use minimal book stub for fallback cover
            let stub = Book(id: UUID().uuidString,
                            title: goodreadsBook.title,
                            author: goodreadsBook.author,
                            publishedYear: goodreadsBook.yearPublished.isEmpty ? nil : goodreadsBook.yearPublished,
                            coverImageURL: nil,
                            isbn: isbn,
                            description: nil,
                            pageCount: nil)
            if let fallbackURL = await BookCoverFallbackService.shared.getFallbackCoverURL(for: stub) {
                coverStats.openLibraryFallback += 1
                let bookItem = GoogleBookItem(
                    id: stub.id,
                    volumeInfo: VolumeInfo(
                        title: stub.title,
                        authors: [stub.author],
                        publishedDate: stub.publishedYear,
                        description: nil,
                        pageCount: nil,
                        imageLinks: ImageLinks(
                            thumbnail: fallbackURL,
                            small: nil,
                            medium: nil,
                            large: nil,
                            extraLarge: nil
                        ),
                        industryIdentifiers: [IndustryIdentifier(type: "ISBN", identifier: isbn)]
                    )
                )
                let bookModel = await createBookModel(from: bookItem, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .titleAuthor
                )
            }
        }
        
        return nil
    }

    // MARK: - Color Gate Helpers
    private func isBookCoverGrayscale(_ book: Book) async -> Bool {
        guard let url = book.coverImageURL,
              let image = await SharedBookCoverManager.shared.loadThumbnail(from: url) else {
            return false
        }
        return ImageQualityEvaluator.isLikelyGrayscale(image)
    }

    private func pickBestNonGrayscale(from books: [Book], maxCheck: Int = 5) async -> Book? {
        for (idx, candidate) in books.prefix(maxCheck).enumerated() {
            if candidate.coverImageURL == nil { continue }
            if let url = candidate.coverImageURL,
               let image = await SharedBookCoverManager.shared.loadThumbnail(from: url) {
                if !ImageQualityEvaluator.isLikelyGrayscale(image) {
                    #if DEBUG
                    print("✅ Using result #\(idx + 1) with colorful cover: \(candidate.id)")
                    #endif
                    return candidate
                } else {
                    #if DEBUG
                    print("⚠️ Result #\(idx + 1) appears grayscale, trying next…")
                    #endif
                }
            }
        }
        return nil
    }
    
    private func isGoodMatch(googleBook: GoogleBookItem, goodreadsBook: GoodreadsBook) -> Bool {
        let titleSimilarity = calculateSimilarity(
            googleBook.volumeInfo.title.lowercased(),
            goodreadsBook.title.lowercased()
        )
        
        let authorMatch = googleBook.volumeInfo.authors?.contains { author in
            author.lowercased().contains(goodreadsBook.author.lowercased()) ||
            goodreadsBook.author.lowercased().contains(author.lowercased())
        } ?? false
        
        return titleSimilarity > 0.8 && authorMatch
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        guard !longer.isEmpty else { return 1.0 }
        
        let editDistance = levenshteinDistance(shorter, longer)
        return Double(longer.count - editDistance) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        var matrix = Array(repeating: Array(repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    private func createBookModel(from googleBook: GoogleBookItem, goodreadsBook: GoodreadsBook) async -> BookModel {
        let volumeInfo = googleBook.volumeInfo
        
        // Get the cover URL from imageLinks with preference for higher quality
        // IMPORTANT: Prefer thumbnail first as it's most reliable from Google Books API
        var coverURL: String?
        if let thumbnail = volumeInfo.imageLinks?.thumbnail {
            // Thumbnail is the most reliable and always present
            coverURL = thumbnail
            #if DEBUG
            print("   ✅ Using thumbnail URL: \(thumbnail)")
            #endif
        } else if let small = volumeInfo.imageLinks?.small {
            coverURL = small
            #if DEBUG
            print("   ✅ Using small URL: \(small)")
            #endif
        } else if let medium = volumeInfo.imageLinks?.medium {
            coverURL = medium
            #if DEBUG
            print("   ✅ Using medium URL: \(medium)")
            #endif
        } else if let large = volumeInfo.imageLinks?.large {
            coverURL = large
            #if DEBUG
            print("   ✅ Using large URL: \(large)")
            #endif
        } else if let extraLarge = volumeInfo.imageLinks?.extraLarge {
            coverURL = extraLarge
            #if DEBUG
            print("   ✅ Using extraLarge URL: \(extraLarge)")
            #endif
        } else {
            #if DEBUG
            print("   ⚠️ No image URLs found in volumeInfo.imageLinks")
            #endif
        }
        
        // Ensure HTTPS for all URLs
        if let url = coverURL, url.starts(with: "http://") {
            coverURL = url.replacingOccurrences(of: "http://", with: "https://")
            #if DEBUG
            print("   🔒 Converted to HTTPS: \(coverURL!)")
            #endif
        }
        
        if verboseLogging {
            print("📚 Creating BookModel for: \(volumeInfo.title)")
            print("   Google Books ID: \(googleBook.id)")
            print("   ImageLinks: \(volumeInfo.imageLinks != nil ? "Present" : "Nil")")
            if let links = volumeInfo.imageLinks {
                print("   - thumbnail: \(links.thumbnail ?? "nil")")
                print("   - small: \(links.small ?? "nil")")
                print("   - medium: \(links.medium ?? "nil")")
                print("   - large: \(links.large ?? "nil")")
                print("   - extraLarge: \(links.extraLarge ?? "nil")")
            }
            print("   Final coverURL: \(coverURL ?? "nil")")
            print("   BookModel.id will be set to: \(googleBook.id)")
            print("   BookModel.coverImageURL will be set to: \(coverURL ?? "nil")")
        }
        
        // Resolve canonical display URL before creating the model
        let resolved = await DisplayCoverURLResolver.resolveDisplayURL(
            googleID: googleBook.id,
            isbn: goodreadsBook.primaryISBN,
            thumbnailURL: coverURL
        )

        let book = BookModel(
            id: googleBook.id,
            title: volumeInfo.title,
            author: volumeInfo.authors?.joined(separator: ", ") ?? goodreadsBook.author,
            publishedYear: volumeInfo.publishedDate,
            coverImageURL: resolved ?? coverURL,  // Use resolved URL if available
            isbn: goodreadsBook.primaryISBN ?? volumeInfo.industryIdentifiers?.first { $0.type.contains("ISBN") }?.identifier,
            description: volumeInfo.description,
            pageCount: Int(goodreadsBook.numberOfPages) ?? volumeInfo.pageCount
        )
        
        // Parse Goodreads-specific data
        if let rating = Int(goodreadsBook.myRating), rating > 0 {
            book.userRating = rating
        }
        
        // Notes: prefer Private Notes, otherwise use My Review; if both exist, merge
        let trimmedPrivate = goodreadsBook.privateNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReview = goodreadsBook.myReview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrivate.isEmpty && !trimmedReview.isEmpty {
            book.userNotes = "\(trimmedPrivate)\n\nReview:\n\(trimmedReview)"
        } else if !trimmedPrivate.isEmpty {
            book.userNotes = trimmedPrivate
        } else if !trimmedReview.isEmpty {
            book.userNotes = trimmedReview
        }
        
        // Set reading status based on exclusive shelf
        if goodreadsBook.exclusiveShelf == "read" || !goodreadsBook.dateRead.isEmpty {
            book.readingStatus = "Read"
        } else if goodreadsBook.exclusiveShelf == "currently-reading" {
            book.readingStatus = "Currently Reading"
        } else if goodreadsBook.exclusiveShelf == "to-read" {
            book.readingStatus = "Want to Read"
        }
        
        // Set the book as in library since we're importing it
        book.isInLibrary = true
        
        return book
    }
    
    private func parseGoodreadsDate(_ dateString: String) -> Date? {
        // Clean the date string
        let cleaned = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        // Common date formats from Goodreads exports
        let dateFormats = [
            "yyyy/MM/dd",           // 2023/12/25
            "yyyy-MM-dd",           // 2023-12-25
            "MM/dd/yyyy",           // 12/25/2023
            "dd/MM/yyyy",           // 25/12/2023
            "yyyy/MM/dd HH:mm:ss",  // 2023/12/25 14:30:00
            "MM/dd/yy",             // 12/25/23
            "dd/MM/yy",             // 25/12/23
            "MMM dd, yyyy",         // Dec 25, 2023
            "dd MMM yyyy",          // 25 Dec 2023
            "MMMM dd, yyyy",        // December 25, 2023
            "yyyy",                 // Just year
            "MM/yyyy",              // Month/Year
            "yyyy/MM"               // Year/Month
        ]
        
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        
        // Try ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: cleaned) {
            return date
        }
        
        // Handle relative dates like "3 days ago"
        if cleaned.contains("ago") {
            return parseRelativeDate(cleaned)
        }
        
        return nil
    }
    
    private func parseRelativeDate(_ dateString: String) -> Date? {
        // Parse strings like "3 days ago", "2 weeks ago", etc.
        let components = dateString.lowercased().components(separatedBy: " ")
        guard components.count >= 3,
              let value = Int(components[0]),
              components.last == "ago" else { return nil }
        
        let unit = components[1]
        let calendar = Calendar.current
        
        switch unit {
        case "day", "days":
            return calendar.date(byAdding: .day, value: -value, to: Date())
        case "week", "weeks":
            return calendar.date(byAdding: .weekOfYear, value: -value, to: Date())
        case "month", "months":
            return calendar.date(byAdding: .month, value: -value, to: Date())
        case "year", "years":
            return calendar.date(byAdding: .year, value: -value, to: Date())
        default:
            return nil
        }
    }
    
    // Helper method to parse bookshelves
    private func parseBookshelves(_ shelves: String) -> [String] {
        guard !shelves.isEmpty else { return [] }
        
        return shelves
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // Helper method to parse rating
    private func parseRating(_ ratingString: String) -> Int? {
        let cleaned = ratingString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle "did not rate" or empty ratings
        if cleaned.isEmpty || cleaned.lowercased().contains("not") {
            return nil
        }
        
        // Try to parse as integer
        if let rating = Int(cleaned) {
            return min(max(rating, 0), 5)  // Clamp to 0-5 range
        }
        
        // Try to parse as float and round
        if let rating = Double(cleaned) {
            return min(max(Int(rating.rounded()), 0), 5)
        }
        
        return nil
    }
    
    private func loadExistingBooks() async {
        let descriptor = FetchDescriptor<BookModel>()
        do {
            let books = try modelContext.fetch(descriptor)
            existingBooksCache = Set(books.compactMap { book in
                if let isbn = book.isbn, !isbn.isEmpty {
                    return isbn
                } else {
                    return "\(book.title.lowercased())_\(book.author.lowercased())"
                }
            })
        } catch {
            os_log(.error, log: OSLog.default, "Failed to load existing books: %@", error.localizedDescription)
        }
    }
    
    private func checkForDuplicate(_ goodreadsBook: GoodreadsBook) async throws -> BookModel? {
        // Check by ISBN first
        if let isbn = goodreadsBook.primaryISBN, existingBooksCache.contains(isbn) {
            // Using simpler fetch without predicate to avoid compilation issues
            let descriptor = FetchDescriptor<BookModel>()
            let allBooks = try modelContext.fetch(descriptor)
            return allBooks.first { $0.isbn == isbn }
        }
        
        // Check by title/author using simpler comparison
        let key = "\(goodreadsBook.title.lowercased())_\(goodreadsBook.author.lowercased())"
        if existingBooksCache.contains(key) {
            // Using simpler fetch without complex predicate
            let descriptor = FetchDescriptor<BookModel>()
            let allBooks = try modelContext.fetch(descriptor)
            return allBooks.first { book in
                book.title.lowercased() == goodreadsBook.title.lowercased() && 
                book.author.lowercased() == goodreadsBook.author.lowercased()
            }
        }
        
        return nil
    }
    
    private func saveBooksInBatches(_ books: [ProcessedBook]) async throws {
        let saveChunks = books.chunked(into: 20)
        let totalChunks = saveChunks.count
        
        #if DEBUG
        print("📚 Starting to save \(books.count) books in \(totalChunks) batches")
        #endif
        
        for (index, chunk) in saveChunks.enumerated() {
            #if DEBUG
            print("💾 Saving batch \(index + 1) of \(totalChunks) (\(chunk.count) books)")
            #endif
            
            // Insert books in this chunk
            for processedBook in chunk {
                #if DEBUG
                print("  📖 Inserting: \(processedBook.bookModel.title) by \(processedBook.bookModel.author)")
                #endif
                modelContext.insert(processedBook.bookModel)
            }
            
            // Save after each chunk
            do {
                try modelContext.save()
                #if DEBUG
                print("  ✅ Batch \(index + 1) saved successfully")
                #endif
            } catch {
                os_log(.error, log: OSLog.default, "Failed to save batch %d: %@", index + 1, error.localizedDescription)
                throw error
            }
            
            // Update progress
            let savedCount = min((index + 1) * 20, books.count)
            let progress = Double(savedCount) / Double(books.count)
            
            await MainActor.run {
                if let current = self.currentProgress {
                    self.currentProgress = ImportProgress(
                        current: current.current,
                        total: current.total,
                        phase: .saving,
                        timeRemaining: nil,
                        currentBook: "Saving batch \(index + 1) of \(totalChunks)... (\(Int(progress * 100))%)",
                        batchNumber: current.batchNumber,
                        totalBatches: current.totalBatches
                    )
                }
            }
            
            // Small delay between save batches to prevent memory spikes
            if index < saveChunks.count - 1 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        #if DEBUG
        print("💾 Successfully saved \(books.count) books in \(totalChunks) batches")
        #endif
    }
    
    // MARK: - Cache Management
    
    private func matchBookWithCache(_ goodreadsBook: GoodreadsBook) async throws -> (ProcessedBook?, Bool) {
        // Check for duplicates first
        if let existing = try await checkForDuplicate(goodreadsBook) {
            throw ImportError.duplicateBook(existing)
        }
        
        // Check cache first
        if let cachedResult = await checkCache(for: goodreadsBook) {
            return (cachedResult, true)
        }
        
        // Perform API lookup
        if let result = try await matchBookViaAPI(goodreadsBook) {
            // Add to cache for future lookups
            updateCache(for: goodreadsBook, with: result)
            return (result, false)
        }
        
        return (nil, false)
    }
    
    private func checkCache(for book: GoodreadsBook) async -> ProcessedBook? {
        // Check ISBN cache first
        if let isbn = book.primaryISBN,
           let cachedBook = isbnCache[isbn] {
            let bookModel = await createBookModel(from: cachedBook, goodreadsBook: book)
            return ProcessedBook(
                goodreadsBook: book,
                bookModel: bookModel,
                matchMethod: .isbn
            )
        }
        
        // Check title/author cache
        let searchKey = "\(book.title.lowercased())_\(book.author.lowercased())"
        if let cachedBook = titleAuthorCache[searchKey] {
            let bookModel = await createBookModel(from: cachedBook, goodreadsBook: book)
            return ProcessedBook(
                goodreadsBook: book,
                bookModel: bookModel,
                matchMethod: .titleAuthor
            )
        }
        
        return nil
    }
    
    private func updateCache(for book: GoodreadsBook, with result: ProcessedBook) {
        // Cache by ISBN if available
        if let isbn = book.primaryISBN {
            // Create GoogleBookItem from BookModel for caching
            let bookItem = createGoogleBookItem(from: result.bookModel)
            isbnCache[isbn] = bookItem
        }
        
        // Also cache by title/author
        let searchKey = "\(book.title.lowercased())_\(book.author.lowercased())"
        let bookItem = createGoogleBookItem(from: result.bookModel)
        titleAuthorCache[searchKey] = bookItem
    }
    
    private func createGoogleBookItem(from bookModel: BookModel) -> GoogleBookItem {
        GoogleBookItem(
            id: bookModel.id,
            volumeInfo: VolumeInfo(
                title: bookModel.title,
                authors: bookModel.author.components(separatedBy: ", "),
                publishedDate: bookModel.publishedYear,
                description: bookModel.desc,
                pageCount: bookModel.pageCount,
                imageLinks: bookModel.coverImageURL != nil ? ImageLinks(
                    thumbnail: bookModel.coverImageURL,
                    small: nil,
                    medium: nil,
                    large: nil,
                    extraLarge: nil
                ) : nil,
                industryIdentifiers: bookModel.isbn != nil ? [IndustryIdentifier(
                    type: "ISBN",
                    identifier: bookModel.isbn!
                )] : nil
            )
        )
    }
    
    private func clearCaches() {
        isbnCache.removeAll()
        titleAuthorCache.removeAll()
        existingBooksCache.removeAll()
        #if DEBUG
        print("🧹 Cleared all caches")
        #endif
    }
    
    private func matchBookViaAPI(_ goodreadsBook: GoodreadsBook) async throws -> ProcessedBook? {
        // This is essentially the existing matchBook logic but separated for clarity
        let googleBooksService = await MainActor.run { self.googleBooksService }
        
        // Try ISBN match first
        if let isbn = goodreadsBook.primaryISBN {
            if let book = await googleBooksService.searchBookByISBN(isbn) {
                let bookItem = GoogleBookItem(
                    id: book.id,
                    volumeInfo: VolumeInfo(
                        title: book.title,
                        authors: book.authors,
                        publishedDate: book.publishedYear,
                        description: book.description,
                        pageCount: book.pageCount,
                        imageLinks: book.coverImageURL != nil ? ImageLinks(
                            thumbnail: book.coverImageURL,
                            small: nil,
                            medium: nil,
                            large: nil,
                            extraLarge: nil
                        ) : nil,
                        industryIdentifiers: book.isbn != nil ? [IndustryIdentifier(
                            type: "ISBN",
                            identifier: book.isbn!
                        )] : nil
                    )
                )
                
                let bookModel = await createBookModel(from: bookItem, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .isbn
                )
            }
        }
        
        // Try title/author match
        await googleBooksService.searchBooks(query: "intitle:\(goodreadsBook.title) inauthor:\(goodreadsBook.author)")
        
        if let book = googleBooksService.searchResults.first {
            let bookItem = GoogleBookItem(
                id: book.id,
                volumeInfo: VolumeInfo(
                    title: book.title,
                    authors: book.authors,
                    publishedDate: book.publishedYear,
                    description: book.description,
                    pageCount: book.pageCount,
                    imageLinks: book.coverImageURL != nil ? ImageLinks(
                        thumbnail: book.coverImageURL,
                        small: nil,
                        medium: nil,
                        large: nil,
                        extraLarge: nil
                    ) : nil,
                    industryIdentifiers: book.isbn != nil ? [IndustryIdentifier(
                        type: "ISBN",
                        identifier: book.isbn!
                    )] : nil
                )
            )
            
            if isGoodMatch(googleBook: bookItem, goodreadsBook: goodreadsBook) {
                let bookModel = await createBookModel(from: bookItem, goodreadsBook: goodreadsBook)
                return ProcessedBook(
                    goodreadsBook: goodreadsBook,
                    bookModel: bookModel,
                    matchMethod: .titleAuthor
                )
            }
        }
        
        return nil
    }
    
    private func updateTimeEstimate(totalBooks: Int) {
        guard let startTime = startTime, processedCount > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let averageTime = elapsed / Double(processedCount)
        let remaining = Double(totalBooks - processedCount) * averageTime
        
        Task { @MainActor in
            if var progress = currentProgress {
                currentProgress = ImportProgress(
                    current: progress.current,
                    total: progress.total,
                    phase: progress.phase,
                    timeRemaining: remaining,
                    currentBook: progress.currentBook,
                    batchNumber: progress.batchNumber,
                    totalBatches: progress.totalBatches
                )
            }
        }
    }
    
    // MARK: - Testing
    
    func runTestImport(modelContext: ModelContext, googleBooksService: GoogleBooksService) async {
        #if DEBUG
        
        // Test CSV data with various edge cases
        let testCSV = """
"Book Id","Title","Author","Author l-f","Additional Authors","ISBN","ISBN13","My Rating","Average Rating","Publisher","Binding","Number of Pages","Year Published","Original Publication Year","Date Read","Date Added","Bookshelves","Bookshelves with positions","Exclusive Shelf","My Review","Spoiler","Private Notes","Read Count","Owned Copies"
"123","The Great Gatsby","F. Scott Fitzgerald","Fitzgerald, F. Scott","","0743273567","9780743273565","4","3.89","Scribner","Paperback","180","2004","1925","2024/01/15","2023/12/01","classics, american-literature","classics (#5), american-literature (#12)","read","Great American novel","false","","1",""
"456","To Kill a Mockingbird","Harper Lee","Lee, Harper","","=\"0061120081\"","=\"9780061120084\"","5","4.27","Harper","Hardcover","324","2006","1960","2024/02/20","2023/11/15","classics, favorites","classics (#3), favorites (#1)","read","Powerful story about justice","false","Private note here","1","1"
"789","Book Without ISBN","Unknown Author","","","","","3","3.5","","","200","2020","","","2024/01/01","fiction","fiction (#10)","want-to-read","","","","",""
"101","Book, With, Commas","Author, With, Commas","Commas, Author With","Second, Author","","","2","3.0","Publisher, Inc.","Paperback","150","2022","","","2024/03/01","test","test (#1)","currently-reading","Review with, commas","true","Note, with, commas","","1"
"""
        
        // Create test file
        let testFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_goodreads.csv")
        
        do {
            // Write test CSV to file
            try testCSV.write(to: testFileURL, atomically: true, encoding: .utf8)
            print("📝 Created test CSV file at: \(testFileURL.path)")
            
            // Test 1: CSV Parsing
            print("\n🔬 Test 1: CSV Parsing")
            print(String(repeating: "-", count: 30))
            
            let books = try await parseCSV(from: testFileURL)
            print("✅ Parsed \(books.count) books from CSV")
            
            for (index, book) in books.enumerated() {
                print("\n📖 Book \(index + 1):")
                print("  Title: \(book.title)")
                print("  Author: \(book.author)")
                print("  ISBN: \(book.isbn.isEmpty ? "None" : book.isbn)")
                print("  ISBN13: \(book.isbn13.isEmpty ? "None" : book.isbn13)")
                print("  Rating: \(book.myRating)")
                print("  Status: \(book.exclusiveShelf)")
                print("  Has ISBN: \(book.hasISBN)")
                
                // Check Excel format handling
                if book.isbn.contains("=") || book.isbn13.contains("=") {
                    print("  ⚠️ Excel formula detected - should be cleaned")
                }
                
                // Check cleaned ISBN
                if let cleanedISBN = book.primaryISBN {
                    print("  Cleaned ISBN: \(cleanedISBN)")
                }
            }
            
            // Test 2: Book Matching with API
            print("\n🔬 Test 2: Book Matching with Google Books API")
            print(String(repeating: "-", count: 30))
            
            for book in books.prefix(2) { // Test first 2 books to avoid rate limits
                print("\n🔍 Matching: \(book.title)")
                
                do {
                    let result = try await matchBookWithCache(book)
                    if let processedBook = result.0 {
                        print("  ✅ Matched with Google Books:")
                        print("    ID: \(processedBook.bookModel.id)")
                        print("    Title: \(processedBook.bookModel.title)")
                        print("    Author: \(processedBook.bookModel.author)")
                        print("    Cover URL: \(processedBook.bookModel.coverImageURL ?? "None")")
                        print("    Page Count: \(processedBook.bookModel.pageCount ?? 0)")
                        print("    Match Method: \(processedBook.matchMethod)")
                        print("    Cache hit: \(result.1)")
                        
                        // Verify high-res cover
                        if let coverURL = processedBook.bookModel.coverImageURL {
                            if coverURL.contains("zoom=1") || coverURL.contains("zoom=2") {
                                print("    ✅ High-res cover URL detected")
                            } else {
                                print("    ⚠️ Low-res cover URL")
                            }
                        }
                    } else {
                        print("  ❌ No match found")
                    }
                } catch {
                    print("  ❌ Error: \(error.localizedDescription)")
                }
            }
            
            // Test 3: Edge Cases
            print("\n🔬 Test 3: Edge Case Handling")
            print(String(repeating: "-", count: 30))
            
            // Test parseCSVLine with various formats
            let testLines = [
                "\"Title\",\"Author\",\"Year\"",
                "\"Book, With, Commas\",\"Author Name\",\"2024\"",
                "Simple Title,Simple Author,2023",
                "\"Quoted \"Title\" Here\",Author,2022",
                "=\"0123456789\",=\"Author Name\",2021"
            ]
            
            for line in testLines {
                let parsed = parseCSVLine(line)
                print("\nInput: \(line)")
                print("Parsed: \(parsed)")
                
                // Verify Excel formula cleaning
                for value in parsed {
                    if value.contains("=") {
                        print("  ⚠️ Excel formula not cleaned: \(value)")
                    }
                }
            }
            
            // Test 4: Duplicate Detection
            print("\n🔬 Test 4: Duplicate Detection")
            print(String(repeating: "-", count: 30))
            
            // Check if books already exist in library
            let descriptor = FetchDescriptor<BookModel>()
            let existingBooks = try modelContext.fetch(descriptor)
            
            for book in books.prefix(2) {
                let isDuplicate = existingBooks.contains { existing in
                    // Check by ISBN first
                    if let bookISBN = book.primaryISBN,
                       let existingISBN = existing.isbn,
                       !bookISBN.isEmpty && !existingISBN.isEmpty {
                        return bookISBN == existingISBN
                    }
                    
                    // Fallback to title/author
                    return existing.title.lowercased() == book.title.lowercased() &&
                           existing.author.lowercased() == book.author.lowercased()
                }
                
                if isDuplicate {
                    print("  ⚠️ Duplicate detected: \(book.title)")
                } else {
                    print("  ✅ Not a duplicate: \(book.title)")
                }
            }
            
            // Test 5: Full Import Process
            print("\n🔬 Test 5: Full Import Process (Small Batch)")
            print(String(repeating: "-", count: 30))
            
            let result = try await importCSV(
                from: testFileURL,
                speed: .fast
            )
            
            print("\n📊 Import Results:")
            print("  ✅ Successful: \(result.successful.count)")
            print("  ⚠️ Needs Matching: \(result.needsMatching.count)")
            print("  🔄 Duplicates: \(result.duplicates.count)")
            print("  ❌ Failed: \(result.failed.count)")
            print("  📚 Total Processed: \(result.totalProcessed)")
            print("  📈 Success Rate: \(String(format: "%.1f%%", result.successRate * 100))")
            
            // Log details of each result
            for book in result.successful {
                print("\n  ✅ Imported: \(book.bookModel.title)")
                print("     Status: \(book.goodreadsBook.exclusiveShelf)")
                print("     Rating: \(book.goodreadsBook.myRating)")
            }
            
            for unmatched in result.needsMatching {
                print("\n  ⚠️ Unmatched: \(unmatched.goodreadsBook.title)")
                print("     Reason: No match found")
            }
            
            // Clean up test file
            try FileManager.default.removeItem(at: testFileURL)
            print("\n🧹 Cleaned up test file")
            
            print("\n✅ All tests completed successfully!")
            print(String(repeating: "=", count: 50))
            
        } catch {
            print("\n❌ Test failed: \(error.localizedDescription)")
            print(String(repeating: "=", count: 50))
        }
        #endif
    }
    
    // MARK: - Errors
    
    enum ImportError: LocalizedError {
        case emptyCSV
        case invalidFormat
        case duplicateBook(BookModel)
        case serviceUnavailable
        
        var errorDescription: String? {
            switch self {
            case .emptyCSV:
                return "The CSV file is empty"
            case .invalidFormat:
                return "Invalid CSV format"
            case .duplicateBook(let book):
                return "Duplicate: \(book.title) already exists"
            case .serviceUnavailable:
                return "Service temporarily unavailable"
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { startIndex in
            let endIndex = Swift.min(startIndex + size, count)
            return Array(self[startIndex..<endIndex])
        }
    }
}
