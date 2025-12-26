import SwiftUI

// MARK: - Template Router View
/// Routes to the appropriate template based on configuration
struct QuoteCardTemplateView: View {
    let data: QuoteCardData
    let config: QuoteCardConfiguration
    let renderSize: CGSize

    var body: some View {
        switch config.template {
        case .minimal:
            MinimalQuoteCard(data: data, config: config, renderSize: renderSize)
        case .bookColor:
            BookColorQuoteCard(data: data, config: config, renderSize: renderSize)
        case .paper:
            PaperQuoteCard(data: data, config: config, renderSize: renderSize)
        case .bold:
            BoldQuoteCard(data: data, config: config, renderSize: renderSize)
        }
    }
}

// MARK: - Template 1: Minimal
/// Clean white/dark background with elegant serif typography
struct MinimalQuoteCard: View {
    let data: QuoteCardData
    let config: QuoteCardConfiguration
    let renderSize: CGSize

    private var backgroundColor: Color {
        if let custom = config.customBackgroundColor { return custom }
        return config.colorScheme == .light ? .white : Color(red: 0.08, green: 0.08, blue: 0.08)
    }

    private var textColor: Color {
        if let custom = config.customTextColor { return custom }
        return config.colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.96, green: 0.96, blue: 0.96)
    }

    private var secondaryTextColor: Color {
        textColor.opacity(0.7)
    }

    private var tertiaryTextColor: Color {
        textColor.opacity(0.5)
    }

    private var scale: CGFloat { renderSize.width / 1080 }

    var body: some View {
        ZStack {
            backgroundColor

            VStack(alignment: config.alignment.horizontalAlignment, spacing: 0) {
                Spacer()
                    .frame(minHeight: 0, idealHeight: 100 * scale, maxHeight: 140 * scale)

                // Opening quote mark
                Text("\u{201C}")
                    .font(.custom(config.font.fontName, size: 180 * scale))
                    .foregroundStyle(textColor.opacity(0.15))
                    .frame(height: 80 * scale)
                    .offset(x: config.alignment == .leading ? -20 * scale : 0)

                // Quote text
                Text(data.text)
                    .font(.custom(config.font.fontName, size: quoteFontSize))
                    .foregroundStyle(textColor)
                    .lineSpacing(14 * scale)
                    .multilineTextAlignment(config.alignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20 * scale)

                Spacer()
                    .frame(minHeight: 40 * scale)

                // Attribution
                if config.showAuthor || config.showBookTitle {
                    attributionSection
                }

                // Watermark
                if config.showWatermark {
                    watermarkView
                        .padding(.top, 40 * scale)
                }

                Spacer()
                    .frame(minHeight: 60 * scale, idealHeight: 100 * scale, maxHeight: 140 * scale)
            }
            .padding(.horizontal, 80 * scale)
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }

    private var quoteFontSize: CGFloat {
        let baseSize: CGFloat = 56
        let length = data.text.count
        let adjusted: CGFloat
        if length > 300 {
            adjusted = baseSize * 0.65
        } else if length > 200 {
            adjusted = baseSize * 0.75
        } else if length > 100 {
            adjusted = baseSize * 0.85
        } else {
            adjusted = baseSize
        }
        return adjusted * scale
    }

    private var attributionSection: some View {
        VStack(alignment: config.alignment.horizontalAlignment, spacing: 12 * scale) {
            // Divider line
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: textColor.opacity(0.05), location: 0),
                            .init(color: textColor.opacity(0.3), location: 0.5),
                            .init(color: textColor.opacity(0.05), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.bottom, 24 * scale)

            if config.showAuthor, let author = data.author {
                Text(author)
                    .font(.system(size: 28 * scale, weight: .medium, design: .serif))
                    .foregroundStyle(secondaryTextColor)
            }

            if config.showBookTitle, let title = data.bookTitle {
                Text(title)
                    .font(.system(size: 22 * scale, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(tertiaryTextColor)
            }

            if config.showPageNumber, let page = data.pageNumber {
                Text("Page \(page)")
                    .font(.system(size: 18 * scale, weight: .regular, design: .monospaced))
                    .foregroundStyle(tertiaryTextColor)
            }
        }
    }

    private var watermarkView: some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 14 * scale))
            Text("Epilogue")
                .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
        }
        .foregroundStyle(tertiaryTextColor.opacity(0.6))
    }
}

// MARK: - Template 2: Book Color
/// Background uses extracted book colors with gradient
struct BookColorQuoteCard: View {
    let data: QuoteCardData
    let config: QuoteCardConfiguration
    let renderSize: CGSize

    private var primaryColor: Color {
        if let custom = config.customBackgroundColor { return custom }
        return data.bookPalette?.primary ?? Color(red: 0.3, green: 0.4, blue: 0.6)
    }

    private var secondaryColor: Color {
        data.bookPalette?.secondary ?? primaryColor.opacity(0.7)
    }

    private var accentColor: Color {
        if let custom = config.customAccentColor { return custom }
        return data.bookPalette?.accent ?? Color.orange
    }

    private var textColor: Color {
        if let custom = config.customTextColor { return custom }
        return data.bookPalette?.textColor ?? .white
    }

    private var scale: CGFloat { renderSize.width / 1080 }

    var body: some View {
        ZStack {
            // Black base
            Color.black

            // Atmospheric gradient from book colors
            atmosphericGradient

            VStack(alignment: config.alignment.horizontalAlignment, spacing: 0) {
                Spacer()
                    .frame(minHeight: 0, idealHeight: 100 * scale, maxHeight: 140 * scale)

                // Large decorative quote
                Text("\u{201C}")
                    .font(.custom(config.font.fontName, size: 200 * scale))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(height: 60 * scale)
                    .offset(x: config.alignment == .leading ? -24 * scale : 0)

                // Quote with drop cap
                HStack(alignment: .top, spacing: 0) {
                    if !data.text.isEmpty {
                        // Drop cap
                        Text(String(data.text.prefix(1)))
                            .font(.custom(config.font.fontName, size: 140 * scale))
                            .foregroundStyle(textColor)
                            .padding(.trailing, 8 * scale)
                            .offset(y: -16 * scale)

                        // Rest of quote
                        Text(String(data.text.dropFirst()))
                            .font(.custom(config.font.fontName, size: quoteFontSize))
                            .foregroundStyle(textColor)
                            .lineSpacing(12 * scale)
                            .multilineTextAlignment(config.alignment.textAlignment)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20 * scale)
                    }
                }
                .padding(.top, 40 * scale)

                Spacer()
                    .frame(minHeight: 40 * scale)

                // Attribution with gradient divider
                attributionSection

                // Book cover thumbnail + watermark row
                bottomSection
            }
            .padding(.horizontal, 80 * scale)
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }

    private var atmosphericGradient: some View {
        ZStack {
            // Top gradient
            LinearGradient(
                stops: [
                    .init(color: primaryColor.opacity(0.85), location: 0.0),
                    .init(color: secondaryColor.opacity(0.65), location: 0.15),
                    .init(color: accentColor.opacity(0.35), location: 0.35),
                    .init(color: Color.clear, location: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Bottom gradient
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.4),
                    .init(color: accentColor.opacity(0.25), location: 0.7),
                    .init(color: secondaryColor.opacity(0.45), location: 0.85),
                    .init(color: primaryColor.opacity(0.55), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var quoteFontSize: CGFloat {
        let baseSize: CGFloat = 52
        let length = data.text.count
        let adjusted: CGFloat
        if length > 300 {
            adjusted = baseSize * 0.65
        } else if length > 200 {
            adjusted = baseSize * 0.75
        } else if length > 100 {
            adjusted = baseSize * 0.85
        } else {
            adjusted = baseSize
        }
        return adjusted * scale
    }

    private var attributionSection: some View {
        VStack(alignment: config.alignment.horizontalAlignment, spacing: 16 * scale) {
            // Gradient divider
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: textColor.opacity(0.1), location: 0),
                    .init(color: textColor.opacity(0.8), location: 0.5),
                    .init(color: textColor.opacity(0.1), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.bottom, 16 * scale)

            if config.showAuthor, let author = data.author {
                Text(author.uppercased())
                    .font(.system(size: 28 * scale, weight: .medium, design: .monospaced))
                    .kerning(3 * scale)
                    .foregroundStyle(textColor.opacity(0.85))
            }

            if config.showBookTitle, let title = data.bookTitle {
                Text(title.uppercased())
                    .font(.system(size: 22 * scale, weight: .regular, design: .monospaced))
                    .kerning(2 * scale)
                    .foregroundStyle(textColor.opacity(0.65))
            }

            if config.showPageNumber, let page = data.pageNumber {
                Text("P. \(page)")
                    .font(.system(size: 18 * scale, weight: .regular, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.5))
            }
        }
    }

    private var bottomSection: some View {
        HStack(alignment: .bottom) {
            // Book cover thumbnail (if available)
            if let coverImage = data.bookCoverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60 * scale, height: 90 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * scale))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            Spacer()

            // Watermark
            if config.showWatermark {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 14 * scale))
                    Text("Epilogue")
                        .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                }
                .foregroundStyle(textColor.opacity(0.5))
            }
        }
        .padding(.top, 32 * scale)
        .padding(.bottom, 60 * scale)
    }
}

// MARK: - Template 3: Paper
/// Textured paper background with vintage/typewriter aesthetic
struct PaperQuoteCard: View {
    let data: QuoteCardData
    let config: QuoteCardConfiguration
    let renderSize: CGSize

    private var scale: CGFloat { renderSize.width / 1080 }

    private var paperColor: Color {
        if let custom = config.customBackgroundColor { return custom }
        return Color(red: 0.96, green: 0.94, blue: 0.88) // Aged paper color
    }

    private var inkColor: Color {
        if let custom = config.customTextColor { return custom }
        return Color(red: 0.15, green: 0.12, blue: 0.10) // Dark ink
    }

    var body: some View {
        ZStack {
            // Paper background with texture
            paperBackground

            VStack(alignment: config.alignment.horizontalAlignment, spacing: 0) {
                Spacer()
                    .frame(minHeight: 80 * scale)

                // Decorative page corner fold
                HStack {
                    Spacer()
                    pageFold
                }

                Spacer()
                    .frame(height: 40 * scale)

                // Quote text
                Text("\"\(data.text)\"")
                    .font(.custom(config.font.fontName, size: quoteFontSize))
                    .foregroundStyle(inkColor)
                    .lineSpacing(16 * scale)
                    .multilineTextAlignment(config.alignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: inkColor.opacity(0.1), radius: 0.5, x: 0.5, y: 0.5)

                Spacer()
                    .frame(minHeight: 40 * scale)

                // Attribution in typewriter style
                attributionSection

                Spacer()
                    .frame(minHeight: 60 * scale)

                // Bottom decoration
                bottomDecoration
            }
            .padding(.horizontal, 100 * scale)

            // Aged edges overlay
            agedEdgesOverlay
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }

    private var paperBackground: some View {
        ZStack {
            paperColor

            // Paper grain texture (simulated with gradients)
            LinearGradient(
                colors: [
                    Color.brown.opacity(0.02),
                    Color.clear,
                    Color.brown.opacity(0.03),
                    Color.clear,
                    Color.brown.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle vertical lines (ruled paper effect)
            GeometryReader { geo in
                ForEach(0..<Int(geo.size.height / (40 * scale)), id: \.self) { i in
                    Rectangle()
                        .fill(Color.blue.opacity(0.03))
                        .frame(height: 0.5)
                        .offset(y: CGFloat(i) * 40 * scale + 100 * scale)
                }
            }
        }
    }

    private var pageFold: some View {
        ZStack {
            // Triangle fold
            Path { path in
                path.move(to: CGPoint(x: 60 * scale, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 60 * scale))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        paperColor.opacity(0.9),
                        Color.brown.opacity(0.15)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .shadow(color: .black.opacity(0.1), radius: 3, x: -2, y: 2)
        }
        .frame(width: 60 * scale, height: 60 * scale)
        .offset(x: 40 * scale, y: -20 * scale)
    }

    private var quoteFontSize: CGFloat {
        let baseSize: CGFloat = 48
        let length = data.text.count
        let adjusted: CGFloat
        if length > 300 {
            adjusted = baseSize * 0.65
        } else if length > 200 {
            adjusted = baseSize * 0.75
        } else if length > 100 {
            adjusted = baseSize * 0.85
        } else {
            adjusted = baseSize
        }
        return adjusted * scale
    }

    private var attributionSection: some View {
        VStack(alignment: config.alignment.horizontalAlignment, spacing: 16 * scale) {
            // Typewriter-style dashes
            Text("— — —")
                .font(.system(size: 20 * scale, weight: .light, design: .monospaced))
                .foregroundStyle(inkColor.opacity(0.3))
                .padding(.bottom, 8 * scale)

            if config.showAuthor, let author = data.author {
                Text("— \(author)")
                    .font(.custom(config.font.fontName, size: 26 * scale))
                    .foregroundStyle(inkColor.opacity(0.8))
            }

            if config.showBookTitle, let title = data.bookTitle {
                Text(title)
                    .font(.custom(config.font.fontName, size: 22 * scale))
                    .italic()
                    .foregroundStyle(inkColor.opacity(0.6))
            }

            if config.showPageNumber, let page = data.pageNumber {
                Text("p. \(page)")
                    .font(.system(size: 18 * scale, weight: .regular, design: .monospaced))
                    .foregroundStyle(inkColor.opacity(0.4))
            }
        }
    }

    private var bottomDecoration: some View {
        HStack {
            if config.showWatermark {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 12 * scale))
                    Text("Epilogue")
                        .font(.system(size: 12 * scale, weight: .regular, design: .serif))
                }
                .foregroundStyle(inkColor.opacity(0.3))
            }

            Spacer()

            // Decorative stamp/seal
            Circle()
                .strokeBorder(inkColor.opacity(0.15), lineWidth: 1.5)
                .frame(width: 50 * scale, height: 50 * scale)
                .overlay(
                    Text("E")
                        .font(.custom("Georgia", size: 24 * scale))
                        .foregroundStyle(inkColor.opacity(0.2))
                )
        }
        .padding(.bottom, 40 * scale)
    }

    private var agedEdgesOverlay: some View {
        ZStack {
            // Top edge aging
            LinearGradient(
                colors: [Color.brown.opacity(0.15), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60 * scale)
            .frame(maxHeight: .infinity, alignment: .top)

            // Bottom edge aging
            LinearGradient(
                colors: [Color.clear, Color.brown.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80 * scale)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Left edge
            LinearGradient(
                colors: [Color.brown.opacity(0.1), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right edge
            LinearGradient(
                colors: [Color.clear, Color.brown.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40 * scale)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Template 4: Bold
/// High contrast with large pull-quote style typography
struct BoldQuoteCard: View {
    let data: QuoteCardData
    let config: QuoteCardConfiguration
    let renderSize: CGSize

    private var scale: CGFloat { renderSize.width / 1080 }

    private var backgroundColor: Color {
        if let custom = config.customBackgroundColor { return custom }
        return config.colorScheme == .light ? .white : .black
    }

    private var primaryTextColor: Color {
        if let custom = config.customTextColor { return custom }
        return config.colorScheme == .light ? .black : .white
    }

    private var accentColor: Color {
        if let custom = config.customAccentColor { return custom }
        return data.bookPalette?.accent ?? Color(red: 1.0, green: 0.3, blue: 0.3)
    }

    var body: some View {
        ZStack {
            backgroundColor

            // Accent color bar
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 12 * scale)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 120 * scale)

                // Large accent quote mark
                Text("\u{201C}")
                    .font(.system(size: 300 * scale, weight: .black))
                    .foregroundStyle(accentColor)
                    .frame(height: 180 * scale)
                    .offset(x: -20 * scale, y: 40 * scale)

                // Quote text - bold and impactful
                Text(data.text)
                    .font(.system(size: quoteFontSize, weight: .bold, design: .default))
                    .foregroundStyle(primaryTextColor)
                    .lineSpacing(8 * scale)
                    .multilineTextAlignment(config.alignment.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
                    .frame(minHeight: 40 * scale)

                // Attribution with accent underline
                attributionSection

                Spacer()
                    .frame(minHeight: 60 * scale)

                // Bottom bar
                bottomBar
            }
            .padding(.horizontal, 80 * scale)
        }
        .frame(width: renderSize.width, height: renderSize.height)
    }

    private var quoteFontSize: CGFloat {
        let baseSize: CGFloat = 64
        let length = data.text.count
        let adjusted: CGFloat
        if length > 300 {
            adjusted = baseSize * 0.55
        } else if length > 200 {
            adjusted = baseSize * 0.65
        } else if length > 100 {
            adjusted = baseSize * 0.80
        } else {
            adjusted = baseSize
        }
        return adjusted * scale
    }

    private var attributionSection: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            // Accent underline
            Rectangle()
                .fill(accentColor)
                .frame(width: 80 * scale, height: 4 * scale)
                .padding(.bottom, 16 * scale)

            if config.showAuthor, let author = data.author {
                Text(author.uppercased())
                    .font(.system(size: 24 * scale, weight: .heavy, design: .default))
                    .kerning(4 * scale)
                    .foregroundStyle(primaryTextColor)
            }

            if config.showBookTitle, let title = data.bookTitle {
                Text(title)
                    .font(.system(size: 20 * scale, weight: .medium, design: .default))
                    .foregroundStyle(primaryTextColor.opacity(0.6))
            }

            if config.showPageNumber, let page = data.pageNumber {
                Text("PAGE \(page)")
                    .font(.system(size: 16 * scale, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            // Watermark
            if config.showWatermark {
                HStack(spacing: 8 * scale) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8 * scale, height: 8 * scale)
                    Text("EPILOGUE")
                        .font(.system(size: 14 * scale, weight: .bold, design: .default))
                        .kerning(2 * scale)
                        .foregroundStyle(primaryTextColor.opacity(0.4))
                }
            }

            Spacer()

            // Decorative element
            HStack(spacing: 4 * scale) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(accentColor.opacity(0.3))
                        .frame(width: 20 * scale, height: 4 * scale)
                }
            }
        }
        .padding(.bottom, 60 * scale)
    }
}

// MARK: - Previews
#Preview("Minimal - Dark") {
    MinimalQuoteCard(
        data: QuoteCardData(
            text: "It is our choices, Harry, that show what we truly are, far more than our abilities.",
            author: "Albus Dumbledore",
            bookTitle: "Harry Potter and the Chamber of Secrets"
        ),
        config: .default,
        renderSize: CGSize(width: 1080, height: 1080)
    )
    .scaleEffect(0.3)
}

#Preview("Book Color") {
    BookColorQuoteCard(
        data: QuoteCardData(
            text: "Not all those who wander are lost.",
            author: "J.R.R. Tolkien",
            bookTitle: "The Fellowship of the Ring"
        ),
        config: QuoteCardConfiguration(template: .bookColor),
        renderSize: CGSize(width: 1080, height: 1080)
    )
    .scaleEffect(0.3)
}

#Preview("Paper") {
    PaperQuoteCard(
        data: QuoteCardData(
            text: "The only way out of the labyrinth of suffering is to forgive.",
            author: "John Green",
            bookTitle: "Looking for Alaska",
            pageNumber: 142
        ),
        config: QuoteCardConfiguration(template: .paper, font: .typewriter),
        renderSize: CGSize(width: 1080, height: 1080)
    )
    .scaleEffect(0.3)
}

#Preview("Bold") {
    BoldQuoteCard(
        data: QuoteCardData(
            text: "In the end, we only regret the chances we didn't take.",
            author: "Lewis Carroll",
            bookTitle: "Alice in Wonderland"
        ),
        config: QuoteCardConfiguration(template: .bold),
        renderSize: CGSize(width: 1080, height: 1080)
    )
    .scaleEffect(0.3)
}
