import SwiftUI

// MARK: - Initial Empty State
struct InitialEmptyStateView: View {
    let onSuggestionTap: (String) -> Void
    let onSelectBook: () -> Void
    var isAmbientMode: Bool = false
    
    @State private var iconOffset: CGFloat = 0
    @State private var iconOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var suggestionsOffset: CGFloat = 20
    
    private let suggestions = [
        ("📚", "What have I been reading lately?"),
        ("✨", "Recommend my next book"),
        ("💭", "Common themes in my library")
    ]
    
    var body: some View {
        VStack(spacing: isAmbientMode ? 20 : 32) {
            if !isAmbientMode {
                // Floating icon - only show in regular mode
                Image("glass-msgs")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent,
                                DesignSystem.Colors.primaryAccent.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: iconOffset)
                    .opacity(iconOpacity)
                    .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.3), radius: 20, y: 10)
            }
            
            // Welcome message
            VStack(spacing: 8) {
                if isAmbientMode {
                    Text("Listening...")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white)
                    
                    Text("Just start talking about what you're reading")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Welcome to your reading companion")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Let's explore your library together")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(contentOpacity)
            
            // Only show suggestions and book selector in regular mode
            if !isAmbientMode {
                VStack(spacing: 12) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionChip(
                            emoji: suggestion.0,
                            text: suggestion.1,
                            delay: Double(index) * 0.1
                        ) {
                            onSuggestionTap(suggestion.1)
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 60, height: 1)
                        .padding(.vertical, 8)
                    
                    // Select book button
                    Button(action: onSelectBook) {
                        HStack(spacing: 8) {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 16, weight: .medium))
                            Text("Select a specific book")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(.white.opacity(0.10))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .offset(y: suggestionsOffset)
                .opacity(contentOpacity)
            }
        }
        .padding(.horizontal, isAmbientMode ? 60 : 40)
        .onAppear {
            if !isAmbientMode {
                // Animate icon floating
                withAnimation(.easeOut(duration: 0.8)) {
                    iconOpacity = 1
                }
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    iconOffset = -10
                }
            }
            
            // Animate content
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1
                suggestionsOffset = 0
            }
        }
    }
}

// MARK: - Book-Specific Empty State
struct BookEmptyStateView: View {
    let book: Book
    let colorPalette: ColorPalette?
    let onSuggestionTap: (String) -> Void
    var isAmbientMode: Bool = false
    
    @State private var coverOpacity: Double = 0
    @State private var coverScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var quotesOpacity: Double = 0
    
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    private var bookQuotes: [Note] {
        notesViewModel.notes
            .filter { $0.type == .quote && $0.bookTitle == book.title }
            .prefix(2)
            .map { $0 }
    }
    
    private var bookQuestions: [String] {
        [
            "What themes stand out in \(book.title)?",
            "How does this book compare to others by \(book.author)?",
            "What's the most memorable part so far?",
            "Tell me about the main characters"
        ]
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Book title moved higher - no "Start discussing" copy
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(colorPalette?.primary ?? .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("by \(book.author)")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .opacity(contentOpacity)
            .padding(.top, -20) // Move higher
            
            // Faded book cover
            if let coverURL = book.coverImageURL {
                SharedBookCoverView(
                    coverURL: coverURL,
                    width: 120,
                    height: 180,
                    loadFullImage: false
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .opacity(1.0 * coverOpacity)
                .scaleEffect(coverScale)
                .shadow(
                    color: (colorPalette?.primary ?? DesignSystem.Colors.primaryAccent).opacity(0.2),
                    radius: 30,
                    y: 15
                )
            }
            
            // Removed "Try asking" section
            
            // Recent quotes as conversation starters - hide in ambient mode
            if !bookQuotes.isEmpty && !isAmbientMode {
                VStack(spacing: 12) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 60, height: 1)
                    
                    Text("Recent quotes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    ForEach(bookQuotes) { quote in
                        QuoteStarter(
                            quote: quote,
                            color: colorPalette?.secondary ?? DesignSystem.Colors.primaryAccent.opacity(0.8)
                        ) {
                            onSuggestionTap("Let's discuss this quote: \"\(quote.content)\"")
                        }
                    }
                }
                .opacity(quotesOpacity)
            }
        }
        .padding(.horizontal, 40)
        .onAppear {
            // Animate book cover
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                coverOpacity = 1
                coverScale = 1
            }
            
            // Animate content
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1
            }
            
            // Animate quotes
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                quotesOpacity = 1
            }
        }
    }
}

// MARK: - Suggestion Chip
struct SuggestionChip: View {
    let emoji: String
    let text: String
    let delay: Double
    let action: () -> Void
    
    @State private var isVisible = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 20))
                
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.vertical, 14)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent.opacity(0.15),
                                DesignSystem.Colors.primaryAccent.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                DesignSystem.Colors.primaryAccent.opacity(0.2),
                                lineWidth: 1
                            )
                    }
            }
            .scaleEffect(isPressed ? 0.95 : (isVisible ? 1 : 0.8))
            .opacity(isVisible ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            isPressed = true
            SensoryFeedback.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Question Chip
struct QuestionChip: View {
    let text: String
    let color: Color
    let delay: Double
    let action: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Quote Starter
struct QuoteStarter: View {
    let quote: Note
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color.opacity(0.6))
                
                Text(quote.content)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(color.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}