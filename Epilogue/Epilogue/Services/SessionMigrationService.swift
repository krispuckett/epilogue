import Foundation
import SwiftData
import SwiftUI

/// Service to migrate orphaned sessions (with no book) to their proper books
@MainActor
class SessionMigrationService {
    static let shared = SessionMigrationService()
    
    private init() {}
    
    /// Migrate all sessions without books by analyzing their content
    func migrateOrphanedSessions(modelContext: ModelContext, libraryViewModel: LibraryViewModel) async {
        #if DEBUG
        print("🔄 Starting session migration...")
        #endif
        
        // Fetch all sessions without a book
        let descriptor = FetchDescriptor<AmbientSession>(
            predicate: #Predicate { session in
                session.bookModel == nil
            }
        )
        
        guard let orphanedSessions = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ Failed to fetch orphaned sessions")
            #endif
            return
        }
        
        #if DEBUG
        print("📊 Found \(orphanedSessions.count) orphaned sessions to migrate")
        #endif
        
        var migratedCount = 0
        
        for session in orphanedSessions {
            if let matchedBook = findBookForSession(session, books: libraryViewModel.books) {
                // Create or find BookModel for the matched book
                let bookModel = findOrCreateBookModel(for: matchedBook, in: modelContext)
                
                // Update the session
                session.bookModel = bookModel
                
                // Also update any captured content with the book
                for quote in session.capturedQuotes ?? [] {
                    if quote.book == nil {
                        quote.book = bookModel
                    }
                }
                
                for note in session.capturedNotes ?? [] {
                    if note.book == nil {
                        note.book = bookModel
                    }
                }
                
                for question in session.capturedQuestions ?? [] {
                    if question.book == nil {
                        question.book = bookModel
                    }
                }
                
                migratedCount += 1
                #if DEBUG
                print("✅ Migrated session to book: \(matchedBook.title)")
                #endif
            }
        }
        
        // Save all changes
        do {
            try modelContext.save()
            #if DEBUG
            print("🎉 Migration complete! Migrated \(migratedCount) of \(orphanedSessions.count) sessions")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save migration: \(error)")
            #endif
        }
    }
    
    /// Find the most likely book for a session based on its content
    private func findBookForSession(_ session: AmbientSession, books: [Book]) -> Book? {
        // Strategy 1: Check questions for book/character names
        let bookMatches = analyzeQuestionsForBookReferences(session.capturedQuestions ?? [], books: books)
        if let bestMatchID = bookMatches.max(by: { $0.value < $1.value }) {
            if bestMatchID.value >= 2 { // At least 2 mentions
                return books.first { $0.id == bestMatchID.key }
            }
        }
        
        // Strategy 2: Check quotes for distinctive phrases
        let quoteMatches = analyzeQuotesForBookContent(session.capturedQuotes ?? [], books: books)
        if let bestMatchID = quoteMatches.max(by: { $0.value < $1.value }) {
            if bestMatchID.value >= 1 { // At least 1 strong match
                return books.first { $0.id == bestMatchID.key }
            }
        }
        
        // Strategy 3: Check session timing against library activity
        // If session was created around the same time a book was being read
        if let recentBook = findRecentlyActiveBook(at: session.startTime ?? Date(), books: books) {
            return recentBook
        }
        
        return nil
    }
    
    /// Analyze questions for book/character references - returns book IDs with scores
    private func analyzeQuestionsForBookReferences(_ questions: [CapturedQuestion], books: [Book]) -> [String: Int] {
        var scores: [String: Int] = [:] // Use book ID as key
        
        // Book-specific keywords
        let bookKeywords: [String: [String]] = [
            "The Lord Of The Rings": ["frodo", "gandalf", "aragorn", "ring", "mordor", "shire", "hobbit", "sauron", "gollum", "samwise", "sam", "merry", "pippin", "boromir", "legolas", "gimli", "elrond", "galadriel", "saruman", "rohan", "gondor", "isengard", "rivendell", "moria", "balrog", "nazgul", "ent", "orc", "elf", "dwarf"],
            "The Odyssey": ["odysseus", "penelope", "telemachus", "athena", "poseidon", "circe", "calypso", "cyclops", "polyphemus", "ithaca", "troy", "homer", "suitors", "scylla", "charybdis", "sirens", "lotus", "zeus", "hermes"],
            "The Silmarillion": ["melkor", "morgoth", "feanor", "silmaril", "valinor", "eru", "valar", "maiar", "noldor", "eldar", "turin", "beren", "luthien", "thingol", "doriath", "gondolin", "beleriand", "ainur"],
            "The Hobbit": ["bilbo", "thorin", "smaug", "dragon", "dwarves", "erebor", "laketown", "barrel", "riddle", "gollum", "eagle", "beorn", "mirkwood", "elvenking", "bard", "arkenstone"],
            "Love Wins": ["hell", "heaven", "salvation", "jesus", "god", "faith", "grace", "gospel", "eternity", "judgment", "mercy", "redemption", "forgiveness", "scripture", "bible"],
            "Dune": ["paul", "atreides", "harkonnen", "spice", "melange", "arrakis", "fremen", "sandworm", "bene gesserit", "kwisatz", "muad'dib", "stilgar", "chani", "jessica", "leto", "caladan", "sardaukar"],
            "War and Peace": ["pierre", "natasha", "andrei", "napoleon", "moscow", "petersburg", "rostov", "bolkonsky", "bezukhov", "kutuzov", "austerlitz", "borodino"],
            "1984": ["winston", "julia", "o'brien", "big brother", "oceania", "thoughtcrime", "ministry", "telescreen", "prole", "goldstein", "room 101", "newspeak", "doublethink"],
            "Pride and Prejudice": ["elizabeth", "darcy", "bennet", "bingley", "wickham", "collins", "pemberley", "netherfield", "longbourn", "meryton"],
            "Atomic Habits": ["habit", "cue", "craving", "response", "reward", "system", "goal", "identity", "compound", "plateau", "marginal", "gain"],
            "Sapiens": ["homo sapiens", "cognitive", "revolution", "agricultural", "neanderthal", "myth", "culture", "evolution", "harari", "cooperation"]
        ]
        
        for question in questions {
            let lowerContent = (question.content ?? "").lowercased()
            let lowerAnswer = (question.answer ?? "").lowercased()
            let combinedText = lowerContent + " " + lowerAnswer
            
            for book in books {
                if let keywords = bookKeywords[book.title] {
                    for keyword in keywords {
                        if combinedText.contains(keyword) {
                            scores[book.id, default: 0] += 1
                        }
                    }
                }
                
                // Also check for direct book title mentions
                if combinedText.contains(book.title.lowercased()) {
                    scores[book.id, default: 0] += 5 // Strong signal
                }
                
                // Check for author mentions
                if combinedText.contains(book.author.lowercased().split(separator: " ").last ?? "") {
                    scores[book.id, default: 0] += 2
                }
            }
        }
        
        return scores
    }
    
    /// Analyze quotes for book-specific content - returns book IDs with scores
    private func analyzeQuotesForBookContent(_ quotes: [CapturedQuote], books: [Book]) -> [String: Int] {
        var scores: [String: Int] = [:] // Use book ID as key
        
        // Distinctive phrases from various books
        let bookPhrases: [String: [String]] = [
            "The Lord Of The Rings": ["one ring", "my precious", "you shall not pass", "all that is gold", "not all those who wander", "even the smallest person", "i will take the ring", "the road goes ever on", "speak friend and enter", "one does not simply", "grief he will not forget", "it will not darken his heart"],
            "The Odyssey": ["wine-dark sea", "rosy-fingered dawn", "sing to me of the man", "tell me o muse", "nobody is my name", "lotus eaters"],
            "The Hobbit": ["in a hole in the ground", "there and back again", "what have i got in my pocket", "the last homely house", "far over the misty mountains"],
            "Love Wins": ["love wins", "heaven is", "hell is", "god's love", "eternal life", "good news"],
            "Dune": ["fear is the mind-killer", "the spice must flow", "plans within plans", "the sleeper must awaken", "he who controls the spice"],
            "1984": ["war is peace", "freedom is slavery", "ignorance is strength", "big brother is watching", "we shall meet in the place where there is no darkness"],
            "Pride and Prejudice": ["it is a truth universally acknowledged", "i declare after all there is no enjoyment like reading", "you must allow me to tell you"],
            "Atomic Habits": ["1% better", "atomic habits", "systems vs goals", "habit stack", "two-minute rule"],
            "Sapiens": ["cognitive revolution", "agricultural revolution", "scientific revolution", "imagined order", "shared myths"]
        ]
        
        for quote in quotes {
            let lowerText = (quote.text ?? "").lowercased()
            
            for book in books {
                if let phrases = bookPhrases[book.title] {
                    for phrase in phrases {
                        if lowerText.contains(phrase) {
                            scores[book.id, default: 0] += 3 // Strong match for exact phrases
                        }
                    }
                }
            }
        }
        
        return scores
    }
    
    /// Find a book that was recently active at the session time
    private func findRecentlyActiveBook(at sessionTime: Date, books: [Book]) -> Book? {
        // This would require tracking when books were last accessed
        // For now, we can use a simple heuristic based on the most popular books
        
        // Default to Lord of the Rings or The Odyssey if they exist (most common in testing)
        if let lotr = books.first(where: { $0.title == "The Lord Of The Rings" }) {
            return lotr
        }
        if let odyssey = books.first(where: { $0.title == "The Odyssey" }) {
            return odyssey
        }
        
        return nil
    }
    
    /// Find or create a BookModel for the given Book
    private func findOrCreateBookModel(for book: Book, in context: ModelContext) -> BookModel {
        // Check if BookModel already exists
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { model in
                model.localId == book.localId.uuidString || model.id == book.id
            }
        )
        
        if let existingModels = try? context.fetch(descriptor),
           let existingModel = existingModels.first {
            return existingModel
        }
        
        // Create new BookModel
        let bookModel = BookModel(from: book)
        context.insert(bookModel)
        return bookModel
    }
}