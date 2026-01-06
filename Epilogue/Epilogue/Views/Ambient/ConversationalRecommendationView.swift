import SwiftUI

// MARK: - Conversational Recommendation View

/// A warm, conversational interface for finding books
/// Replaces the rigid questionnaire with mood chips and personalized starters
struct ConversationalRecommendationView: View {
    let books: [Book]
    let onMoodSelected: (AmbientConversationFlows.ReadingMood) -> Void
    let onStarterSelected: (String) -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var selectedMood: AmbientConversationFlows.ReadingMood?

    private var conversationStarters: [AmbientConversationFlows.ConversationStarter] {
        AmbientConversationFlows.shared.getConversationStarters(from: books)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Warm greeting
                VStack(spacing: 8) {
                    Text("What kind of book are you in the mood for?")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Tap a vibe or tell me what you're feeling")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -15)

                // Mood chips - 2x4 grid
                MoodChipGrid(
                    selectedMood: $selectedMood,
                    onSelect: { mood in
                        SensoryFeedback.selection()
                        onMoodSelected(mood)
                    }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)

                // Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                    Text("or")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)
                .opacity(isVisible ? 1 : 0)

                // Personalized conversation starters
                VStack(spacing: 10) {
                    ForEach(conversationStarters) { starter in
                        ConversationStarterPill(
                            starter: starter,
                            delay: Double(conversationStarters.firstIndex(where: { $0.id == starter.id }) ?? 0) * 0.06
                        ) {
                            SensoryFeedback.selection()
                            onStarterSelected(starter.prompt)
                        }
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 15)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Mood Chip Grid

private struct MoodChipGrid: View {
    @Binding var selectedMood: AmbientConversationFlows.ReadingMood?
    let onSelect: (AmbientConversationFlows.ReadingMood) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(AmbientConversationFlows.ReadingMood.allCases.enumerated()), id: \.element) { index, mood in
                MoodChip(
                    mood: mood,
                    isSelected: selectedMood == mood,
                    delay: Double(index) * 0.04
                ) {
                    selectedMood = mood
                    onSelect(mood)
                }
            }
        }
    }
}

// MARK: - Mood Chip

private struct MoodChip: View {
    let mood: AmbientConversationFlows.ReadingMood
    let isSelected: Bool
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isPressed else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: mood.sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                Text(mood.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .glassEffect(
                isSelected ? .regular.tint(.white.opacity(0.15)) : .regular,
                in: .rect(cornerRadius: 16)
            )
            .scaleEffect(isPressed ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Conversation Starter Pill

private struct ConversationStarterPill: View {
    let starter: AmbientConversationFlows.ConversationStarter
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !isPressed else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: starter.sfSymbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20)

                Text(starter.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.3 + delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        ConversationalRecommendationView(
            books: [
                Book(id: "1", title: "Project Hail Mary", author: "Andy Weir", isbn: nil),
                Book(id: "2", title: "The Name of the Wind", author: "Patrick Rothfuss", isbn: nil)
            ],
            onMoodSelected: { mood in
                print("Mood: \(mood.rawValue)")
            },
            onStarterSelected: { prompt in
                print("Starter: \(prompt)")
            },
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}
