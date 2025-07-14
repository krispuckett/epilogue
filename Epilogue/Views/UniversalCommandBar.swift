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
                    Button(action: saveNote) {
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
        
        let newNote = Note(
            type: noteType,
            content: trimmedContent,
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
    @FocusState private var isFocused: Bool
    @Namespace private var animation
    @Namespace private var tabSelection
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Suggestions overlay - positioned above the command bar
            if isExpanded && showSuggestions {
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
                // Expanded command bar
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
                            .onChange(of: commandText) { _, new in
                                detectedIntent = CommandParser.parse(new)
                                suggestions = CommandSuggestion.suggestions(for: new)
                                showSuggestions = !new.isEmpty
                                
                                // Check if user is typing "note" to trigger composer
                                if new.lowercased().starts(with: "note") && new.count > 4 && !showNoteComposer {
                                    // Extract any text after "note:" or "note "
                                    if new.lowercased().starts(with: "note:") {
                                        noteComposerText = String(new.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                    } else if new.lowercased().starts(with: "note ") {
                                        noteComposerText = String(new.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                                    } else {
                                        noteComposerText = ""
                                    }
                                    
                                    // Trigger composer after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if commandText.lowercased().starts(with: "note") && commandText.count > 4 && !showNoteComposer {
                                            showNoteComposer = true
                                            isFocused = false
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
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
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                // Ensure focus happens after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        .overlay {
            // Note composer overlay
            if showNoteComposer {
                NoteComposerView(
                    isPresented: $showNoteComposer,
                    initialText: $noteComposerText,
                    noteType: .note
                ) { note in
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.0, anchor: .bottom)),
                    removal: .opacity
                ))
                .zIndex(100)
            }
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
        // For now, let's just save quotes directly without the composer
        // This could be enhanced to use the composer for quotes as well
        var cleanedText = text
        if cleanedText.lowercased().starts(with: "quote:") {
            cleanedText = String(cleanedText.dropFirst(6))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespaces)
        
        // Remove surrounding quotes if present
        if cleanedText.hasPrefix("\"") && cleanedText.hasSuffix("\"") {
            cleanedText = String(cleanedText.dropFirst().dropLast())
        }
        
        // Create and save the quote
        let newNote = Note(
            type: .quote,
            content: cleanedText,
            bookTitle: nil,
            author: nil,
            pageNumber: nil,
            dateCreated: Date()
        )
        
        // Add to notes view model
        notesViewModel.addNote(newNote)
        
        // Navigate to Notes tab
        selectedTab = 1
        
        HapticManager.shared.success()
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
