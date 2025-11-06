import Foundation
import SwiftData

@MainActor
class ReadwiseService: ObservableObject {
    static let shared = ReadwiseService()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: SyncProgress?
    @Published var error: ReadwiseError?
    
    // MARK: - Types
    struct SyncProgress {
        let current: Int
        let total: Int
        let message: String
    }
    
    enum ReadwiseError: LocalizedError {
        case noToken
        case invalidToken
        case networkError(String)
        case decodingError
        case rateLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .noToken:
                return "No Readwise token found. Please add your token in settings."
            case .invalidToken:
                return "Invalid Readwise token. Please check your token and try again."
            case .networkError(let message):
                return "Network error: \(message)"
            case .decodingError:
                return "Failed to process Readwise data"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
            }
        }
    }
    
    // MARK: - API Configuration
    private let baseURL = "https://readwise.io/api/v2"
    private let rateLimit = 240 // requests per minute
    private let pageSize = 1000
    
    // MARK: - Initialization
    private init() {
        checkAuthenticationStatus()
        loadLastSyncDate()
    }
    
    // MARK: - Authentication
    func setToken(_ token: String) {
        KeychainManager.shared.setAPIKey(token, for: .readwise)
        checkAuthenticationStatus()
    }
    
    func removeToken() {
        KeychainManager.shared.removeAPIKey(for: .readwise)
        isAuthenticated = false
    }
    
    private func checkAuthenticationStatus() {
        isAuthenticated = KeychainManager.shared.getAPIKey(for: .readwise) != nil
    }
    
    private func getToken() throws -> String {
        guard let token = KeychainManager.shared.getAPIKey(for: .readwise) else {
            throw ReadwiseError.noToken
        }
        return token
    }
    
    // MARK: - Sync Management
    func syncWithReadwise(modelContext: ModelContext, direction: SyncDirection = .both) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        error = nil
        
        do {
            let token = try getToken()
            
            // Validate token first
            try await validateToken(token)
            
            switch direction {
            case .importOnly:
                try await importHighlights(token: token, modelContext: modelContext)
            case .exportOnly:
                try await exportHighlights(token: token, modelContext: modelContext)
            case .both:
                try await importHighlights(token: token, modelContext: modelContext)
                try await exportHighlights(token: token, modelContext: modelContext)
            }
            
            // Update last sync date
            lastSyncDate = Date()
            saveLastSyncDate()
            
        } catch let readwiseError as ReadwiseError {
            error = readwiseError
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
        
        isSyncing = false
        syncProgress = nil
    }
    
    enum SyncDirection {
        case importOnly
        case exportOnly
        case both
    }
    
    // MARK: - Import from Readwise
    private func importHighlights(token: String, modelContext: ModelContext) async throws {
        var allHighlights: [ReadwiseHighlight] = []
        var nextPageCursor: String? = nil
        var pageCount = 0
        
        repeat {
            syncProgress = SyncProgress(
                current: pageCount,
                total: pageCount + 1,
                message: "Fetching highlights from Readwise..."
            )
            
            let response = try await fetchHighlights(
                token: token,
                cursor: nextPageCursor,
                updatedAfter: lastSyncDate
            )
            
            allHighlights.append(contentsOf: response.results)
            nextPageCursor = response.nextPageCursor
            pageCount += 1
            
            // Small delay to respect rate limits
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            
        } while nextPageCursor != nil
        
        // Process and save highlights
        try await processImportedHighlights(allHighlights, modelContext: modelContext)
    }
    
    private func fetchHighlights(token: String, cursor: String? = nil, updatedAfter: Date? = nil) async throws -> ReadwiseResponse {
        var components = URLComponents(string: "\(baseURL)/export/")!
        
        var queryItems: [URLQueryItem] = []
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "pageCursor", value: cursor))
        }
        if let date = updatedAfter {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "updatedAfter", value: formatter.string(from: date)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for rate limit
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw ReadwiseError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 {
                throw ReadwiseError.invalidToken
            } else if httpResponse.statusCode != 200 {
                throw ReadwiseError.networkError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(ReadwiseResponse.self, from: data)
        } catch {
            throw ReadwiseError.decodingError
        }
    }
    
    private func processImportedHighlights(_ highlights: [ReadwiseHighlight], modelContext: ModelContext) async throws {
        let totalHighlights = highlights.count
        var processedCount = 0
        
        // Group highlights by book
        let highlightsByBook = Dictionary(grouping: highlights) { highlight in
            "\(highlight.title ?? "Unknown")-\(highlight.author ?? "Unknown")"
        }
        
        for (bookKey, bookHighlights) in highlightsByBook {
            processedCount += bookHighlights.count
            
            syncProgress = SyncProgress(
                current: processedCount,
                total: totalHighlights,
                message: "Importing highlights for \(bookHighlights.first?.title ?? "book")..."
            )
            
            // Find or create book
            let book = try await findOrCreateBook(
                title: bookHighlights.first?.title ?? "Unknown Title",
                author: bookHighlights.first?.author ?? "Unknown Author",
                modelContext: modelContext
            )
            
            // Add highlights to book
            for highlight in bookHighlights {
                // Check if highlight already exists
                let existingQuote = book.quotes?.first { quote in
                    quote.text == highlight.text
                }
                
                if existingQuote == nil {
                    let capturedQuote = CapturedQuote(
                        text: highlight.text,
                        pageNumber: highlight.location != nil ? Int(highlight.location!) : nil,
                        timestamp: highlight.highlightedAt ?? Date(),
                        additionalNotes: highlight.note,
                        captureSource: .import_
                    )
                    capturedQuote.book = book
                    modelContext.insert(capturedQuote)
                }
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Export to Readwise
    private func exportHighlights(token: String, modelContext: ModelContext) async throws {
        // Fetch all quotes that haven't been exported
        let descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.exportedToReadwise == false && quote.book != nil
            }
        )
        
        let quotes = try modelContext.fetch(descriptor)
        
        if quotes.isEmpty {
            syncProgress = SyncProgress(
                current: 1,
                total: 1,
                message: "No new highlights to export"
            )
            return
        }
        
        // Convert to Readwise format
        let highlights = quotes.map { quote in
            ReadwiseHighlightCreate(
                text: quote.text ?? "",
                title: quote.book?.title,
                author: quote.book?.author,
                note: quote.additionalNotes,
                location: quote.pageNumber != nil ? String(quote.pageNumber!) : nil,
                highlightedAt: quote.timestamp ?? Date()
            )
        }
        
        // Send in batches of 100
        let batchSize = 100
        let batches = highlights.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            syncProgress = SyncProgress(
                current: index + 1,
                total: batches.count,
                message: "Exporting highlights to Readwise..."
            )
            
            try await createHighlights(token: token, highlights: batch)
            
            // Mark quotes as exported
            let batchQuotes = Array(quotes[index * batchSize..<min((index + 1) * batchSize, quotes.count)])
            for quote in batchQuotes {
                quote.exportedToReadwise = true
            }
            
            try modelContext.save()
            
            // Rate limit delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    private func createHighlights(token: String, highlights: [ReadwiseHighlightCreate]) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/highlights/")!)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["highlights": highlights]
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw ReadwiseError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 {
                throw ReadwiseError.invalidToken
            } else if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                throw ReadwiseError.networkError("HTTP \(httpResponse.statusCode)")
            }
        }
    }
    
    // MARK: - Validation
    private func validateToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/auth/")!)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                throw ReadwiseError.invalidToken
            } else if httpResponse.statusCode != 204 {
                throw ReadwiseError.networkError("Unexpected response: \(httpResponse.statusCode)")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func findOrCreateBook(title: String, author: String, modelContext: ModelContext) async throws -> BookModel {
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.title == title && book.author == author
            }
        )
        
        if let existingBook = try modelContext.fetch(descriptor).first {
            return existingBook
        }
        
        // Create new book
        let newBook = BookModel(
            title: title,
            author: author,
            totalPages: 0,
            currentPage: 0,
            readingStatus: "toRead"
        )
        
        modelContext.insert(newBook)
        try modelContext.save()
        
        return newBook
    }
    
    // MARK: - Persistence
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "readwise_last_sync")
        }
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "readwise_last_sync") as? Date
    }
}

// MARK: - Data Models
struct ReadwiseResponse: Codable {
    let count: Int
    let nextPageCursor: String?
    let results: [ReadwiseHighlight]
}

struct ReadwiseHighlight: Codable {
    let id: Int
    let text: String
    let note: String?
    let title: String?
    let author: String?
    let category: String?
    let location: String?
    let locationNormalized: Double?
    let url: String?
    let tags: [ReadwiseTag]?
    let highlightedAt: Date?
    let updated: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, text, note, title, author, category, location, url, tags, updated
        case locationNormalized = "location_normalized"
        case highlightedAt = "highlighted_at"
    }
}

struct ReadwiseTag: Codable {
    let id: Int
    let name: String
}

struct ReadwiseHighlightCreate: Codable {
    let text: String
    let title: String?
    let author: String?
    let note: String?
    let location: String?
    let highlightedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case text, title, author, note, location
        case highlightedAt = "highlighted_at"
    }
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}