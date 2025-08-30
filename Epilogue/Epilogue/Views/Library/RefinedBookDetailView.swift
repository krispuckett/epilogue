import SwiftUI
import SwiftData

// MARK: - Refined Book Detail View with Smooth Animations
struct RefinedBookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Animation States
    @State private var viewPhase: ViewPhase = .initial
    @State private var coverScale: CGFloat = 0.85
    @State private var coverOpacity: Double = 0
    @State private var coverBlur: CGFloat = 10
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var metadataOpacity: Double = 0
    @State private var contentSections: [Bool] = [false, false, false, false]
    @State private var scrollOffset: CGFloat = 0
    @State private var coverImage: UIImage? = nil
    
    // Color & Gradient
    @State private var colorPalette: ColorPalette?
    @State private var gradientOpacity: Double = 0
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    
    // Section Selection
    @State private var selectedSection: BookSection = .notes
    @Namespace private var sectionAnimation
    
    enum ViewPhase {
        case initial
        case loadingColors
        case animatingIn
        case ready
    }
    
    // MARK: - Computed Properties
    
    private var dynamicGradientOpacity: Double {
        let scrollFade = 1.0 - (min(scrollOffset, 200) / 200)
        return max(0.2, scrollFade) * gradientOpacity
    }
    
    private var textColor: Color { .white }
    private var secondaryTextColor: Color { .white.opacity(0.8) }
    
    private var accentColor: Color {
        guard let palette = colorPalette else {
            return DesignSystem.Colors.primaryAccent
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
        
        return DesignSystem.Colors.primaryAccent
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Gradient Background with smooth fade-in
            BookAtmosphericGradientView(
                colorPalette: colorPalette ?? generatePlaceholderPalette(),
                intensity: gradientIntensity
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(dynamicGradientOpacity)
            .animation(.easeOut(duration: 0.8), value: dynamicGradientOpacity)
            .blur(radius: viewPhase == .initial ? 20 : 0)
            .animation(.easeOut(duration: 1.0), value: viewPhase)
            
            // Main Content
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Invisible scroll detector
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                    scrollOffset = max(0, -newValue + 150)
                                }
                        }
                        .frame(height: 0)
                        
                        // Header with staggered animations
                        animatedHeaderView
                            .padding(.top, 20)
                        
                        // Content sections with cascade effect
                        VStack(spacing: 24) {
                            // Summary
                            if contentSections[0], let description = book.description {
                                summarySection(description: description)
                                    .transition(.asymmetric(
                                        insertion: .opacity
                                            .combined(with: .scale(scale: 0.95, anchor: .top))
                                            .combined(with: .offset(y: 10)),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Progress
                            if contentSections[1], book.readingStatus == .currentlyReading {
                                progressSection
                                    .transition(.asymmetric(
                                        insertion: .opacity
                                            .combined(with: .scale(scale: 0.95, anchor: .leading))
                                            .combined(with: .offset(x: -10)),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Section Tabs
                            if contentSections[2] {
                                sectionTabBar
                                    .transition(.asymmetric(
                                        insertion: .opacity
                                            .combined(with: .scale(scale: 0.98))
                                            .combined(with: .offset(y: 5)),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Content
                            if contentSections[3] {
                                selectedContentSection
                                    .transition(.asymmetric(
                                        insertion: .opacity
                                            .combined(with: .move(edge: .bottom))
                                            .combined(with: .scale(scale: 0.98)),
                                        removal: .opacity
                                    ))
                                    .scrollTransition { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : 0.6)
                                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                            .blur(radius: phase.isIdentity ? 0 : 1)
                                    }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                        .padding(.bottom, 100)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startAnimationSequence()
        }
    }
    
    // MARK: - Animated Header
    
    private var animatedHeaderView: some View {
        VStack(spacing: 20) {
            // Book Cover with elegant entrance
            SharedBookCoverView(
                coverURL: book.coverImageURL,
                width: 180,
                height: 270,
                loadFullImage: true,
                isLibraryView: false,
                onImageLoaded: { uiImage in
                    self.coverImage = uiImage
                    extractColors(from: uiImage)
                }
            )
            .scaleEffect(coverScale)
            .opacity(coverOpacity)
            .blur(radius: coverBlur)
            .shadow(
                color: .black.opacity(coverOpacity * 0.3),
                radius: 20 * coverOpacity,
                y: 10 * coverOpacity
            )
            .rotation3DEffect(
                .degrees(coverScale < 1 ? 5 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            
            // Title with slide-up animation
            VStack(spacing: 12) {
                Text(book.title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                    .blur(radius: titleOpacity < 1 ? 2 : 0)
                
                // Author
                Text("by \(book.author)")
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
                    .opacity(metadataOpacity)
                    .scaleEffect(metadataOpacity)
                
                // Status badge
                HStack(spacing: 16) {
                    statusBadge
                        .opacity(metadataOpacity)
                        .scaleEffect(metadataOpacity < 1 ? 0.9 : 1)
                    
                    if let pageCount = book.pageCount {
                        Text("\(pageCount) pages")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                            .opacity(metadataOpacity)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }
    
    private var statusBadge: some View {
        Text(book.readingStatus.rawValue)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.2))
                    .overlay(
                        Capsule()
                            .strokeBorder(accentColor.opacity(0.5), lineWidth: 1)
                    )
            )
    }
    
    // MARK: - Content Sections
    
    private var sectionTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BookSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }
    
    @ViewBuilder
    private var selectedContentSection: some View {
        switch selectedSection {
        case .notes:
            notesSection
        case .quotes:
            quotesSection
        case .chat:
            chatSection
        }
    }
    
    private var notesSection: some View {
        VStack(spacing: 16) {
            Text("Notes section")
                .foregroundColor(.white)
        }
    }
    
    private var quotesSection: some View {
        VStack(spacing: 16) {
            Text("Quotes section")
                .foregroundColor(.white)
        }
    }
    
    private var chatSection: some View {
        VStack(spacing: 16) {
            Text("Chat section")
                .foregroundColor(.white)
        }
    }
    
    private func summarySection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(textColor)
            
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(secondaryTextColor)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Reading Progress")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Text("\(book.currentPage) / \(book.pageCount ?? 0)")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
            }
            .foregroundColor(textColor)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var progressPercentage: Double {
        guard let total = book.pageCount, total > 0 else { return 0 }
        return Double(book.currentPage) / Double(total)
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() async {
        // Check for cached colors first
        let bookID = book.localId.uuidString
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                self.colorPalette = cachedPalette
                viewPhase = .loadingColors
            }
        }
        
        // Start entrance animations
        await MainActor.run {
            viewPhase = .animatingIn
            
            // Gradient fade in
            withAnimation(.easeOut(duration: 0.8)) {
                gradientOpacity = 1.0
            }
            
            // Cover animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                coverScale = 1.0
                coverOpacity = 1.0
                coverBlur = 0
            }
        }
        
        // Title animation (delayed)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
        }
        
        // Metadata animation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        await MainActor.run {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                metadataOpacity = 1.0
            }
        }
        
        // Content sections cascade
        for i in 0..<contentSections.count {
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s between each
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    contentSections[i] = true
                }
            }
        }
        
        // Mark as ready
        await MainActor.run {
            viewPhase = .ready
        }
    }
    
    // MARK: - Color Extraction
    
    private func extractColors(from image: UIImage) {
        guard colorPalette == nil else { return }
        
        Task.detached(priority: .userInitiated) {
            let bookID = book.localId.uuidString
            let extractor = await OKLABColorExtractor()
            
            if let palette = try? await extractor.extractPalette(from: image, imageSource: bookID) {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.colorPalette = palette
                    }
                }
                
                // Cache it
                if let coverURL = book.coverImageURL {
                    await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: coverURL)
                }
            }
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
        accent: DesignSystem.Colors.primaryAccent,
        background: Color.black,
        textColor: .white,
        luminance: 0.3,
        isMonochromatic: false,
        extractionQuality: 1.0
    )
}