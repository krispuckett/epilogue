import SwiftUI

// MARK: - Enhanced Quote Card with Reader Mode for Long Quotes
struct SimpleQuoteCard: View {
    let note: Note
    let capturedQuote: CapturedQuote?
    @Environment(\.sizeCategory) var sizeCategory
    @State private var isPressed = false
    @State private var showDate = false
    @State private var showingSessionSummary = false
    @State private var showingReaderMode = false
    @State private var showingQuoteCardEditor = false

    // Convenience initializer for backward compatibility
    init(note: Note, capturedQuote: CapturedQuote? = nil) {
        self.note = note
        self.capturedQuote = capturedQuote
    }

    // MARK: - Content Detection
    private var isVeryLongQuote: Bool {
        note.content.count > 500  // ~3+ paragraphs
    }

    private var previewContent: String {
        guard isVeryLongQuote else { return note.content }
        // Show first ~400 characters
        let index = note.content.index(note.content.startIndex, offsetBy: min(400, note.content.count))
        return String(note.content[..<index])
    }

    var firstLetter: String {
        String((isVeryLongQuote ? previewContent : note.content).prefix(1)).uppercased()
    }

    var restOfContent: String {
        String((isVeryLongQuote ? previewContent : note.content).dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header (shown on tap)
            if showDate {
                HStack {
                    Text(formatDate(note.dateCreated).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                    
                    Spacer()
                    
                    // Session pill for ambient quotes
                    if let session = capturedQuote?.ambientSession,
                       let source = capturedQuote?.source as? String,
                       source == "ambient" {
                        Button {
                            showingSessionSummary = true
                            SensoryFeedback.light()
                        } label: {
                            HStack(spacing: 6) {
                                Text("SESSION")
                                    .font(.system(size: 10, weight: .semibold, design: .default))
                                    .kerning(1.0)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(DesignSystem.Colors.primaryAccent.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                    .stroke(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Large transparent opening quote - subtle amber
            Text("\u{201C}")
                .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 60 : 80))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
                .offset(x: -10, y: 20)
                .frame(height: 0)
                .accessibilityHidden(true)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 70 : 56))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 30 : 24))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineSpacing(sizeCategory.isAccessibilitySize ? 14 : 11) // Line height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 20)

            // "Continue Reading" button for very long quotes
            if isVeryLongQuote {
                HStack {
                    Spacer()
                    Button {
                        showingReaderMode = true
                        SensoryFeedback.light()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Continue Reading")
                                .font(.system(size: 13, weight: .medium, design: .default))
                            Image(systemName: "book.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.primaryAccent.opacity(0.12))
                        .overlay {
                            Capsule().stroke(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 0.5)
                        }
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 24)
                .transition(.scale.combined(with: .opacity))
            }

            // Attribution section
            VStack(alignment: .leading, spacing: 16) {
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
                .frame(height: 0.5)
                .padding(.top, 28)
                
                // Attribution text - reordered: Author -> Source -> Page
                VStack(alignment: .leading, spacing: 8) {
                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    }
                    
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                            .padding(.bottom, 2) // Add a bit more space before page number
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            // Golden favorite indicator on left edge
            if capturedQuote?.isFavorite == true {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 2)
                    .padding(.vertical, 1)
                    .padding(.leading, 1)
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: capturedQuote?.isFavorite)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .animation(DesignSystem.Animation.springStandard, value: showDate)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.springStandard) {
                showDate.toggle()
            }
            SensoryFeedback.light()
        }
        .pressEvents(onPress: {
            withAnimation(.spring(response: 0.1)) {
                isPressed = true
            }
        }, onRelease: {
            withAnimation(.spring(response: 0.1)) {
                isPressed = false
            }
        })
        .sheet(isPresented: $showingSessionSummary) {
            if let session = capturedQuote?.ambientSession {
                NavigationStack {
                    AmbientSessionSummaryView(session: session, colorPalette: nil)
                }
            }
        }
        // Quote reader mode for very long quotes
        .sheet(isPresented: $showingReaderMode) {
            QuoteReaderView(note: note, capturedQuote: capturedQuote)
        }
        // Quote card editor for sharing as image
        .sheet(isPresented: $showingQuoteCardEditor) {
            QuoteCardEditorView(
                quoteData: QuoteCardData(
                    text: note.content,
                    author: note.author,
                    bookTitle: note.bookTitle,
                    pageNumber: note.pageNumber,
                    bookCoverImage: bookCoverImage
                )
            )
        }
        .contextMenu {
            Button {
                showingQuoteCardEditor = true
            } label: {
                Label("Share as Card", systemImage: "photo.on.rectangle.angled")
            }

            Button {
                showingReaderMode = true
            } label: {
                Label("Read Full Quote", systemImage: "book")
            }

            if let capturedQuote = capturedQuote {
                Button {
                    capturedQuote.isFavorite.toggle()
                } label: {
                    Label(
                        capturedQuote.isFavorite ? "Remove Favorite" : "Add to Favorites",
                        systemImage: capturedQuote.isFavorite ? "star.slash" : "star"
                    )
                }
            }
        }
    }

    private var bookCoverImage: UIImage? {
        // Try to get cover from capturedQuote's book relationship
        if let imageData = capturedQuote?.book?.coverImageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}