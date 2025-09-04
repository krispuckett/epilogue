import SwiftUI

struct FollowUpCapsules: View {
    let suggestions: [String]
    let onTap: (String) -> Void
    @State private var animatedSuggestions: [String] = []
    @State private var selectedSuggestion: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(animatedSuggestions, id: \.self) { suggestion in
                    FollowUpCapsule(
                        text: suggestion,
                        isSelected: selectedSuggestion == suggestion,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedSuggestion = suggestion
                            }
                            
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            // Delay to show selection animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onTap(suggestion)
                                selectedSuggestion = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .onAppear {
            animateSuggestionsAppearance()
        }
        .onChange(of: suggestions) { oldValue, newValue in
            animatedSuggestions = []
            animateSuggestionsAppearance()
        }
    }
    
    private func animateSuggestionsAppearance() {
        for (index, suggestion) in suggestions.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if !animatedSuggestions.contains(suggestion) {
                        animatedSuggestions.append(suggestion)
                    }
                }
            }
        }
    }
}

struct FollowUpCapsule: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Base glass effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.05))
                    
                    // Animated gradient overlay
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.0),
                                    .white.opacity(0.1),
                                    .white.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerPhase)
                        .opacity(isHovered ? 1 : 0)
                }
            )
            .glassEffect()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isSelected ? 0.5 : 0.2),
                                .white.opacity(isSelected ? 0.3 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
            .brightness(isHovered ? 0.1 : 0)
            .shadow(
                color: .white.opacity(isSelected ? 0.3 : 0),
                radius: isSelected ? 8 : 0
            )
            .onTapGesture(perform: onTap)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
                
                if hovering {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerPhase = 200
                    }
                } else {
                    shimmerPhase = -200
                }
            }
    }
}

// Enhanced version with icons and smart categorization
struct SmartFollowUpCapsules: View {
    let originalQuestion: String
    let answer: String
    let book: Book?
    let onSelectSuggestion: (String) -> Void
    
    @State private var suggestions: [(text: String, icon: String, category: SuggestionCategory)] = []
    @State private var isGenerating = false
    
    enum SuggestionCategory {
        case deeper, related, clarification, prediction
        
        var color: Color {
            switch self {
            case .deeper: return .blue
            case .related: return .green
            case .clarification: return .orange
            case .prediction: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white.opacity(0.6))
                    
                    Text("Thinking of follow-ups...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal)
            } else if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions, id: \.text) { suggestion in
                            SmartFollowUpCapsule(
                                text: suggestion.text,
                                icon: suggestion.icon,
                                category: suggestion.category,
                                onTap: {
                                    onSelectSuggestion(suggestion.text)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(height: 52)
            }
        }
        .onAppear {
            generateSmartSuggestions()
        }
    }
    
    private func generateSmartSuggestions() {
        isGenerating = true
        
        Task {
            // Use existing SmartFollowUpSuggestions service
            let followUps = SmartFollowUpSuggestions.shared.generateFollowUps(
                originalQuestion: originalQuestion,
                answer: answer,
                book: book
            )
            
            await MainActor.run {
                suggestions = followUps.prefix(3).map { followUp in
                    let category = categorize(followUp.question)
                    let icon = iconFor(category)
                    return (followUp.question, icon, category)
                }
                isGenerating = false
            }
        }
    }
    
    private func categorize(_ question: String) -> SuggestionCategory {
        let lower = question.lowercased()
        if lower.contains("why") || lower.contains("how") || lower.contains("explain") {
            return .deeper
        } else if lower.contains("what about") || lower.contains("similar") {
            return .related
        } else if lower.contains("what") || lower.contains("who") || lower.contains("when") {
            return .clarification
        } else {
            return .prediction
        }
    }
    
    private func iconFor(_ category: SuggestionCategory) -> String {
        switch category {
        case .deeper: return "arrow.down.circle"
        case .related: return "arrow.triangle.branch"
        case .clarification: return "questionmark.circle"
        case .prediction: return "sparkles"
        }
    }
}

struct SmartFollowUpCapsule: View {
    let text: String
    let icon: String
    let category: SmartFollowUpCapsules.SuggestionCategory
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(category.color)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Category-tinted glass
                RoundedRectangle(cornerRadius: 22)
                    .fill(category.color.opacity(0.05))
                
                // Glass overlay
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(0.03))
            }
        )
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            category.color.opacity(0.3),
                            category.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
}