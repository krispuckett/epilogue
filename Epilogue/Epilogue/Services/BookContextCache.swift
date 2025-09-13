import Foundation
import SwiftData

// MARK: - Book Context Cache
// Pre-caches book context for instant AI responses
class BookContextCache {
    static let shared = BookContextCache()
    
    // Cache storage
    private var contextCache: [String: BookContext] = [:]
    private let cacheQueue = DispatchQueue(label: "com.epilogue.contextcache")
    
    // Book context structure
    struct BookContext: Codable {
        let title: String
        let author: String
        let mainCharacter: String?
        let keyThemes: [String]
        let plotSummary: String?
        let genre: String?
        let setting: String?
        let yearPublished: Int?
        let generatedAt: Date
        
        var contextString: String {
            var parts: [String] = []
            parts.append("Book: '\(title)' by \(author)")
            
            if let character = mainCharacter {
                parts.append("Main character: \(character)")
            }
            
            if !keyThemes.isEmpty {
                parts.append("Themes: \(keyThemes.joined(separator: ", "))")
            }
            
            if let setting = setting {
                parts.append("Setting: \(setting)")
            }
            
            if let genre = genre {
                parts.append("Genre: \(genre)")
            }
            
            return parts.joined(separator: ". ")
        }
    }
    
    private init() {
        loadCachedContexts()
    }
    
    // MARK: - Public Methods
    
    func getContext(for book: Book) -> BookContext? {
        cacheQueue.sync {
            return contextCache[book.localId.uuidString]
        }
    }
    
    func generateContextForBook(_ book: Book) async {
        // Check if we already have context
        if getContext(for: book) != nil {
            print("📚 Context already cached for: \(book.title)")
            return
        }
        
        print("🔄 Generating context for: \(book.title)")
        
        // For now, use known book data
        // Later this could call an API to get rich context
        let context = createBasicContext(for: book)
        
        // Cache it
        cacheQueue.async { [weak self] in
            self?.contextCache[book.localId.uuidString] = context
            self?.saveCachedContexts()
        }
        
        print("✅ Context cached for: \(book.title)")
    }
    
    func generateContextForAllBooks(_ books: [Book]) async {
        print("🔄 Generating context for \(books.count) books...")
        
        for book in books {
            await generateContextForBook(book)
        }
        
        print("✅ Generated context for all books")
    }
    
    // MARK: - Context Generation
    
    private func createBasicContext(for book: Book) -> BookContext {
        // Known book contexts - expand this over time
        let knownBooks: [String: BookContext] = [
            "The Odyssey": BookContext(
                title: "The Odyssey",
                author: "Homer",
                mainCharacter: "Odysseus",
                keyThemes: ["heroism", "journey home", "loyalty", "perseverance", "cunning over strength"],
                plotSummary: "Odysseus's ten-year journey home to Ithaca after the Trojan War, facing monsters, gods, and temptations",
                genre: "Epic poetry",
                setting: "Ancient Greece and the Mediterranean Sea",
                yearPublished: nil,
                generatedAt: Date()
            ),
            "The Lord of the Rings": BookContext(
                title: "The Lord of the Rings",
                author: "J.R.R. Tolkien",
                mainCharacter: "Frodo Baggins",
                keyThemes: ["good vs evil", "power and corruption", "friendship", "sacrifice", "hope"],
                plotSummary: "A hobbit's quest to destroy the One Ring and save Middle-earth from the Dark Lord Sauron",
                genre: "High fantasy",
                setting: "Middle-earth",
                yearPublished: 1954,
                generatedAt: Date()
            ),
            "The Silmarillion": BookContext(
                title: "The Silmarillion",
                author: "J.R.R. Tolkien",
                mainCharacter: "Multiple protagonists including Fëanor, Beren, and Túrin",
                keyThemes: ["creation mythology", "pride and downfall", "fate vs free will", "light vs darkness"],
                plotSummary: "The creation of Middle-earth and the history of the First Age, including the creation and theft of the Silmarils",
                genre: "High fantasy mythology",
                setting: "Middle-earth, primarily Beleriand",
                yearPublished: 1977,
                generatedAt: Date()
            ),
            "The Hobbit": BookContext(
                title: "The Hobbit",
                author: "J.R.R. Tolkien",
                mainCharacter: "Bilbo Baggins",
                keyThemes: ["adventure", "personal growth", "greed", "home", "courage"],
                plotSummary: "Bilbo Baggins joins thirteen dwarves on a quest to reclaim their homeland from the dragon Smaug",
                genre: "Children's fantasy",
                setting: "Middle-earth",
                yearPublished: 1937,
                generatedAt: Date()
            ),
            "1984": BookContext(
                title: "1984",
                author: "George Orwell",
                mainCharacter: "Winston Smith",
                keyThemes: ["totalitarianism", "surveillance", "thought control", "truth and lies", "rebellion"],
                plotSummary: "Winston Smith rebels against the totalitarian Party that rules Oceania with omnipresent surveillance",
                genre: "Dystopian fiction",
                setting: "Airstrip One (formerly Britain), Oceania",
                yearPublished: 1949,
                generatedAt: Date()
            )
        ]
        
        // Check if we have known context
        if let known = knownBooks[book.title] {
            return known
        }
        
        // Return basic context for unknown books
        return BookContext(
            title: book.title,
            author: book.author,
            mainCharacter: nil,
            keyThemes: [],
            plotSummary: nil,
            genre: nil,  // Book doesn't have categories
            setting: nil,
            yearPublished: book.publishedYear != nil ? Int(book.publishedYear!) : nil,
            generatedAt: Date()
        )
    }
    
    // MARK: - Persistence
    
    private func saveCachedContexts() {
        guard let url = cacheFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contextCache)
            try data.write(to: url)
            print("💾 Saved \(contextCache.count) book contexts to cache")
        } catch {
            print("❌ Failed to save context cache: \(error)")
        }
    }
    
    private func loadCachedContexts() {
        guard let url = cacheFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            print("📚 No existing context cache found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            contextCache = try decoder.decode([String: BookContext].self, from: data)
            print("📚 Loaded \(contextCache.count) book contexts from cache")
        } catch {
            print("❌ Failed to load context cache: \(error)")
        }
    }
    
    private var cacheFileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("book_contexts.json")
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.contextCache.removeAll()
            self?.saveCachedContexts()
        }
        print("🗑️ Context cache cleared")
    }
}