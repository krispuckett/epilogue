import SwiftUI
import SwiftData

// MARK: - Optimized Book Detail View
// This is a performance-optimized version that loads faster without touching the gradient system

struct OptimizedBookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // UI States
    @State private var selectedSection: BookSection = .notes
    @Namespace private var sectionAnimation
    @State private var scrollOffset: CGFloat = 0
    @State private var coverImage: UIImage? = nil
    
    // Performance Optimizations
    @State private var hasAppeared = false
    @State private var isInitialLoad = true
    @State private var colorPalette: ColorPalette?
    @State private var cachedPalette: ColorPalette?
    @State private var isLoadingHighRes = false
    
    // Settings
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    
    // MARK: - Performance Optimizations
    
    init(book: Book) {
        self.book = book
    }
    
    // Dynamic gradient opacity based on scroll (same as original)
    private var gradientOpacity: Double {
        let opacity = 1.0 - (min(scrollOffset, 200) / 200)
        return max(0.2, opacity)
    }
    
    // Keep all the same color calculations
    private var textColor: Color { .white }
    private var secondaryTextColor: Color { .white.opacity(0.8) }
    
    private var accentColor: Color {
        guard let palette = colorPalette ?? cachedPalette else {
            return Color(red: 1.0, green: 0.55, blue: 0.26)
        }
        
        let bookAccent = palette.accent
        let uiColor = UIColor(bookAccent)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0  
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let hueDegrees = hue * 360
        if (hueDegrees >= 180 && hueDegrees <= 280) ||
           (hueDegrees >= 150 && hueDegrees <= 180) ||
           (hueDegrees >= 80 && hueDegrees <= 150) {
            if brightness < 0.5 {
                // Adjust brightness manually
                let uiColor = UIColor(bookAccent)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                return Color(UIColor(hue: h, saturation: s, brightness: 0.6, alpha: a))
            }
            return bookAccent
        }
        
        if hueDegrees <= 80 || hueDegrees >= 280 {
            if hueDegrees >= 20 && hueDegrees <= 60 {
                return Color(red: 1.0, green: 0.55 + (0.15 * saturation), blue: 0.26)
            }
        }
        
        return Color(red: 1.0, green: 0.55, blue: 0.26)
    }
    
    var body: some View {
        ZStack {
            // GRADIENT SYSTEM - UNTOUCHED
            // Use cached palette first, then update when real palette loads
            BookAtmosphericGradientView(
                colorPalette: colorPalette ?? cachedPalette ?? generatePlaceholderPalette(),
                intensity: gradientIntensity
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(gradientOpacity)
            .animation(enableAnimations ? .easeOut(duration: 0.2) : nil, value: gradientOpacity)
            .id(book.id)
            
            // Content
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        // Scroll detector
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
                                    let offset = -newValue + 150
                                    scrollOffset = max(0, min(offset, 500))
                                }
                        }
                        .frame(height: 0)
                        
                        // Main Content - Lazy loaded
                        VStack(spacing: 32) {
                            // Header - loads immediately with cached colors
                            centeredHeaderView
                                .padding(.top, 60)
                            
                            // Progress section (if currently reading)
                            if book.readingStatus == .currentlyReading {
                                progressSection
                            }
                            
                            // Sections - lazy loaded
                            if !isInitialLoad {
                                sectionTabBar
                                    .padding(.horizontal)
                                
                                // Content sections
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
                                .transition(.opacity)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // Edit action
                    } label: {
                        Label("Edit Book", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        // Delete action
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            guard !hasAppeared else { return }
            hasAppeared = true
            
            // Check for cached colors immediately
            let bookID = book.localId.uuidString
            if let cached = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
                cachedPalette = cached
                colorPalette = cached
            }
            
            // Load sections after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.3)) {
                    isInitialLoad = false
                }
            }
            
            // Start high-res color extraction in background
            if colorPalette == nil && !isLoadingHighRes {
                Task.detached(priority: .background) {
                    await loadHighResColors()
                }
            }
        }
    }
    
    // MARK: - Optimized Header
    
    private var centeredHeaderView: some View {
        VStack(spacing: 16) {
            // Optimized cover loading
            OptimizedBookCoverView(
                book: book,
                width: 180,
                height: 270,
                onImageLoaded: { image in
                    self.coverImage = image
                    
                    // Only extract colors if we don't have cached ones
                    if colorPalette == nil && cachedPalette == nil {
                        Task.detached(priority: .utility) {
                            await extractQuickColors(from: image)
                        }
                    }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            
            // Title
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Author
            Text("by \(book.author)")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(secondaryTextColor)
            
            // Status badge
            HStack(spacing: 16) {
                statusBadge
                
                if let pageCount = book.pageCount {
                    Text("\(pageCount) pages")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
    }
    
    private var statusBadge: some View {
        Text(book.readingStatus.rawValue)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Lazy Sections
    
    private var sectionTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSection = section
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: section.icon)
                            .font(.system(size: 20))
                        Text(section.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedSection == section ? accentColor : secondaryTextColor)
                    .overlay(alignment: .bottom) {
                        if selectedSection == section {
                            Rectangle()
                                .fill(accentColor)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tab", in: sectionAnimation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var progressSection: some View {
        Text("Progress section placeholder")
            .foregroundColor(.white)
            .padding()
    }
    
    private var notesSection: some View {
        LazyVStack(spacing: 16) {
            Text("Notes will load here")
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    private var quotesSection: some View {
        LazyVStack(spacing: 16) {
            Text("Quotes will load here")
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    private var chatSection: some View {
        VStack {
            Text("Chat section")
                .foregroundColor(.white)
        }
        .padding()
    }
    
    // MARK: - Optimized Color Extraction
    
    private func extractQuickColors(from image: UIImage) async {
        // Quick extraction for immediate UI update
        let bookID = book.localId.uuidString
        
        // Downsample for quick extraction
        let quickImage = await image.resized(to: CGSize(width: 200, height: 300)) ?? image
        
        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: quickImage, imageSource: bookID)
            
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    self.colorPalette = palette
                }
            }
            
            // Cache it
            if let coverURL = book.coverImageURL {
                await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: coverURL)
            }
        } catch {
            print("Quick color extraction failed: \(error)")
        }
    }
    
    private func loadHighResColors() async {
        guard !isLoadingHighRes else { return }
        isLoadingHighRes = true
        
        // Load high-res image in background
        guard let coverURL = book.coverImageURL,
              let fullImage = await SharedBookCoverManager.shared.loadFullImage(from: coverURL) else {
            isLoadingHighRes = false
            return
        }
        
        // Extract high quality colors
        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: fullImage, imageSource: book.localId.uuidString)
            
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.5)) {
                    self.colorPalette = palette
                }
            }
            
            // Update cache with high-res palette
            await BookColorPaletteCache.shared.cachePalette(
                palette,
                for: book.localId.uuidString,
                coverURL: coverURL
            )
        } catch {
            print("High-res color extraction failed: \(error)")
        }
        
        isLoadingHighRes = false
    }
}

// MARK: - Optimized Cover View
struct OptimizedBookCoverView: View {
    let book: Book
    let width: CGFloat
    let height: CGFloat
    let onImageLoaded: ((UIImage) -> Void)?
    
    @State private var displayImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .animation(.easeIn(duration: 0.3), value: displayImage != nil)
        .task(id: book.localId) {
            guard displayImage == nil else { return }
            
            // Load thumbnail first for instant display
            if let coverURL = book.coverImageURL,
               let thumbnail = await SharedBookCoverManager.shared.loadThumbnail(from: coverURL) {
                displayImage = thumbnail
                onImageLoaded?(thumbnail)
                
                // Then load full image
                if let fullImage = await SharedBookCoverManager.shared.loadLibraryThumbnail(from: coverURL) {
                    displayImage = fullImage
                    onImageLoaded?(fullImage)
                }
            }
            
            isLoading = false
        }
    }
}

// MARK: - BookSection (local copy to avoid conflicts)
private enum BookSection: String, CaseIterable {
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

// Generate placeholder while loading
private func generatePlaceholderPalette() -> ColorPalette {
    ColorPalette(
        primary: Color(red: 0.2, green: 0.2, blue: 0.3),
        secondary: Color(red: 0.3, green: 0.3, blue: 0.4),
        accent: Color(red: 1.0, green: 0.55, blue: 0.26),
        background: Color.black,
        textColor: .white,
        luminance: 0.3,
        isMonochromatic: false,
        extractionQuality: 1.0
    )
}