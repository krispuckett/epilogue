import SwiftUI
import SwiftData

// MARK: - Multi-Modal Chat Input Bar
struct MultiModalChatInputBar: View {
    @Binding var navigationPath: NavigationPath
    @State private var inputText = ""
    @State private var detectedIntent: DetectedIntent = .unknown
    @State private var isAmbientModeActive = false
    @State private var showingBookPicker = false
    @State private var isExpanded = false
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    
    enum DetectedIntent {
        case unknown
        case question
        case note
        case quote
        case bookSearch
        
        var color: Color {
            switch self {
            case .question: return Color.warmAmber
            case .note: return Color(red: 0.6, green: 0.8, blue: 1.0)
            case .quote: return Color(red: 1.0, green: 0.75, blue: 0.5)
            case .bookSearch: return Color(red: 0.8, green: 0.6, blue: 1.0)
            case .unknown: return Color.white.opacity(0.5)
            }
        }
        
        var icon: String {
            switch self {
            case .question: return "questionmark.circle"
            case .note: return "note.text"
            case .quote: return "quote.bubble"
            case .bookSearch: return "book"
            case .unknown: return "sparkles"
            }
        }
        
        var label: String {
            switch self {
            case .question: return "Question"
            case .note: return "Note"
            case .quote: return "Quote"
            case .bookSearch: return "Book Search"
            case .unknown: return "General"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Intent pills when typing
            if isExpanded && detectedIntent != .unknown {
                HStack {
                    IntentPill(intent: detectedIntent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main input bar
            HStack(spacing: 8) {
                // Microphone button (left)
                Button {
                    HapticManager.shared.mediumTap()
                    isAmbientModeActive = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.warmAmber.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.warmAmber)
                    }
                }
                .glassEffect(in: Circle())
                
                // Text input field
                HStack(spacing: 8) {
                    TextField("Ask, note, or quote...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                        .onChange(of: inputText) { _, newValue in
                            detectIntent(from: newValue)
                        }
                        .onSubmit {
                            handleSubmit()
                        }
                    
                    if !inputText.isEmpty {
                        // Send button
                        Button {
                            handleSubmit()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white, detectedIntent.color)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Book picker button
                        Button {
                            showingBookPicker = true
                        } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.warmAmber.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            detectedIntent != .unknown ? detectedIntent.color.opacity(0.3) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inputText.isEmpty)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: detectedIntent)
        }
        .onChange(of: isTextFieldFocused) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded = newValue
            }
        }
        .fullScreenCover(isPresented: $isAmbientModeActive) {
            AmbientChatOverlay(
                isActive: $isAmbientModeActive,
                selectedBook: .constant(nil),
                session: .constant(nil)
            )
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet { book in
                handleBookSelection(book)
            }
            .environmentObject(libraryViewModel)
        }
    }
    
    // MARK: - Intent Detection
    private func detectIntent(from text: String) {
        let lowercased = text.lowercased()
        
        // Question patterns
        if lowercased.contains("?") || 
           lowercased.starts(with: "what") ||
           lowercased.starts(with: "why") ||
           lowercased.starts(with: "how") ||
           lowercased.starts(with: "when") ||
           lowercased.starts(with: "who") ||
           lowercased.starts(with: "where") ||
           lowercased.starts(with: "is") ||
           lowercased.starts(with: "are") ||
           lowercased.starts(with: "can") ||
           lowercased.starts(with: "should") {
            detectedIntent = .question
        }
        // Quote patterns
        else if lowercased.contains("\"") || 
                lowercased.contains("\u{201C}") ||
                lowercased.contains("\u{201D}") ||
                lowercased.starts(with: "quote:") ||
                lowercased.contains("said") ||
                lowercased.contains("wrote") {
            detectedIntent = .quote
        }
        // Book search patterns
        else if lowercased.contains("book") ||
                lowercased.contains("recommend") ||
                lowercased.contains("reading") ||
                lowercased.contains("author") ||
                lowercased.contains("genre") {
            detectedIntent = .bookSearch
        }
        // Note patterns (default for declarative statements)
        else if !text.isEmpty {
            detectedIntent = .note
        } else {
            detectedIntent = .unknown
        }
    }
    
    // MARK: - Actions
    private func handleSubmit() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        HapticManager.shared.lightTap()
        
        // Route to appropriate handler based on intent
        switch detectedIntent {
        case .question, .bookSearch:
            // Create or navigate to general chat thread
            navigateToGeneralChat(with: inputText)
        case .note, .quote:
            // Create a note/quote directly
            createNoteFromInput()
        case .unknown:
            // Default to chat
            navigateToGeneralChat(with: inputText)
        }
        
        // Reset
        inputText = ""
        detectedIntent = .unknown
        isTextFieldFocused = false
    }
    
    private func navigateToGeneralChat(with message: String) {
        // Find or create general chat thread
        let descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate { thread in
                thread.bookId == nil
            }
        )
        
        do {
            let threads = try modelContext.fetch(descriptor)
            let generalThread = threads.first ?? ChatThread()
            
            if threads.isEmpty {
                modelContext.insert(generalThread)
            }
            
            // Add the message
            let chatMessage = ThreadedChatMessage(
                content: message,
                isUser: true,
                timestamp: Date()
            )
            generalThread.messages.append(chatMessage)
            generalThread.lastMessageDate = Date()
            
            try? modelContext.save()
            
            // Navigate
            navigationPath.append(generalThread)
        } catch {
            print("Error accessing threads: \(error)")
        }
    }
    
    private func createNoteFromInput() {
        // This would create a note directly
        // Implementation depends on your notes system
        print("Creating note: \(inputText)")
    }
    
    private func handleBookSelection(_ book: Book) {
        // Find or create book chat thread
        let bookId = book.localId
        let descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate { thread in
                thread.bookId == bookId
            }
        )
        
        do {
            let threads = try modelContext.fetch(descriptor)
            let bookThread = threads.first ?? ChatThread(book: book)
            
            if threads.isEmpty {
                modelContext.insert(bookThread)
                try? modelContext.save()
            }
            
            // Navigate
            navigationPath.append(bookThread)
        } catch {
            print("Error accessing threads: \(error)")
        }
        
        showingBookPicker = false
    }
}

// MARK: - Intent Pill
struct IntentPill: View {
    let intent: MultiModalChatInputBar.DetectedIntent
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: intent.icon)
                .font(.system(size: 12, weight: .medium))
            Text(intent.label)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(intent.color.opacity(0.2))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(intent.color.opacity(0.4), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}