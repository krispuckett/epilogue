import SwiftUI
import SwiftData
import CoreMotion
import Combine

/// Reading Wrapped Experiment
/// A Spotify Wrapped-style annual reading summary with sophisticated visual effects
/// Access from Settings > Developer Options
struct ReadingWrappedExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // View state
    @State private var currentCardIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating: Bool = false

    // Motion tracking
    @State private var motionManager = CMMotionManager()
    @State private var pitch: Double = 0
    @State private var roll: Double = 0

    // Shader animation
    @State private var time: CGFloat = 0
    @State private var showControls: Bool = false

    // Shader parameters
    @State private var chromaticSpread: CGFloat = 0.5
    @State private var displacementIntensity: CGFloat = 0.6

    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    // Mock wrapped data
    private var wrappedData: MockWrappedData {
        MockWrappedData.generate(from: books)
    }

    private var cards: [WrappedCard] {
        [
            .intro,
            .booksRead,
            .topBook,
            .readingTime,
            .topGenre,
            .readingStreak,
            .topQuote,
            .yearInReview
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Deep black background
                Color.black
                    .ignoresSafeArea()

                // Card carousel
                GeometryReader { geometry in
                    ZStack {
                        ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                            wrappedCardView(card: card, index: index, size: geometry.size)
                                .opacity(cardOpacity(for: index))
                                .scaleEffect(cardScale(for: index))
                                .offset(x: cardOffset(for: index, width: geometry.size.width))
                                .zIndex(Double(cards.count - abs(index - currentCardIndex)))
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                handleDragEnd(value: value, width: geometry.size.width)
                            }
                    )
                }

                // Navigation dots
                VStack {
                    Spacer()
                    navigationDots
                        .padding(.bottom, 60)
                }

                // Controls overlay
                if showControls {
                    VStack {
                        Spacer()
                        controlsPanel
                            .padding(.bottom, 120)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                setupMotionTracking()
            }
            .onDisappear {
                motionManager.stopDeviceMotionUpdates()
            }
            .onReceive(timer) { _ in
                time += 1/60
            }
        }
    }

    // MARK: - Card View
    @ViewBuilder
    private func wrappedCardView(card: WrappedCard, index: Int, size: CGSize) -> some View {
        ZStack {
            // Dynamic background based on card type
            cardBackground(for: card)
                .layerEffect(
                    ShaderLibrary.chromatic_liquid(
                        .boundingRect,
                        .float(time),
                        .float(displacementIntensity),
                        .float(chromaticSpread)
                    ),
                    maxSampleOffset: CGSize(width: 50, height: 50)
                )

            // Card content
            cardContent(for: card)
                .offset(x: roll * 6, y: pitch * 6)
        }
        .frame(width: size.width * 0.85, height: size.height * 0.7)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: cardShadowColor(for: card).opacity(0.4), radius: 40, y: 20)
        .rotation3DEffect(
            .degrees(roll * 4),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .rotation3DEffect(
            .degrees(-pitch * 4),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
    }

    // MARK: - Card Backgrounds
    @ViewBuilder
    private func cardBackground(for card: WrappedCard) -> some View {
        switch card {
        case .intro:
            RadialGradient(
                colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.6),
                    Color(red: 0.2, green: 0.1, blue: 0.4),
                    Color.black
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        case .booksRead:
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.6),
                    Color(red: 0.05, green: 0.2, blue: 0.4),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .topBook:
            if let topBook = wrappedData.topBook,
               let imageData = topBook.coverImageData,
               let image = UIImage(data: imageData) {
                BookAtmosphericGradientWithImage(image: image)
                    .blur(radius: 40)
            } else {
                defaultGradient(hue: 0.05)
            }
        case .readingTime:
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.3, blue: 0.1),
                    Color(red: 0.3, green: 0.15, blue: 0.05),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .topGenre:
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.5, blue: 0.3),
                    Color(red: 0.1, green: 0.3, blue: 0.2),
                    Color.black
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .readingStreak:
            RadialGradient(
                colors: [
                    Color(red: 0.8, green: 0.4, blue: 0.1),
                    Color(red: 0.5, green: 0.2, blue: 0.05),
                    Color.black
                ],
                center: .center,
                startRadius: 0,
                endRadius: 350
            )
        case .topQuote:
            LinearGradient(
                colors: [
                    Color(red: 0.3, green: 0.2, blue: 0.5),
                    Color(red: 0.15, green: 0.1, blue: 0.3),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .yearInReview:
            // Composite gradient from all book colors
            meshGradientBackground
        }
    }

    private func defaultGradient(hue: Double) -> some View {
        LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.6, brightness: 0.5),
                Color(hue: hue, saturation: 0.5, brightness: 0.3),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var meshGradientBackground: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                Color(red: 0.4, green: 0.2, blue: 0.6),
                Color(red: 0.2, green: 0.4, blue: 0.5),
                Color(red: 0.5, green: 0.3, blue: 0.2),
                Color(red: 0.3, green: 0.5, blue: 0.4),
                Color.black,
                Color(red: 0.6, green: 0.3, blue: 0.4),
                Color(red: 0.2, green: 0.3, blue: 0.5),
                Color(red: 0.4, green: 0.4, blue: 0.3),
                Color(red: 0.5, green: 0.2, blue: 0.4)
            ]
        )
    }

    private func cardShadowColor(for card: WrappedCard) -> Color {
        switch card {
        case .intro: return .purple
        case .booksRead: return .blue
        case .topBook: return .orange
        case .readingTime: return .orange
        case .topGenre: return .green
        case .readingStreak: return .orange
        case .topQuote: return .purple
        case .yearInReview: return .white
        }
    }

    // MARK: - Card Content
    @ViewBuilder
    private func cardContent(for card: WrappedCard) -> some View {
        switch card {
        case .intro:
            introContent
        case .booksRead:
            booksReadContent
        case .topBook:
            topBookContent
        case .readingTime:
            readingTimeContent
        case .topGenre:
            topGenreContent
        case .readingStreak:
            readingStreakContent
        case .topQuote:
            topQuoteContent
        case .yearInReview:
            yearInReviewContent
        }
    }

    // MARK: - Card Contents

    private var introContent: some View {
        VStack(spacing: 24) {
            Text("Your")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.7))

            Text("2024")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Reading Wrapped")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Let's see what you've been reading")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 20)
        }
    }

    private var booksReadContent: some View {
        VStack(spacing: 20) {
            Text("You read")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Text("\(wrappedData.totalBooks)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .cyan.opacity(0.5), radius: 20)

            Text("books this year")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("That's \(wrappedData.pagesRead.formatted()) pages of adventure")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 16)
        }
    }

    private var topBookContent: some View {
        VStack(spacing: 20) {
            Text("Your top book")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            if let topBook = wrappedData.topBook,
               let imageData = topBook.coverImageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            }

            VStack(spacing: 8) {
                Text(wrappedData.topBook?.title ?? "The Great Gatsby")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(wrappedData.topBook?.author ?? "F. Scott Fitzgerald")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("You spent the most time with this one")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }

    private var readingTimeContent: some View {
        VStack(spacing: 24) {
            Text("You spent")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(wrappedData.totalHours)")
                    .font(.system(size: 90, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("hours")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text("lost in books")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 8) {
                Text("That's \(wrappedData.totalHours / 24) full days")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))

                Text("or \(wrappedData.minutesPerDay) minutes per day")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.top, 16)
        }
    }

    private var topGenreContent: some View {
        VStack(spacing: 24) {
            Text("Your favorite genre")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(wrappedData.topGenre)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Genre breakdown
            VStack(spacing: 12) {
                ForEach(wrappedData.genreBreakdown.prefix(4), id: \.genre) { item in
                    HStack {
                        Text(item.genre)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))

                        Spacer()

                        Text("\(item.count) books")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 16)
        }
    }

    private var readingStreakContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("\(wrappedData.longestStreak)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("day reading streak")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Your longest streak of the year!")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)
        }
    }

    private var topQuoteContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "quote.opening")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))

            Text(wrappedData.favoriteQuote)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .italic()
                .padding(.horizontal, 24)

            Text("— \(wrappedData.quoteSource)")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var yearInReviewContent: some View {
        VStack(spacing: 24) {
            Text("2024")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("in books")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            // Mini stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statBadge(value: "\(wrappedData.totalBooks)", label: "Books")
                statBadge(value: "\(wrappedData.pagesRead.formatted())", label: "Pages")
                statBadge(value: "\(wrappedData.totalHours)h", label: "Reading Time")
                statBadge(value: "\(wrappedData.longestStreak)", label: "Day Streak")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Here's to another year of reading")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 16)
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
        )
    }

    // MARK: - Navigation Dots
    private var navigationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<cards.count, id: \.self) { index in
                Circle()
                    .fill(index == currentCardIndex ? .white : .white.opacity(0.3))
                    .frame(width: index == currentCardIndex ? 8 : 6, height: index == currentCardIndex ? 8 : 6)
                    .animation(.spring(response: 0.3), value: currentCardIndex)
            }
        }
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Chromatic Spread")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.2f", chromaticSpread))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $chromaticSpread, in: 0...2)
                    .tint(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Displacement")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.2f", displacementIntensity))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $displacementIntensity, in: 0...2)
                    .tint(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Card Positioning
    private func cardOffset(for index: Int, width: CGFloat) -> CGFloat {
        let baseOffset = CGFloat(index - currentCardIndex) * width * 0.9
        return baseOffset + dragOffset
    }

    private func cardOpacity(for index: Int) -> Double {
        let distance = abs(index - currentCardIndex)
        return distance == 0 ? 1.0 : (distance == 1 ? 0.5 : 0.0)
    }

    private func cardScale(for index: Int) -> CGFloat {
        let distance = abs(index - currentCardIndex)
        return distance == 0 ? 1.0 : 0.9
    }

    // MARK: - Drag Handling
    private func handleDragEnd(value: DragGesture.Value, width: CGFloat) {
        let threshold = width * 0.2
        var newIndex = currentCardIndex

        if value.translation.width < -threshold && currentCardIndex < cards.count - 1 {
            newIndex = currentCardIndex + 1
        } else if value.translation.width > threshold && currentCardIndex > 0 {
            newIndex = currentCardIndex - 1
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentCardIndex = newIndex
            dragOffset = 0
        }

        SensoryFeedback.selection()
    }

    // MARK: - Motion Tracking
    private func setupMotionTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
            guard let motion = motion else { return }

            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                pitch = motion.attitude.pitch * 15
                roll = motion.attitude.roll * 15
            }
        }
    }
}

// MARK: - Supporting Types

enum WrappedCard {
    case intro
    case booksRead
    case topBook
    case readingTime
    case topGenre
    case readingStreak
    case topQuote
    case yearInReview
}

struct MockWrappedData {
    let totalBooks: Int
    let pagesRead: Int
    let totalHours: Int
    let minutesPerDay: Int
    let topBook: BookModel?
    let topGenre: String
    let genreBreakdown: [(genre: String, count: Int)]
    let longestStreak: Int
    let favoriteQuote: String
    let quoteSource: String

    static func generate(from books: [BookModel]) -> MockWrappedData {
        let finishedBooks = books.filter { $0.readingStatus == ReadingStatus.read.rawValue }
        let totalBooks = max(finishedBooks.count, 24) // Mock minimum for demo

        return MockWrappedData(
            totalBooks: totalBooks,
            pagesRead: totalBooks * 280,
            totalHours: totalBooks * 8,
            minutesPerDay: (totalBooks * 8 * 60) / 365,
            topBook: books.first(where: { $0.coverImageData != nil }),
            topGenre: "Literary Fiction",
            genreBreakdown: [
                ("Literary Fiction", 8),
                ("Science Fiction", 5),
                ("Mystery", 4),
                ("Non-Fiction", 4),
                ("Fantasy", 3)
            ],
            longestStreak: 42,
            favoriteQuote: "So we beat on, boats against the current, borne back ceaselessly into the past.",
            quoteSource: "The Great Gatsby"
        )
    }
}

#Preview {
    ReadingWrappedExperiment()
        .modelContainer(for: BookModel.self)
}
