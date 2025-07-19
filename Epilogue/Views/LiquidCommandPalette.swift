import SwiftUI

struct LiquidCommandPalette: View {
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @FocusState private var isFocused: Bool
    @State private var showQuickSuggestions = false
    @State private var pillOpacities: [Double] = [0, 0, 0, 0]
    @State private var pillScales: [CGFloat] = [0.8, 0.8, 0.8, 0.8]
    @State private var currentGlowColor = Color(red: 1.0, green: 0.55, blue: 0.26) // Amber initial
    @State private var isAnimating = false
    @State private var showBookSearch = false
    @State private var textEditorHeight: CGFloat = 36
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Animation namespace for matched geometry
    var animationNamespace: Namespace.ID
    
    let suggestions = [
        ("Note", "note: ", "Add a quick thought"),
        ("Quote", "\"", "Save a memorable quote"),
        ("Book", "add book ", "Add to your library"),
        ("Search", "search ", "Find in your library")
    ]
    
    // Optional initial content for editing
    let initialContent: String?
    let editingNote: Note?
    let onUpdate: ((Note) -> Void)?
    
    init(isPresented: Binding<Bool>, animationNamespace: Namespace.ID, initialContent: String? = nil, editingNote: Note? = nil, onUpdate: ((Note) -> Void)? = nil) {
        self._isPresented = isPresented
        self.animationNamespace = animationNamespace
        self.initialContent = initialContent
        self.editingNote = editingNote
        self.onUpdate = onUpdate
    }
    
    private var showActionButton: Bool {
        !commandText.isEmpty && detectedIntent != .unknown
    }
    
    var body: some View {
        ZStack {
            // Invisible backdrop to catch taps
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissPalette()
                }
            
            VStack {
                Spacer()
                
                // Quick suggestions pills floating above
                if showQuickSuggestions {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                                let (title, prefix, _) = suggestion
                                Button {
                                    commandText = prefix
                                    // Hide all pills with staggered animation
                                    for i in (0..<suggestions.count).reversed() {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                            pillOpacities[i] = 0
                                            pillScales[i] = 0.8
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showQuickSuggestions = false
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: iconForTitle(title))
                                            .font(.system(size: 14, weight: .medium))
                                        Text(title)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular.tint(colorForTitle(title).opacity(0.4)), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        colorForTitle(title).opacity(0.5),
                                                        colorForTitle(title).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    }
                                    .shadow(color: colorForTitle(title).opacity(0.2), radius: 8, y: 4)
                                }
                                .opacity(pillOpacities[index])
                                .scaleEffect(pillScales[index])
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 40)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .padding(.bottom, 8)
                }
                
                // iMessage-style input bar
                HStack(spacing: 8) {
                    // Plus button (left side)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showQuickSuggestions.toggle()
                            if showQuickSuggestions {
                                // Show pills with staggered animation
                                for i in 0..<suggestions.count {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(Double(i) * 0.05)) {
                                        pillOpacities[i] = 1
                                        pillScales[i] = 1
                                    }
                                }
                            } else {
                                // Hide pills
                                for i in (0..<suggestions.count).reversed() {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                        pillOpacities[i] = 0
                                        pillScales[i] = 0.8
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: Circle())
                    }
                    
                    // Input field container with glass effect
                    HStack(spacing: 0) {
                        // Question mark icon
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(currentGlowColor)
                            .font(.system(size: 20, weight: .medium))
                            .padding(.leading, 12)
                            .padding(.trailing, 8)
                        
                        // Text field
                        ZStack(alignment: .leading) {
                            if commandText.isEmpty {
                                Text(editingNote != nil ? "Edit your note..." : "What's on your mind?")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $commandText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .focused($isFocused)
                                .lineLimit(1...5)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onChange(of: commandText) { _, newValue in
                                    // Hide suggestions when user starts typing
                                    if !newValue.isEmpty && showQuickSuggestions {
                                        showQuickSuggestions = false
                                        for i in (0..<suggestions.count).reversed() {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(suggestions.count - i - 1) * 0.05)) {
                                                pillOpacities[i] = 0
                                                pillScales[i] = 0.8
                                            }
                                        }
                                    }
                                    
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.trailing, 12)
                    }
                    .frame(minHeight: 36)
                    .glassEffect(.regular.tint(currentGlowColor.opacity(0.15)), in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        currentGlowColor.opacity(0.3),
                                        currentGlowColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    
                    // Send button (appears when there's text and valid intent)
                    if showActionButton {
                        Button {
                            executeCommand()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white, currentGlowColor)
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
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
            
            // Auto-focus immediately
            isFocused = true
            
            // Pills are hidden initially - only show when plus button is tapped
        }
        .onDisappear {
            // Clear on dismiss
            isFocused = false
            isAnimating = false
            showQuickSuggestions = false
            // Reset pill states
            pillOpacities = [0, 0, 0, 0]
            pillScales = [0.8, 0.8, 0.8, 0.8]
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: {
                    if case .addBook(let query) = detectedIntent {
                        return query
                    }
                    return commandText
                }(),
                onBookSelected: { book in
                    libraryViewModel.addBook(book)
                    HapticManager.shared.success()
                    dismissPalette()
                }
            )
        }
    }
    
    private func iconForTitle(_ title: String) -> String {
        switch title {
        case "Note": return "note.text"
        case "Quote": return "quote.opening"
        case "Book": return "book"
        case "Search": return "magnifyingglass"
        default: return "circle"
        }
    }
    
    private func colorForTitle(_ title: String) -> Color {
        switch title {
        case "Note": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Quote": return Color(red: 1.0, green: 0.55, blue: 0.26)
        case "Book": return Color(red: 0.6, green: 0.4, blue: 0.8)
        case "Search": return Color(red: 0.3, green: 0.7, blue: 0.5)
        default: return .gray
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
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isPresented = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            // Show book search sheet
            showBookSearch = true
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
