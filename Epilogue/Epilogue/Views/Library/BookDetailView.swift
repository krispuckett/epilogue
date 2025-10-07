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
    static let midnightScholar = DesignSystem.Colors.surfaceBackground // #1C1B1A
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

    // SwiftData queries for notes and quotes
    @Query private var allCapturedNotes: [CapturedNote]
    @Query private var allCapturedQuotes: [CapturedQuote]
    @Query private var allBookModels: [BookModel]

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
    @State private var contentLoaded = false
    @State private var delayedContentLoaded = false
    @State private var summaryBlur: Double = 10
    @State private var summaryOpacity: Double = 0
    @State private var contextBlur: Double = 10
    @State private var contextOpacity: Double = 0
    
    // Enhanced animation states - using blur instead of scale
    @State private var coverBlur: Double = 10
    @State private var coverOpacity: Double = 0
    @State private var titleBlur: Double = 10
    @State private var titleOpacity: Double = 0
    @State private var metadataBlur: Double = 10
    @State private var metadataOpacity: Double = 0
    
    // Dynamic gradient opacity based on scroll
    private var gradientOpacity: Double {
        // Fixed calculation - no more crazy values
        let opacity = 1.0 - (min(scrollOffset, 200) / 200)
        return max(0.4, opacity)  // Increased minimum from 0.2 to 0.4
    }
    
    // Color extraction
    @State private var colorPalette: ColorPalette?
    @State private var isExtractingColors = false
    @State private var hasLowResColors = false
    @State private var hasHighResColors = false
    // Remove DisplayColorScheme - we don't need it
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    
    // Fixed colors for Claude voice mode style (always white text on dark background)
    private var textColor: Color {
        .white
    }
    
    private var secondaryTextColor: Color {
        .white.opacity(0.8)
    }
    
    private var accentColor: Color {
        // Smart accent color that adapts to book colors while ensuring readability
        guard let palette = colorPalette else {
            return DesignSystem.Colors.primaryAccent // Default warm amber
        }
        
        // Try to use the book's actual colors if they're suitable
        let bookAccent = palette.accent
        
        // Check if the color is readable and pleasant
        let uiColor = UIColor(bookAccent)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0  
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Accept blues, teals, purples, and greens directly - they look great
        let hueDegrees = hue * 360
        if (hueDegrees >= 180 && hueDegrees <= 280) || // Blues and purples
           (hueDegrees >= 150 && hueDegrees <= 180) || // Teals
           (hueDegrees >= 80 && hueDegrees <= 150) {   // Greens
            // Ensure minimum brightness for visibility
            if brightness < 0.5 {
                // Adjust brightness manually
                let uiColor = UIColor(bookAccent)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                return Color(UIColor(hue: h, saturation: s, brightness: 0.6, alpha: a))
            }
            return bookAccent
        }
        
        // For warm colors (reds, oranges, yellows), shift to our amber
        if hueDegrees <= 80 || hueDegrees >= 280 {
            // But preserve some of the original hue character
            if hueDegrees >= 20 && hueDegrees <= 60 { // Oranges and yellows
                return Color(red: 1.0, green: 0.55 + (0.15 * saturation), blue: 0.26)
            }
        }
        
        // Fallback to warm amber for unsuitable colors
        return DesignSystem.Colors.primaryAccent
    }
    
    private var shadowColor: Color {
        .black.opacity(0.5)
    }
    
    // Edit book states
    @State private var showingBookSearch = false
    @State private var editedTitle = ""
    @State private var isEditingTitle = false
    
    // Progress editing states
    @State private var showingProgressSheet = false
    @State private var editingCurrentPage = ""
    // Removed showingProgressEditor - progress is now directly interactive via slider
    @State private var showingCompletionSheet = false
    
    // Status picker state
    @State private var showingStatusPicker = false

    // Reading session state
    @State private var activeSession: ReadingSession?
    @State private var showingEndSession = false
    @State private var showingSessionSavedToast = false

    // Get or create BookModel for this Book struct
    private var bookModel: BookModel? {
        allBookModels.first { $0.localId == book.localId.uuidString }
    }

    // Computed properties for filtering notes by book
    private var progressPercentage: Double {
        guard let total = book.pageCount,
              total > 0 else { return 0 }
        return Double(book.currentPage) / Double(total)
    }

    private var startReadingButton: some View {
        Button(action: startSession) {
            startReadingLabel
        }
    }

    private var startReadingLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 13))
            Text("Start Reading")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.001)))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        }
    }

    private func startSession() {
        let model: BookModel
        if let existing = bookModel {
            model = existing
        } else {
            model = BookModel(from: book)
            modelContext.insert(model)
        }
        let session = ReadingSession(bookModel: model, startPage: book.currentPage)
        modelContext.insert(session)

        // Polished morphing animation with haptic
        SensoryFeedback.success()
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            activeSession = session
        }
    }

    private func upgradeToAmbientMode() {
        guard let session = activeSession else { return }

        // Mark session as ambient and save
        SensoryFeedback.light()
        session.toggleAmbientMode()
        try? modelContext.save()

        // Launch ambient mode with current book and transfer session
        SimplifiedAmbientCoordinator.shared.openAmbientReading(with: book)

        print("🎙️ Upgraded to Ambient Mode - Session transferred")
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

    private var backgroundGradient: some View {
        BookAtmosphericGradientView(
            colorPalette: colorPalette ?? generatePlaceholderPalette(),
            intensity: gradientIntensity
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(gradientOpacity)
        .animation(.easeOut(duration: 0.3), value: gradientOpacity)
        .id(book.id)
    }

    @ViewBuilder
    private var sessionHUD: some View {
        EmptyView() // Removed - session now morphs in place below author
    }

    @ViewBuilder
    private var sessionPillOrHUD: some View {
        if let session = activeSession {
            // Full session HUD (morphs from pill) - compact rectangular version
            HStack(spacing: 12) {
                // Metrics with staggered fade-in
                HStack(spacing: 12) {
                    metricItem(value: session.formattedDuration, label: "DURATION")
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3).delay(0.15)),
                        removal: .scale.combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
                    ))

                    Divider()
                    .frame(height: 24)
                    .background(Color.white.opacity(0.2))
                    .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.23)))

                    metricItem(value: "\(session.endPage)", label: "PAGE")
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3).delay(0.23)),
                        removal: .scale.combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
                    ))

                    if let totalPages = book.pageCount, totalPages > 0 {
                    Divider()
                        .frame(height: 24)
                        .background(Color.white.opacity(0.2))
                        .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.31)))

                    metricItem(value: "\(totalPages - session.endPage)", label: "LEFT")
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3).delay(0.31)),
                            removal: .scale.combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
                        ))
                    }
                }

                // Ambient upgrade + End session buttons
                HStack(spacing: 8) {
                    // Upgrade to Ambient button - using ambient orb shader
                    AmbientOrbButton(size: 32) {
                    upgradeToAmbientMode()
                    }
                    .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3).delay(0.38)),
                    removal: .scale.combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
                    ))

                    // End session button
                    Button {
                    showingEndSession = true
                    } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .accessibilityLabel("End reading session")
                    .accessibilityHint("Double tap to end your current reading session")
                    .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3).delay(0.45)),
                    removal: .scale.combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // Remove any under-glass background to preserve inherited blur
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5) }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(duration: 0.5, bounce: 0.3)),
                removal: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.2))
            ))
        } else {
            // Quick Reading Session pill
            Button(action: startSession) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    Text("Quick Reading Session")
                    .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                // No background under glass to keep liquid refraction
                .glassEffect(.regular, in: .capsule)
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5) }
            }
            .accessibilityLabel("Start quick reading session")
            .accessibilityHint("Double tap to begin a new reading session for this book")
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(duration: 0.4, bounce: 0.3)),
                removal: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(duration: 0.3, bounce: 0.2))
            ))
        }
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.2)
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                centeredHeaderView
                    .padding(.top, 20)

                // Session pill/HUD that morphs in place
                sessionPillOrHUD
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    .padding(.top, 16)

                if contentLoaded {
                    Group {
                    if let description = book.description {
                        summarySection(description: description)
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                            .padding(.top, 32)
                            .fixedSize(horizontal: false, vertical: true)
                            .blur(radius: summaryBlur)
                            .opacity(summaryOpacity)
                    }

                    if book.readingStatus == .currentlyReading, let pageCount = book.pageCount, pageCount > 0 {
                        progressSection
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                            .padding(.top, 24)
                            .blur(radius: summaryBlur)
                            .opacity(summaryOpacity)
                    }
                    }
                }

                if delayedContentLoaded {
                    Group {
                    contextualContentSections
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                        .blur(radius: contextBlur)
                        .opacity(contextOpacity)
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
    }

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                sessionHUD
                contentScrollView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .onAppear {
            // Set the current detail book in the view model
            libraryViewModel.currentDetailBook = book

            // Trigger micro-interaction for ambient icon animation
            MicroInteractionManager.shared.enteredBookView()

            // Sessions checked on demand when button tapped

            // Enrich book with smart synopsis/themes if not already done
            if let bookModel = bookModel {
                if !bookModel.isEnriched {
                    print("📖 Triggering enrichment for: \(bookModel.title)")
                    Task {
                        await BookEnrichmentService.shared.enrichBook(bookModel)
                        print("✅ Enrichment completed for: \(bookModel.title)")
                        print("   Synopsis: \(bookModel.smartSynopsis?.prefix(50) ?? "nil")")
                    }
                } else {
                    print("ℹ️ Book already enriched: \(bookModel.title)")
                }
            } else {
                print("⚠️ Could not find BookModel for: \(book.title)")
            }
        }
        .onDisappear {
            // Clear the current detail book when leaving
            libraryViewModel.currentDetailBook = nil
        }
        .toolbar {
            // Reading status pill (exact copy from header)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            libraryViewModel.updateReadingStatus(for: book.id, status: status)
                            if status == .read && book.readingStatus != .read {
                                SensoryFeedback.success()
                            }
                            if status == .read && book.readingStatus != .read {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingCompletionSheet = true
                                }
                            }
                        }
                    } label: {
                        Label(
                            status.rawValue,
                            systemImage: status == book.readingStatus ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    }
                } label: {
                    StatusPill(text: book.readingStatus.rawValue, color: accentColor, interactive: true)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Reading status: \(book.readingStatus.rawValue)")
                .accessibilityHint("Double tap to change reading status")
            }
        }
        .sheet(isPresented: $showingBookSearch) {
            BookSearchSheet(
                searchQuery: editedTitle,
                onBookSelected: { selected in
                    Task { @MainActor in
                    // Resolve a canonical display URL for the selected book
                    let resolved = await DisplayCoverURLResolver.resolveDisplayURL(
                        googleID: selected.id,
                        isbn: selected.isbn,
                        thumbnailURL: selected.coverImageURL
                    )
                    var updated = selected
                    updated.coverImageURL = resolved ?? selected.coverImageURL

                    // Replace while preserving user data
                    libraryViewModel.replaceBook(originalBook: book, with: updated, preserveCover: false)

                    // Update cover explicitly to override any preserved-cover logic
                    libraryViewModel.updateBookCover(updated, newCoverURL: updated.coverImageURL)

                    // Refresh image caches and palette
                    if let oldURL = book.coverImageURL {
                        _ = await SharedBookCoverManager.shared.refreshCover(for: oldURL)
                    }
                    if let newURL = updated.coverImageURL {
                        _ = await SharedBookCoverManager.shared.loadFullImage(from: newURL)
                        await BookColorPaletteCache.shared.refreshPalette(for: updated.id, coverURL: newURL)
                    }

                    NotificationCenter.default.post(name: NSNotification.Name("RefreshLibrary"), object: nil)
                    showingBookSearch = false
                    }
                },
                mode: .replace
            )
        }
        .sheet(isPresented: $showingCompletionSheet) {
            BookCompletionSheet(
                book: Binding(
                    get: { book },
                    set: { updatedBook in
                    // Update the book in the library when changes are made
                    libraryViewModel.updateBook(updatedBook)
                    }
                ),
                isPresented: $showingCompletionSheet
            )
            .environmentObject(libraryViewModel)
        }
        .sheet(isPresented: $showingEndSession) {
            if let session = activeSession {
                EndSessionSheet(
                    session: session,
                    book: book,
                    activeSession: $activeSession,
                    colorPalette: nil,
                    showingSessionSavedToast: $showingSessionSavedToast
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
                .presentationCornerRadius(32)
            }
        }
        .glassToast(isShowing: $showingSessionSavedToast, message: "Quick Session Saved")
        .onAppear {
            // findOrCreateThreadForBook() // DISABLED - ChatThread removed
            
            // Check for cached colors first for instant display
            Task {
                let bookID = book.localId.uuidString
                if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
                    await MainActor.run {
                    self.colorPalette = cachedPalette
                    }
                }
            }
            
            // Enable animations immediately for smoother transition
            hasAppeared = true
            
            // Start cover blur-in animation if image is already loaded
            if coverImage != nil {
                withAnimation(.easeOut(duration: 0.4)) {
                    coverBlur = 0
                    coverOpacity = 1.0
                }
            }

            // Title blur-in animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.35)) {
                    titleBlur = 0
                    titleOpacity = 1.0
                }
            }

            // Metadata blur-in animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.35)) {
                    metadataBlur = 0
                    metadataOpacity = 1.0
                }
            }

            // Load content immediately to prevent layout shifts
            contentLoaded = true
            delayedContentLoaded = true

            // Summary blur-in animation (after metadata)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.35)) {
                    summaryBlur = 0
                    summaryOpacity = 1.0
                }
            }

            // Context sections blur-in animation (last)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.35)) {
                    contextBlur = 0
                    contextOpacity = 1.0
                }
            }
        }
        .onChange(of: coverImage) { _, _ in
            // Don't reset color palette when cover changes
            // The color extraction will handle updates automatically
        }
    }
    
    private var centeredHeaderView: some View {
        VStack(spacing: 16) {
            // Book Cover with 3D effect and smooth entrance
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 180,
                height: 270,
                loadFullImage: true,  // Explicitly request full quality
                isLibraryView: false,
                onImageLoaded: { uiImage in
                    // Store the actual displayed image
                    self.coverImage = uiImage
                    
                    // Trigger smooth cover blur-in animation
                    withAnimation(.easeOut(duration: 0.4)) {
                    coverBlur = 0
                    coverOpacity = 1.0
                    }
                    
                    // Only extract colors if we don't have them yet
                    if colorPalette == nil && !isExtractingColors {
                    Task.detached(priority: .userInitiated) {
                        // Quick extraction from displayed image
                        if !hasLowResColors {
                            await extractColorsFromDisplayedImage(uiImage)
                            hasLowResColors = true
                        }
                    }
                    }
                }
            )
            .accessibilityLabel("Book cover for \(book.title)")
            .blur(radius: coverBlur)
            .opacity(coverOpacity)
            .shadow(color: Color.black.opacity(coverOpacity * 0.3), radius: 20 * coverOpacity, y: 10 * coverOpacity)
            .task(id: book.localId) {
                // Color extraction now happens when image loads in SharedBookCoverView
            }
            
            // Title - dynamic color with adaptive shadow and fade-in
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(textColor)
                .shadow(color: shadowColor, radius: 1, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                .blur(radius: titleBlur)
                .opacity(titleOpacity)
            
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
            .blur(radius: metadataBlur)
            .opacity(metadataOpacity)
            
            // Rating only (status pill moved to toolbar)
            if let rating = book.userRating {
                StatusPill(text: "★ \(rating)", color: accentColor, interactive: false)
                    .accessibilityLabel("Rating: \(rating) stars")
                    .padding(.top, 8)
                    .blur(radius: metadataBlur)
                    .opacity(metadataOpacity)
            }
            
            // Progress bar removed per user request
            
            // Removed segmented control - using continuous scroll instead
        }
    }
    
    
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(DesignSystem.Animation.springStandard) {
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
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .fill(Color.warmAmber.opacity(0.15))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                                    .strokeBorder(Color.warmAmber.opacity(0.3), lineWidth: 1)
                            }
                            .shadow(color: Color.warmAmber.opacity(0.3), radius: 6)
                            .matchedGeometryEffect(id: "sectionSelection", in: sectionAnimation)
                    }
                    }
                }
                .accessibilityLabel("\(section.rawValue) section")
                .accessibilityHint(selectedSection == section ? "Currently selected" : "Double tap to select")
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
                    withAnimation(DesignSystem.Animation.springStandard) {
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
    
    @ViewBuilder
    private var contextualContentSections: some View {
        VStack(spacing: 32) {
            // Always show Notes section (persistent)
            notesSection

            // Content based on reading status
            if book.readingStatus == .currentlyReading {
                // Currently Reading sections
                if !bookNotes.isEmpty || !bookQuotes.isEmpty {
                    recentActivitySection
                }
                
                BookSessionHistoryCard(book: book)
                
                readingInsightsSection
                
            } else if book.readingStatus == .wantToRead {
                // Want to Read sections
                startReadingSection
                
                if let pageCount = book.pageCount {
                    estimatedReadingTimeSection(pageCount: pageCount)
                }
                
            } else if book.readingStatus == .read {
                // Finished Reading sections
                if book.userRating != nil || book.userNotes != nil {
                    yourReviewSection
                } else {
                    addReviewPromptSection
                }
                
                if !bookQuotes.isEmpty {
                    memorableQuotesSection
                }
                
                BookSessionHistoryCard(book: book)
                
                readingStatsSection
            }
            
            // Always show notes and quotes at the bottom if they exist
            if !bookNotes.isEmpty {
                allNotesSection
            }
            
            if !bookQuotes.isEmpty && book.readingStatus != .read {
                allQuotesSection
            }
        }
        // Only animate status changes after initial load
        .animation(hasAppeared ? DesignSystem.Animation.easeStandard : nil, value: book.readingStatus)
    }
    
    private func summarySection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)

                Text("Summary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)

                Spacer()
            }

            // Show enriched synopsis if available, otherwise Google Books description
            Group {
                if let synopsis = bookModel?.smartSynopsis {
                    // Enriched synopsis (spoiler-free)
                    Text(synopsis)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(textColor.opacity(0.9))
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onAppear {
                            print("📱 [UI] Displaying ENRICHED synopsis for '\(book.title)'")
                            print("   Length: \(synopsis.count) chars")
                            print("   Preview: \(synopsis.prefix(80))...")
                        }
                } else {
                    // Fallback to Google Books description
                    if summaryExpanded {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundColor(textColor.opacity(0.85))
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                            .onAppear {
                                print("📱 [UI] Displaying GOOGLE BOOKS description for '\(book.title)' (expanded)")
                                print("   BookModel enriched: \(bookModel?.isEnriched ?? false)")
                                print("   SmartSynopsis: \(bookModel?.smartSynopsis?.prefix(30) ?? "nil")")
                            }
                    } else {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundColor(textColor.opacity(0.85))
                            .lineSpacing(8)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                            .onAppear {
                                print("📱 [UI] Displaying GOOGLE BOOKS description for '\(book.title)' (collapsed)")
                                print("   BookModel enriched: \(bookModel?.isEnriched ?? false)")
                                print("   SmartSynopsis: \(bookModel?.smartSynopsis?.prefix(30) ?? "nil")")
                            }
                    }
                }
            }
            .animation(hasAppeared ? .easeInOut(duration: 0.2) : nil, value: summaryExpanded)

            // Read more/less button (only for Google Books description)
            if bookModel?.smartSynopsis == nil && description.count > 200 {
                Button {
                    summaryExpanded.toggle()
                } label: {
                    Text(summaryExpanded ? "Read less" : "Read more")
                        .font(.caption)
                        .foregroundColor(accentColor)
                        .shadow(color: shadowColor.opacity(0.7), radius: 0.5, x: 0, y: 0.5)
                }
            }

            // Themes (if enriched)
            if let themes = bookModel?.keyThemes, !themes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THEMES")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.5))
                        .tracking(1.2)

                    // Flow layout for theme pills (NO .background!)
                    FlowLayout(spacing: 8) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(in: Capsule())
                        }
                    }
                }
                .padding(.top, 4)
            }

            // Characters (if enriched and non-empty)
            if let characters = bookModel?.majorCharacters, !characters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHARACTERS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.5))
                        .tracking(1.2)

                    Text(characters.joined(separator: " · "))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textColor.opacity(0.7))
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
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

                Text("Drag to adjust")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor.opacity(0.5))
            }
            
            // Ambient Reading Progress Timeline - Detailed View (now interactive!)
            AmbientReadingProgressView(
                book: book,
                bookModel: bookModel,
                width: 320,
                showDetailed: true,
                colorPalette: colorPalette
            )
            .environmentObject(libraryViewModel)
        }
    }
    
    // MARK: - Notes Section (Persistent)
    @ViewBuilder
    private var notesSection: some View {
        // Filter notes for this specific book
        let bookNotesCaptured = allCapturedNotes.filter { note in
            note.book?.localId == book.localId.uuidString
        }

        VStack(alignment: .leading, spacing: 16) {
            // Header with add button
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Notes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textColor)

                Spacer()

                // Quick add note button
                Button {
                    SensoryFeedback.light()
                    // Show unified quick action card
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowQuickActionCard"),
                        object: nil
                    )
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(accentColor)
                }
            }

            if bookNotesCaptured.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(accentColor.opacity(0.5))

                    Text("No notes yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.5))

                    Text("Tap + to add your first note")
                        .font(.system(size: 12))
                        .foregroundStyle(textColor.opacity(0.4))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                // Compact note cards
                VStack(spacing: 12) {
                    ForEach(bookNotesCaptured.prefix(3)) { note in
                    CompactNoteCard(note: note, accentColor: accentColor)
                    }

                    if bookNotesCaptured.count > 3 {
                    Button {
                        // Navigate to all notes
                        selectedSection = .notes
                    } label: {
                        HStack {
                            Text("View all \(bookNotesCaptured.count) notes")
                                .font(.system(size: 14, weight: .medium))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }

    // MARK: - Contextual Sections for Currently Reading

    @ViewBuilder
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            // Show last 2 notes and 2 quotes
            let recentNotes = bookNotes.prefix(2)
            let recentQuotes = bookQuotes.prefix(2)
            
            ForEach(recentNotes) { note in
                BookNoteCard(note: note)
            }
            
            ForEach(recentQuotes) { quote in
                BookQuoteCard(quote: quote)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var readingInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("Reading Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if let pageCount = book.pageCount, pageCount > 0 {
                    let pagesPerDay = max(1, book.currentPage / max(1, Calendar.current.dateComponents([.day], from: book.dateAdded, to: Date()).day ?? 1))
                    let daysToFinish = (pageCount - book.currentPage) / max(1, pagesPerDay)
                    
                    Text("At your current pace of \(pagesPerDay) pages per day")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    
                    Text("You'll finish in approximately \(daysToFinish) days")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                if bookQuotes.count > 0 {
                    Text("\(bookQuotes.count) quotes saved from this book")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    // MARK: - Contextual Sections for Want to Read
    
    @ViewBuilder
    private var startReadingSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                    colors: [accentColor, accentColor.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                    )
                )
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("Ready to start reading?")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                if let pageCount = book.pageCount {
                    Text("\(pageCount) pages await")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Button {
                SensoryFeedback.medium()
                withAnimation(.spring(response: 0.3)) {
                    libraryViewModel.updateReadingStatus(for: book.id, status: .currentlyReading)
                }
                
                // Delayed success haptic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    SensoryFeedback.success()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    Text("Start Reading")
                    .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                    .fill(accentColor.opacity(0.2))
                }
                .glassEffect(in: Capsule())
                .overlay {
                    Capsule()
                    .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                    colors: [
                        accentColor.opacity(0.3),
                        accentColor.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    @ViewBuilder
    private func aboutThisBookSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("About This Book")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            Text(description)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(8)
                .lineLimit(summaryExpanded ? nil : 6)
            
            if description.count > 300 {
                Button {
                    summaryExpanded.toggle()
                } label: {
                    Text(summaryExpanded ? "Show less" : "Read more")
                    .font(.caption)
                    .foregroundStyle(accentColor)
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private func estimatedReadingTimeSection(pageCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("Estimated Reading Time")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            let avgPagesPerHour = 30 // Average reading speed
            let hours = pageCount / avgPagesPerHour
            let days = hours / 2 // Assuming 2 hours reading per day
            
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("\(hours)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    Text("hours total")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(alignment: .leading) {
                    Text("\(days)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    Text("days at 2hr/day")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    // MARK: - Contextual Sections for Finished Reading
    
    @ViewBuilder
    private var yourReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Review")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    showingCompletionSheet = true
                    SensoryFeedback.light()
                } label: {
                    Text("Edit")
                    .font(.system(size: 14))
                    .foregroundStyle(accentColor)
                }
            }
            
            if let rating = book.userRating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(accentColor)
                    }
                }
                .padding(.bottom, 8)
            }
            
            if let notes = book.userNotes {
                Text(notes)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(8)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var addReviewPromptSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.leadinghalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(accentColor.opacity(0.8))
            
            Text("How was this book?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Text("Add your private rating and review")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Button {
                showingCompletionSheet = true
                SensoryFeedback.light()
            } label: {
                Text("Add Review")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var memorableQuotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("Memorable Quotes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(bookQuotes.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(in: Capsule())
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(bookQuotes) { quote in
                    BookQuoteCard(quote: quote)
                        .frame(width: 280)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var readingStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("Reading Stats")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            let daysSinceStart = Calendar.current.dateComponents([.day], from: book.dateAdded, to: Date()).day ?? 1
            let pagesPerDay = book.currentPage / max(1, daysSinceStart)
            
            HStack(spacing: 32) {
                VStack(alignment: .leading) {
                    Text("\(daysSinceStart)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    Text("days to finish")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(alignment: .leading) {
                    Text("\(pagesPerDay)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    Text("pages per day")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                }
                
                if bookQuotes.count > 0 {
                    VStack(alignment: .leading) {
                    Text("\(bookQuotes.count)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("quotes saved")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    // MARK: - Always Available Sections
    
    @ViewBuilder
    private var allNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("All Notes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(bookNotes.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(in: Capsule())
            }
            
            ForEach(bookNotes) { note in
                BookNoteCard(note: note)
                    .iOS26SwipeActions([
                    SwipeAction(
                        icon: "pencil",
                        backgroundColor: accentColor,
                        handler: {
                            NotificationCenter.default.post(
                                name: Notification.Name("EditNote"),
                                object: note
                            )
                            SensoryFeedback.light()
                        }
                    ),
                    SwipeAction(
                        icon: "trash.fill",
                        backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                        isDestructive: true,
                        handler: {
                            withAnimation(.spring(response: 0.4)) {
                                notesViewModel.deleteNote(note)
                            }
                        }
                    )
                    ])
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var allQuotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
                
                Text("All Quotes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(bookQuotes.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(in: Capsule())
            }
            
            ForEach(bookQuotes) { quote in
                BookQuoteCard(quote: quote)
                    .iOS26SwipeActions([
                    SwipeAction(
                        icon: "square.and.arrow.up",
                        backgroundColor: Color(red: 0.2, green: 0.6, blue: 1.0),
                        handler: {
                            ShareQuoteService.shareQuote(quote)
                            SensoryFeedback.success()
                        }
                    ),
                    SwipeAction(
                        icon: "trash.fill",
                        backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                        isDestructive: true,
                        handler: {
                            withAnimation(.spring(response: 0.4)) {
                                notesViewModel.deleteNote(quote)
                            }
                        }
                    )
                    ])
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
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
                    .iOS26SwipeActions([
                        SwipeAction(
                            icon: "pencil",
                            backgroundColor: accentColor,
                            handler: {
                                // Edit quote
                                NotificationCenter.default.post(
                                    name: Notification.Name("EditNote"),
                                    object: quote
                                )
                                SensoryFeedback.light()
                            }
                        ),
                        SwipeAction(
                            icon: "square.and.arrow.up",
                            backgroundColor: Color(red: 0.2, green: 0.6, blue: 1.0),
                            handler: {
                                // Share quote
                                ShareQuoteService.shareQuote(quote)
                                SensoryFeedback.success()
                            }
                        ),
                        SwipeAction(
                            icon: "trash.fill",
                            backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                            isDestructive: true,
                            handler: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    notesViewModel.deleteNote(quote)
                                }
                            }
                        )
                    ])
                }
            }
        }
    }

    private var oldNotesSection_Disabled: some View {
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
                    .iOS26SwipeActions([
                        SwipeAction(
                            icon: "pencil",
                            backgroundColor: accentColor,
                            handler: {
                                // Edit note
                                NotificationCenter.default.post(
                                    name: Notification.Name("EditNote"),
                                    object: note
                                )
                                SensoryFeedback.light()
                            }
                        ),
                        SwipeAction(
                            icon: "square.and.arrow.up",
                            backgroundColor: Color(red: 0.2, green: 0.6, blue: 1.0),
                            handler: {
                                // Share note as text
                                let shareText = """
                                \(note.content)
                                
                                — Note from "\(note.bookTitle ?? "Unknown Book")"
                                """
                                
                                let activityController = UIActivityViewController(
                                    activityItems: [shareText],
                                    applicationActivities: nil
                                )
                                
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    rootViewController.present(activityController, animated: true)
                                }
                                
                                SensoryFeedback.success()
                            }
                        ),
                        SwipeAction(
                            icon: "trash.fill",
                            backgroundColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                            isDestructive: true,
                            handler: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    notesViewModel.deleteNote(note)
                                }
                            }
                        )
                    ])
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
        
        // Use a subtle warm gradient as placeholder that works well with any book
        // This creates a pleasant default that transitions smoothly to extracted colors
        return ColorPalette(
            primary: Color(red: 0.4, green: 0.3, blue: 0.25),    // Warm brown
            secondary: Color(red: 0.3, green: 0.2, blue: 0.15),  // Darker warm brown
            accent: Color(red: 0.6, green: 0.4, blue: 0.3),      // Light warm brown
            background: Color(red: 0.15, green: 0.1, blue: 0.08), // Very dark warm brown
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: false,  // Not monochromatic so it gets full processing
            extractionQuality: 0.1 // Low quality to indicate placeholder
        )
    }
    
    private func extractColorsFromDisplayedImage(_ displayedImage: UIImage) async {
        // Check cache first - use localId like AmbientMode does
        let bookID = book.localId.uuidString
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
            // Use OKLABColorExtractor directly like AmbientMode does
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: displayedImage, imageSource: book.title)
            
            await MainActor.run {
                self.colorPalette = palette
                
                print("🎨 Low-res extracted colors:")
                print("  Primary: \(palette.primary)")
                print("  Secondary: \(palette.secondary)")
                print("  Accent: \(palette.accent)")
                print("  Background: \(palette.background)")
            }
            
            // Cache the result with localId
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
        } catch {
            print("❌ Error in color extraction: \(error)")
        }
        
        isExtractingColors = false
    }
    
    private func extractColorsFromCover() async {
        // Check cache first - use localId like AmbientMode does
        let bookID = book.localId.uuidString
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
            // Load image directly from URL like AmbientMode does
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else {
                print("❌ Failed to create image from data")
                isExtractingColors = false
                return
            }
            
            // Store the cover image
            self.coverImage = uiImage
            
            // Use OKLABColorExtractor directly like AmbientMode does
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: uiImage, imageSource: book.title)
            
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
            guard URL(string: secureURLString) != nil else {
                print("❌ Invalid cover URL for diagnostic")
                return
            }
            
            guard await SharedBookCoverManager.shared.loadFullImage(from: secureURLString) != nil else {
                print("❌ Could not load image for diagnostic from SharedBookCoverManager")
                return
            }
            
            // ColorExtractionDiagnostic was removed - diagnostic functionality no longer available
            // let diagnostic = ColorExtractionDiagnostic()
            // await diagnostic.runDiagnostic(on: uiImage, bookTitle: book.title)
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
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(textColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
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
                    .strokeBorder(DesignSystem.Colors.textQuaternary, lineWidth: 1)
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
        .foregroundColor(.white)
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
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: 56))
                    .foregroundStyle(DesignSystem.Colors.surfaceBackground)
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(DesignSystem.Colors.surfaceBackground)
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
                    .init(color: DesignSystem.Colors.surfaceBackground.opacity(0.1), location: 0),
                    .init(color: DesignSystem.Colors.surfaceBackground.opacity(1.0), location: 0.5),
                    .init(color: DesignSystem.Colors.surfaceBackground.opacity(0.1), location: 1.0)
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
                        .foregroundStyle(DesignSystem.Colors.surfaceBackground.opacity(0.8))
                    }
                    
                    if let bookTitle = quote.bookTitle {
                    Text(bookTitle.uppercased())
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(DesignSystem.Colors.surfaceBackground.opacity(0.6))
                    }
                    
                    if let pageNumber = quote.pageNumber {
                    Text("PAGE \(pageNumber)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(DesignSystem.Colors.surfaceBackground.opacity(0.5))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
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
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
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
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
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
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 10)
                    .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
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

// MARK: - Reading Session Views

// MARK: - Compact Session HUD (Bottom Floating) - Proper Glass Card
struct CompactSessionHUD: View {
    @Bindable var session: ReadingSession
    let book: Book
    @Binding var activeSession: ReadingSession?

    @State private var currentTime = Date()
    @State private var showingPageSheet = false
    @State private var editingPage = false
    @State private var pageText = ""
    @FocusState private var isPageFocused: Bool
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 20) {
            // Duration metric
            VStack(spacing: 4) {
                Text(session.formattedDuration)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))

                Text("DURATION")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 0.5)
                .frame(maxHeight: 40)

            // Page tracking - tappable to edit
            if editingPage {
                VStack(spacing: 4) {
                    TextField("Page", text: $pageText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .focused($isPageFocused)
                    .keyboardType(.numberPad)
                    .onSubmit {
                        savePageNumber()
                    }

                    Text("PAGE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                }
            } else {
                Button {
                    pageText = "\(session.endPage)"
                    editingPage = true
                    isPageFocused = true
                    SensoryFeedback.light()
                } label: {
                    VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Text("\(session.endPage)")
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))

                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Text("PAGE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.5)
                    }
                }
                .buttonStyle(.plain)
            }

            // Progress indicator if we have page count
            if let totalPages = book.pageCount, totalPages > 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 0.5)
                    .frame(maxHeight: 40)

                VStack(spacing: 4) {
                    Text("\(totalPages - session.endPage)")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))

                    Text("LEFT")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.001))
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onTapGesture {
            if editingPage {
                savePageNumber()
            }
        }
    }

    private func savePageNumber() {
        editingPage = false
        isPageFocused = false

        if let pageNumber = Int(pageText), pageNumber > 0 {
            session.updateCurrentPage(pageNumber)
            // Also update the book's current page for timeline progress
            if let bookModel = session.bookModel {
                bookModel.currentPage = pageNumber
            }
            print("📖 Updated session page to: \(pageNumber)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
}

// MARK: - End Session Sheet - Matches Ambient Session Summary
struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    @Bindable var session: ReadingSession
    let book: Book
    @Binding var activeSession: ReadingSession?
    let colorPalette: ColorPalette?
    @Binding var showingSessionSavedToast: Bool

    @State private var pagesRead: String
    @State private var currentPage: String
    @State private var isUpdatingFromPagesRead = false
    @State private var isUpdatingFromCurrentPage = false
    @FocusState private var focusedField: Field?

    enum Field {
        case pagesRead, currentPage
    }

    init(session: ReadingSession, book: Book, activeSession: Binding<ReadingSession?>, colorPalette: ColorPalette?, showingSessionSavedToast: Binding<Bool>) {
        self.session = session
        self.book = book
        self._activeSession = activeSession
        self.colorPalette = colorPalette
        self._showingSessionSavedToast = showingSessionSavedToast
        _pagesRead = State(initialValue: "0")
        _currentPage = State(initialValue: "\(session.startPage)")
    }

    // Enhanced color matching the gradient background
    private var accentColor: Color {
        guard let palette = colorPalette else { return Color.warmAmber }
        return enhanceColor(palette.primary)
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Same enhancement as BookAtmosphericGradientView
        saturation = min(saturation * 1.4, 1.0)  // Boost vibrancy
        brightness = max(brightness, 0.4)         // Minimum brightness

        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Duration - prominent at top
                VStack(spacing: 8) {
                    Text(session.formattedDuration)
                        .font(.system(size: 48, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("DURATION")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.2)
                }
                .padding(.top, 40)

                // Inputs contained in a single glass card
                VStack {
                    HStack(spacing: 24) {
                        // Pages Read
                        VStack(spacing: 8) {
                            TextField("0", text: $pagesRead)
                                .font(.system(size: 36, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                                .focused($focusedField, equals: .pagesRead)
                                .keyboardType(.numberPad)
                                .onChange(of: pagesRead) { _, newValue in
                                    if let pages = Int(newValue), !isUpdatingFromCurrentPage {
                                        isUpdatingFromPagesRead = true
                                        let calculated = session.startPage + pages
                                        currentPage = "\(calculated)"
                                        isUpdatingFromPagesRead = false
                                    }
                                }

                            Text("PAGES READ")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .padding(8)
                        .overlay {
                            if focusedField == .pagesRead {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(accentColor.opacity(0.5), lineWidth: 1)
                            }
                        }

                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.3))

                        // Current Page
                        VStack(spacing: 8) {
                            TextField("\(session.startPage)", text: $currentPage)
                                .font(.system(size: 36, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                                .focused($focusedField, equals: .currentPage)
                                .keyboardType(.numberPad)
                                .onChange(of: currentPage) { _, newValue in
                                    if let page = Int(newValue), !isUpdatingFromPagesRead {
                                        isUpdatingFromCurrentPage = true
                                        let calculated = page - session.startPage
                                        pagesRead = "\(max(0, calculated))"
                                        isUpdatingFromCurrentPage = false
                                    }
                                }

                            Text("CURRENT PAGE")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .padding(8)
                        .overlay {
                            if focusedField == .currentPage {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(accentColor.opacity(0.5), lineWidth: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                // Apply glass directly to the container (no background)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("End Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // Remove trailing primary to avoid two competing CTAs; bottom CTA is primary
            }
            // Bottom button area
            .safeAreaInset(edge: .bottom) {
                Button {
                    let finalPage = Int(currentPage) ?? session.endPage
                    session.endSession(at: finalPage)
                    if let bookModel = session.bookModel {
                        bookModel.currentPage = finalPage
                        try? modelContext.save()
                        print("📊 Session ended - Updated currentPage to \(finalPage)")
                        print("📊 Book total pages: \(bookModel.pageCount ?? 0)")
                    }
                    // Also update the Book struct through LibraryViewModel
                    libraryViewModel.updateCurrentPage(for: book, to: finalPage)
                    activeSession = nil
                    dismiss()
                    SensoryFeedback.success()

                    // Show success toast after a brief delay (after sheet dismisses)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingSessionSavedToast = true
                        }
                    }
                } label: {
                    Text("Save Session")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .glassEffect(.regular.tint(accentColor.opacity(0.3)), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            focusedField = .pagesRead
        }
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
        }
    }
}
