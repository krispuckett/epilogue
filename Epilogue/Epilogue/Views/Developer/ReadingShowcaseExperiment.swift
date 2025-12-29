import SwiftUI
import SwiftData

// MARK: - Stripe Press-Inspired 3D Book Showcase
// A visually stunning book display with pseudo-3D effects,
// dynamic lighting, and smooth animations

struct ReadingShowcaseExperiment: View {
    @Query(sort: \BookModel.title) private var books: [BookModel]
    @State private var selectedIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showStats = false

    // Animation states
    @State private var floatOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0.5

    private let bookWidth: CGFloat = 220
    private let bookHeight: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic gradient background based on current book
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.top, 60)

                    Spacer()

                    // 3D Book Carousel
                    bookCarousel(in: geometry)

                    Spacer()

                    // Book info
                    if !books.isEmpty {
                        bookInfo
                            .padding(.bottom, 40)
                    }

                    // Stats teaser
                    if showStats {
                        statsTeaser
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            startFloatingAnimation()
            startGlowAnimation()

            // Show stats after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showStats = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let colors = currentBookColors

        return ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    colors.primary.opacity(0.4),
                    Color.black,
                    colors.secondary.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated glow orbs
            Circle()
                .fill(colors.primary.opacity(0.3 * glowIntensity))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)

            Circle()
                .fill(colors.secondary.opacity(0.2 * glowIntensity))
                .blur(radius: 80)
                .frame(width: 200, height: 200)
                .offset(x: 150, y: 300)

            // Noise texture overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.1)
        }
        .animation(.easeInOut(duration: 0.8), value: selectedIndex)
    }

    private var currentBookColors: (primary: Color, secondary: Color) {
        // In production, extract from book cover
        // For now, use a beautiful default palette
        let palettes: [(Color, Color)] = [
            (Color(red: 0.4, green: 0.2, blue: 0.6), Color(red: 0.8, green: 0.4, blue: 0.3)),
            (Color(red: 0.2, green: 0.4, blue: 0.6), Color(red: 0.3, green: 0.7, blue: 0.5)),
            (Color(red: 0.6, green: 0.3, blue: 0.2), Color(red: 0.9, green: 0.6, blue: 0.3)),
            (Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.5, green: 0.3, blue: 0.4)),
            (Color(red: 0.1, green: 0.3, blue: 0.4), Color(red: 0.2, green: 0.5, blue: 0.6)),
        ]

        let index = selectedIndex % palettes.count
        return palettes[index]
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("YOUR YEAR IN BOOKS")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))

            Text("2024")
                .font(.system(size: 48, weight: .bold, design: .serif))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Book Carousel

    private func bookCarousel(in geometry: GeometryProxy) -> some View {
        let centerX = geometry.size.width / 2

        return ZStack {
            ForEach(Array(books.prefix(10).enumerated()), id: \.element.id) { index, book in
                Book3DCard(
                    book: book,
                    isSelected: index == selectedIndex,
                    offset: calculateOffset(for: index, centerX: centerX),
                    floatOffset: floatOffset
                )
                .zIndex(index == selectedIndex ? 100 : Double(10 - abs(index - selectedIndex)))
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedIndex = index
                    }
                }
            }
        }
        .frame(height: bookHeight + 100)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    isDragging = false
                    let threshold: CGFloat = 50

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.width < -threshold && selectedIndex < books.count - 1 {
                            selectedIndex += 1
                        } else if value.translation.width > threshold && selectedIndex > 0 {
                            selectedIndex -= 1
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    private func calculateOffset(for index: Int, centerX: CGFloat) -> CGFloat {
        let baseOffset = CGFloat(index - selectedIndex) * (bookWidth * 0.7)
        let dragAdjustment = isDragging ? dragOffset * 0.3 : 0
        return baseOffset + dragAdjustment
    }

    // MARK: - Book Info

    private var bookInfo: some View {
        let book = books.isEmpty ? nil : books[min(selectedIndex, books.count - 1)]

        return VStack(spacing: 12) {
            if let book = book {
                Text(book.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(book.author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                // Reading time badge
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("\(book.pageCount ?? 0) pages")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 40)
        .animation(.easeOut(duration: 0.3), value: selectedIndex)
    }

    // MARK: - Stats Teaser

    private var statsTeaser: some View {
        HStack(spacing: 30) {
            StatPill(value: "\(books.count)", label: "Books Read")
            StatPill(value: "\(totalPages)", label: "Pages")
            StatPill(value: "\(totalHours)h", label: "Reading Time")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 30)
    }

    private var totalPages: String {
        let total = books.reduce(0) { $0 + ($1.pageCount ?? 0) }
        if total > 1000 {
            return String(format: "%.1fk", Double(total) / 1000)
        }
        return "\(total)"
    }

    private var totalHours: Int {
        // Estimate: ~2 minutes per page
        let totalMinutes = books.reduce(0) { $0 + ($1.pageCount ?? 0) } * 2
        return totalMinutes / 60
    }

    // MARK: - Animations

    private func startFloatingAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            floatOffset = 10
        }
    }

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
    }
}

// MARK: - 3D Book Card

struct Book3DCard: View {
    let book: BookModel
    let isSelected: Bool
    let offset: CGFloat
    let floatOffset: CGFloat

    @State private var coverImage: UIImage?

    private let bookWidth: CGFloat = 220
    private let bookHeight: CGFloat = 320
    private let spineWidth: CGFloat = 30

    var body: some View {
        ZStack {
            // Book shadow
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
                .frame(width: bookWidth, height: bookHeight)
                .blur(radius: isSelected ? 30 : 20)
                .offset(x: 10, y: 20)

            // 3D Book representation
            HStack(spacing: 0) {
                // Spine
                spineView

                // Cover
                coverView
            }
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(isSelected ? 1.0 : 0.85)
            .offset(y: isSelected ? -floatOffset : 0)
        }
        .offset(x: offset)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSelected)
        .task {
            await loadCoverImage()
        }
    }

    private var rotationAngle: Double {
        // Rotate books based on position
        let normalizedOffset = offset / 300
        let baseRotation = Double(normalizedOffset) * 25
        return isSelected ? 0 : baseRotation.clamped(to: -35...35)
    }

    private var spineView: some View {
        ZStack {
            // Spine base
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            spineColor.opacity(0.9),
                            spineColor,
                            spineColor.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Spine texture lines
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 4)

            // Spine title
            Text(book.title.prefix(20))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .rotationEffect(.degrees(-90))
                .lineLimit(1)
        }
        .frame(width: spineWidth, height: bookHeight)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var coverView: some View {
        ZStack {
            // Cover base
            RoundedRectangle(cornerRadius: 4)
                .fill(coverColor)

            // Cover image
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bookWidth - spineWidth, height: bookHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // Placeholder with title
                VStack(spacing: 16) {
                    Text(book.title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text(book.author)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Shine effect
            LinearGradient(
                colors: [
                    Color.white.opacity(isSelected ? 0.3 : 0.15),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Edge highlight
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .frame(width: bookWidth - spineWidth, height: bookHeight)
    }

    private var coverColor: Color {
        // Generate consistent color from title
        let hash = abs(book.title.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.4)
    }

    private var spineColor: Color {
        coverColor.opacity(0.8)
    }

    private func loadCoverImage() async {
        // Try cached data first
        if let data = book.coverImageData, let image = UIImage(data: data) {
            await MainActor.run { coverImage = image }
            return
        }

        // Try URL
        guard let urlString = book.coverImageURL,
              let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run { coverImage = image }
            }
        } catch {
            // Silent fail - use placeholder
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
        }
    }
}

// MARK: - Preview

#Preview {
    ReadingShowcaseExperiment()
}
