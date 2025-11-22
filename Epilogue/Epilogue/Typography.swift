import SwiftUI
import Combine

// MARK: - Typography System
// iOS 26 SF Font implementation following Apple's design guidelines

extension Font {
    // MARK: Display Styles
    static let displayLarge = Font.system(size: 57, weight: .regular, design: .default)
    static let displayMedium = Font.system(size: 45, weight: .regular, design: .default)
    static let displaySmall = Font.system(size: 36, weight: .regular, design: .default)
    
    // MARK: Headline Styles
    static let headlineLarge = Font.system(size: 32, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    // MARK: Title Styles
    static let titleLarge = Font.system(size: 22, weight: .medium, design: .default)
    static let titleMedium = Font.system(size: 16, weight: .medium, design: .default)
    static let titleSmall = Font.system(size: 14, weight: .medium, design: .default)
    
    // MARK: Body Styles
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // MARK: Label Styles
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
}

// MARK: - Text Style View Modifier
struct TextStyleModifier: ViewModifier {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
    }
}

extension View {
    func textStyle(_ font: Font, color: Color = .primary, lineSpacing: CGFloat = 0) -> some View {
        self.modifier(TextStyleModifier(font: font, color: color, lineSpacing: lineSpacing))
    }
}

// MARK: - Typography Preview
struct TypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    Text("Display Large")
                        .font(.displayLarge)
                    Text("Display Medium")
                        .font(.displayMedium)
                    Text("Display Small")
                        .font(.displaySmall)
                }
                
                Divider()
                
                Group {
                    Text("Headline Large")
                        .font(.headlineLarge)
                    Text("Headline Medium")
                        .font(.headlineMedium)
                    Text("Headline Small")
                        .font(.headlineSmall)
                }
                
                Divider()
                
                Group {
                    Text("Title Large")
                        .font(.titleLarge)
                    Text("Title Medium")
                        .font(.titleMedium)
                    Text("Title Small")
                        .font(.titleSmall)
                }
                
                Divider()
                
                Group {
                    Text("Body Large")
                        .font(.bodyLarge)
                    Text("Body Medium")
                        .font(.bodyMedium)
                    Text("Body Small")
                        .font(.bodySmall)
                }
                
                Divider()
                
                Group {
                    Text("Label Large")
                        .font(.labelLarge)
                    Text("Label Medium")
                        .font(.labelMedium)
                    Text("Label Small")
                        .font(.labelSmall)
                }
            }
            .padding()
        }
        .navigationTitle("Typography System")
    }
}

#Preview {
    TypographyPreview()
}

// MARK: - Shared Types for Notes Feature

// MARK: - Note Models
enum NoteType: String, CaseIterable, Codable {
    case quote = "quote"
    case note = "note"
    
    var icon: String {
        switch self {
        case .quote:
            return "quote.opening"
        case .note:
            return "note.text"
        }
    }
    
    var displayName: String {
        switch self {
        case .quote:
            return "Quote"
        case .note:
            return "Note"
        }
    }
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NoteType
    let content: String
    let contentFormat: String  // "markdown" or "plaintext"
    let bookId: UUID?  // Link to specific book
    let bookTitle: String?
    let author: String?
    let pageNumber: Int?
    let dateCreated: Date
    let ambientSessionId: UUID?  // Link to ambient session
    let source: String?  // Source of the note (manual, ambient, etc.)

    init(type: NoteType, content: String, bookId: UUID? = nil, bookTitle: String? = nil, author: String? = nil, pageNumber: Int? = nil, dateCreated: Date = Date(), id: UUID = UUID(), ambientSessionId: UUID? = nil, source: String? = nil, contentFormat: String = "plaintext") {
        self.id = id
        self.type = type
        self.content = content
        self.contentFormat = contentFormat
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.author = author
        self.pageNumber = pageNumber
        self.dateCreated = dateCreated
        self.ambientSessionId = ambientSessionId
        self.source = source
    }

    // Computed property to check if content is markdown
    var isMarkdown: Bool {
        contentFormat == "markdown"
    }
    
    /// Check if this note is linked to a specific book
    var isLinkedToBook: Bool {
        return bookId != nil
    }
    
    /// Check if this note has book information but no link
    var hasUnlinkedBookInfo: Bool {
        return bookId == nil && (bookTitle != nil || author != nil)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
    }
}

// MARK: - Notes View Model
@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = [] {
        didSet {
            #if DEBUG
            print("📝 DEBUG: notes array didSet - count: \(notes.count)")
            #endif
            objectWillChange.send()
        }
    }
    @Published var isEditingNote: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let notesKey = "com.epilogue.savedNotes"
    
    init() {
        #if DEBUG
        print("🏗 DEBUG: NotesViewModel init")
        #endif
        
        // Debug: Check if UserDefaults has data
        if let data = userDefaults.data(forKey: notesKey) {
            #if DEBUG
            print("📦 DEBUG: Found existing data in UserDefaults, size: \(data.count) bytes")
            #endif
        } else {
            #if DEBUG
            print("📦 DEBUG: No existing data in UserDefaults")
            #endif
        }
        
        loadNotes()
        
        // Ensure we have some data
        if notes.isEmpty {
            #if DEBUG
            print("⚠️ DEBUG: No notes after loadNotes(), forcing sample data")
            #endif
            loadSampleData()
        }
        
        // Listen for book replacements
        NotificationCenter.default.addObserver(
            forName: Notification.Name("BookReplaced"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleBookReplacement(notification)
            }
        }
    }
    
    private func loadNotes() {
        #if DEBUG
        print("🔍 DEBUG: loadNotes() called")
        #if DEBUG
        print("🔍 DEBUG: UserDefaults key: \(notesKey)")
        #endif
        #endif
        
        if let data = userDefaults.data(forKey: notesKey) {
            #if DEBUG
            print("🔍 DEBUG: Found data in UserDefaults, size: \(data.count) bytes")
            #endif
            
            do {
                let decodedNotes = try JSONDecoder().decode([Note].self, from: data)
                #if DEBUG
                print("🔍 DEBUG: Successfully decoded \(decodedNotes.count) notes")
                #endif
                self.notes = decodedNotes
                
                // Print details of each note
                for (index, note) in decodedNotes.enumerated() {
                    #if DEBUG
                    print("🔍 DEBUG: Note \(index): type=\(note.type.rawValue), [\(note.content.count) characters]")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ DEBUG: Failed to decode notes: \(error)")
                #if DEBUG
                print("❌ DEBUG: Error details: \(error.localizedDescription)")
                #endif
                #endif
                // Load sample data on decode error
                loadSampleData()
            }
        } else {
            #if DEBUG
            print("🔍 DEBUG: No data found in UserDefaults for key: \(notesKey)")
            #endif
            // Load sample data only on first launch
            loadSampleData()
        }
        
        #if DEBUG
        print("🔍 DEBUG: loadNotes() finished. Total notes: \(self.notes.count)")
        #endif
    }
    
    private func saveNotes() {
        #if DEBUG
        print("💾 DEBUG: saveNotes() called")
        #if DEBUG
        print("💾 DEBUG: Attempting to save \(notes.count) notes")
        #endif
        #if DEBUG
        print("💾 DEBUG: UserDefaults key: \(notesKey)")
        #endif
        #endif
        
        do {
            let encoded = try JSONEncoder().encode(notes)
            #if DEBUG
            print("💾 DEBUG: Successfully encoded notes, size: \(encoded.count) bytes")
            #endif
            userDefaults.set(encoded, forKey: notesKey)
            
            // Force synchronize to ensure data is written
            let success = userDefaults.synchronize()
            #if DEBUG
            print("💾 DEBUG: UserDefaults synchronize: \(success)")
            #endif
            
            // Verify the save
            #if DEBUG
            if let verifyData = userDefaults.data(forKey: notesKey) {
                #if DEBUG
                print("✅ DEBUG: Verified data saved to UserDefaults, size: \(verifyData.count) bytes")
                #endif
            } else {
                #if DEBUG
                print("❌ DEBUG: Failed to verify data in UserDefaults after save")
                #endif
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ DEBUG: Failed to encode notes: \(error)")
            #if DEBUG
            print("❌ DEBUG: Error details: \(error.localizedDescription)")
            #endif
            #endif
        }
    }
    
    func addNote(_ note: Note) {
        #if DEBUG
        print("➕ DEBUG: addNote() called")
        #if DEBUG
        print("➕ DEBUG: Adding note - type: \(note.type.rawValue), [\(note.content.count) characters]")
        #endif
        #if DEBUG
        print("➕ DEBUG: Notes count before: \(notes.count)")
        #endif
        #endif
        
        notes.append(note)
        
        #if DEBUG
        print("➕ DEBUG: Notes count after: \(notes.count)")
        #endif
        saveNotes()
    }
    
    func deleteNote(_ note: Note) {
        #if DEBUG
        print("🗑 DEBUG: deleteNote() called for note ID: \(note.id)")
        #if DEBUG
        print("🗑 DEBUG: Notes count before: \(notes.count)")
        #endif
        #endif
        
        notes.removeAll { $0.id == note.id }
        
        #if DEBUG
        print("🗑 DEBUG: Notes count after: \(notes.count)")
        #endif
        saveNotes()
    }
    
    func updateNote(_ note: Note) {
        #if DEBUG
        print("✏️ DEBUG: updateNote() called for note ID: \(note.id)")
        #endif
        
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            #if DEBUG
            print("✏️ DEBUG: Found note at index: \(index)")
            #endif
            notes[index] = note
            saveNotes()
        } else {
            #if DEBUG
            print("❌ DEBUG: Note not found for update")
            #endif
        }
    }
    
    func updateNote(_ oldNote: Note, with newNote: Note) {
        #if DEBUG
        print("✏️ DEBUG: updateNote() called for note ID: \(oldNote.id)")
        #endif
        
        if let index = notes.firstIndex(where: { $0.id == oldNote.id }) {
            #if DEBUG
            print("✏️ DEBUG: Found note at index: \(index)")
            #endif
            // Keep the same ID but update the content
            var updatedNote = newNote
            updatedNote = Note(
                type: newNote.type,
                content: newNote.content,
                bookId: newNote.bookId,
                bookTitle: newNote.bookTitle,
                author: newNote.author,
                pageNumber: newNote.pageNumber,
                dateCreated: oldNote.dateCreated,
                id: oldNote.id
            )
            notes[index] = updatedNote
            saveNotes()
        } else {
            #if DEBUG
            print("❌ DEBUG: Note not found for update")
            #endif
        }
    }
    
    // Public method to manually reload notes
    func reloadNotes() {
        #if DEBUG
        print("🔄 DEBUG: Manual reload requested")
        #endif
        loadNotes()
    }
    
    // Sync with SwiftData to bring in ambient session quotes/notes  
    // Remove this - it causes ambiguity issues with Note type
    /*
    func syncWithSwiftData(quotes: [CapturedQuote], notes: [CapturedNote]) {
        #if DEBUG
        print("🔄 Syncing with SwiftData: \(quotes.count) quotes, \(notes.count) notes")
        #endif
        
        // Convert SwiftData quotes to Note model
        for quote in quotes {
            // Check if already exists
            if !self.notes.contains(where: { $0.content == quote.text }) {
                let note = Note(
                    type: .quote,
                    content: quote.text,
                    bookId: quote.book?.id,
                    bookTitle: quote.book?.title,
                    author: quote.author,
                    pageNumber: nil,
                    dateCreated: quote.timestamp,
                    id: UUID()
                )
                self.notes.append(note)
            }
        }
        
        // Convert SwiftData notes to Note model
        for capturedNote in notes {
            // Check if already exists
            if !self.notes.contains(where: { $0.content == capturedNote.content }) {
                let note = Note(
                    type: .note,
                    content: capturedNote.content,
                    bookId: capturedNote.book?.id,
                    bookTitle: capturedNote.book?.title,
                    author: nil,
                    pageNumber: capturedNote.pageNumber,
                    dateCreated: capturedNote.timestamp,
                    id: UUID()
                )
                self.notes.append(note)
            }
        }
        
        // Save the synced notes
        saveNotes()
    }
    */
    
    // Handle book replacement by updating note bookId references
    private func handleBookReplacement(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let oldLocalId = userInfo["oldLocalId"] as? UUID,
              let newLocalId = userInfo["newLocalId"] as? UUID else {
            return
        }
        
        #if DEBUG
        print("📚 DEBUG: Handling book replacement: \(oldLocalId) -> \(newLocalId)")
        #endif
        
        var updatedNotes = false
        for i in notes.indices {
            if notes[i].bookId == oldLocalId {
                notes[i] = Note(
                    type: notes[i].type,
                    content: notes[i].content,
                    bookId: newLocalId,
                    bookTitle: notes[i].bookTitle,
                    author: notes[i].author,
                    pageNumber: notes[i].pageNumber,
                    dateCreated: notes[i].dateCreated,
                    id: notes[i].id
                )
                updatedNotes = true
                #if DEBUG
                print("📚 DEBUG: Updated note \(notes[i].id) to new book")
                #endif
            }
        }
        
        if updatedNotes {
            saveNotes()
            #if DEBUG
            print("📚 DEBUG: Saved updated notes after book replacement")
            #endif
        }
    }
    
    // Debug method to check UserDefaults
    #if DEBUG
    func debugUserDefaults() {
        #if DEBUG
        print("🔍 DEBUG: Checking UserDefaults diagnostics")
        #endif
        #if DEBUG
        print("🔍 DEBUG: UserDefaults suite: \(userDefaults)")
        #endif
        
        // Check all keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        #if DEBUG
        print("🔍 DEBUG: All UserDefaults keys: \(allKeys)")
        #endif
        
        // Check our specific key
        if let data = userDefaults.data(forKey: notesKey) {
            #if DEBUG
            print("🔍 DEBUG: Found data for key '\(notesKey)': \(data.count) bytes")
            #endif
            
            // Try to decode to see if there's an issue
            do {
                let notes = try JSONDecoder().decode([Note].self, from: data)
                #if DEBUG
                print("🔍 DEBUG: Successfully decoded \(notes.count) notes from UserDefaults")
                #endif
            } catch {
                #if DEBUG
                print("❌ DEBUG: Failed to decode from UserDefaults: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ DEBUG: No data found for key '\(notesKey)'")
            #endif
        }
        
        // Try clearing and re-saving to test
        #if DEBUG
        print("🔍 DEBUG: Testing save/load cycle...")
        #endif
        let testNote = Note(type: .note, content: "Test note", dateCreated: Date())
        let testNotes = [testNote]
        
        if let encoded = try? JSONEncoder().encode(testNotes) {
            userDefaults.set(encoded, forKey: "com.epilogue.testNotes")
            userDefaults.synchronize()
            
            if userDefaults.data(forKey: "com.epilogue.testNotes") != nil {
                #if DEBUG
                print("✅ DEBUG: Test save/load successful")
                #endif
                userDefaults.removeObject(forKey: "com.epilogue.testNotes")
            } else {
                #if DEBUG
                print("❌ DEBUG: Test save/load failed")
                #endif
            }
        }
    }
    #endif
    
    private func loadSampleData() {
        #if DEBUG
        print("📚 DEBUG: loadSampleData() called - Loading sample notes")
        #endif
        
        notes = [
            Note(
                type: .quote,
                content: "It is during our darkest moments that we must focus to see the light.",
                bookTitle: "The Collected Wisdom",
                author: "Aristotle",
                pageNumber: 47,
                dateCreated: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
            ),
            Note(
                type: .note,
                content: "The character development in this chapter really shows how the author builds tension through small details and seemingly insignificant conversations.",
                bookTitle: "The Great Gatsby",
                author: "F. Scott Fitzgerald",
                pageNumber: 89,
                dateCreated: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
            Note(
                type: .quote,
                content: "In three words I can sum up everything I've learned about life: it goes on.",
                bookTitle: "Selected Poems",
                author: "Robert Frost",
                pageNumber: 156,
                dateCreated: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            ),
            Note(
                type: .note,
                content: "Need to research more about the historical context of this period. The author mentions several events that seem crucial to understanding the protagonist's motivations.",
                bookTitle: nil,
                author: nil,
                pageNumber: nil,
                dateCreated: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
            )
        ]
        
        #if DEBUG
        print("📚 DEBUG: Created \(notes.count) sample notes")
        #endif
        
        // Save the sample data
        saveNotes()
    }
}
