import SwiftUI
import SwiftData
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Models
struct BookQuestion: Identifiable {
    let id = UUID()
    let question: String
    let answer: String?
    let timestamp: Date
    let bookTitle: String
    let bookAuthor: String
}

// MARK: - Color Extensions
extension Color {
    static let midnightScholar = Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
    static let warmWhite = Color(red: 0.98, green: 0.97, blue: 0.96) // #FAF8F5
    static let warmAmber = Color(red: 1.0, green: 0.549, blue: 0.259) // #FF8C42
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Helper Extensions
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
}

struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedSection: BookSection = .notes
    @Namespace private var sectionAnimation
    
    // Chat integration
    @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @State private var bookThread: ChatThread?
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    // UI States
    @State private var summaryExpanded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var textColor: Color = .white
    @State private var backgroundBrightness: Double = 0.5
    @State private var accentColor: Color = Color(red: 1.0, green: 0.8, blue: 0.0) // Default yellow/gold
    
    private var secondaryTextColor: Color {
        textColor.opacity(0.8)
    }
    
    // Edit book states
    @State private var showingBookSearch = false
    @State private var editedTitle = ""
    @State private var isEditingTitle = false
    
    // Computed properties for filtering notes by book
    var bookQuotes: [Note] {
        notesViewModel.notes.filter { note in
            note.type == .quote && (
                // Primary: match by bookId if available
                (note.bookId != nil && note.bookId == book.localId) ||
                // Fallback: match by title for legacy notes
                (note.bookId == nil && note.bookTitle == book.title)
            )
        }
    }
    
    var bookNotes: [Note] {
        notesViewModel.notes.filter { note in
            note.type == .note && (
                // Primary: match by bookId if available
                (note.bookId != nil && note.bookId == book.localId) ||
                // Fallback: match by title for legacy notes
                (note.bookId == nil && note.bookTitle == book.title)
            )
        }
    }
    
    enum BookSection: String, CaseIterable {
        case notes = "Notes"
        case quotes = "Quotes"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .notes: return "note.text"
            case .quotes: return "quote.opening"
            case .chat: return "bubble.left.and.bubble.right.fill"
            }
        }
    }
    
    
    var body: some View {
        ZStack {
            // Simple ambient background
            AmbientBookView(book: book, scrollOffset: $scrollOffset, textColor: $textColor)
                .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Book info section
                    centeredHeaderView
                        .padding(.horizontal, 20)
                    
                    // Summary section
                    if let description = book.description {
                        summarySection(description: description)
                            .padding(.horizontal, 24)  // THIS IS THE KEY!
                            .padding(.top, 32)
                    }
                    
                    // Content sections
                    contentView
                        .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 100)  // Space for tab bar
            }
            .background(GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
            })
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit Book") {
                    editedTitle = book.title
                    showingBookSearch = true
                    HapticManager.shared.lightTap()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityLabel("Edit book details")
                .accessibilityHint("Opens book search to change book information")
                // No background, glassEffect, or overlay!
            }
        }
        .sheet(isPresented: $showingBookSearch) {
            EditBookSheet(
                currentBook: book,
                initialSearchTerm: editedTitle,
                onBookReplaced: { newBook in
                    libraryViewModel.replaceBook(originalBook: book, with: newBook)
                    showingBookSearch = false
                }
            )
            .environmentObject(libraryViewModel)
        }
        .onAppear {
            findOrCreateThreadForBook()
        }
    }
    
    private var centeredHeaderView: some View {
        VStack(spacing: 16) {
            // Book Cover with 3D effect
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 180,
                height: 270
            )
            .accessibilityLabel("Book cover for \(book.title)")
            .rotation3DEffect(
                Angle(degrees: 5),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(1 + (scrollOffset > 0 ? scrollOffset / 1000 : 0))
            
            // Title - dynamic color with adaptive shadow
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Author(s) - Handle multiple authors by splitting on comma
            VStack(spacing: 4) {
                let authors = book.author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if authors.count == 1 {
                    Text("by \(book.author)")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundColor(textColor.opacity(0.8))
                        } else {
                    Text("by")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundColor(textColor.opacity(0.7))
                            
                    ForEach(authors, id: \.self) { author in
                        Text(author)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundColor(textColor.opacity(0.8))
                                }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, -8)
            
            // Status and page info
            HStack(spacing: 16) {
                // Interactive reading status dropdown
                Menu {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                libraryViewModel.updateReadingStatus(for: book.id, status: status)
                                HapticManager.shared.lightTap()
                            }
                        } label: {
                            Label {
                                Text(status.rawValue)
                            } icon: {
                                Image(systemName: status == book.readingStatus ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .tint(accentColor)
                    }
                } label: {
                    StatusPill(text: book.readingStatus.rawValue, color: accentColor, interactive: true)
                }
                .accessibilityLabel("Reading status: \(book.readingStatus.rawValue). Tap to change.")
                
                if let pageCount = book.pageCount {
                    Text("\(book.currentPage) of \(pageCount) pages")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.7))
                                .accessibilityLabel("Progress: \(book.currentPage) of \(pageCount) pages")
                }
                
                if let rating = book.userRating {
                    StatusPill(text: "★ \(rating)", color: accentColor.opacity(0.8))
                        .accessibilityLabel("Rating: \(rating) stars")
                }
            }
            .padding(.top, 8)
            
            // Icon-only segmented control
            iconOnlySegmentedControl
                .padding(.top, 20)
        }
    }
    
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(section.rawValue)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(selectedSection == section ? textColor : secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background {
                        if selectedSection == section {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.warmAmber.opacity(0.15))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.warmAmber.opacity(0.3), lineWidth: 1)
                                }
                                .shadow(color: Color.warmAmber.opacity(0.3), radius: 6)
                                .matchedGeometryEffect(id: "sectionSelection", in: sectionAnimation)
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
    
    private var iconOnlySegmentedControl: some View {
        HStack(spacing: 20) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSection = section
                    }
                } label: {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(selectedSection == section ? accentColor : textColor.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background {
                            if selectedSection == section {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .matchedGeometryEffect(id: "iconSelection", in: sectionAnimation)
                            }
                        }
                }
                .accessibilityLabel("\(section.rawValue) section")
                .accessibilityHint(selectedSection == section ? "Currently selected" : "Tap to select")
            }
        }
    }
    
    private var contentView: some View {
        Group {
            switch selectedSection {
            case .notes:
                notesSection
            case .quotes:
                quotesSection
            case .chat:
                chatSection
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }
    
    private func summarySection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Summary", systemImage: "book.pages")
                .font(.headline)
                .foregroundColor(textColor.opacity(0.9))
            
            Text(description)
                .font(.body)
                .foregroundColor(textColor.opacity(0.8))
                .lineSpacing(4)
                .lineLimit(summaryExpanded ? nil : 4)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: summaryExpanded)
            
            // Read more/less button
            if description.count > 200 {
                Button {
                    withAnimation {
                        summaryExpanded.toggle()
                    }
                } label: {
                    Text(summaryExpanded ? "Read less" : "Read more")
                        .font(.caption)
                        .foregroundColor(accentColor)
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                }
        }
    }
    
    private var quotesSection: some View {
        VStack(spacing: 16) {
            if bookQuotes.isEmpty {
                emptyStateView(
                    icon: "quote.opening",
                    title: "No quotes yet",
                    subtitle: "Use the command bar below to add a quote"
                )
            } else {
                ForEach(bookQuotes) { quote in
                    BookQuoteCard(quote: quote)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    notesViewModel.deleteNote(quote)
                                    HapticManager.shared.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(spacing: 16) {
            if bookNotes.isEmpty {
                emptyStateView(
                    icon: "note.text",
                    title: "No notes yet",
                    subtitle: "Use the command bar below to add a note"
                )
            } else {
                ForEach(bookNotes) { note in
                    BookNoteCard(note: note)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    notesViewModel.deleteNote(note)
                                    HapticManager.shared.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
    
    private var chatSection: some View {
        VStack(spacing: 0) {
            if let thread = bookThread {
                // Messages ScrollView
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Welcome message
                            if thread.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(accentColor.opacity(0.6))
                                    
                                    Text("Ask me about this book")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(textColor.opacity(0.8))
                                    
                                    Text("I can help you explore themes, characters, or discuss any aspect of \"\(book.title)\"")
                                        .font(.system(size: 14))
                                        .foregroundColor(textColor.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.vertical, 60)
                            }
                            
                            // Messages
                            ForEach(thread.messages) { message in
                                ChatMessageBubble(message: message, accentColor: accentColor, textColor: textColor)
                                    .id(message.id)
                            }
                            
                            // Spacer for input
                            Color.clear
                                .frame(height: 20)
                                .id("bottom")
                        }
                    }
                    .onChange(of: thread.messages.count) { _, _ in
                        withAnimation {
                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
                // Input field
                HStack(spacing: 12) {
                    TextField("Ask about this book...", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? accentColor.opacity(0.3) : accentColor)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.vertical, 16)
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(accentColor)
                    Text("Setting up chat...")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .padding(.vertical, 60)
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(accentColor.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor.opacity(0.7))
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Chat Functions
    
    private func findOrCreateThreadForBook() {
        // Check if thread already exists for this book
        if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
            bookThread = existingThread
        } else {
            // Create new thread for this book
            let newThread = ChatThread(book: book)
            modelContext.insert(newThread)
            try? modelContext.save()
            bookThread = newThread
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let thread = bookThread else { return }
        
        // Create user message
        let userMessage = ThreadedChatMessage(
            content: messageText,
            isUser: true,
            bookTitle: book.title,
            bookAuthor: book.author
        )
        
        thread.messages.append(userMessage)
        thread.lastMessageDate = Date()
        
        // Clear input
        messageText = ""
        
        // Save context
        try? modelContext.save()
        
        // Simulate AI response (in real app, this would call an API)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            let aiResponse = ThreadedChatMessage(
                content: "I'd be happy to discuss \"\(book.title)\" with you. What aspects of the book would you like to explore?",
                isUser: false,
                bookTitle: book.title,
                bookAuthor: book.author
            )
            
            await MainActor.run {
                thread.messages.append(aiResponse)
                thread.lastMessageDate = Date()
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Color Extraction
    
    
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let icon: String
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(textColor.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(textColor.opacity(0.1))
                )
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var interactive: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
            
            if interactive {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        }
    }
}

struct BookQuoteCard: View {
    let quote: Note
    @State private var isExpanded = false
    
    var firstLetter: String {
        String(quote.content.prefix(1))
    }
    
    var restOfContent: String {
        String(quote.content.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large transparent opening quote
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: 56))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .lineSpacing(11) // Line height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            
            // Attribution section
            VStack(alignment: .leading, spacing: 12) {
                // Thin horizontal rule with gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 0),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(1.0), location: 0.5),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 20)
                
                // Attribution text - reordered: Author -> Source -> Page
                VStack(alignment: .leading, spacing: 6) {
                    if let author = quote.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.8))
                    }
                    
                    if let bookTitle = quote.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.6))
                    }
                    
                    if let pageNumber = quote.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.5))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.96)) // #FAF8F5
                .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
}

struct BookNoteCard: View {
    let note: Note
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.content)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
            
            HStack {
                Text(formatRelativeDate(note.dateCreated))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.black.opacity(0.5))
                
                Spacer()
                
                if let pageNumber = note.pageNumber {
                    Text("Page \(pageNumber)")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "FAF8F5"))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday evening"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "\(formatter.string(from: date)) evening"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct QuestionCard: View {
    let question: BookQuestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.warmAmber)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.question)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))
                        .lineLimit(2)
                    
                    if let answer = question.answer {
                        Text(answer)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.black.opacity(0.6))
                            .lineLimit(3)
                            .padding(.top, 4)
                    }
                    
                    Text("Tap to view conversation →")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.warmAmber.opacity(0.8))
                        .padding(.top, 2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "FAF8F5"))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
        .onTapGesture {
            // TODO: Navigate to chat view with this question context
        }
    }
}

struct ChatMessageBubble: View {
    let message: ThreadedChatMessage
    let accentColor: Color
    let textColor: Color
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(message.isUser ? .white : .black.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? accentColor : Color(hex: "FAF8F5"))
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Preview

struct BookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BookDetailView(
                book: Book(
                    id: "1",
                    title: "The Great Gatsby",
                    author: "F. Scott Fitzgerald",
                    publishedYear: "1925",
                    coverImageURL: nil,
                    isbn: "9780743273565",
                    description: "A classic American novel set in the Jazz Age on Long Island. The story primarily concerns the young and mysterious millionaire Jay Gatsby and his quixotic passion and obsession with the beautiful former debutante Daisy Buchanan.",
                    pageCount: 180,
                    localId: UUID()
                )
            )
        }
        .preferredColorScheme(.dark)
        .environmentObject(NotesViewModel())
        .environmentObject(LibraryViewModel())
        .modelContainer(for: [ChatThread.self])
    }
}
