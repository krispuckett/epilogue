import SwiftUI
import SwiftData

// MARK: - Animation Phase
enum ReturnCardAnimationPhase: Equatable {
    case hidden      // At Dynamic Island, pill shape, opacity 0
    case appearing   // Growing pill, opacity 1
    case dropping    // Moving to center
    case expanded    // Full card size, content visible
    case dismissing  // Reverse back to island
}

// MARK: - Return Card Overlay
/// Overlay that manages the return card animation from Dynamic Island
struct ReturnCardOverlay: View {
    @Environment(\.modelContext) private var modelContext

    // Query for currently reading books
    @Query(
        filter: #Predicate<BookModel> { $0.readingStatus == "Currently Reading" },
        sort: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
    ) private var currentlyReadingBooks: [BookModel]

    // Fallback: any book with cover data
    @Query(
        sort: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
    ) private var allBooks: [BookModel]

    @State private var phase: ReturnCardAnimationPhase = .hidden
    @State private var colorPalette: ColorPalette?
    @State private var contentOpacity: Double = 0

    let onDismiss: () -> Void

    // Dynamic Island dimensions (approximate for iPhone 14 Pro+)
    private let islandWidth: CGFloat = 126
    private let islandHeight: CGFloat = 37
    private let islandY: CGFloat = 60

    // Card dimensions
    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 420

    private var currentBook: BookModel? {
        // First try currently reading with cover
        if let book = currentlyReadingBooks.first(where: { $0.coverImageData != nil }) {
            return book
        }
        // Fallback to any book with cover
        return allBooks.first(where: { $0.coverImageData != nil })
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimming background
                Color.black
                    .opacity(dimmingOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                // The morphing card
                if let book = currentBook {
                    morphingCard(book: book, in: geometry)
                        .position(cardPosition(in: geometry))
                        .onTapGesture {
                            dismiss()
                        }
                } else {
                    // Debug: No book found - show message and auto-dismiss
                    Text("No book with cover found")
                        .foregroundStyle(.white.opacity(0.6))
                        .task {
                            #if DEBUG
                            print("🎴 ReturnCard: No book found. Currently reading: \(currentlyReadingBooks.count), All books: \(allBooks.count)")
                            for book in allBooks.prefix(3) {
                                print("  - \(book.title): hasCover=\(book.coverImageData != nil), status=\(book.readingStatus)")
                            }
                            #endif
                            // Auto-dismiss after brief delay
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            dismiss()
                        }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await extractColors()
            startAnimation()
        }
    }

    // MARK: - Morphing Card

    @ViewBuilder
    private func morphingCard(book: BookModel, in geometry: GeometryProxy) -> some View {
        ZStack {
            // Atmospheric gradient background
            atmosphericGradient
                .blur(radius: 30)

            // Card content
            ReturnCardContent(
                book: book,
                colorPalette: colorPalette,
                contentOpacity: contentOpacity
            )
        }
        .frame(width: currentWidth, height: currentHeight)
        .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(shadowOpacity), radius: 40, y: 20)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
    }

    // MARK: - Atmospheric Gradient

    private var atmosphericGradient: some View {
        Group {
            if let palette = colorPalette {
                let colors = [palette.primary, palette.secondary, palette.accent, palette.background]
                let enhanced = colors.map { enhanceColor($0) }

                LinearGradient(
                    stops: [
                        .init(color: enhanced[0].opacity(1.0), location: 0.0),
                        .init(color: enhanced[1].opacity(0.8), location: 0.15),
                        .init(color: enhanced[2].opacity(0.5), location: 0.3),
                        .init(color: enhanced[3].opacity(0.3), location: 0.45),
                        .init(color: Color.clear, location: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [.purple.opacity(0.6), .blue.opacity(0.4), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let enhancedSaturation = min(saturation * 1.4, 1.0)
        let enhancedBrightness = max(brightness, 0.4)

        return Color(hue: Double(hue), saturation: Double(enhancedSaturation), brightness: Double(enhancedBrightness))
    }

    // MARK: - Animation Properties

    private var currentWidth: CGFloat {
        switch phase {
        case .hidden, .appearing:
            return islandWidth
        case .dropping:
            return cardWidth * 0.6
        case .expanded:
            return cardWidth
        case .dismissing:
            return islandWidth
        }
    }

    private var currentHeight: CGFloat {
        switch phase {
        case .hidden, .appearing:
            return islandHeight
        case .dropping:
            return cardHeight * 0.4
        case .expanded:
            return cardHeight
        case .dismissing:
            return islandHeight
        }
    }

    private var currentCornerRadius: CGFloat {
        switch phase {
        case .hidden, .appearing, .dismissing:
            return islandHeight / 2 // Pill shape
        case .dropping:
            return 28
        case .expanded:
            return 24
        }
    }

    private func cardPosition(in geometry: GeometryProxy) -> CGPoint {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2

        switch phase {
        case .hidden, .appearing:
            return CGPoint(x: centerX, y: islandY)
        case .dropping:
            return CGPoint(x: centerX, y: centerY * 0.7)
        case .expanded:
            return CGPoint(x: centerX, y: centerY)
        case .dismissing:
            return CGPoint(x: centerX, y: islandY)
        }
    }

    private var cardOpacity: Double {
        switch phase {
        case .hidden:
            return 0
        case .appearing, .dropping, .expanded:
            return 1
        case .dismissing:
            return 0
        }
    }

    private var cardScale: CGFloat {
        switch phase {
        case .hidden:
            return 0.8
        case .appearing, .dropping, .expanded:
            return 1.0
        case .dismissing:
            return 0.8
        }
    }

    private var dimmingOpacity: Double {
        switch phase {
        case .hidden, .appearing:
            return 0
        case .dropping:
            return 0.4
        case .expanded:
            return 0.7
        case .dismissing:
            return 0
        }
    }

    private var shadowOpacity: Double {
        switch phase {
        case .hidden, .appearing, .dismissing:
            return 0
        case .dropping:
            return 0.3
        case .expanded:
            return 0.5
        }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 1: Appear at island
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            phase = .appearing
        }

        // Phase 2: Drop down
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                phase = .dropping
            }
        }

        // Phase 3: Expand to full size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                phase = .expanded
            }
        }

        // Phase 4: Fade in content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                contentOpacity = 1.0
            }
        }
    }

    private func dismiss() {
        SensoryFeedback.light()

        // Fade out content first
        withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
            contentOpacity = 0
        }

        // Then morph back to island
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phase = .dismissing
            }
        }

        // Complete dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }

    // MARK: - Color Extraction

    private func extractColors() async {
        guard let book = currentBook,
              let imageData = book.coverImageData,
              let image = UIImage(data: imageData) else {
            return
        }

        let extractor = OKLABColorExtractor()
        if let palette = try? await extractor.extractPalette(from: image, imageSource: "return_card") {
            await MainActor.run {
                colorPalette = palette
            }
        }
    }
}

// MARK: - Return Card Content
/// The actual content inside the return card
struct ReturnCardContent: View {
    let book: BookModel
    let colorPalette: ColorPalette?
    let contentOpacity: Double

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Welcome back"
        }
    }

    private var subGreeting: String {
        "Picking up where you left off"
    }

    private var progressPercent: Double {
        guard let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }

    private var bookCoverImage: UIImage? {
        guard let data = book.coverImageData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Greeting
            VStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subGreeting)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .opacity(contentOpacity)

            // Book info
            VStack(spacing: 16) {
                // Book cover
                if let image = bookCoverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                }

                // Book title and progress
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))

                    // Progress indicator
                    progressBar
                        .padding(.top, 8)
                }
            }
            .opacity(contentOpacity)

            // Reading streak badge (if applicable)
            if let streak = readingStreak, streak > 0 {
                streakBadge(days: streak)
                    .opacity(contentOpacity)
            }
        }
        .padding(32)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercent, height: 4)
                }
            }
            .frame(height: 4)
            .frame(width: 160)

            Text("\(Int(progressPercent * 100))% complete")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Streak Badge

    private func streakBadge(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            Text("\(days) day streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.white.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Reading Streak (placeholder - would need actual streak data)

    private var readingStreak: Int? {
        // TODO: Get actual reading streak from ReadingStreakManager or similar
        // For now, return nil to hide the badge
        nil
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ReturnCardOverlay {
            print("Dismissed!")
        }
    }
    .modelContainer(for: BookModel.self)
}
