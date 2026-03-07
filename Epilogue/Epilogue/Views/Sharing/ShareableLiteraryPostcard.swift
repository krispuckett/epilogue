import SwiftUI

// MARK: - Shareable Literary Postcard
/// A beautiful, shareable card for literary moments.
/// Designed for 1080x1350 (4:5 Instagram ratio) or 1080x1080 (square).

struct ShareableLiteraryPostcard: View {
    let content: PostcardContent
    let theme: PostcardTheme
    let includeAttribution: Bool
    let senderName: String?

    init(
        content: PostcardContent,
        theme: PostcardTheme = .warm,
        includeAttribution: Bool = true,
        senderName: String? = nil
    ) {
        self.content = content
        self.theme = theme
        self.includeAttribution = includeAttribution
        self.senderName = senderName
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(minHeight: 80, idealHeight: 120, maxHeight: 140)

                // Headline (e.g., "Finished", "Halfway there")
                Text(content.headline.uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(theme.secondaryTextColor)

                Spacer()
                    .frame(height: 24)

                // Book title
                Text(content.bookTitle)
                    .font(.custom("Georgia", size: 36))
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Author
                Text("by \(content.bookAuthor)")
                    .font(.custom("Georgia", size: 18))
                    .italic()
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.top, 8)

                Spacer()
                    .frame(minHeight: 32, idealHeight: 48)

                // Divider
                Rectangle()
                    .fill(theme.textColor.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: 120)

                Spacer()
                    .frame(height: 32)

                // Body text (reflection)
                Text(content.bodyText)
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(theme.textColor)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Attribution footer
                if includeAttribution {
                    VStack(alignment: .leading, spacing: 8) {
                        if let sender = senderName, !sender.isEmpty {
                            Text("Shared by \(sender)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.secondaryTextColor)
                        }

                        HStack(spacing: 6) {
                            Text("EPILOGUE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .kerning(2)
                            Text("readepilogue.com")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                        }
                        .foregroundStyle(theme.textColor.opacity(0.5))
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
        }
        .frame(width: 1080, height: 1350)
    }
}

// MARK: - Square Variant (1080x1080)

struct ShareableLiteraryPostcardSquare: View {
    let content: PostcardContent
    let theme: PostcardTheme
    let senderName: String?

    init(
        content: PostcardContent,
        theme: PostcardTheme = .warm,
        senderName: String? = nil
    ) {
        self.content = content
        self.theme = theme
        self.senderName = senderName
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(minHeight: 60, idealHeight: 80, maxHeight: 100)

                // Headline
                Text(content.headline.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .kerning(2.5)
                    .foregroundStyle(theme.secondaryTextColor)

                Spacer()
                    .frame(height: 20)

                // Book title
                Text(content.bookTitle)
                    .font(.custom("Georgia", size: 32))
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textColor)
                    .lineLimit(2)

                // Author
                Text("by \(content.bookAuthor)")
                    .font(.custom("Georgia", size: 16))
                    .italic()
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.top, 6)

                Spacer()
                    .frame(height: 28)

                // Divider
                Rectangle()
                    .fill(theme.textColor.opacity(0.2))
                    .frame(height: 1)
                    .frame(maxWidth: 100)

                Spacer()
                    .frame(height: 24)

                // Body text (shorter for square)
                Text(content.bodyText)
                    .font(.custom("Georgia", size: 18))
                    .foregroundStyle(theme.textColor)
                    .lineSpacing(6)
                    .lineLimit(6)

                Spacer()

                // Attribution
                HStack(spacing: 6) {
                    if let sender = senderName, !sender.isEmpty {
                        Text("from \(sender)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                        Text("·")
                    }
                    Text("EPILOGUE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .kerning(1.5)
                }
                .foregroundStyle(theme.textColor.opacity(0.5))
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Preview Postcard (Scaled for UI)

struct PostcardPreview: View {
    let content: PostcardContent
    let theme: PostcardTheme
    let senderName: String?
    let isSquare: Bool

    init(
        content: PostcardContent,
        theme: PostcardTheme = .warm,
        senderName: String? = nil,
        isSquare: Bool = false
    ) {
        self.content = content
        self.theme = theme
        self.senderName = senderName
        self.isSquare = isSquare
    }

    var body: some View {
        Group {
            if isSquare {
                ShareableLiteraryPostcardSquare(
                    content: content,
                    theme: theme,
                    senderName: senderName
                )
                .scaleEffect(0.28)
                .frame(width: 302, height: 302)
            } else {
                ShareableLiteraryPostcard(
                    content: content,
                    theme: theme,
                    senderName: senderName
                )
                .scaleEffect(0.25)
                .frame(width: 270, height: 337.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Previews

#Preview("Warm - Completion") {
    let content = PostcardContent(
        headline: "Finished",
        bookTitle: "The Brothers Karamazov",
        bookAuthor: "Fyodor Dostoevsky",
        bodyText: "What lingers: Alyosha's quiet faith in the face of doubt. The way suffering and grace intertwine throughout every page.",
        coverImageURL: nil,
        momentType: .sessionReflection(reflection: "", bookTitle: "", bookAuthor: "")
    )

    PostcardPreview(content: content, theme: .warm, senderName: "Kris")
        .padding()
        .background(Color.black)
}

#Preview("Twilight - Session") {
    let content = PostcardContent(
        headline: "Reading Tonight",
        bookTitle: "Anna Karenina",
        bookAuthor: "Leo Tolstoy",
        bodyText: "Tonight I finally understood why Tolstoy opens with that famous line. Every family's unhappiness really is unique.",
        coverImageURL: nil,
        momentType: .sessionReflection(reflection: "", bookTitle: "", bookAuthor: "")
    )

    PostcardPreview(content: content, theme: .twilight, senderName: nil)
        .padding()
        .background(Color.black)
}

#Preview("Square - Milestone") {
    let content = PostcardContent(
        headline: "Halfway there",
        bookTitle: "Infinite Jest",
        bookAuthor: "David Foster Wallace",
        bodyText: "Halfway through and the story has its hooks in me. The footnotes have become their own narrative.",
        coverImageURL: nil,
        momentType: .sessionReflection(reflection: "", bookTitle: "", bookAuthor: "")
    )

    PostcardPreview(content: content, theme: .ocean, senderName: "Kris", isSquare: true)
        .padding()
        .background(Color.black)
}
