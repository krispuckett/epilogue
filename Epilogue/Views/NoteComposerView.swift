import SwiftUI

struct NoteComposerView: View {
    @Binding var isPresented: Bool
    @Binding var initialText: String
    let noteType: NoteType
    let onSave: (Note) -> Void
    
    @State private var noteContent: String = ""
    @State private var selectedBook: Book? = nil
    @FocusState private var isTextFieldFocused: Bool
    @State private var animateIn = false
    
    init(isPresented: Binding<Bool>, initialText: Binding<String>, noteType: NoteType, onSave: @escaping (Note) -> Void) {
        self._isPresented = isPresented
        self._initialText = initialText
        self.noteType = noteType
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)
                .onTapGesture {
                    dismissComposer()
                }
            
            // Note composer drawer
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    // Handle bar
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismissComposer()
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: noteType.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                            
                            Text("New \(noteType.displayName)")
                                .font(.system(size: 17, weight: .semibold, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        }
                        
                        Spacer()
                        
                        Button("Save") {
                            saveNote()
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Text editor
                    VStack(alignment: .leading, spacing: 12) {
                        // Optional book context
                        if let book = selectedBook {
                            HStack(spacing: 8) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7))
                                
                                Text(book.title)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                                
                                Spacer()
                                
                                Button(action: { selectedBook = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                            }
                        }
                        
                        // Text editor with placeholder
                        ZStack(alignment: .topLeading) {
                            if noteContent.isEmpty {
                                Text(placeholderText)
                                    .font(.system(size: 18, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.3))
                                    .padding(.top, 8)
                                    .padding(.horizontal, 4)
                            }
                            
                            TextEditor(text: $noteContent)
                                .font(.system(size: 18, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .focused($isTextFieldFocused)
                                .frame(minHeight: 150)
                        }
                        
                        // Character count
                        HStack {
                            Spacer()
                            Text("\(noteContent.count) characters")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.02))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
                .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
                .offset(y: animateIn ? 0 : 400)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // Set initial text if provided
            if !initialText.isEmpty {
                noteContent = cleanInitialText(initialText)
            }
            
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
            
            // Focus text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var placeholderText: String {
        switch noteType {
        case .quote:
            return "Enter a memorable quote..."
        case .note:
            return "What's on your mind?"
        }
    }
    
    private func cleanInitialText(_ text: String) -> String {
        var cleaned = text
        let prefixes = ["note:", "quote:", "thought:", "idea:"]
        
        for prefix in prefixes {
            if cleaned.lowercased().starts(with: prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        // Remove quotes if it's a quote type
        if noteType == .quote && cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        return cleaned
    }
    
    private func saveNote() {
        let newNote = Note(
            type: noteType,
            content: noteContent.trimmingCharacters(in: .whitespacesAndNewlines),
            bookTitle: selectedBook?.title,
            author: selectedBook?.author,
            pageNumber: nil,
            dateCreated: Date()
        )
        
        HapticManager.shared.success()
        onSave(newNote)
        dismissComposer()
    }
    
    private func dismissComposer() {
        isTextFieldFocused = false
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animateIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
            initialText = ""
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea()
        
        NoteComposerView(
            isPresented: .constant(true),
            initialText: .constant("note: This is a test"),
            noteType: .note
        ) { note in
            print("Saved note: \(note.content)")
        }
    }
}