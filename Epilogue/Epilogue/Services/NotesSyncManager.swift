import Foundation
import Combine
import SwiftUI

// MARK: - Notes Sync Manager
/// Manages synchronization between NotesView and ChatView for consistent data
@MainActor
final class NotesSyncManager: ObservableObject {
    static let shared = NotesSyncManager()
    
    // MARK: - Published Properties
    @Published var deletedNoteIds: Set<UUID> = []
    @Published var updatedNotes: [UUID: Note] = [:]
    
    // MARK: - Notification Names
    static let noteDeletedNotification = Notification.Name("NotesSyncManager.noteDeleted")
    static let noteUpdatedNotification = Notification.Name("NotesSyncManager.noteUpdated")
    static let noteBatchDeletedNotification = Notification.Name("NotesSyncManager.noteBatchDeleted")
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.epilogue.notesSync", qos: .userInitiated)
    
    nonisolated private init() {
        Task { @MainActor in
            self.setupNotificationObservers()
        }
    }
    
    // MARK: - Setup
    private func setupNotificationObservers() {
        // Listen for note deletions from any source
        NotificationCenter.default.publisher(for: Self.noteDeletedNotification)
            .compactMap { $0.object as? UUID }
            .receive(on: syncQueue)
            .sink { [weak self] noteId in
                self?.handleNoteDeleted(noteId)
            }
            .store(in: &cancellables)
        
        // Listen for note updates
        NotificationCenter.default.publisher(for: Self.noteUpdatedNotification)
            .compactMap { $0.object as? Note }
            .receive(on: syncQueue)
            .sink { [weak self] note in
                self?.handleNoteUpdated(note)
            }
            .store(in: &cancellables)
        
        // Listen for batch deletions
        NotificationCenter.default.publisher(for: Self.noteBatchDeletedNotification)
            .compactMap { $0.object as? [UUID] }
            .receive(on: syncQueue)
            .sink { [weak self] noteIds in
                self?.handleBatchDeletion(noteIds)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Notify that a note has been deleted
    func noteDeleted(_ noteId: UUID) {
        NotificationCenter.default.post(
            name: Self.noteDeletedNotification,
            object: noteId
        )
    }
    
    /// Notify that a note has been updated
    func noteUpdated(_ note: Note) {
        NotificationCenter.default.post(
            name: Self.noteUpdatedNotification,
            object: note
        )
    }
    
    /// Notify that multiple notes have been deleted
    func notesDeleted(_ noteIds: [UUID]) {
        NotificationCenter.default.post(
            name: Self.noteBatchDeletedNotification,
            object: noteIds
        )
    }
    
    /// Check if a note has been deleted
    func isNoteDeleted(_ noteId: UUID) -> Bool {
        deletedNoteIds.contains(noteId)
    }
    
    /// Get the latest version of a note if it was updated
    func getUpdatedNote(for id: UUID) -> Note? {
        updatedNotes[id]
    }
    
    /// Clear sync data (call when views are refreshed)
    func clearSyncData() {
        syncQueue.async { [weak self] in
            self?.deletedNoteIds.removeAll()
            self?.updatedNotes.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func handleNoteDeleted(_ noteId: UUID) {
        deletedNoteIds.insert(noteId)
        updatedNotes.removeValue(forKey: noteId)
    }
    
    private func handleNoteUpdated(_ note: Note) {
        updatedNotes[note.id] = note
        // If note was previously marked as deleted, remove from deleted set
        deletedNoteIds.remove(note.id)
    }
    
    private func handleBatchDeletion(_ noteIds: [UUID]) {
        noteIds.forEach { id in
            deletedNoteIds.insert(id)
            updatedNotes.removeValue(forKey: id)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply note sync filtering to a collection of notes
    func syncFiltered<T: RandomAccessCollection>(
        notes: T,
        syncManager: NotesSyncManager = .shared
    ) -> [Note] where T.Element == Note {
        notes.filter { note in
            !syncManager.isNoteDeleted(note.id)
        }.map { note in
            syncManager.getUpdatedNote(for: note.id) ?? note
        }
    }
}

// MARK: - NotesViewModel Extension
extension NotesViewModel {
    /// Delete a note with sync notification
    func deleteNoteWithSync(_ note: Note) {
        // First notify sync manager
        NotesSyncManager.shared.noteDeleted(note.id)
        
        // Then delete from view model
        deleteNote(note)
    }
    
    /// Update a note with sync notification
    func updateNoteWithSync(_ note: Note) {
        // First update in view model
        updateNote(note)
        
        // Then notify sync manager
        NotesSyncManager.shared.noteUpdated(note)
    }
    
    /// Delete multiple notes with sync notification
    func deleteNotesWithSync(_ notes: [Note]) {
        // First notify sync manager
        NotesSyncManager.shared.notesDeleted(notes.map { $0.id })
        
        // Then delete from view model
        notes.forEach { deleteNote($0) }
    }
}

// MARK: - Chat Message Filtering
struct SyncFilteredChatMessage: ViewModifier {
    @ObservedObject var syncManager = NotesSyncManager.shared
    let message: UnifiedChatMessage
    
    func body(content: Content) -> some View {
        if let noteId = extractNoteId(from: message),
           syncManager.isNoteDeleted(noteId) {
            EmptyView()
        } else {
            content
        }
    }
    
    private func extractNoteId(from message: UnifiedChatMessage) -> UUID? {
        switch message.messageType {
        case .note(let capturedNote):
            return capturedNote.id
        case .noteWithContext(let capturedNote, _):
            return capturedNote.id
        case .quote(let capturedQuote):
            return capturedQuote.id
        default:
            return nil
        }
    }
}

// MARK: - UnifiedChatMessage Extension
extension UnifiedChatMessage {
    /// Check if this message references a deleted note
    func isDeleted(using syncManager: NotesSyncManager = .shared) -> Bool {
        switch messageType {
        case .note(let capturedNote):
            return syncManager.isNoteDeleted(capturedNote.id ?? UUID())
        case .noteWithContext(let capturedNote, _):
            return syncManager.isNoteDeleted(capturedNote.id ?? UUID())
        case .quote(let capturedQuote):
            return syncManager.isNoteDeleted(capturedQuote.id ?? UUID())
        default:
            return false
        }
    }
    
    /// Get updated version of embedded note if available
    func withUpdatedNote(using syncManager: NotesSyncManager = .shared) -> UnifiedChatMessage? {
        // For now, return self as we don't have a way to update the embedded note
        // This could be enhanced in the future
        return self
    }
}

// MARK: - Usage Example
/*
 In NotesView:
 ```swift
 private func deleteNote(_ note: Note) {
     notesViewModel.deleteNoteWithSync(note)
 }
 ```
 
 In ChatView:
 ```swift
 ForEach(messages) { message in
     ChatMessageView(message: message)
         .modifier(SyncFilteredChatMessage(message: message))
 }
 ```
 
 Or use the sync filtered helper:
 ```swift
 var syncFilteredNotes: [Note] {
     syncFiltered(notes: notesViewModel.notes)
 }
 ```
 */