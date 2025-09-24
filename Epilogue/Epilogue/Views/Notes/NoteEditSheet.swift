import SwiftUI

struct NoteEditSheet: View {
    let note: Note
    @State private var editedContent: String
    @FocusState private var isTextFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    init(note: Note) {
        self.note = note
        self._editedContent = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(DesignSystem.Colors.textQuaternary)
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
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 8)
                .glassEffect(
                    .regular.interactive(),
                    in: .capsule
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.bottom, 12)
            
            // Text editor with proper padding
            TextEditor(text: $editedContent)
                .font(.system(size: 16, design: note.type == .quote ? .serif : .default))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.bottom, 16)
                .focused($isTextFocused)
        }
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.hidden) // We have our own drag indicator
        .interactiveDismissDisabled()
        .onAppear {
            isTextFocused = true
            // Set editing state to hide action bar
            notesViewModel.isEditingNote = true
        }
        .onDisappear {
            // Clear editing state to show action bar again
            notesViewModel.isEditingNote = false
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
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
        }
    }
    
    private func saveAndDismiss() {
        // Since Note is a struct with immutable properties, we need to update through the view model
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
        
        // Also post a notification so SwiftDataNotesView can update if needed
        NotificationCenter.default.post(
            name: Notification.Name("NoteUpdated"),
            object: updatedNote
        )
        
        dismiss()
    }
}