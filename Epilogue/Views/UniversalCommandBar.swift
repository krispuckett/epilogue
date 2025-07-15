import SwiftUI
import UIKit

// MARK: - Note Composer View
struct NoteComposerView: View {
    @Binding var isPresented: Bool
    @Binding var initialText: String
    let noteType: NoteType
    let onSave: (Note) -> Void
    
    @State private var noteContent: String = ""
    @State private var selectedBook: Book? = nil
    @FocusState private var isTextFieldFocused: Bool
    @State private var animateIn = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .opacity(animateIn ? 1 : 0)
                    .onTapGesture {
                        dismissComposer()
                    }
                
                // Note composer drawer - 3/4 height
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Text editor
                    VStack(alignment: .leading, spacing: 12) {
                        // Text editor with placeholder
                        ZStack(alignment: .topLeading) {
                            if noteContent.isEmpty {
                                Text(noteType == .quote ? "Enter a memorable quote..." : "What's on your mind?")
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
                                .frame(maxHeight: .infinity)
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
                    .padding(.bottom, 12)
                    
                    // Save button near keyboard
                    Button(action: {
                        saveNote()
                    }) {
                        HStack {
                            Text("Save \(noteType.displayName)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(height: geometry.size.height * 0.75) // 3/4 height
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
                .offset(y: animateIn ? 0 : geometry.size.height)
                }
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
        let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse attribution for notes
        var finalContent = trimmedContent
        var finalAuthor: String? = selectedBook?.author
        var finalBookTitle: String? = selectedBook?.title
        var bookId: UUID? = selectedBook?.localId
        
        // For notes, use content as-is for now
        // Attribution parsing is handled in the command bar
        
        let newNote = Note(
            type: noteType,
            content: finalContent,
            bookId: bookId,
            bookTitle: finalBookTitle,
            author: finalAuthor,
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

// MARK: - Haptic Feedback Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func lightTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func softFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Literary Loading Components
struct LiteraryQuote {
    let text: String
    let author: String
}

struct LiteraryQuotes {
    static let loadingQuotes: [LiteraryQuote] = [
        LiteraryQuote(text: "A room without books is like a body without a soul", author: "Cicero"),
        LiteraryQuote(text: "So many books, so little time", author: "Frank Zappa"),
        LiteraryQuote(text: "Books are a uniquely portable magic", author: "Stephen King"),
        LiteraryQuote(text: "A reader lives a thousand lives before he dies", author: "George R.R. Martin"),
        LiteraryQuote(text: "The more that you read, the more things you will know", author: "Dr. Seuss"),
        LiteraryQuote(text: "Reading is to the mind what exercise is to the body", author: "Joseph Addison")
    ]
    
    static func randomQuote() -> LiteraryQuote {
        return loadingQuotes.randomElement() ?? loadingQuotes[0]
    }
}

struct LiteraryLoadingView: View {
    let message: String?
    @State private var currentQuote: LiteraryQuote
    @State private var rotationAngle: Double = 0
    @State private var quoteOpacity: Double = 0
    
    init(message: String? = nil) {
        self.message = message
        self._currentQuote = State(initialValue: LiteraryQuotes.randomQuote())
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Warm amber spinner
            ZStack {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.26),
                                Color(red: 1.0, green: 0.7, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }
            
            // Loading message if provided
            if let message = message {
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
            }
            
            // Literary quote with Georgia italic
            VStack(spacing: 8) {
                Text(currentQuote.text)
                    .font(.custom("Georgia", size: 15))
                    .italic()
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text("— \(currentQuote.author)")
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7))
            }
            .opacity(quoteOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                    quoteOpacity = 1
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Reading Progress Indicator
struct ReadingProgressIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let width: CGFloat
    @State private var animateProgress = false
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    var progressText: String {
        return "\(currentPage) of \(totalPages)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress text
            Text(progressText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
            
            // Amber bookmark ribbon progress bar
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width, height: 2)
                    .clipShape(Capsule())
                
                // Progress fill with bookmark ribbon effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.7, blue: 0.3), // Bright amber
                                Color(red: 1.0, green: 0.55, blue: 0.26) // Deep amber
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: animateProgress ? width * progress : 0, height: 2)
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), radius: 2, y: 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Book Progress Extension
extension Book {
    var currentPage: Int {
        guard let totalPages = pageCount, totalPages > 0 else { return 0 }
        
        switch readingStatus {
        case .wantToRead:
            return 0
        case .currentlyReading:
            return Int.random(in: 10...(totalPages - 50))
        case .finished:
            return totalPages
        }
    }
}


struct UniversalCommandBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var isExpanded = false
    @State private var commandText = ""
    @State private var detectedIntent: CommandIntent = .unknown
    @State private var showBookSearch = false
    @State private var suggestions: [CommandSuggestion] = []
    @State private var showSuggestions = false
    @State private var showNoteComposer = false
    @State private var noteComposerText = ""
    @State private var showQuoteComposer = false
    @State private var quoteComposerText = ""
    @State private var composerMode: ComposerMode = .none
    @FocusState private var isFocused: Bool
    @Namespace private var animation
    @Namespace private var tabSelection
    @Namespace private var glassTransition
    
    enum ComposerMode {
        case none
        case note
        case quote
    }
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Suggestions overlay - positioned above the command bar (but below composer)
            if isExpanded && showSuggestions && composerMode == .none {
                VStack {
                    Spacer()
                    CommandSuggestionsView(suggestions: suggestions) { suggestion in
                        commandText = suggestion.text
                        detectedIntent = suggestion.intent
                        executeCommand()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Adjusted for proper positioning
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
            
            // Main content that switches between tab bar and command bar
            if isExpanded {
                // Check if we're in composer mode
                if composerMode != .none {
                    // Composer view with glass effect transition - this will be on top
                    InlineComposerView(
                        mode: $composerMode,
                        text: $commandText,
                        onSave: saveComposition,
                        onCancel: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                composerMode = .none
                                commandText = ""
                                collapse()
                            }
                        }
                    )
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .glassEffectID("composer", in: glassTransition)
                    .padding(.horizontal, 16)
                    .zIndex(1) // Ensure composer is above suggestions
                } else {
                    // Regular expanded command bar
                    HStack(spacing: 12) {
                        // Collapse button
                        Button(action: collapse) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(in: Circle())
                    
                    // Command input field
                    HStack(spacing: 12) {
                        Image(systemName: detectedIntent.icon)
                            .foregroundStyle(detectedIntent.color)
                            .font(.system(size: 20))
                            .animation(.spring(response: 0.3), value: detectedIntent)
                        
                        TextField("What's on your mind?", text: $commandText)
                            .textFieldStyle(.plain)
                            .font(.bodyLarge)
                            .foregroundStyle(.white)
                            .focused($isFocused)
                            .onChange(of: commandText) {
                                // Auto-convert em-dash to long em-dash
                                var updatedText = commandText
                                if updatedText.contains("–") {
                                    updatedText = updatedText.replacingOccurrences(of: "–", with: "—")
                                    commandText = updatedText
                                }
                                
                                detectedIntent = CommandParser.parse(updatedText)
                                suggestions = CommandSuggestion.suggestions(for: updatedText)
                                showSuggestions = !updatedText.isEmpty
                                
                                // Check if user is typing a command that needs composer
                                if composerMode == .none {
                                    if updatedText.lowercased().starts(with: "note") && updatedText.count > 4 {
                                        // Extract any text after "note:" or "note "
                                        var composerText = ""
                                        if updatedText.lowercased().starts(with: "note:") {
                                            composerText = String(updatedText.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                        } else if updatedText.lowercased().starts(with: "note ") {
                                            composerText = String(updatedText.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                        }
                                        
                                        // Smoothly transition to note composer
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            composerMode = .note
                                            commandText = composerText
                                        }
                                    } else if case .createQuote = detectedIntent {
                                        // Smoothly transition to quote composer
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            composerMode = .quote
                                        }
                                    }
                                }
                            }
                            .onSubmit {
                                // Don't execute if we're about to show the composer
                                if !showNoteComposer {
                                    executeCommand()
                                }
                            }
                        
                        if !commandText.isEmpty {
                            Button(action: executeCommand) {
                                Text(detectedIntent.actionText)
                                    .font(.labelMedium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(detectedIntent.color)
                                    .clipShape(Capsule())
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .glassEffectID("commandbar", in: glassTransition)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
            } else {
                // Normal state - tab bar with floating orb
                HStack(spacing: 12) {
                    // Tab bar
                    HStack(spacing: 0) {
                        TabBarItem(
                            icon: "books.vertical",
                            label: "Library",
                            isSelected: selectedTab == 0,
                            namespace: tabSelection
                        ) {
                            selectedTab = 0
                        }
                        
                        TabBarItem(
                            icon: "note.text",
                            label: "Notes",
                            isSelected: selectedTab == 1,
                            namespace: tabSelection
                        ) {
                            selectedTab = 1
                        }
                        
                        TabBarItem(
                            icon: "message",
                            label: "Chat",
                            isSelected: selectedTab == 2,
                            namespace: tabSelection
                        ) {
                            selectedTab = 2
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 32))
                    
                    // Plus button - smaller floating orb
                    Button(action: expand) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                            
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .glassEffect(in: Circle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: showSuggestions)
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: CommandParser.parse(commandText).bookQuery ?? commandText,
                onBookSelected: { book in
                    libraryViewModel.addBook(book)
                }
            )
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                // Ensure focus happens after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        // Using inline composer instead of sheet presentation
        /*
        .sheet(isPresented: $showNoteComposer) {
            EditNoteSheet(
                note: Note(
                    type: .note,
                    content: noteComposerText,
                    bookTitle: nil,
                    author: nil,
                    pageNumber: nil,
                    dateCreated: Date()
                ),
                onSave: { note in
                    // Save the note
                    notesViewModel.addNote(note)
                    
                    // Navigate to Notes tab
                    selectedTab = 1
                    
                    // Reset command bar
                    commandText = ""
                    noteComposerText = ""
                    collapse()
                    
                    // Reset any filters in NotesView
                    NotificationCenter.default.post(name: Notification.Name("ResetNotesFilter"), object: nil)
                }
            )
            .presentationBackground(.regularMaterial)
        }
        */
        .sheet(isPresented: $showQuoteComposer) {
            EditNoteSheet(
                note: Note(
                    type: .quote,
                    content: quoteComposerText,
                    bookTitle: nil,
                    author: nil,
                    pageNumber: nil,
                    dateCreated: Date()
                ),
                onSave: { note in
                    // Save the quote
                    notesViewModel.addNote(note)
                    
                    // Navigate to Notes tab
                    selectedTab = 1
                    
                    // Reset
                    quoteComposerText = ""
                    
                    HapticManager.shared.success()
                }
            )
            .presentationBackground(.regularMaterial)
        }
    }
    
    // MARK: - Actions
    
    private func expand() {
        HapticManager.shared.mediumImpact()
        withAnimation {
            isExpanded = true
        }
    }
    
    private func collapse() {
        withAnimation {
            isExpanded = false
            commandText = ""
            detectedIntent = .unknown
            isFocused = false
            showSuggestions = false
        }
    }
    
    private func executeCommand() {
        HapticManager.shared.lightTap()
        switch detectedIntent {
        case .addBook:
            showBookSearch = true
        case .createQuote(let text):
            saveQuote(text)
        case .createNote(let text):
            saveNote(text)
        case .searchLibrary(let query):
            searchLibrary(query)
        case .unknown:
            break
        }
    }
    
    private func saveQuote(_ text: String) {
        // Parse the quote to extract content and author
        let parsed = CommandParser.parseQuote(text)
        
        // Remove quotation marks from content since they're implied in the design
        var cleanContent = parsed.content
        if (cleanContent.hasPrefix("\"") && cleanContent.hasSuffix("\"")) ||
           (cleanContent.hasPrefix("\u{201C}") && cleanContent.hasSuffix("\u{201D}")) {
            cleanContent = String(cleanContent.dropFirst().dropLast())
        }
        
        // Set the text and show composer
        quoteComposerText = cleanContent
        
        // Check if author contains the special separator for book info
        var authorText: String? = nil
        var bookText: String? = nil
        var pageText: String? = nil
        
        if let author = parsed.author {
            if author.contains("|||BOOK|||") {
                // Split into author, book, and possibly page
                let parts = author.split(separator: "|||")
                
                // First part is author
                if parts.count > 0 {
                    authorText = String(parts[0])
                }
                
                // Look for BOOK marker
                for i in 0..<parts.count-1 {
                    if parts[i] == "BOOK" && i+1 < parts.count {
                        bookText = String(parts[i+1])
                    }
                    if parts[i] == "PAGE" && i+1 < parts.count {
                        pageText = String(parts[i+1])
                    }
                }
            } else {
                authorText = author
            }
        }
        
        // Create the quote text in the format EditNoteSheet expects
        // Include author, book, and page as separate lines
        if let author = authorText {
            quoteComposerText = "\(cleanContent)\n\n— \(author)"
            if let book = bookText {
                quoteComposerText += "\n\(book)"
            }
            if let page = pageText {
                quoteComposerText += "\n\(page)"
            }
        }
        
        showQuoteComposer = true
        collapse()
    }
    
    private func saveNote(_ text: String) {
        // Trigger the note composer instead of directly saving
        noteComposerText = text
        
        // Clean the initial text
        let prefixes = ["note:", "thought:", "idea:"]
        for prefix in prefixes {
            if noteComposerText.lowercased().starts(with: prefix) {
                noteComposerText = String(noteComposerText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        showNoteComposer = true
        isFocused = false
    }
    
    private func searchLibrary(_ query: String) {
        // Switch to library tab and set search
        selectedTab = 0
        
        // TODO: Implement search in LibraryView
        collapse()
    }
    
    private func parseNoteAttribution(_ text: String) -> (content: String, author: String?, bookTitle: String?) {
        // Check for pattern: "content - Author, Book Title"
        let attributionPattern = "^(.+?)\\s*-\\s*([^,]+)(?:,\\s*(.+))?$"
        
        if let regex = try? NSRegularExpression(pattern: attributionPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                // Check if this looks like attribution (not just a dash in the middle of content)
                if let contentRange = Range(match.range(at: 1), in: text),
                   let authorRange = Range(match.range(at: 2), in: text) {
                    
                    let possibleContent = String(text[contentRange]).trimmingCharacters(in: .whitespaces)
                    let possibleAuthor = String(text[authorRange]).trimmingCharacters(in: .whitespaces)
                    
                    // Only parse as attribution if author part looks like a name (not too long, no periods)
                    if possibleAuthor.split(separator: " ").count <= 4 && !possibleAuthor.contains(".") {
                        var bookTitle: String? = nil
                        
                        if match.range(at: 3).location != NSNotFound,
                           let bookRange = Range(match.range(at: 3), in: text) {
                            bookTitle = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
                        }
                        
                        return (content: possibleContent, author: possibleAuthor, bookTitle: bookTitle)
                    }
                }
            }
        }
        
        return (content: text, author: nil, bookTitle: nil)
    }
    
    private func parseFullTextForQuote(_ text: String) -> (content: String, author: String?, bookTitle: String?, pageNumber: Int?) {
        var workingText = text
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        // Check if this is a quote format: "content" author, book, page
        print("🔍 Attempting to parse quote from: \(text)")
        
        // Debug: Check what quote characters we have
        if let firstChar = text.first {
            print("📊 First character: '\(firstChar)' (Unicode: U+\(String(format: "%04X", firstChar.unicodeScalars.first!.value)))")
        }
        
        // Try multiple quote patterns - ORDER MATTERS!
        let quotePatterns = [
            "^\"(.+?)\"\\s*(.+)$",                          // Regular double quotes (ASCII 34)
            "^[\u{201C}](.+?)[\u{201D}]\\s*(.+)$",         // Smart quotes left and right
            "^'(.+?)'\\s*(.+)$",                            // Single quotes
            "^[\u{2018}](.+?)[\u{2019}]\\s*(.+)$"          // Smart single quotes
        ]
        
        for (index, pattern) in quotePatterns.enumerated() {
            print("🧪 Trying pattern \(index + 1): \(pattern)")
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(location: 0, length: text.utf16.count)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if let contentRange = Range(match.range(at: 1), in: text),
                       let attributionRange = Range(match.range(at: 2), in: text) {
                        // Extract the quote content (without quotes)
                        let quoteContent = String(text[contentRange]).trimmingCharacters(in: .whitespaces)
                        let attribution = String(text[attributionRange]).trimmingCharacters(in: .whitespaces)
                        
                        print("✅ Matched! Content: '\(quoteContent)', Attribution: '\(attribution)'")
                        
                        // Parse the attribution
                        // First check if it uses comma separation
                        if attribution.contains(",") {
                            // Parse comma-separated format: "Seneca, On the Shortness of Life, pg 30"
                            let parts = attribution.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            
                            if parts.count >= 1 {
                                author = parts[0]
                            }
                            if parts.count >= 2 {
                                var bookTitleText = parts[1]
                                
                                // Check if the book title contains page info (e.g., "Lord of the Rings pg 400")
                                let pageInBookPattern = #"^(.+?)\s+(pg|p\.|page)\s+(\d+)$"#
                                if let regex = try? NSRegularExpression(pattern: pageInBookPattern, options: .caseInsensitive) {
                                    let range = NSRange(location: 0, length: bookTitleText.utf16.count)
                                    if let match = regex.firstMatch(in: bookTitleText, options: [], range: range) {
                                        if let titleRange = Range(match.range(at: 1), in: bookTitleText),
                                           let pageRange = Range(match.range(at: 3), in: bookTitleText) {
                                            bookTitle = String(bookTitleText[titleRange]).trimmingCharacters(in: .whitespaces)
                                            pageNumber = Int(String(bookTitleText[pageRange]))
                                        }
                                    } else {
                                        bookTitle = bookTitleText
                                    }
                                } else {
                                    bookTitle = bookTitleText
                                }
                            }
                            if parts.count >= 3 {
                                let pageStr = parts[2]
                                // Only extract page if we didn't already get it from book title
                                if pageNumber == nil {
                                    // Extract page number from strings like "pg 30", "p. 30", "page 30"
                                    if let pageMatch = pageStr.range(of: #"\d+"#, options: .regularExpression) {
                                        pageNumber = Int(pageStr[pageMatch])
                                    }
                                }
                            }
                        } else {
                            // Parse space-separated format with dash: "- Gandalf Lord of the Rings pg 230"
                            var cleanAttribution = attribution
                            
                            // Remove leading dash if present
                            if cleanAttribution.hasPrefix("-") {
                                cleanAttribution = String(cleanAttribution.dropFirst()).trimmingCharacters(in: .whitespaces)
                            }
                            
                            // Try to parse "Author BookTitle pg 123" format
                            let attributionPattern = #"^(\S+)\s+(.+?)\s+(pg|p\.|page)\s+(\d+)$"#
                            if let regex = try? NSRegularExpression(pattern: attributionPattern, options: .caseInsensitive) {
                                let range = NSRange(location: 0, length: cleanAttribution.utf16.count)
                                if let match = regex.firstMatch(in: cleanAttribution, options: [], range: range) {
                                    if let authorRange = Range(match.range(at: 1), in: cleanAttribution),
                                       let titleRange = Range(match.range(at: 2), in: cleanAttribution),
                                       let pageRange = Range(match.range(at: 4), in: cleanAttribution) {
                                        author = String(cleanAttribution[authorRange])
                                        bookTitle = String(cleanAttribution[titleRange])
                                        pageNumber = Int(String(cleanAttribution[pageRange]))
                                    }
                                }
                            } else {
                                // Fallback: just try to find the first word as author and rest as book
                                let words = cleanAttribution.split(separator: " ", maxSplits: 1).map(String.init)
                                if words.count >= 2 {
                                    author = words[0]
                                    bookTitle = words[1]
                                    
                                    // Try to extract page from book title
                                    let pageInBookPattern = #"^(.+?)\s+(pg|p\.|page)\s+(\d+)$"#
                                    if let regex = try? NSRegularExpression(pattern: pageInBookPattern, options: .caseInsensitive) {
                                        let range = NSRange(location: 0, length: bookTitle!.utf16.count)
                                        if let match = regex.firstMatch(in: bookTitle!, options: [], range: range) {
                                            if let titleRange = Range(match.range(at: 1), in: bookTitle!),
                                               let pageRange = Range(match.range(at: 3), in: bookTitle!) {
                                                let extractedTitle = String(bookTitle![titleRange]).trimmingCharacters(in: .whitespaces)
                                                pageNumber = Int(String(bookTitle![pageRange]))
                                                bookTitle = extractedTitle
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        print("📚 Parsed - Author: \(author ?? "nil"), Book: \(bookTitle ?? "nil"), Page: \(pageNumber?.description ?? "nil")")
                        
                        return (content: quoteContent, author: author, bookTitle: bookTitle, pageNumber: pageNumber)
                    }
                }
            }
        }
        
        print("❌ No quote pattern matched")
        
        // If no quote pattern matched, return the original text as content
        return (content: text, author: nil, bookTitle: nil, pageNumber: nil)
    }
    
    private func saveComposition() {
        switch composerMode {
        case .note:
            let parsed = parseNoteAttribution(commandText)
            
            // Try to match with a book in the library
            var matchedBook: Book? = nil
            if let bookTitle = parsed.bookTitle {
                matchedBook = libraryViewModel.findMatchingBook(title: bookTitle, author: parsed.author)
            }
            
            let note = Note(
                type: .note,
                content: parsed.content,
                bookId: matchedBook?.localId,
                bookTitle: matchedBook?.title ?? parsed.bookTitle,
                author: matchedBook?.author ?? parsed.author,
                pageNumber: nil,
                dateCreated: Date()
            )
            
            notesViewModel.addNote(note)
            
            // Link note to book if matched
            if let book = matchedBook {
                libraryViewModel.addNoteToBook(book.localId, note: note)
            }
            
            HapticManager.shared.success()
            
        case .quote:
            let parsed = parseFullTextForQuote(commandText)
            
            print("📝 Quote parsed - Content: '\(parsed.content)', Author: '\(parsed.author ?? "nil")', Book: '\(parsed.bookTitle ?? "nil")', Page: \(parsed.pageNumber?.description ?? "nil")")
            
            // Try to match with a book in the library
            var matchedBook: Book? = nil
            if let bookTitle = parsed.bookTitle {
                print("🔍 Attempting to match book title: '\(bookTitle)' with author: '\(parsed.author ?? "nil")'")
                matchedBook = libraryViewModel.findMatchingBook(title: bookTitle, author: parsed.author)
                if let book = matchedBook {
                    print("✅ Found matching book: '\(book.title)' by '\(book.author)'")
                } else {
                    print("❌ No matching book found in library")
                }
            }
            
            let note = Note(
                type: .quote,
                content: parsed.content,
                bookId: matchedBook?.localId,
                bookTitle: matchedBook?.title ?? parsed.bookTitle,
                author: matchedBook?.author ?? parsed.author,
                pageNumber: parsed.pageNumber,
                dateCreated: Date()
            )
            
            notesViewModel.addNote(note)
            
            // Link note to book if matched
            if let book = matchedBook {
                libraryViewModel.addNoteToBook(book.localId, note: note)
            }
            
            HapticManager.shared.success()
            
        case .none:
            break
        }
        
        // Navigate to Notes tab
        selectedTab = 1
        
        // Reset any filters in NotesView
        NotificationCenter.default.post(name: Notification.Name("ResetNotesFilter"), object: nil)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            composerMode = .none
            commandText = ""
            collapse()
        }
    }
}

// MARK: - Inline Composer View
struct InlineComposerView: View {
    @Binding var mode: UniversalCommandBar.ComposerMode
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text(mode == .note ? "New Note" : "New Quote")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: onSave) {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Text editor
            TextField(
                mode == .note ? "What's on your mind?" : "Enter a memorable quote...",
                text: $text,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .focused($isFocused)
            .lineLimit(3...10)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(.clear)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 56)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: 56)
                                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
                        }
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 6)
                        .matchedGeometryEffect(id: "tabSelection", in: namespace)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}



// MARK: - Extensions
extension CommandIntent {
    var bookQuery: String? {
        switch self {
        case .addBook(let query):
            return query
        default:
            return nil
        }
    }
}

#Preview {
    ZStack {
        // Colorful gradient background to test glass effects
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.2, blue: 0.5),
                Color(red: 0.3, green: 0.1, blue: 0.4),
                Color(red: 0.2, green: 0.3, blue: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            UniversalCommandBar(selectedTab: .constant(0))
        }
        .environmentObject(LibraryViewModel())
        .environmentObject(NotesViewModel())
    }
}
