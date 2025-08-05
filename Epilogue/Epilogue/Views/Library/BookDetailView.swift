import SwiftUI
import SwiftData
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import UIImageColors

// MARK: - Models
struct BookQuestion: Identifiable {
    let id = UUID()
    let question: String
    let answer: String?
    let timestamp: Date
    let bookTitle: String
    let bookAuthor: String
}

struct BookColorScheme {
    var textColor: Color = .white
    var secondaryTextColor: Color = .white.opacity(0.8)
    var accentColor: Color = .orange
    var isLoading: Bool = true
    
    static let loading = BookColorScheme()
    
    static func from(palette: AmbientPalette) -> BookColorScheme {
        let shouldUseDarkText = palette.luminance > 0.65
        
        return BookColorScheme(
            textColor: shouldUseDarkText ? .black : .white,
            secondaryTextColor: shouldUseDarkText ? .black.opacity(0.7) : .white.opacity(0.8),
            accentColor: palette.colors.first ?? .orange,
            isLoading: false
        )
    }
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

// MARK: - Helper Extensions removed (already defined in AmbientReadingProgressView)

struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedSection: BookSection = .notes
    @Namespace private var sectionAnimation
    
    // Chat integration - DISABLED (ChatThread removed)
    // @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // @State private var bookThread: ChatThread?
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    // UI States
    @State private var summaryExpanded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var coverImage: UIImage? = nil
    @State private var hasAppeared = false
    
    // Dynamic gradient opacity based on scroll
    private var gradientOpacity: Double {
        // Fixed calculation - no more crazy values
        let opacity = 1.0 - (min(scrollOffset, 200) / 200)
        return max(0.2, opacity)
    }
    
    // Color extraction
    @State private var colorPalette: ColorPalette?
    @State private var isExtractingColors = false
    @State private var hasLowResColors = false
    @State private var hasHighResColors = false
    // Remove DisplayColorScheme - we don't need it
    
    // Fixed colors for Claude voice mode style (always white text on dark background)
    private var textColor: Color {
        .white
    }
    
    private var secondaryTextColor: Color {
        .white.opacity(0.8)
    }
    
    private var accentColor: Color {
        // Use the book's accent color but ensure it's bright enough
        if let accent = colorPalette?.accent {
            let uiColor = UIColor(accent)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Ensure accent is bright enough to stand out on dark background
            if b < 0.7 {
                return Color(hue: h, saturation: s, brightness: 0.8, opacity: a)
            }
            return accent
        }
        return .orange
    }
    
    private var shadowColor: Color {
        .black.opacity(0.5)
    }
    
    // Edit book states
    @State private var showingBookSearch = false
    @State private var editedTitle = ""
    @State private var isEditingTitle = false
    @State private var showingProgressEditor = false
    
    // Computed properties for filtering notes by book
    private var progressPercentage: Double {
        guard let total = book.pageCount,
              total > 0 else { return 0 }
        return Double(book.currentPage) / Double(total)
    }
    
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
            // Use the Apple Music-style atmospheric gradient with dynamic opacity
            BookAtmosphericGradientView(colorPalette: colorPalette ?? generatePlaceholderPalette())
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(gradientOpacity) // Fades on scroll
                .animation(.easeOut(duration: 0.2), value: gradientOpacity)
                .id(book.id) // Force view recreation when book changes
            
            // Content - always visible but colors update
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Scroll detector with FIXED calculation
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
                                    // Simple, reliable calculation
                                    let offset = -newValue + 150  // Adjust based on header height
                                    scrollOffset = max(0, offset)
                                }
                        }
                        .frame(height: 0)
                        
                        // Book info section
                        centeredHeaderView
                            .padding(.top, 20)
                    
                    // Summary section wrapped in padding container
                    if let description = book.description {
                        summarySection(description: description)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                    }
                    
                    // Progress section
                    if book.readingStatus == .currentlyReading, let pageCount = book.pageCount, pageCount > 0 {
                        progressSection
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    }
                    
                    // Content sections
                    contentView
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Book") {
                    editedTitle = book.title
                    showingBookSearch = true
                    HapticManager.shared.lightTap()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
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
            // findOrCreateThreadForBook() // DISABLED - ChatThread removed
            
            // TEMPORARY: Clear cache to test new color extraction
            Task {
                await BookColorPaletteCache.shared.clearCache()
                print("🧹 CLEARED COLOR CACHE - FORCING FRESH EXTRACTION")
            }
            
            // Placeholder is now generated inline in the gradient view
            
            // Enable animations after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
        .onChange(of: coverImage) { _ in
            // Don't reset color palette when cover changes
            // The color extraction will handle updates automatically
        }
    }
    
    private var centeredHeaderView: some View {
        VStack(spacing: 16) {
            // Book Cover with 3D effect
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 180,
                height: 270,
                onImageLoaded: { uiImage in
                    // Store the actual displayed image
                    print("🖼️ BookDetailView: Received displayed image")
                    print("📐 Image size: \(uiImage.size)")
                    self.coverImage = uiImage
                    
                    // Extract colors progressively
                    Task {
                        // If we don't have low-res colors yet, extract from this image
                        if !hasLowResColors {
                            await extractColorsFromDisplayedImage(uiImage)
                            hasLowResColors = true
                        }
                        
                        // Always trigger high-res extraction for best quality
                        if !hasHighResColors {
                            await extractColorsFromCover()
                            hasHighResColors = true
                        }
                    }
                }
            )
            .accessibilityLabel("Book cover for \(book.title)")
            #if DEBUG
            .colorExtractionDebug(book: book, coverImage: coverImage)
            #endif
            .rotation3DEffect(
                Angle(degrees: 5),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .task(id: book.localId) {
                // Color extraction now happens when image loads in SharedBookCoverView
            }
            
            // Title - dynamic color with adaptive shadow
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(textColor)
                .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Author(s) - Handle multiple authors by splitting on comma
            VStack(spacing: 4) {
                let authors = book.author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if authors.count == 1 {
                    Text("by \(book.author)")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundColor(secondaryTextColor)
                        .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
                        } else {
                    Text("by")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundColor(secondaryTextColor.opacity(0.875))
                            
                    ForEach(authors, id: \.self) { author in
                        Text(author)
                            .font(.system(size: 16, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundColor(secondaryTextColor)
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
                        .shadow(color: accentColor.opacity(0.3), radius: 8)
                }
                .accessibilityLabel("Reading status: \(book.readingStatus.rawValue). Tap to change.")
                
                // Page count and percentage removed per user request
                
                if let rating = book.userRating {
                    StatusPill(text: "★ \(rating)", color: accentColor.opacity(0.8))
                        .accessibilityLabel("Rating: \(rating) stars")
                }
            }
            .padding(.top, 8)
            
            // Progress bar removed per user request
            
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
        .animation(hasAppeared ? .easeInOut(duration: 0.2) : nil, value: selectedSection)
    }
    
    private func summarySection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)  // Fixed size
                
                Text("Summary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                
                Spacer()
            }
            
            // Summary text
            Text(description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(textColor.opacity(0.85))
                .lineSpacing(8)
                .lineLimit(summaryExpanded ? nil : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                // NO animation on the text itself
            
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
                        .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)  // Fixed width from start
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        // NO transition modifier
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)
                
                Text("Reading Timeline")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                
                Spacer()
                
                // Edit button
                Button {
                    showingProgressEditor = true
                    HapticManager.shared.lightTap()
                } label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentColor)
                }
            }
            
            // Ambient Reading Progress Timeline - Detailed View
            AmbientReadingProgressView(
                book: book,
                width: 320,
                showDetailed: true,
                colorPalette: colorPalette
            )
            .environmentObject(libraryViewModel)
        }
        .sheet(isPresented: $showingProgressEditor) {
            AmbientProgressSheet(book: book, isPresented: $showingProgressEditor, colorPalette: colorPalette)
                .environmentObject(libraryViewModel)
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
        // Chat functionality disabled - ChatThread removed
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(accentColor.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Chat Temporarily Unavailable")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor.opacity(0.7))
                    .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                
                Text("Chat functionality is being updated")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor.opacity(0.5))
                    .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
                    .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor.opacity(0.5))
                    .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Chat Functions - DISABLED (ChatThread removed)
    
    /*
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
    */
    
    // MARK: - Color Extraction
    
    private func colorDescription(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255)))"
    }
    
    private func generatePlaceholderPalette() -> ColorPalette {
        // Temporary overrides for known problematic books
        if book.title.lowercased().contains("lord of the rings") {
            return ColorPalette(
                primary: Color(red: 0.8, green: 0.6, blue: 0.2),  // Gold
                secondary: Color(red: 0.7, green: 0.2, blue: 0.1), // Dark red
                accent: Color(red: 0.9, green: 0.7, blue: 0.3),    // Light gold
                background: Color(red: 0.3, green: 0.1, blue: 0.05), // Dark brown
                textColor: .white,
                luminance: 0.4,
                isMonochromatic: false,
                extractionQuality: 1.0
            )
        } else if book.title.lowercased().contains("odyssey") {
            return ColorPalette(
                primary: Color(red: 0.2, green: 0.5, blue: 0.7),   // Ocean blue
                secondary: Color(red: 0.3, green: 0.6, blue: 0.8), // Light blue
                accent: Color(red: 0.1, green: 0.4, blue: 0.6),    // Dark blue
                background: Color(red: 0.05, green: 0.2, blue: 0.3), // Deep ocean
                textColor: .white,
                luminance: 0.5,
                isMonochromatic: false,
                extractionQuality: 1.0
            )
        }
        
        // Use a subtle, neutral warm gradient as placeholder
        // This won't be jarring when it transitions to the real colors
        return ColorPalette(
            primary: Color(white: 0.3),      // Dark gray
            secondary: Color(white: 0.25),   // Slightly darker gray
            accent: Color.warmAmber.opacity(0.3), // Very subtle amber accent
            background: Color(white: 0.1),   // Very dark gray
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: true,
            extractionQuality: 0.1 // Low quality to indicate placeholder
        )
    }
    
    private func extractColorsFromDisplayedImage(_ displayedImage: UIImage) async {
        // Check cache first
        let bookID = book.id
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                self.colorPalette = cachedPalette
            }
            return
        }
        
        // Set extracting state
        isExtractingColors = true
        
        print("🎨 Extracting colors from DISPLAYED image for: \(book.title)")
        print("📐 Displayed image size: \(displayedImage.size)")
        print("🔍 This is the EXACT SAME IMAGE shown in the UI")
        
        // Verify this is a full cover, not cropped
        if displayedImage.size.width < 100 || displayedImage.size.height < 100 {
            print("⚠️ WARNING: Displayed image is too small, may be cropped!")
        }
        
        do {
            // Use improved color extraction with validation
            if let palette = await ImprovedColorExtraction.extractColors(from: displayedImage, bookTitle: book.title) {
                await MainActor.run {
                    self.colorPalette = palette
                    
                    print("🎨 Low-res extracted colors:")
                    print("  Primary: \(palette.primary)")
                    print("  Secondary: \(palette.secondary)")
                    print("  Accent: \(palette.accent)")
                    print("  Background: \(palette.background)")
                }
                
                // Cache the result
                await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
            } else {
                print("❌ Color extraction returned nil")
            }
        } catch {
            print("❌ Error in color extraction: \(error)")
        }
        
        isExtractingColors = false
    }
    
    private func extractColorsFromCover() async {
        // Check cache first
        let bookID = book.id
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                self.colorPalette = cachedPalette
            }
            return
        }
        
        // Set extracting state
        isExtractingColors = true
        
        print("🎨 Starting OKLAB color extraction for book: \(book.title)")
        
        // Try to load the book cover image
        guard let coverURLString = book.coverImageURL else {
            print("❌ No cover URL")
            isExtractingColors = false
            return
        }
        
        // Convert HTTP to HTTPS for security and REMOVE zoom to get full cover
        let secureURLString = coverURLString
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=5", with: "")
            .replacingOccurrences(of: "&zoom=4", with: "")
            .replacingOccurrences(of: "&zoom=3", with: "")
            .replacingOccurrences(of: "&zoom=2", with: "")
            .replacingOccurrences(of: "&zoom=1", with: "")
            .replacingOccurrences(of: "zoom=5", with: "")
            .replacingOccurrences(of: "zoom=4", with: "")
            .replacingOccurrences(of: "zoom=3", with: "")
            .replacingOccurrences(of: "zoom=2", with: "")
            .replacingOccurrences(of: "zoom=1", with: "")
        guard let coverURL = URL(string: secureURLString) else {
            print("❌ Invalid cover URL")
            isExtractingColors = false
            return
        }
        
        do {
            // Download the image
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else {
                print("❌ Could not create UIImage from data")
                isExtractingColors = false
                return
            }
            
            // Store the cover image
            self.coverImage = uiImage
            
            // Use improved color extraction with validation
            if let palette = await ImprovedColorExtraction.extractColors(from: uiImage, bookTitle: book.title) {
                await MainActor.run {
                    self.colorPalette = palette
                    print("🎨 High-res extracted colors (final):")
                    print("  Primary: \(palette.primary)")
                    print("  Secondary: \(palette.secondary)")
                    print("  Accent: \(palette.accent)")
                    print("  Background: \(palette.background)")
                }
                
                // Cache the result outside of MainActor.run
                await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
            }
            
            // Debug print moved inside MainActor block above
            
        } catch {
            print("❌ Failed to extract colors: \(error.localizedDescription)")
        }
        
        isExtractingColors = false
    }
    
    private func testImageConsistency() async {
        print("\n🧪 TESTING IMAGE CONSISTENCY")
        print("Book: \(book.title)")
        print("Cover URL: \(book.coverImageURL ?? "nil")")
        
        // Wait for images to be saved
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        print("\n📊 TEST RESULTS:")
        print("1. Check console logs for checksums")
        print("2. Check Photos app for saved images:")
        print("   - DISPLAYED_* images (what you see)")
        print("   - EXTRACTED_* images (what color extractor uses)")
        print("3. Both checksums should match if using same image")
        print("\n⚠️ If checksums differ, the images are different!")
    }
    
    private func runColorDiagnostic() async {
        print("🔬 Running color diagnostic for: \(book.title)")
        
        // Try to get the cover image
        if coverImage != nil {
            // ColorExtractionDiagnostic was removed - diagnostic functionality no longer available
            // let diagnostic = ColorExtractionDiagnostic()
            // await diagnostic.runDiagnostic(on: coverImage, bookTitle: book.title)
        } else if let coverURLString = book.coverImageURL {
            // Download the image if we don't have it
            let secureURLString = coverURLString
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "&zoom=5", with: "")
                .replacingOccurrences(of: "&zoom=4", with: "")
                .replacingOccurrences(of: "&zoom=3", with: "")
                .replacingOccurrences(of: "&zoom=2", with: "")
                .replacingOccurrences(of: "&zoom=1", with: "")
                .replacingOccurrences(of: "zoom=5", with: "")
                .replacingOccurrences(of: "zoom=4", with: "")
                .replacingOccurrences(of: "zoom=3", with: "")
                .replacingOccurrences(of: "zoom=2", with: "")
                .replacingOccurrences(of: "zoom=1", with: "")
            guard let coverURL = URL(string: secureURLString) else {
                print("❌ Invalid cover URL for diagnostic")
                return
            }
            
            do {
                let (imageData, _) = try await URLSession.shared.data(from: coverURL)
                guard UIImage(data: imageData) != nil else {
                    print("❌ Could not create UIImage for diagnostic")
                    return
                }
                
                // ColorExtractionDiagnostic was removed - diagnostic functionality no longer available
                // let diagnostic = ColorExtractionDiagnostic()
                // await diagnostic.runDiagnostic(on: uiImage, bookTitle: book.title)
            } catch {
                print("❌ Failed to download image for diagnostic: \(error)")
            }
        } else {
            print("❌ No cover image available for diagnostic")
        }
    }
    
    // Removed debug view
    /*
    @ViewBuilder
    private func colorDebugView(palette: ColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎨 OKLAB Color Extraction")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
            
            HStack(spacing: 12) {
                // Color circles
                VStack(spacing: 8) {
                    colorCircle(palette.primary, label: "Primary")
                    colorCircle(palette.secondary, label: "Secondary")
                }
                
                VStack(spacing: 8) {
                    colorCircle(palette.accent, label: "Accent")
                    colorCircle(palette.background, label: "Background")
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Luminance: \(String(format: "%.2f", palette.luminance))")
                        .font(.system(size: 12))
                    Text("Monochromatic: \(palette.isMonochromatic ? "Yes" : "No")")
                        .font(.system(size: 12))
                    Text("Quality: \(String(format: "%.1f", palette.extractionQuality * 100))%")
                        .font(.system(size: 12))
                    Text("Text: \(palette.textColor == .white ? "White" : "Black")")
                        .font(.system(size: 12))
                }
                .foregroundColor(secondaryTextColor)
                
                Spacer()
            }
            
            // Toggle button
            Button(action: {
                withAnimation {
                    showColorDebug.toggle()
                }
            }) {
                Label("Hide Debug", systemImage: "eye.slash")
                    .font(.system(size: 12))
            }
            
            // Diagnostic button
            Button(action: {
                Task {
                    await runColorDiagnostic()
                }
            }) {
                Label("Run Diagnostic", systemImage: "stethoscope")
                    .font(.system(size: 12))
            }
            
            // Test consistency button
            Button(action: {
                Task {
                    await testImageConsistency()
                }
            }) {
                Label("Test Images", systemImage: "checkmark.seal")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(secondaryTextColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(textColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(textColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
    */
    
    private func colorCircle(_ color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(secondaryTextColor)
        }
    }
}

// MARK: - Scroll Offset Preference Key

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
        .foregroundColor(.white)  // Always white text
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.3))  // Use color as background
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(color.opacity(0.5), lineWidth: 0.5)
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

// ChatMessageBubble - DISABLED (ThreadedChatMessage removed)
/*
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
*/

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(isActive ? 0.1 : 0),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 100)
                .animation(
                    isActive ? 
                    Animation.linear(duration: 1.5).repeatForever(autoreverses: false) : 
                    nil,
                    value: phase
                )
            )
            .onAppear { phase = 1 }
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
        // .modelContainer(for: [ChatThread.self]) // DISABLED - ChatThread removed
    }
}
