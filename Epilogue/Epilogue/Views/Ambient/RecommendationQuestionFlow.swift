import SwiftUI

// MARK: - Recommendation Question Flow

/// Interactive question flow for gathering book preferences
/// Uses liquid glass pills matching Epilogue's design language
struct RecommendationQuestionFlow: View {
    let onComplete: (RecommendationContext) -> Void
    let onDismiss: () -> Void

    @State private var currentQuestionIndex = 0
    @State private var answers: [String] = []
    @State private var isVisible = false
    @State private var questionVisible = false

    private let questions: [QuestionData] = [
        QuestionData(
            question: "What are you in the mood for?",
            options: ["Fiction", "Non-fiction", "Either"]
        ),
        QuestionData(
            question: "How much time do you have?",
            options: ["Quick read", "Medium", "Epic journey"]
        ),
        QuestionData(
            question: "What feeling are you chasing?",
            options: ["Escape", "Learn something", "Feel deeply", "Be challenged"]
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Question text
            if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]

                VStack(spacing: 24) {
                    // Question
                    Text(question.question)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(questionVisible ? 1 : 0)
                        .offset(y: questionVisible ? 0 : -10)

                    // Options - horizontal for 3 or fewer short options, vertical for more
                    Group {
                        if question.options.count <= 3 && question.options.allSatisfy({ $0.count <= 12 }) {
                            // Horizontal layout for short option lists
                            HStack(spacing: 10) {
                                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                    QuestionOptionPill(
                                        text: option,
                                        delay: Double(index) * 0.06
                                    ) {
                                        selectOption(option)
                                    }
                                }
                            }
                        } else {
                            // Vertical layout for longer option lists
                            VStack(spacing: 10) {
                                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                                    QuestionOptionPill(
                                        text: option,
                                        delay: Double(index) * 0.06
                                    ) {
                                        selectOption(option)
                                    }
                                }
                            }
                        }
                    }
                    .opacity(questionVisible ? 1 : 0)
                    .offset(y: questionVisible ? 0 : 15)
                }
                .id(currentQuestionIndex) // Force view recreation on question change
            }

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<questions.count, id: \.self) { index in
                    Circle()
                        .fill(index < currentQuestionIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == currentQuestionIndex ? 1.3 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentQuestionIndex)
                }
            }
            .padding(.top, 20)

            // Skip button
            Button {
                skipToRecommendations()
            } label: {
                Text("Skip to recommendations")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                questionVisible = true
            }
        }
    }

    private func selectOption(_ option: String) {
        SensoryFeedback.selection()
        answers.append(option)

        // Animate out current question
        withAnimation(.easeOut(duration: 0.15)) {
            questionVisible = false
        }

        // Move to next question or complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
                // Animate in next question
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    questionVisible = true
                }
            } else {
                completeFlow()
            }
        }
    }

    private func skipToRecommendations() {
        SensoryFeedback.light()
        completeFlow()
    }

    private func completeFlow() {
        let context = RecommendationContext(
            fictionPreference: answers.indices.contains(0) ? answers[0] : nil,
            lengthPreference: answers.indices.contains(1) ? answers[1] : nil,
            moodPreference: answers.indices.contains(2) ? answers[2] : nil
        )
        onComplete(context)
    }
}

// MARK: - Question Data

private struct QuestionData {
    let question: String
    let options: [String]
}

// MARK: - Recommendation Context

struct RecommendationContext {
    let fictionPreference: String?
    let lengthPreference: String?
    let moodPreference: String?

    var isEmpty: Bool {
        fictionPreference == nil && lengthPreference == nil && moodPreference == nil
    }

    /// Builds a descriptive string for the AI prompt
    func buildPromptContext() -> String {
        var parts: [String] = []

        if let fiction = fictionPreference {
            switch fiction {
            case "Fiction": parts.append("fiction books")
            case "Non-fiction": parts.append("non-fiction books")
            default: break
            }
        }

        if let length = lengthPreference {
            switch length {
            case "Quick read": parts.append("shorter books (under 300 pages)")
            case "Medium": parts.append("medium-length books")
            case "Epic journey": parts.append("longer, immersive books")
            default: break
            }
        }

        if let mood = moodPreference {
            switch mood {
            case "Escape": parts.append("escapist reads that transport me somewhere else")
            case "Learn something": parts.append("books that teach me something new")
            case "Feel deeply": parts.append("emotionally impactful books")
            case "Be challenged": parts.append("thought-provoking, challenging reads")
            default: break
            }
        }

        if parts.isEmpty {
            return "Give me your best book recommendations"
        }

        return "I'm looking for \(parts.joined(separator: ", "))"
    }
}

// MARK: - Question Option Pill

private struct QuestionOptionPill: View {
    let text: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button {
            guard !isPressed else { return } // Prevent double-tap
            isPressed = true
            SensoryFeedback.selection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        } label: {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Capsule()) // Ensure full hit area
                .glassEffect(.regular, in: .capsule) // Removed .interactive() which can interfere
        }
        .buttonStyle(PillButtonStyle(isPressed: isPressed))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// Custom button style for reliable press feedback
private struct PillButtonStyle: ButtonStyle {
    let isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
// Note: FlowLayout is defined in SessionInsightCards.swift and is reused here

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        RecommendationQuestionFlow(
            onComplete: { context in
                print("Context: \(context.buildPromptContext())")
            },
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}
