import SwiftUI
import SwiftData

// MARK: - Intelligent Command Palette with @mentions
struct IntelligentCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var commandText: String
    @FocusState private var isFocused: Bool
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.modelContext) private var modelContext
    
    // Intelligent state
    @State private var showingBookMentions = false
    @State private var mentionQuery = ""
    @State private var mentionSuggestions: [Book] = []
    @State private var parsedIntent: CommandIntent = .unknown
    @State private var cursorPosition: Int = 0
    
    // UI state
    @State private var dragOffset: CGFloat = 0
    
    // Real-time command suggestions
    private var suggestions: [CommandSuggestion] {
        generateSmartSuggestions()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Enhanced input field with @mention support
            VStack(spacing: 12) {
                // Input field with real-time parsing
                HStack(spacing: 12) {
                    // Command icon that changes based on parsed intent
                    Image(systemName: parsedIntent.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(parsedIntent.color)
                        .frame(width: 24)
                        .contentTransition(.symbolEffect(.replace))
                    
                    // Text field
                    TextField("Try: 'Add Dune and Foundation' or 'Note @1984 about...'", text: $commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .focused($isFocused)
                        .onChange(of: commandText) { _, newValue in
                            handleTextChange(newValue)
                        }
                        .onSubmit {
                            executeCommand()
                        }
                    
                    // Action button (changes based on parsed intent)
                    if !commandText.isEmpty {
                        Button {
                            executeCommand()
                        } label: {
                            Text(parsedIntent.actionText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect()
                                .clipShape(Capsule())
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 12)
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                
                // Real-time command preview
                if !commandText.isEmpty && parsedIntent != .unknown {
                    CommandPreviewCard(intent: parsedIntent)
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            
            // @Book mention suggestions
            if showingBookMentions && !mentionSuggestions.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Books matching '@\(mentionQuery)'")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 8)
                    
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(mentionSuggestions, id: \.localId) { book in
                                BookMentionRow(book: book) {
                                    insertBookMention(book)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    }
                    .frame(maxHeight: 200)
                }
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
            
            // Smart suggestions
            if commandText.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Smart Suggestions")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    
                    VStack(spacing: 4) {
                        ForEach(suggestions) { suggestion in
                            SmartSuggestionRow(suggestion: suggestion) {
                                commandText = suggestion.text
                                handleTextChange(suggestion.text)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                }
                .padding(.vertical, 12)
            }
            
            // Examples section
            if commandText.isEmpty {
                ExamplesSection()
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.bottom, 16)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        dismissPalette()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            isFocused = true
        }
        .animation(DesignSystem.Animation.springStandard, value: showingBookMentions)
        .animation(DesignSystem.Animation.springStandard, value: parsedIntent)
    }
    
    // MARK: - Text Change Handler
    private func handleTextChange(_ newValue: String) {
        // Parse the command in real-time
        parsedIntent = CommandParser.parse(newValue, books: libraryViewModel.books, notes: notesViewModel.notes)
        
        // Detect @mentions
        if let atIndex = newValue.lastIndex(of: "@") {
            let afterAt = String(newValue[newValue.index(after: atIndex)...])
            
            // Only show suggestions if we're still typing the mention
            if !afterAt.contains(" ") && !afterAt.isEmpty {
                mentionQuery = afterAt
                mentionSuggestions = BookMentionParser.getSuggestions(
                    for: afterAt,
                    books: libraryViewModel.books,
                    limit: 5
                )
                showingBookMentions = true
            } else {
                showingBookMentions = false
            }
        } else {
            showingBookMentions = false
        }
    }
    
    // MARK: - Insert Book Mention
    private func insertBookMention(_ book: Book) {
        if let atIndex = commandText.lastIndex(of: "@") {
            let beforeAt = String(commandText[..<atIndex])
            commandText = beforeAt + "@" + book.title + " "
            showingBookMentions = false
            mentionQuery = ""
        }
    }
    
    // MARK: - Execute Command
    private func executeCommand() {
        guard !commandText.isEmpty else { return }
        
        // Parse the command to determine intent
        let intent = CommandParser.parse(commandText, books: libraryViewModel.books, notes: notesViewModel.notes)
        
        // Save the command text before clearing
        let savedCommand = commandText
        
        // Haptic feedback
        SensoryFeedback.success()
        
        // Clear command text and dismiss FIRST
        commandText = ""
        dismissPalette()
        
        // Then process the command after a delay to ensure palette is fully dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let processor = CommandProcessingManager(
                modelContext: modelContext,
                libraryViewModel: libraryViewModel,
                notesViewModel: notesViewModel
            )
            
            processor.processInlineCommand(savedCommand)
        }
    }
    
    // MARK: - Generate Smart Suggestions
    private func generateSmartSuggestions() -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []
        
        // Time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 || hour < 6 {
            suggestions.append(CommandSuggestion(
                text: "Update reading progress",
                icon: "book.pages",
                intent: .searchAll(query: "progress"),
                description: "Record tonight's reading"
            ))
        }
        
        // Recent books suggestions
        if let recentBook = libraryViewModel.books.first {
            suggestions.append(CommandSuggestion(
                text: "Add note @\(recentBook.title)",
                icon: "note.text",
                intent: .createNoteWithBook(text: "", book: recentBook),
                description: "Quick thought about your current read"
            ))
        }
        
        // Common actions
        suggestions.append(CommandSuggestion(
            text: "Add Dune and Foundation to library",
            icon: "plus.circle",
            intent: .batchAddBooks(["Dune", "Foundation"]),
            description: "Add multiple books at once"
        ))
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        suggestions.append(CommandSuggestion(
            text: "Remind me to read tomorrow at 8pm",
            icon: "bell.badge",
            intent: .createReminder(text: "Time to read", date: tomorrow),
            description: "Set a reading reminder"
        ))
        
        return suggestions
    }
    
    private func dismissPalette() {
        withAnimation(.spring()) {
            isPresented = false
        }
    }
}

// MARK: - Command Preview Card
struct CommandPreviewCard: View {
    let intent: CommandIntent
    
    var body: some View {
        HStack {
            Image(systemName: intent.icon)
                .font(.system(size: 20))
                .foregroundStyle(intent.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(previewTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = previewSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    private var previewTitle: String {
        switch intent {
        case .createNoteWithBook(_, let book):
            return "Save note to \(book.title)"
        case .createQuoteWithBook(_, let book):
            return "Save quote from \(book.title)"
        case .multiStepCommand(let commands):
            return "\(commands.count) actions will be executed"
        case .createReminder(let text, let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "Reminder: \(formatter.string(from: date))"
        case .setReadingGoal(let book, let pages):
            return "\(pages) pages/day for \(book.title)"
        case .batchAddBooks(let titles):
            return "Add \(titles.count) books"
        default:
            return intent.actionText
        }
    }
    
    private var previewSubtitle: String? {
        switch intent {
        case .multiStepCommand:
            return "Tap Enter to execute all"
        case .createReminder(let text, _):
            return text
        default:
            return nil
        }
    }
}

// MARK: - Book Mention Row
struct BookMentionRow: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book cover thumbnail
                if let coverURL = book.coverImageURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                    }
                    .frame(width: 28, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.2))
                        .frame(width: 28, height: 42)
                        .overlay(
                            Text(String(book.title.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.primaryAccent)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Smart Suggestion Row
struct SmartSuggestionRow: View {
    let suggestion: CommandSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let description = suggestion.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Examples Section
struct ExamplesSection: View {
    let examples = [
        ("@1984", "Tag a book"),
        ("add Dune and Foundation", "Multiple books"),
        ("remind me tomorrow", "Natural dates"),
        ("20 pages daily @Hobbit", "Reading goals")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(examples, id: \.0) { example, description in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.primaryAccent)
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .glassEffect()
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                }
            }
        }
    }
}

// Note: CommandSuggestion is now defined in CommandIntent.swift