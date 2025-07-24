import SwiftUI

struct NoteEditSheet: View {
    let note: Note
    @State private var editedContent: String
    @FocusState private var isTextFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    init(note: Note) {
        self.note = note
        self._editedContent = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Glass header with Done button
            HStack {
                Spacer()
                
                Button("Done") {
                    saveAndDismiss()
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(
                    .regular.interactive(),
                    in: .capsule
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Text editor with proper padding
            TextEditor(text: $editedContent)
                .font(.system(size: 16, design: note.type == .quote ? .serif : .default))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .focused($isTextFocused)
        }
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.hidden) // We have our own drag indicator
        .interactiveDismissDisabled()
        .onAppear {
            isTextFocused = true
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isTextFocused)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button("Done") {
                    isTextFocused = false
                    saveAndDismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
        }
    }
    
    private func saveAndDismiss() {
        // Create updated note with new content
        let updatedNote = Note(
            type: note.type,
            content: editedContent,
            bookId: note.bookId,
            bookTitle: note.bookTitle,
            author: note.author,
            pageNumber: note.pageNumber,
            dateCreated: note.dateCreated,
            id: note.id
        )
        
        // Update through view model
        notesViewModel.updateNote(updatedNote)
        
        dismiss()
    }
}