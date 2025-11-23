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
        NavigationStack {
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

                // Rich text editor with formatting toolbar
                RichTextEditor(
                    text: $editedContent,
                    placeholder: note.type == .quote ? "Add your thoughts about this quote..." : "What are you thinking about?",
                    isFocused: $isTextFocused
                )
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.bottom, 16)
            }
            .presentationDetents([.fraction(0.7), .large])  // Taller for formatting toolbar
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
        }
    }
    
    private func saveAndDismiss() {
        // Detect if content has markdown formatting
        let hasMarkdown = detectMarkdown(in: editedContent)

        // Since Note is a struct with immutable properties, we need to update through the view model
        let updatedNote = Note(
            type: note.type,
            content: editedContent,
            bookId: note.bookId,
            bookTitle: note.bookTitle,
            author: note.author,
            pageNumber: note.pageNumber,
            dateCreated: note.dateCreated,
            id: note.id,
            ambientSessionId: note.ambientSessionId,
            source: note.source,
            contentFormat: hasMarkdown ? "markdown" : "plaintext"
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

    /// Detects if text contains markdown formatting
    private func detectMarkdown(in text: String) -> Bool {
        // Check inline patterns
        let inlinePatterns = [
            "\\*\\*.*?\\*\\*",  // Bold
            "__.*?__",           // Bold alternative
            "\\*.*?\\*",         // Italic
            "_.*?_",             // Italic alternative
            "==.*?=="            // Highlight
        ]

        for pattern in inlinePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Check line-start patterns by splitting into lines
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("> ") ||     // Blockquote
               line.hasPrefix("# ") ||     // Header 1
               line.hasPrefix("## ") ||    // Header 2
               line.hasPrefix("- ") ||     // Bullet list
               line.range(of: "^\\d+\\. ", options: .regularExpression) != nil {  // Numbered list
                return true
            }
        }

        return false
    }
}