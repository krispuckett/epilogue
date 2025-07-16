import SwiftUI

struct LiquidCommandPalette: View {
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @FocusState private var isFocused: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26) // Amber initial
    @State private var containerOpacity: Double = 0
    @State private var isAnimating = false
    
    // Optional initial content for editing
    let initialContent: String?
    let editingNote: Note?
    let onUpdate: ((Note) -> Void)?
    
    init(isPresented: Binding<Bool>, initialContent: String? = nil, editingNote: Note? = nil, onUpdate: ((Note) -> Void)? = nil) {
        self._isPresented = isPresented
        self.initialContent = initialContent
        self.editingNote = editingNote
        self.onUpdate = onUpdate
    }
    
    private var showActionButton: Bool {
        !commandText.isEmpty && detectedIntent != .unknown
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPalette()
                }
            
            VStack {
                Spacer()
                
                // Compact glass container
                VStack(spacing: 12) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    
                    // Compact input field
                    HStack(spacing: 10) {
                        Image(systemName: detectedIntent.icon)
                            .foregroundStyle(currentGlowColor)
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField(editingNote != nil ? "Edit your note..." : "What's on your mind?", text: $commandText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .focused($isFocused)
                            .lineLimit(1...3)  // Allow expansion up to 3 lines
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()  // Prevent smart quote conversion
                            .submitLabel(.done)
                            .onChange(of: commandText) { _, newValue in
                                // Normalize smart quotes to regular quotes
                                let normalizedText = newValue
                                    .replacingOccurrences(of: "\u{201C}", with: "\"")
                                    .replacingOccurrences(of: "\u{201D}", with: "\"")
                                    .replacingOccurrences(of: "\u{2018}", with: "'")
                                    .replacingOccurrences(of: "\u{2019}", with: "'")
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    detectedIntent = CommandParser.parse(normalizedText)
                                    updateGlowColor()
                                }
                            }
                            .onSubmit {
                                executeCommand()
                            }
                        
                        // Clear button - always present, animated with opacity
                        Button {
                            commandText = ""
                            detectedIntent = .unknown
                            updateGlowColor()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .opacity(commandText.isEmpty ? 0 : 1)
                        .scaleEffect(commandText.isEmpty ? 0.5 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: commandText.isEmpty)
                        .allowsHitTesting(!commandText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // Action button - always present, animated with opacity
                    Button {
                        executeCommand()
                    } label: {
                        HStack(spacing: 8) {
                            Text(editingNote != nil ? "Update" : detectedIntent.actionText)
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: editingNote != nil ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentGlowColor.gradient.opacity(0.3))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .opacity(showActionButton ? 1 : 0)
                    .scaleEffect(showActionButton ? 1 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showActionButton)
                    .allowsHitTesting(showActionButton)
                    .disabled(!showActionButton)
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            currentGlowColor.opacity(0.4),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: currentGlowColor.opacity(0.25), radius: 16, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8) // Small padding from keyboard
                .opacity(containerOpacity)
            }
        }
        .onAppear {
            guard !isAnimating else { return }
            
            // Reset state
            containerOpacity = 0
            
            // Initialize with existing content if editing
            if let initialContent = initialContent {
                commandText = initialContent
                detectedIntent = CommandParser.parse(initialContent)
                updateGlowColor()
            } else {
                commandText = ""
                detectedIntent = .unknown
                currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26)
            }
            
            // Animate container appearance
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    containerOpacity = 1
                }
                
                // Delay keyboard focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                    isAnimating = false
                }
            }
        }
        .onDisappear {
            // Clean up state
            containerOpacity = 0
            isFocused = false
            isAnimating = false
        }
    }
    
    private func updateGlowColor() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch detectedIntent {
            case .createQuote:
                currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26) // Orange
            case .createNote:
                currentGlowColor = Color(red: 0.4, green: 0.6, blue: 0.9) // Blue
            case .addBook:
                currentGlowColor = Color(red: 0.6, green: 0.4, blue: 0.8) // Purple
            case .searchLibrary:
                currentGlowColor = Color(red: 0.3, green: 0.7, blue: 0.5) // Green
            default:
                currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26) // Amber default
            }
        }
    }
    
    private func dismissPalette() {
        guard !isAnimating else { return }
        
        isAnimating = true
        isFocused = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            containerOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            isAnimating = false
        }
    }
    
    private func executeCommand() {
        guard detectedIntent != .unknown else { return }
        
        HapticManager.shared.mediumImpact()
        
        // Handle editing mode
        if let editingNote = editingNote, let onUpdate = onUpdate {
            switch detectedIntent {
            case .createNote(let text):
                updateNote(from: text, editingNote: editingNote, onUpdate: onUpdate)
            case .createQuote(let text):
                updateQuote(from: text, editingNote: editingNote, onUpdate: onUpdate)
            default:
                break
            }
            return
        }
        
        // Handle creation mode
        switch detectedIntent {
        case .createNote(let text):
            createNote(from: text)
        case .createQuote(let text):
            createQuote(from: text)
        case .addBook(let query):
            // TODO: Show book search sheet
            HapticManager.shared.success()
            dismissPalette()
        case .searchLibrary(let query):
            // TODO: Implement library search
            HapticManager.shared.success()
            dismissPalette()
        default:
            break
        }
    }
    
    private func createNote(from text: String) {
        // Normalize smart quotes before processing
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        // Remove various note prefixes
        let prefixes = ["note:", "note -", "note ", "thought:", "idea:", "reminder:", "todo:"]
        for prefix in prefixes {
            if content.lowercased().hasPrefix(prefix) {
                content = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        content = content.trimmingCharacters(in: .whitespaces)
        
        let note = Note(
            type: .note,
            content: content,
            bookId: nil,
            bookTitle: nil,
            author: nil,
            pageNumber: nil
        )
        
        notesViewModel.addNote(note)
        HapticManager.shared.success()
        dismissPalette()
    }
    
    private func createQuote(from text: String) {
        // Normalize smart quotes before parsing
        let normalizedText = text
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
        
        let quote = Note(
            type: .quote,
            content: content,
            bookId: nil,
            bookTitle: bookTitle,
            author: author,
            pageNumber: pageNumber
        )
        
        notesViewModel.addNote(quote)
        HapticManager.shared.success()
        dismissPalette()
    }
    
    private func updateNote(from text: String, editingNote: Note, onUpdate: @escaping (Note) -> Void) {
        // Normalize smart quotes before processing
        let normalizedText = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        
        var content = normalizedText
        
        // Remove various note prefixes
        let prefixes = ["note:", "note -", "note ", "thought:", "idea:", "reminder:", "todo:"]
        for prefix in prefixes {
            if content.lowercased().hasPrefix(prefix) {
                content = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        content = content.trimmingCharacters(in: .whitespaces)
        
        let updatedNote = Note(
            type: .note,
            content: content,
            bookId: editingNote.bookId,
            bookTitle: editingNote.bookTitle,
            author: editingNote.author,
            pageNumber: editingNote.pageNumber,
            dateCreated: editingNote.dateCreated,
            id: editingNote.id
        )
        
        onUpdate(updatedNote)
        HapticManager.shared.success()
        dismissPalette()
    }
    
    private func updateQuote(from text: String, editingNote: Note, onUpdate: @escaping (Note) -> Void) {
        // Normalize smart quotes before parsing
        let normalizedText = text
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
        
        let updatedQuote = Note(
            type: .quote,
            content: content,
            bookId: editingNote.bookId,
            bookTitle: bookTitle ?? editingNote.bookTitle,
            author: author ?? editingNote.author,
            pageNumber: pageNumber ?? editingNote.pageNumber,
            dateCreated: editingNote.dateCreated,
            id: editingNote.id
        )
        
        onUpdate(updatedQuote)
        HapticManager.shared.success()
        dismissPalette()
    }
}