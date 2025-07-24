import SwiftUI
import SwiftData

// MARK: - Liquid Glass Book Detail View
struct LiquidGlassBookDetailView: View {
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
    @State private var coverImage: UIImage?
    @State private var colorAnalysis: BookCoverAnalyzer.ColorAnalysis?
    @State private var isAnalyzing = true
    
    // Edit book states
    @State private var showingBookSearch = false
    @State private var editedTitle = ""
    
    @StateObject private var coverAnalyzer = BookCoverAnalyzer()
    
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
            // Liquid Glass Background System
            if let analysis = colorAnalysis {
                LiquidGlassBackground(
                    colorPalette: analysis.palette,
                    strategy: analysis.strategy,
                    scrollOffset: scrollOffset
                )
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 1.0)))
            } else {
                // Loading state background
                LoadingGlassBackground()
                    .ignoresSafeArea()
            }
            
            // Main content with proper glass integration
            ScrollView {
                VStack(spacing: 0) {
                    // Header with book info
                    glassHeaderView
                        .padding(.top, 20)
                    
                    // Summary section with glass
                    if let description = book.description {
                        glassSummarySection(description: description)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                    }
                    
                    // Content sections
                    glassContentView
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                }
            }
            .overlay(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                }
            )
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("Edit")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        editedTitle = book.title
                        showingBookSearch = true
                    }
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
            loadAndAnalyzeCover()
            findOrCreateThreadForBook()
        }
    }
    
    // MARK: - Glass Header View
    private var glassHeaderView: some View {
        VStack(spacing: 16) {
            // Book Cover with glass enhancement
            Group {
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                } else {
                    SharedBookCoverView(
                        coverURL: book.coverImageURL,
                        width: 180,
                        height: 270
                    )
                }
            }
            .rotation3DEffect(
                Angle(degrees: 5),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(1 + (scrollOffset > 0 ? scrollOffset / 1000 : 0))
            
            // Title with adaptive text
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .adaptiveGlassText(luminance: colorAnalysis?.luminanceMap.averageLuminance ?? 0.5)
            
            // Author(s)
            VStack(spacing: 4) {
                let authors = book.author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if authors.count == 1 {
                    Text("by \(book.author)")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("by")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(.tertiary)
                    
                    ForEach(authors, id: \.self) { author in
                        Text(author)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, -8)
            .adaptiveGlassText(luminance: colorAnalysis?.luminanceMap.averageLuminance ?? 0.5)
            
            // Status and info with glass pills
            HStack(spacing: 16) {
                // Reading status
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
                                    .foregroundColor(status == book.readingStatus ? accentColor : .secondary)
                            }
                        }
                    }
                } label: {
                    GlassStatusPill(
                        text: book.readingStatus.rawValue,
                        color: accentColor,
                        interactive: true
                    )
                }
                
                if let pageCount = book.pageCount {
                    Text("\(book.currentPage) of \(pageCount) pages")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                if let rating = book.userRating {
                    GlassStatusPill(
                        text: "★ \(rating)",
                        color: accentColor.opacity(0.8)
                    )
                }
            }
            .padding(.top, 8)
            
            // Segmented control with glass
            glassSegmentedControl
                .padding(.top, 20)
        }
    }
    
    // MARK: - Glass Summary Section
    private func glassSummarySection(description: String) -> some View {
        GlassSectionContainer(title: nil) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    
                    Text("Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        summaryExpanded.toggle()
                    }
                }
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineSpacing(8)
                    .lineLimit(summaryExpanded ? nil : 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: summaryExpanded)
                
                if !summaryExpanded && description.count > 200 {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                summaryExpanded = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Read more")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(accentColor)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Glass Segmented Control
    private var glassSegmentedControl: some View {
        HStack(spacing: 20) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSection = section
                    }
                } label: {
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .fill(Material.thin)
                                .opacity(selectedSection == section ? 0.8 : 0)
                                .matchedGeometryEffect(
                                    id: "iconSelection",
                                    in: sectionAnimation,
                                    isSource: selectedSection == section
                                )
                        )
                        .glassEffect()
                }
            }
        }
    }
    
    // MARK: - Glass Content View
    private var glassContentView: some View {
        Group {
            switch selectedSection {
            case .notes:
                glassNotesSection
            case .quotes:
                glassQuotesSection
            case .chat:
                glassChatSection
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }
    
    // MARK: - Glass Notes Section
    private var glassNotesSection: some View {
        VStack(spacing: 16) {
            if bookNotes.isEmpty {
                GlassEmptyStateView(
                    icon: "note.text",
                    title: "No notes yet",
                    subtitle: "Use the command bar below to add a note"
                )
            } else {
                ForEach(bookNotes) { note in
                    GlassNoteCard(note: note)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
        }
    }
    
    // MARK: - Glass Quotes Section
    private var glassQuotesSection: some View {
        VStack(spacing: 16) {
            if bookQuotes.isEmpty {
                GlassEmptyStateView(
                    icon: "quote.opening",
                    title: "No quotes yet",
                    subtitle: "Use the command bar below to add a quote"
                )
            } else {
                ForEach(bookQuotes) { quote in
                    GlassQuoteCard(quote: quote)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
        }
    }
    
    // MARK: - Glass Chat Section
    private var glassChatSection: some View {
        VStack(spacing: 0) {
            if let thread = bookThread {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if thread.messages.isEmpty {
                                GlassChatWelcome(book: book)
                            }
                            
                            ForEach(thread.messages) { message in
                                GlassChatBubble(
                                    message: message,
                                    accentColor: accentColor
                                )
                                .padding(.horizontal, 24)
                                .id(message.id)
                            }
                            
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
                
                // Glass input bar
                GlassChatInputBar(
                    messageText: $messageText,
                    isInputFocused: _isInputFocused,
                    accentColor: accentColor,
                    onSend: sendMessage
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            } else {
                ProgressView()
                    .tint(accentColor)
                    .padding(.vertical, 60)
            }
        }
    }
    
    // MARK: - Computed Properties
    var bookQuotes: [Note] {
        notesViewModel.notes.filter { note in
            note.type == .quote && (
                (note.bookId != nil && note.bookId == book.localId) ||
                (note.bookId == nil && note.bookTitle == book.title)
            )
        }
    }
    
    var bookNotes: [Note] {
        notesViewModel.notes.filter { note in
            note.type == .note && (
                (note.bookId != nil && note.bookId == book.localId) ||
                (note.bookId == nil && note.bookTitle == book.title)
            )
        }
    }
    
    var accentColor: Color {
        colorAnalysis?.palette.glass.first ?? 
        colorAnalysis?.palette.primary.first ?? 
        .blue
    }
    
    // MARK: - Helper Methods
    private func loadAndAnalyzeCover() {
        Task {
            // Load cover image
            if let coverURL = book.coverImageURL,
               let url = URL(string: coverURL) {
                
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.coverImage = image
                    }
                    
                    // Analyze cover
                    let analysis = await coverAnalyzer.analyzeCover(image)
                    
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            self.colorAnalysis = analysis
                            self.isAnalyzing = false
                        }
                    }
                }
            }
        }
    }
    
    private func findOrCreateThreadForBook() {
        if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
            bookThread = existingThread
        } else {
            let newThread = ChatThread(book: book)
            modelContext.insert(newThread)
            try? modelContext.save()
            bookThread = newThread
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let thread = bookThread else { return }
        
        let userMessage = ThreadedChatMessage(
            content: messageText,
            isUser: true,
            bookTitle: book.title,
            bookAuthor: book.author
        )
        
        thread.messages.append(userMessage)
        thread.lastMessageDate = Date()
        
        messageText = ""
        
        try? modelContext.save()
        
        // Simulate AI response
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
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
}

// MARK: - Supporting Glass Components

struct GlassStatusPill: View {
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
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct GlassEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .glassSection(cornerRadius: 24)
    }
}

struct GlassNoteCard: View {
    let note: Note
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.content)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
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
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let pageNumber = note.pageNumber {
                    Text("Page \(pageNumber)")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassSection()
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        _ = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct GlassQuoteCard: View {
    let quote: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(.secondary.opacity(0.3))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            Text(quote.content)
                .font(.custom("Georgia", size: 24))
                .foregroundStyle(.primary)
                .lineSpacing(11)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    if let author = quote.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let pageNumber = quote.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(32)
        .glassSection()
    }
}

struct GlassChatWelcome: View {
    let book: Book
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Ask me about this book")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
            
            Text("I can help you explore themes, characters, or discuss any aspect of \"\(book.title)\"")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
        .glassSection(cornerRadius: 24)
    }
}

struct GlassChatBubble: View {
    let message: ThreadedChatMessage
    let accentColor: Color
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isUser ? accentColor.opacity(0.2) : Color.white.opacity(0.1))
                    )
                    .glassEffect()
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct GlassChatInputBar: View {
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool
    let accentColor: Color
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about this book...", text: $messageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                )
                .focused($isInputFocused)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? accentColor.opacity(0.3) : accentColor)
            }
            .disabled(messageText.isEmpty)
        }
    }
}

struct LoadingGlassBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: sin(phase + Double(index) * .pi / 3) * 50,
                        y: cos(phase + Double(index) * .pi / 3) * 50
                    )
                    .blur(radius: 20)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}