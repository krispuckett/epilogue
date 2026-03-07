import SwiftUI

// MARK: - Quote Gift Sheet
/// Sheet for sharing a quote with personalization: "I thought of you when I read this"

struct QuoteGiftSheet: View {
    let quote: CapturedQuote
    let onShare: (QuoteGift) -> Void
    let onDismiss: () -> Void

    @State private var personalNote: String = ""
    @State private var selectedTheme: ShareGradientTheme = .amber
    @State private var senderName: String = ""
    @State private var shareAsImage: Bool = true
    @State private var isGeneratingImage: Bool = false

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""

    @FocusState private var isNoteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quote preview card
                    QuoteGiftPreview(
                        quote: quote,
                        personalNote: personalNote,
                        theme: selectedTheme,
                        senderName: senderName
                    )
                    .animation(.easeInOut(duration: 0.3), value: selectedTheme)

                    // Personal note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a note (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("I thought of you because...", text: $personalNote, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                            .focused($isNoteFieldFocused)
                    }
                    .padding(.horizontal)

                    // Theme selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShareGradientTheme.allCases) { theme in
                                    GradientThemePill(
                                        theme: theme,
                                        isSelected: selectedTheme == theme
                                    )
                                    .onTapGesture {
                                        selectedTheme = theme
                                        SensoryFeedback.selection()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Sender name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Your name", text: $senderName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    .onAppear {
                        if senderName.isEmpty && !savedDisplayName.isEmpty {
                            senderName = savedDisplayName
                        }
                    }

                    // Share format
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share as")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Format", selection: $shareAsImage) {
                            Text("Image").tag(true)
                            Text("Text").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
            .navigationTitle("Share Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        shareQuote()
                    } label: {
                        if isGeneratingImage {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Share")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isGeneratingImage)
                }
            }
            .onTapGesture {
                isNoteFieldFocused = false
            }
        }
    }

    private func shareQuote() {
        // Save display name for future use
        if !senderName.isEmpty {
            savedDisplayName = senderName
        }

        let gift = QuoteGift(
            quote: quote,
            personalNote: personalNote.isEmpty ? nil : personalNote,
            senderName: senderName.isEmpty ? nil : senderName,
            theme: selectedTheme,
            shareAsImage: shareAsImage
        )

        onShare(gift)
    }
}

// MARK: - Quote Gift Model

struct QuoteGift {
    let quote: CapturedQuote
    let personalNote: String?
    let senderName: String?
    let theme: ShareGradientTheme
    let shareAsImage: Bool

    var formattedText: String {
        var text = "\"\(quote.text ?? "")\""

        if let author = quote.author {
            text += "\n\n— \(author)"

            if let book = quote.book {
                text += ", \(book.title)"
            }

            if let page = quote.pageNumber {
                text += ", p. \(page)"
            }
        }

        if let note = personalNote, !note.isEmpty {
            text += "\n\n\(note)"
        }

        if let sender = senderName, !sender.isEmpty {
            text += "\n\n— Shared by \(sender) via Epilogue"
        } else {
            text += "\n\n• Shared from Epilogue"
        }

        return text
    }
}

// MARK: - Quote Gift Preview

private struct QuoteGiftPreview: View {
    let quote: CapturedQuote
    let personalNote: String
    let theme: ShareGradientTheme
    let senderName: String

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Gradient
            theme.atmosphericGradient

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Personal note at top if present
                if !personalNote.isEmpty {
                    Text(personalNote)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .italic()
                        .padding(.bottom, 16)
                }

                // Opening quote mark
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 48))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(x: -8, y: 12)
                    .frame(height: 0)

                // Quote text (truncated for preview)
                let quoteText = quote.text ?? ""
                let displayText = quoteText.count > 150
                    ? String(quoteText.prefix(147)) + "..."
                    : quoteText

                HStack(alignment: .top, spacing: 0) {
                    Text(String(displayText.prefix(1)))
                        .font(.custom("Georgia", size: 36))
                        .foregroundStyle(Color.white)
                        .padding(.trailing, 2)
                        .offset(y: -4)

                    Text(String(displayText.dropFirst()))
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(Color.white)
                        .lineSpacing(6)
                        .padding(.top, 4)
                }
                .padding(.top, 12)

                Spacer(minLength: 16)

                // Attribution
                if let author = quote.author {
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 24, height: 1)

                        Text(author.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }

                if let book = quote.book {
                    Text(book.title.uppercased())
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .kerning(1)
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.leading, 32)
                        .padding(.top, 4)
                }

                // Sender attribution
                if !senderName.isEmpty {
                    HStack {
                        Spacer()
                        Text("from \(senderName)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.top, 12)
                }
            }
            .padding(24)
        }
        .frame(width: 280, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Gradient Theme Pill

private struct GradientThemePill: View {
    let theme: ShareGradientTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(theme.gradient)
                .frame(width: 40, height: 40)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                    }
                }
                .shadow(color: theme.gradientColors.first?.opacity(0.4) ?? .clear, radius: 4, x: 0, y: 2)

            Text(theme.rawValue)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shareable Quote Card with Personalization

struct ShareableQuoteGiftCard: View {
    let quote: CapturedQuote
    let personalNote: String?
    let senderName: String?
    let theme: ShareGradientTheme

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Gradient
            theme.atmosphericGradient

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(minHeight: 60, idealHeight: 100, maxHeight: 120)

                // Personal note
                if let note = personalNote, !note.isEmpty {
                    Text(note)
                        .font(.custom("Georgia", size: 52))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.bottom, 48)
                }

                // Large quote mark
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 200))
                    .foregroundStyle(.white.opacity(0.25))
                    .offset(x: -24, y: 48)
                    .frame(height: 0)

                // Quote with drop cap
                HStack(alignment: .top, spacing: 0) {
                    let quoteText = quote.text ?? ""

                    Text(String(quoteText.prefix(1)))
                        .font(.custom("Georgia", size: 140))
                        .foregroundStyle(Color.white)
                        .padding(.trailing, 10)
                        .offset(y: -20)

                    Text(String(quoteText.dropFirst()))
                        .font(.custom("Georgia", size: 60))
                        .foregroundStyle(Color.white)
                        .lineSpacing(28)
                        .padding(.top, 20)
                }
                .padding(.top, 48)

                Spacer()
                    .frame(minHeight: 48)

                // Divider
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.1), location: 0),
                        .init(color: Color.white.opacity(0.8), location: 0.5),
                        .init(color: Color.white.opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.top, 64)

                // Attribution
                VStack(alignment: .leading, spacing: 20) {
                    if let author = quote.author {
                        Text(author.uppercased())
                            .font(.system(size: 32, weight: .medium, design: .monospaced))
                            .kerning(4)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }

                    if let book = quote.book {
                        Text(book.title.uppercased())
                            .font(.system(size: 28, weight: .regular, design: .monospaced))
                            .kerning(3)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .padding(.top, 40)

                Spacer()

                // Sender & app attribution
                HStack {
                    if let sender = senderName, !sender.isEmpty {
                        Text("Shared by \(sender)")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))

                        Spacer()
                    }

                    Text("EPILOGUE")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .kerning(2)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.bottom, 16)
            }
            .padding(80)
        }
        .frame(width: 1080, height: 1080)
    }
}

// MARK: - Preview

#Preview {
    let mockBook = BookModel(
        id: "123",
        title: "The Brothers Karamazov",
        author: "Fyodor Dostoevsky"
    )

    let mockQuote = CapturedQuote(
        text: "The soul is healed by being with children.",
        book: mockBook,
        author: "Fyodor Dostoevsky"
    )

    QuoteGiftSheet(
        quote: mockQuote,
        onShare: { _ in },
        onDismiss: {}
    )
}
