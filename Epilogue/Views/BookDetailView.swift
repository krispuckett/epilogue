import SwiftUI
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

struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedSection: BookSection = .notes
    @Namespace private var sectionAnimation
    
    // Questions data - will be replaced with real chat integration
    @State private var questions: [BookQuestion] = []
    
    // UI States
    @State private var summaryExpanded = false
    @State private var coverImage: UIImage?
    @State private var dominantColor: Color = .midnightScholar
    @State private var secondaryColor: Color = .clear
    @State private var scrollOffset: CGFloat = 0
    
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
        case questions = "Questions"
        
        var icon: String {
            switch self {
            case .notes: return "note.text"
            case .quotes: return "quote.opening"
            case .questions: return "questionmark.circle"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Base midnight scholar background
            Color.midnightScholar
                .ignoresSafeArea()
            
            // Ambient gradient background from book colors
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.4),
                    secondaryColor.opacity(0.3),
                    dominantColor.opacity(0.2),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Radial glow at the top with secondary color accent
            RadialGradient(
                colors: [
                    secondaryColor == .clear ? dominantColor.opacity(0.3) : secondaryColor.opacity(0.4),
                    dominantColor.opacity(0.2),
                    Color.clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Centered header with book info
                    centeredHeaderView
                        .padding(.top, 20)
                    
                    // Summary section
                    if let description = book.description {
                        summarySection(description: description)
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                    }
                    
                    // Content sections
                    contentView
                        .padding(.top, 24)
                        .padding(.bottom, 100) // Space for tab bar
                }
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
                Button("Edit") {
                    editedTitle = book.title
                    showingBookSearch = true
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.warmAmber)
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
            loadCoverImage()
        }
    }
    
    private var centeredHeaderView: some View {
        VStack(spacing: 16) {
            // Book Cover with 3D effect
            Group {
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .rotation3DEffect(
                            .degrees(5),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .scaleEffect(1 + (scrollOffset > 0 ? scrollOffset / 1000 : 0))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 180, height: 270)
                        .overlay(
                            ProgressView()
                                .tint(.warmWhite.opacity(0.5))
                        )
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                }
            }
            
            // Title
            Text(book.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundColor(.warmWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Author
            Text("by \(book.author)")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .kerning(1.2)
                .foregroundColor(.warmWhite.opacity(0.8))
                .padding(.top, -8)
            
            // Status and page info
            HStack(spacing: 16) {
                StatusPill(text: book.readingStatus.rawValue, color: .warmAmber)
                
                if let pageCount = book.pageCount {
                    Text("\(book.currentPage) of \(pageCount) pages")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.warmWhite.opacity(0.7))
                }
                
                if let rating = book.userRating {
                    StatusPill(text: "★ \(rating)", color: .warmWhite.opacity(0.7))
                }
            }
            .padding(.top, 8)
            
            // Icon-only segmented control
            iconOnlySegmentedControl
                .padding(.top, 20)
        }
    }
    
    private func summarySection(description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(.warmAmber.opacity(0.8))
                
                Text("Summary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.warmWhite)
                
                Spacer()
                
                Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.warmWhite.opacity(0.6))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    summaryExpanded.toggle()
                }
            }
            
            // Summary text
            Text(description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.warmWhite.opacity(0.85))
                .lineSpacing(8)
                .lineLimit(summaryExpanded ? nil : 4)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: summaryExpanded)
            
            // Read more/less button
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
                        .foregroundColor(.warmAmber)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.warmWhite.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.warmWhite.opacity(0.05), lineWidth: 0.5)
                }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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
                    .foregroundColor(selectedSection == section ? .warmWhite : .warmWhite.opacity(0.6))
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
                        .foregroundColor(selectedSection == section ? .warmAmber : .warmWhite.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background {
                            if selectedSection == section {
                                Circle()
                                    .fill(Color.warmAmber.opacity(0.15))
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color.warmAmber.opacity(0.3), lineWidth: 1)
                                    }
                                    .shadow(color: Color.warmAmber.opacity(0.3), radius: 6)
                                    .matchedGeometryEffect(id: "iconSelection", in: sectionAnimation)
                            }
                        }
                }
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
            case .questions:
                questionsSection
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
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
                        .padding(.horizontal, 24)
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
                        .padding(.horizontal, 24)
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
    
    private var questionsSection: some View {
        VStack(spacing: 16) {
            if questions.isEmpty {
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "No questions yet",
                    subtitle: "Navigate to Chat to ask about this book"
                )
            } else {
                ForEach(questions) { question in
                    QuestionCard(question: question)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.warmWhite.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.warmWhite.opacity(0.7))
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.warmWhite.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Color Extraction
    
    private func loadCoverImage() {
        guard let urlString = book.coverImageURL?.replacingOccurrences(of: "http://", with: "https://"),
              let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = uiImage
                    self.extractDominantColor(from: uiImage)
                }
            }
        }.resume()
    }
    
    private func extractDominantColor(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        let context = CIContext()
        let size = CGSize(width: 50, height: 50)
        
        // Scale down for performance
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = Float(size.width / ciImage.extent.width)
        
        guard let outputImage = scaleFilter.outputImage else { return }
        
        // Extract colors
        let extent = outputImage.extent
        let bitmap = context.createCGImage(outputImage, from: extent)
        
        guard let cgImage = bitmap else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        bitmapContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Collect all colors with their frequencies
        var colorCounts: [UIColor: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let index = ((width * y) + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Quantize colors to reduce variations
                let quantizedR = round(r * 10) / 10
                let quantizedG = round(g * 10) / 10
                let quantizedB = round(b * 10) / 10
                
                let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                colorCounts[color, default: 0] += 1
            }
        }
        
        // Sort colors by frequency and filter out very dark/light colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
            .compactMap { (color, _) -> (UIColor, CGFloat, CGFloat, CGFloat)? in
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                
                // Filter out very dark, very light, or desaturated colors
                if b > 0.2 && b < 0.95 && s > 0.2 {
                    return (color, h, s, b)
                }
                return nil
            }
        
        // Get primary and secondary colors
        if let firstColor = sortedColors.first {
            let (_, h1, s1, b1) = firstColor
            
            // Boost saturation for primary color
            let boostedS1 = min(s1 * 1.5, 1.0)
            let boostedB1 = min(b1 * 1.3, 0.85)
            
            withAnimation(.easeInOut(duration: 0.8)) {
                dominantColor = Color(hue: Double(h1), saturation: Double(boostedS1), brightness: Double(boostedB1))
            }
            
            // Look for a contrasting secondary color
            if sortedColors.count > 1 {
                // Find a color with different hue
                for i in 1..<min(sortedColors.count, 10) {
                    let (_, h2, s2, b2) = sortedColors[i]
                    let hueDiff = abs(h1 - h2)
                    
                    // If hue is different enough (at least 30 degrees on color wheel)
                    if hueDiff > 0.083 && hueDiff < 0.917 { // 30/360 and not opposite
                        let boostedS2 = min(s2 * 1.4, 1.0)
                        let boostedB2 = min(b2 * 1.2, 0.8)
                        
                        withAnimation(.easeInOut(duration: 0.8)) {
                            secondaryColor = Color(hue: Double(h2), saturation: Double(boostedS2), brightness: Double(boostedB2))
                        }
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
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
    }
}