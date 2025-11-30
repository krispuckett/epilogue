import SwiftUI

// MARK: - Redesigned Liquid Command Palette
struct LiquidCommandPaletteV2: View {
    @Binding var isPresented: Bool
    @State private var commandText = ""
    @State private var showingSuggestions = true
    @FocusState private var isFocused: Bool
    
    // Animation states
    @State private var backdropOpacity: Double = 0
    @State private var cardScale: Double = 0.9
    @State private var cardOpacity: Double = 0
    
    // Search and commands
    @State private var searchResults: [SearchResult] = []
    @State private var recentCommands: [String] = []
    
    // Environment
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    // Context
    let context: CommandContext
    let onComplete: ((CommandResult) -> Void)?
    
    enum CommandContext {
        case library
        case bookDetail(Book)
        case notes
        case quickCapture
    }
    
    enum CommandResult {
        case note(String)
        case richTextNote
        case quote(String, attribution: String?)
        case bookAdded(Book)
        case search(String)
        case cancel
    }
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let type: ResultType
        let title: String
        let subtitle: String?
        let icon: String
        let action: () -> Void
        
        enum ResultType {
            case command
            case book
            case note
            case suggestion
        }
    }
    
    init(isPresented: Binding<Bool>, 
         context: CommandContext = .library,
         onComplete: ((CommandResult) -> Void)? = nil) {
        self._isPresented = isPresented
        self.context = context
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPalette()
                }
            
            // Main palette card
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100) // Space from top
                
                paletteCard
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            showPalette()
            loadRecentCommands()
        }
    }
    
    // MARK: - Palette Card
    private var paletteCard: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Search/Command Input
            inputField
            
            // Results/Suggestions
            if showingSuggestions {
                suggestionsList
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Input Field (No Background!)
    private var inputField: some View {
        HStack(spacing: 12) {
            // Context indicator
            contextIcon
            
            // Text input - Clean, no background
            ZStack(alignment: .leading) {
                if commandText.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                TextField("", text: $commandText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .accentColor(DesignSystem.Colors.primaryAccent)
                    .focused($isFocused)
                    .lineLimit(1...3)
                    .onSubmit {
                        processCommand()
                    }
                    .onChange(of: commandText) { _, newValue in
                        updateSearchResults(for: newValue)
                    }
            }
            
            // Submit button only - NO VOICE
            Button {
                processCommand()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(commandText.isEmpty ?
                        Color.white.opacity(0.2) : DesignSystem.Colors.primaryAccent)
            }
            .disabled(commandText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Context Icon
    private var contextIcon: some View {
        Group {
            switch context {
            case .library:
                Image(systemName: "books.vertical")
            case .bookDetail(let book):
                // Show book initial or icon
                Text(String(book.title.prefix(1)))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            case .notes:
                Image(systemName: "note.text")
            case .quickCapture:
                Image(systemName: "bolt")
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(DesignSystem.Colors.primaryAccent)
        .frame(width: 28, height: 28)
        .glassEffect(in: Circle())
    }
    
    // MARK: - Suggestions List
    private var suggestionsList: some View {
        ScrollView {
            VStack(spacing: 1) {
                // Commands section
                if !commandSuggestions.isEmpty {
                    sectionHeader("QUICK ACTIONS")
                    ForEach(commandSuggestions) { result in
                        resultRow(result)
                    }
                }
                
                // Recent commands
                if !recentCommands.isEmpty && commandText.isEmpty {
                    sectionHeader("RECENT")
                    ForEach(recentCommands, id: \.self) { command in
                        recentCommandRow(command)
                    }
                }
                
                // Search results
                if !searchResults.isEmpty {
                    sectionHeader("RESULTS")
                    ForEach(searchResults) { result in
                        resultRow(result)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Result Row
    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            result.action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: result.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor(for: result.type))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    
                    if let subtitle = result.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if result.type == .command {
                    Text("⌘")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
    
    // MARK: - Recent Command Row
    private func recentCommandRow(_ command: String) -> some View {
        Button {
            commandText = command
        } label: {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 28)
                
                Text(command)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidRowButtonStyle())
    }
    
    // MARK: - Helpers
    private var placeholderText: String {
        switch context {
        case .library:
            return "Search, add books, or capture thoughts..."
        case .bookDetail(let book):
            return "Note about \(book.title)..."
        case .notes:
            return "Search or create notes..."
        case .quickCapture:
            return "Quick capture..."
        }
    }
    
    private var commandSuggestions: [SearchResult] {
        var suggestions: [SearchResult] = []

        // Ask Epilogue - only show when NOT in book detail context
        // Book-specific ambient is accessed via the ambient icon in book views
        if case .bookDetail = context {
            // Don't show generic ambient option in book context
        } else {
            suggestions.append(SearchResult(
                type: .command,
                title: "Ask Epilogue",
                subtitle: "Recommendations, reading plans, insights",
                icon: "sparkles",
                action: { launchGenericAmbient() }
            ))
        }

        // Standard commands
        suggestions.append(contentsOf: [
            SearchResult(
                type: .command,
                title: "New Note",
                subtitle: "Capture a thought",
                icon: "note.text",
                action: { startNote() }
            ),
            SearchResult(
                type: .command,
                title: "New Quote",
                subtitle: "Save a passage",
                icon: "quote.opening",
                action: { startQuote() }
            ),
            SearchResult(
                type: .command,
                title: "Add Book",
                subtitle: "Add to library",
                icon: "plus.circle",
                action: { startBookAdd() }
            )
        ])

        return suggestions
    }
    
    private func iconColor(for type: SearchResult.ResultType) -> Color {
        switch type {
        case .command:
            return DesignSystem.Colors.primaryAccent
        case .book:
            return .blue
        case .note:
            return .green
        case .suggestion:
            return .white.opacity(0.6)
        }
    }
    
    // MARK: - Actions
    private func showPalette() {
        withAnimation(.easeOut(duration: 0.2)) {
            backdropOpacity = 0.4
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.05)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isFocused = true
        }
    }
    
    private func dismissPalette() {
        isFocused = false
        
        withAnimation(.easeIn(duration: 0.15)) {
            cardScale = 0.95
            cardOpacity = 0
            backdropOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            onComplete?(.cancel)
        }
    }
    
    private func processCommand() {
        let text = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Save to recent commands
        saveRecentCommand(text)
        
        // Process based on content
        if text.hasPrefix("\"") || text.contains("\"") {
            // Quote
            let processed = CommandParser.parseQuote(text)
            onComplete?(.quote(processed.0, attribution: processed.1))
        } else if text.hasPrefix("note:") || text.hasPrefix("n:") {
            // Note
            let noteText = text.replacingOccurrences(of: "note:", with: "")
                               .replacingOccurrences(of: "n:", with: "")
                               .trimmingCharacters(in: .whitespacesAndNewlines)
            onComplete?(.note(noteText))
        } else {
            // Default to note
            onComplete?(.note(text))
        }
        
        SensoryFeedback.success()
        dismissPalette()
    }
    
    
    private func updateSearchResults(for query: String) {
        // Implement search logic
        searchResults = []
        
        if !query.isEmpty {
            // Search books
            let matchingBooks = libraryViewModel.books.filter { book in
                book.title.localizedCaseInsensitiveContains(query) ||
                book.author.localizedCaseInsensitiveContains(query)
            }.prefix(3)
            
            searchResults += matchingBooks.map { book in
                SearchResult(
                    type: .book,
                    title: book.title,
                    subtitle: book.author,
                    icon: "book",
                    action: { 
                        NotificationCenter.default.post(
                            name: Notification.Name("NavigateToBook"),
                            object: book
                        )
                        dismissPalette()
                    }
                )
            }
        }
    }
    
    private func startNote() {
        commandText = "note: "
    }

    private func startQuote() {
        commandText = "\""
    }

    private func startBookAdd() {
        commandText = "add book "
    }

    /// Launch generic ambient mode from command palette
    private func launchGenericAmbient() {
        // Dismiss palette first
        dismissPalette()

        // Small delay to allow palette dismissal animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Launch generic ambient mode via coordinator
            EpilogueAmbientCoordinator.shared.launchGenericMode()
        }
    }
    
    private func loadRecentCommands() {
        recentCommands = UserDefaults.standard.stringArray(forKey: "recentCommands") ?? []
    }
    
    private func saveRecentCommand(_ command: String) {
        var recent = UserDefaults.standard.stringArray(forKey: "recentCommands") ?? []
        recent.insert(command, at: 0)
        recent = Array(recent.prefix(5))
        UserDefaults.standard.set(recent, forKey: "recentCommands")
    }
}

// MARK: - Button Style
struct LiquidRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(configuration.isPressed ? 0.05 : 0.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Integration Helper
extension View {
    func liquidCommandPalette(
        isPresented: Binding<Bool>,
        context: LiquidCommandPaletteV2.CommandContext = .library,
        onComplete: ((LiquidCommandPaletteV2.CommandResult) -> Void)? = nil
    ) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                LiquidCommandPaletteV2(
                    isPresented: isPresented,
                    context: context,
                    onComplete: onComplete
                )
                .environmentObject(LibraryViewModel())
                .environmentObject(NotesViewModel())
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.black, Color.indigo.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        Text("Background Content")
            .foregroundStyle(.white)
    }
    .liquidCommandPalette(
        isPresented: .constant(true),
        context: .library
    ) { result in
        #if DEBUG
        print("Command result: \(result)")
        #endif
    }
}
