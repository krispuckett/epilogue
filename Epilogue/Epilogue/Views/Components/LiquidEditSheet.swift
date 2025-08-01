import SwiftUI

struct LiquidEditSheet: View {
    let note: Note?
    let noteType: NoteType
    let onSave: (Note) -> Void
    let onDismiss: () -> Void
    
    @State private var isPresented = true
    @Namespace private var animation
    
    init(note: Note? = nil, noteType: NoteType = .note, onSave: @escaping (Note) -> Void, onDismiss: @escaping () -> Void) {
        self.note = note
        self.noteType = note?.type ?? noteType
        self.onSave = onSave
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        LiquidCommandPalette(
            isPresented: $isPresented,
            animationNamespace: animation,
            initialContent: formatNoteForEditing(note),
            editingNote: note,
            onUpdate: onSave,
            bookContext: nil  // No specific book context for general note editing
        )
        .onDisappear {
            onDismiss()
        }
        .onAppear {
            isPresented = true
        }
    }
    
    private func formatNoteForEditing(_ note: Note?) -> String? {
        guard let note = note else { return nil }
        
        switch note.type {
        case .note:
            return "note: \(note.content)"
        case .quote:
            // Clean the content - remove any trailing dashes or attribution that might have been saved
            var cleanContent = note.content.trimmingCharacters(in: .whitespaces)
            
            // Remove trailing dashes if they exist
            while cleanContent.hasSuffix("-") || cleanContent.hasSuffix("—") {
                cleanContent = String(cleanContent.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            
            var formatted = "\"\(cleanContent)\""
            if let author = note.author {
                formatted += " - \(author)"
                if let bookTitle = note.bookTitle {
                    formatted += ", \(bookTitle)"
                    if let pageNumber = note.pageNumber {
                        formatted += ", p. \(pageNumber)"
                    }
                }
            }
            return formatted
        }
    }
}