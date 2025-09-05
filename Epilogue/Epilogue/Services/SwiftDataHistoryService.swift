import Foundation
import SwiftData
import SwiftUI

// MARK: - History Entry Model
@Model
final class HistoryEntry {
    var id: UUID
    var entityType: String
    var entityId: String
    var changeType: String // "created", "updated", "deleted"
    var changes: String // JSON string of changes
    var timestamp: Date
    var userId: String?
    
    init(
        entityType: String,
        entityId: String,
        changeType: String,
        changes: String,
        timestamp: Date = Date(),
        userId: String? = nil
    ) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.changeType = changeType
        self.changes = changes
        self.timestamp = timestamp
        self.userId = userId
    }
}

// MARK: - SwiftData History Service
@MainActor
final class SwiftDataHistoryService {
    static let shared = SwiftDataHistoryService()
    
    private let modelContainer: ModelContainer?
    private let modelContext: ModelContext?
    
    private init() {
        do {
            let schema = Schema([
                HistoryEntry.self,
                BookModel.self,
                CapturedNote.self,
                CapturedQuote.self,
                CapturedQuestion.self,
                AmbientSession.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
            
            self.modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to initialize SwiftData history: \(error)")
            self.modelContainer = nil
            self.modelContext = nil
        }
    }
    
    // MARK: - Track Book Changes
    
    func trackBookCreated(_ book: BookModel) {
        let changes = bookToJSON(book)
        createHistoryEntry(
            entityType: "Book",
            entityId: book.id,
            changeType: "created",
            changes: changes
        )
        
        // Haptic feedback for creation
        SensoryFeedback.bookAdded()
    }
    
    func trackBookUpdated(_ book: BookModel, oldValues: [String: Any]) {
        let currentValues = bookToDictionary(book)
        let changes = computeChanges(old: oldValues, new: currentValues)
        
        if !changes.isEmpty {
            createHistoryEntry(
                entityType: "Book",
                entityId: book.id,
                changeType: "updated",
                changes: changesToJSON(changes)
            )
            
            SensoryFeedback.impact(.light)
        }
    }
    
    func trackBookDeleted(_ bookId: String, bookTitle: String) {
        createHistoryEntry(
            entityType: "Book",
            entityId: bookId,
            changeType: "deleted",
            changes: "{\"title\":\"\(bookTitle)\"}"
        )
        
        SensoryFeedback.bookDeleted()
    }
    
    // MARK: - Track Note Changes
    
    func trackNoteCreated(_ note: CapturedNote) {
        let changes = capturedNoteToJSON(note)
        createHistoryEntry(
            entityType: "Note",
            entityId: note.id?.uuidString ?? "unknown",
            changeType: "created",
            changes: changes
        )
        
        SensoryFeedback.noteCreated()
    }
    
    func trackNoteUpdated(_ note: CapturedNote, oldContent: String) {
        if note.content != oldContent {
            let changes = "{\"oldContent\":\"\(oldContent)\",\"newContent\":\"\(note.content)\"}"
            createHistoryEntry(
                entityType: "Note",
                entityId: note.id?.uuidString ?? "unknown",
                changeType: "updated",
                changes: changes
            )
            
            SensoryFeedback.impact(.light)
        }
    }
    
    func trackNoteDeleted(_ noteId: UUID, content: String) {
        createHistoryEntry(
            entityType: "Note",
            entityId: noteId.uuidString,
            changeType: "deleted",
            changes: "{\"content\":\"\(content)\"}"
        )
        
        SensoryFeedback.impact(.medium)
    }
    
    // MARK: - Query History
    
    func getHistory(for entityType: String? = nil, limit: Int = 50) -> [HistoryEntry] {
        guard let context = modelContext else { return [] }
        
        let descriptor: FetchDescriptor<HistoryEntry>
        
        if let entityType = entityType {
            let predicate = #Predicate<HistoryEntry> { entry in
                entry.entityType == entityType
            }
            descriptor = FetchDescriptor<HistoryEntry>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<HistoryEntry>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        }
        
        do {
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = limit
            return try context.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }
    
    func getRecentChanges(since date: Date) -> [HistoryEntry] {
        guard let context = modelContext else { return [] }
        
        let predicate = #Predicate<HistoryEntry> { entry in
            entry.timestamp > date
        }
        
        let descriptor = FetchDescriptor<HistoryEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch recent changes: \(error)")
            return []
        }
    }
    
    // MARK: - Undo Support
    
    func canUndo(for entityId: String) -> Bool {
        let history = getHistory(limit: 1).first { $0.entityId == entityId }
        return history?.changeType != "deleted"
    }
    
    func undoLastChange(for entityId: String) -> Bool {
        guard let lastEntry = getHistory(limit: 1).first(where: { $0.entityId == entityId }) else {
            return false
        }
        
        // Implement undo logic based on change type
        switch lastEntry.changeType {
        case "created":
            // Delete the entity
            return undoCreation(entry: lastEntry)
        case "updated":
            // Restore previous values
            return undoUpdate(entry: lastEntry)
        case "deleted":
            // Restore the entity
            return undoDeletion(entry: lastEntry)
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func createHistoryEntry(
        entityType: String,
        entityId: String,
        changeType: String,
        changes: String
    ) {
        guard let context = modelContext else { return }
        
        let entry = HistoryEntry(
            entityType: entityType,
            entityId: entityId,
            changeType: changeType,
            changes: changes
        )
        
        context.insert(entry)
        
        do {
            try context.save()
        } catch {
            print("Failed to save history entry: \(error)")
        }
    }
    
    private func bookToJSON(_ book: BookModel) -> String {
        let dict = bookToDictionary(book)
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    private func bookToDictionary(_ book: BookModel) -> [String: Any] {
        return [
            "id": book.id,
            "title": book.title,
            "author": book.author,
            "readingStatus": book.readingStatus,
            "currentPage": book.currentPage,
            "userRating": book.userRating ?? 0,
            "dateAdded": book.dateAdded.timeIntervalSince1970
        ]
    }
    
    private func capturedNoteToJSON(_ note: CapturedNote) -> String {
        let dict: [String: Any] = [
            "id": note.id?.uuidString ?? "unknown",
            "content": note.content,
            "bookLocalId": note.bookLocalId ?? "",
            "timestamp": note.timestamp?.timeIntervalSince1970 ?? 0,
            "source": (note.source as? String) ?? "unknown",
            "pageNumber": note.pageNumber ?? 0
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    private func computeChanges(old: [String: Any], new: [String: Any]) -> [String: Any] {
        var changes: [String: Any] = [:]
        
        for (key, newValue) in new {
            if let oldValue = old[key] {
                // Compare values (simplified - you might need more sophisticated comparison)
                if "\(oldValue)" != "\(newValue)" {
                    changes[key] = ["old": oldValue, "new": newValue]
                }
            }
        }
        
        return changes
    }
    
    private func changesToJSON(_ changes: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: changes),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    private func undoCreation(entry: HistoryEntry) -> Bool {
        // Implementation would delete the created entity
        // This is simplified - you'd need to handle the actual deletion
        return false
    }
    
    private func undoUpdate(entry: HistoryEntry) -> Bool {
        // Implementation would restore previous values from the changes JSON
        // This is simplified - you'd need to parse the JSON and update the entity
        return false
    }
    
    private func undoDeletion(entry: HistoryEntry) -> Bool {
        // Implementation would recreate the deleted entity from the changes JSON
        // This is simplified - you'd need to parse the JSON and recreate the entity
        return false
    }
}

// MARK: - History View Component
struct HistoryTimelineView: View {
    let entries: [HistoryEntry]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(entries, id: \.id) { entry in
                    HistoryEntryRow(entry: entry)
                        .transition(.asymmetric(
                            insertion: .push(from: .trailing).combined(with: .opacity),
                            removal: .push(from: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding()
        }
    }
}

struct HistoryEntryRow: View {
    let entry: HistoryEntry
    
    var icon: String {
        switch entry.changeType {
        case "created": return "plus.circle.fill"
        case "updated": return "pencil.circle.fill"
        case "deleted": return "trash.circle.fill"
        default: return "circle.fill"
        }
    }
    
    var color: Color {
        switch entry.changeType {
        case "created": return .green
        case "updated": return .orange
        case "deleted": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.entityType) \(entry.changeType)")
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}