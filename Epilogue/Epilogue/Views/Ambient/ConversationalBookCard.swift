import SwiftUI

// MARK: - Conversational Book Card
/// Interactive book recommendation card for conversational AI responses
/// Supports add-to-library and purchase link functionality

struct ConversationalBookCard: View {
    let recommendation: UnifiedChatMessage.BookRecommendation
    let onAddToLibrary: (UnifiedChatMessage.BookRecommendation) -> Void
    let onPurchase: (String) -> Void

    @State private var isAdded = false
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Book cover or placeholder
            AsyncImage(url: URL(string: recommendation.coverURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 90)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                @unknown default:
                    EmptyView()
                }
            }

            // Book info
            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("by \(recommendation.author)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                Text(recommendation.reason)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 8) {
                // Add to library button
                Button {
                    SensoryFeedback.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isAdded = true
                    }
                    onAddToLibrary(recommendation)
                } label: {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isAdded ? .green : DesignSystem.Colors.primaryAccent)
                }
                .disabled(isAdded)

                // Purchase link button - uses user's preferred bookstore
                Button {
                    SensoryFeedback.light()
                    onPurchase(recommendation.bookstoreURL)
                } label: {
                    Image(systemName: "cart.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Book Recommendations Message View
/// Displays a list of book recommendations in a conversational format

struct BookRecommendationsMessageView: View {
    let recommendations: [UnifiedChatMessage.BookRecommendation]
    let introText: String
    let onAddToLibrary: (UnifiedChatMessage.BookRecommendation) -> Void
    let onPurchase: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Intro text
            if !introText.isEmpty {
                Text(introText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(4)
            }

            // Book cards
            ForEach(recommendations) { rec in
                ConversationalBookCard(
                    recommendation: rec,
                    onAddToLibrary: onAddToLibrary,
                    onPurchase: onPurchase
                )
            }
        }
    }
}

// MARK: - Conversational Response Message View
/// Displays AI response with follow-up question pills

struct ConversationalResponseMessageView: View {
    let text: String
    let followUpQuestions: [String]
    let onFollowUpTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main response text with proper formatting
            Text(formatResponse(text))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(4)

            // Follow-up question pills
            if !followUpQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Follow up:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    FlowLayout(spacing: 8) {
                        ForEach(followUpQuestions, id: \.self) { question in
                            FollowUpPill(text: question) {
                                onFollowUpTap(question)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatResponse(_ text: String) -> AttributedString {
        let result = AttributedString(text)
        // Basic formatting - could be enhanced with markdown parsing
        return result
    }
}

// MARK: - Follow Up Pill

private struct FollowUpPill: View {
    let text: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            SensoryFeedback.light()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: Capsule())
                .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout for Pills
// Note: FlowLayout is defined in SessionInsightCards.swift and reused here

// MARK: - Preview

#Preview("Book Recommendations") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        VStack {
            BookRecommendationsMessageView(
                recommendations: [
                    UnifiedChatMessage.BookRecommendation(
                        title: "Piranesi",
                        author: "Susanna Clarke",
                        reason: "A mesmerizing fantasy with beautiful prose",
                        coverURL: nil,
                        isbn: "9781635575637",
                        purchaseURL: nil
                    ),
                    UnifiedChatMessage.BookRecommendation(
                        title: "The House in the Cerulean Sea",
                        author: "TJ Klune",
                        reason: "Heartwarming found family story",
                        coverURL: nil,
                        isbn: "9781250217318",
                        purchaseURL: nil
                    )
                ],
                introText: "Based on your love of atmospheric fantasy, here are some books I think you'd enjoy:",
                onAddToLibrary: { _ in },
                onPurchase: { _ in }
            )
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Conversational Response") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        ConversationalResponseMessageView(
            text: "I'd be happy to help you find your next read! To give you the best recommendations, I'd love to know a bit more about what you're in the mood for.",
            followUpQuestions: [
                "Something light and fun",
                "A deep, thought-provoking read",
                "Recommend based on my library"
            ],
            onFollowUpTap: { question in
                print("Tapped: \(question)")
            }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
