import SwiftUI

/// Gradient themes for shareable quote cards
enum ShareGradientTheme: String, CaseIterable, Identifiable {
    case amber = "Amber"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    case lavender = "Lavender"
    case crimson = "Crimson"
    case midnight = "Midnight"

    var id: String { rawValue }

    // Atmospheric gradients matching ambient mode style
    var atmosphericGradient: some View {
        let colors = gradientColors
        return ZStack {
            // Top gradient
            LinearGradient(
                stops: [
                    .init(color: colors[0].opacity(0.85), location: 0.0),
                    .init(color: colors[1].opacity(0.65), location: 0.15),
                    .init(color: colors[2].opacity(0.45), location: 0.3),
                    .init(color: Color.clear, location: 0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Bottom gradient
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.4),
                    .init(color: colors[2].opacity(0.35), location: 0.7),
                    .init(color: colors[1].opacity(0.5), location: 0.85),
                    .init(color: colors[3].opacity(0.65), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // Color palette for each theme
    var gradientColors: [Color] {
        switch self {
        case .amber:
            return [
                Color(red: 1.0, green: 0.549, blue: 0.259),
                Color(red: 0.98, green: 0.4, blue: 0.2),
                Color(red: 0.9, green: 0.35, blue: 0.18),
                Color(red: 0.85, green: 0.3, blue: 0.15)
            ]
        case .ocean:
            return [
                Color(red: 0.3, green: 0.65, blue: 0.9),
                Color(red: 0.2, green: 0.55, blue: 0.8),
                Color(red: 0.15, green: 0.45, blue: 0.7),
                Color(red: 0.1, green: 0.35, blue: 0.6)
            ]
        case .sunset:
            return [
                Color(red: 1.0, green: 0.45, blue: 0.55),
                Color(red: 0.95, green: 0.35, blue: 0.6),
                Color(red: 0.9, green: 0.3, blue: 0.7),
                Color(red: 0.85, green: 0.25, blue: 0.75)
            ]
        case .forest:
            return [
                Color(red: 0.25, green: 0.75, blue: 0.55),
                Color(red: 0.2, green: 0.65, blue: 0.5),
                Color(red: 0.15, green: 0.55, blue: 0.45),
                Color(red: 0.1, green: 0.45, blue: 0.4)
            ]
        case .lavender:
            return [
                Color(red: 0.75, green: 0.55, blue: 0.95),
                Color(red: 0.65, green: 0.45, blue: 0.88),
                Color(red: 0.55, green: 0.35, blue: 0.82),
                Color(red: 0.45, green: 0.25, blue: 0.75)
            ]
        case .crimson:
            return [
                Color(red: 0.95, green: 0.25, blue: 0.35),
                Color(red: 0.85, green: 0.2, blue: 0.3),
                Color(red: 0.75, green: 0.15, blue: 0.25),
                Color(red: 0.65, green: 0.1, blue: 0.2)
            ]
        case .midnight:
            return [
                Color(red: 0.2, green: 0.2, blue: 0.3),
                Color(red: 0.15, green: 0.15, blue: 0.25),
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ]
        }
    }

    // Simple gradients for sharing (clean, minimal)
    var gradient: LinearGradient {
        switch self {
        case .amber:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.549, blue: 0.259), // Warm amber
                    Color(red: 0.98, green: 0.4, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ocean:
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.6, blue: 0.86),
                    Color(red: 0.1, green: 0.4, blue: 0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.4, blue: 0.5),
                    Color(red: 0.9, green: 0.3, blue: 0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .forest:
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.7, blue: 0.5),
                    Color(red: 0.1, green: 0.5, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .lavender:
            return LinearGradient(
                colors: [
                    Color(red: 0.7, green: 0.5, blue: 0.9),
                    Color(red: 0.5, green: 0.3, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .crimson:
            return LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.2, blue: 0.3),
                    Color(red: 0.7, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            return LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.25),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Beautiful shareable quote card matching Epilogue's design
struct ShareableQuoteCard: View {
    let quote: String
    let author: String?
    let bookTitle: String?
    let gradient: ShareGradientTheme

    var body: some View {
        ZStack {
            // Black base
            Color.black

            // Atmospheric gradient background
            gradient.atmosphericGradient

            // Content layout matching note card EXACTLY (scaled 3.18x for 1080x1080)
            VStack(alignment: .leading, spacing: 0) {
                // Flexible top spacer (shrinks for long quotes)
                Spacer()
                    .frame(minHeight: 0, idealHeight: 127, maxHeight: 127)

                // Large transparent curly quote - subtle
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 254))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(x: -32, y: 64)
                    .frame(height: 0)

                // Quote content with drop cap
                HStack(alignment: .top, spacing: 0) {
                    // Drop cap
                    Text(String(quote.prefix(1)))
                        .font(.custom("Georgia", size: 178))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .padding(.trailing, 13)
                        .offset(y: -25)

                    // Rest of quote
                    Text(String(quote.dropFirst()))
                        .font(.custom("Georgia", size: 76))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .lineSpacing(35)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 25)
                }
                .padding(.top, 64)

                // Flexible middle spacer (shrinks for long quotes)
                Spacer()
                    .frame(minHeight: 64)

                // Attribution section (always visible at bottom)
                VStack(alignment: .leading, spacing: 51) {
                    // Thin horizontal rule with gradient
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(1.0), location: 0.5),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1.6)
                    .padding(.top, 89)

                    // Attribution text
                    VStack(alignment: .leading, spacing: 25) {
                        if let author = author, !author.isEmpty {
                            Text(author.uppercased())
                                .font(.system(size: 41, weight: .medium, design: .monospaced))
                                .kerning(4.8)
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        }

                        if let bookTitle = bookTitle, !bookTitle.isEmpty {
                            Text(bookTitle.uppercased())
                                .font(.system(size: 35, weight: .regular, design: .monospaced))
                                .kerning(3.8)
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                        }
                    }
                }
            }
            .padding(102)
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Preview
#Preview {
    ShareableQuoteCard(
        quote: "It is our choices, Harry, that show what we truly are, far more than our abilities.",
        author: "Albus Dumbledore",
        bookTitle: "Harry Potter and the Chamber of Secrets",
        gradient: .amber
    )
}

#Preview("Ocean Theme") {
    ShareableQuoteCard(
        quote: "Not all those who wander are lost.",
        author: "J.R.R. Tolkien",
        bookTitle: "The Fellowship of the Ring",
        gradient: .ocean
    )
}

#Preview("Sunset Theme") {
    ShareableQuoteCard(
        quote: "The only way out of the labyrinth of suffering is to forgive.",
        author: "John Green",
        bookTitle: "Looking for Alaska",
        gradient: .sunset
    )
}
