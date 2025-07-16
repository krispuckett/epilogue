import SwiftUI

struct GlassEditNoteSheet: View {
    let note: Note
    let onSave: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    @State private var inputText = ""
    @State private var noteType: NoteType
    @State private var containerOpacity: Double = 0
    @State private var isAnimating = false
    @FocusState private var isFocused: Bool
    @State private var currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26)
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        self.note = note
        self.onSave = onSave
        self._noteType = State(initialValue: note.type)
        
        // Initialize input text with existing note content
        var initialText = note.content
        if note.type == .quote {
            // Format as quote with attribution
            if let author = note.author {
                initialText = "\"\(note.content)\" \(author)"
                if let bookTitle = note.bookTitle {
                    initialText += ", \(bookTitle)"
                }
                if let pageNumber = note.pageNumber {
                    initialText += ", p. \(pageNumber)"
                }
            } else {
                initialText = "\"\(note.content)\""
            }
        }
        self._inputText = State(initialValue: initialText)
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSheet()
                }
            
            VStack {
                Spacer().frame(height: UIScreen.main.bounds.height * 0.25)
                
                // Glass container taking 3/4 of screen
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Drag indicator
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)
                        
                        // Type selector
                        HStack(spacing: 12) {
                            ForEach(NoteType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        noteType = type
                                        updateGlowColor()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 14))
                                        Text(type.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(noteType == type ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background {
                                        if noteType == type {
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(typeColor.gradient.opacity(0.3))
                                        }
                                    }
                                }
                                .glassEffect(in: Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Single input field
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(noteType == .quote ? "Enter your quote with attribution" : "What's on your mind?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            // Main input field
                            TextField(
                                noteType == .quote ? 
                                "\"Quote content\" Author, Book Title, p. 123" : 
                                "Enter your note...",
                                text: $inputText,
                                axis: .vertical
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .lineLimit(5...10)
                            .focused($isFocused)
                            .padding(16)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                saveNote()
                            }
                        }
                        
                        // Helper text
                        if noteType == .quote {
                            Text("Format: \"Quote\" Author, Book, Page")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button {
                                dismissSheet()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            
                            Button {
                                saveNote()
                            } label: {
                                Text("Save")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(currentGlowColor.gradient.opacity(0.4))
                                    )
                            }
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 28))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            currentGlowColor.opacity(0.4),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: currentGlowColor.opacity(0.25), radius: 16, y: 4)
                .opacity(containerOpacity)
            }
        }
        .onAppear {
            updateGlowColor()
            // Animate appearance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                containerOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
    
    private var typeColor: Color {
        switch noteType {
        case .quote:
            return Color(red: 1.0, green: 0.55, blue: 0.26) // Orange
        case .note:
            return Color(red: 0.4, green: 0.6, blue: 0.9) // Blue
        }
    }
    
    private func updateGlowColor() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentGlowColor = typeColor
        }
    }
    
    private func dismissSheet() {
        isFocused = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containerOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dismiss()
        }
    }
    
    private func saveNote() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        if noteType == .quote {
            // Parse the quote using CommandParser
            let normalizedText = trimmedText
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .replacingOccurrences(of: "\u{2019}", with: "'")
            
            let (content, attribution) = CommandParser.parseQuote(normalizedText)
            
            var author: String? = nil
            var bookTitle: String? = nil
            var pageNumber: Int? = nil
            
            if let attr = attribution {
                let parts = attr.split(separator: "|||").map { String($0) }
                if parts.count >= 3 {
                    author = parts[0]
                    if parts[1] == "BOOK" && parts.count > 2 {
                        bookTitle = parts[2]
                    }
                    if parts.count > 4 && parts[3] == "PAGE" {
                        let pageStr = parts[4].trimmingCharacters(in: .whitespaces)
                        pageNumber = Int(pageStr.replacingOccurrences(of: "p.", with: "")
                            .replacingOccurrences(of: "page", with: "")
                            .replacingOccurrences(of: "pg", with: "")
                            .trimmingCharacters(in: .whitespaces))
                    }
                } else {
                    author = attr
                }
            }
            
            let updatedNote = Note(
                type: .quote,
                content: content,
                bookId: note.bookId,
                bookTitle: bookTitle,
                author: author,
                pageNumber: pageNumber,
                dateCreated: note.dateCreated,
                id: note.id
            )
            
            HapticManager.shared.success()
            onSave(updatedNote)
            dismissSheet()
        } else {
            // For regular notes, just save the text as-is
            let updatedNote = Note(
                type: .note,
                content: trimmedText,
                bookId: note.bookId,
                bookTitle: note.bookTitle,
                author: note.author,
                pageNumber: note.pageNumber,
                dateCreated: note.dateCreated,
                id: note.id
            )
            
            HapticManager.shared.success()
            onSave(updatedNote)
            dismissSheet()
        }
    }
}

// Create note version (for new notes)
struct GlassCreateNoteSheet: View {
    let noteType: NoteType
    let onSave: (Note) -> Void
    
    var body: some View {
        GlassEditNoteSheet(
            note: Note(
                type: noteType,
                content: "",
                bookTitle: nil,
                author: nil,
                pageNumber: nil,
                dateCreated: Date()
            ),
            onSave: onSave
        )
    }
}