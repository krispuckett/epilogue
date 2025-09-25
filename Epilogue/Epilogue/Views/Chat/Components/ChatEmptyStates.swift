import SwiftUI

// MARK: - Initial Empty State
struct InitialEmptyStateView: View {
    let onSuggestionTap: (String) -> Void
    let onSelectBook: () -> Void
    var isAmbientMode: Bool = false
    
    var body: some View {
        ContentUnavailableView {
            Label("No Conversations Yet", systemImage: "bubble.left.and.bubble.right")
                .foregroundStyle(.white)
        } description: {
            Text("Start a conversation about your books, explore themes, or get personalized recommendations")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Book-Specific Empty State
struct BookEmptyStateView: View {
    let book: Book
    let colorPalette: ColorPalette?
    let onSuggestionTap: (String) -> Void
    var isAmbientMode: Bool = false
    
    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("Start discussing \(book.title)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
        } description: {
            Text("Ask questions, explore themes, or dive deeper into this book")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
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