import SwiftUI

// MARK: - Text Animation Experiments for Note Card Expansion
// Testing different text rendering animations inspired by custom TextRenderer effects

struct TextAnimationExperiments: View {
    @State private var isExpanded = false
    @State private var selectedEffect = TextEffect.fadeIn

    private let sampleText = """
In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.

"Whenever you feel like criticizing any one," he told me, "just remember that all the people in this world haven't had the advantages that you've had." He didn't say any more but we've always been unusually communicative in a reserved way, and I understood that he meant a great deal more than that.
"""

    enum TextEffect: String, CaseIterable {
        case fadeIn = "Fade In"
        case slideUp = "Slide Up"
        case slideUpFade = "Slide Up + Fade"
        case scaleBlur = "Scale + Blur"
        case offsetBlur = "Offset + Blur (Custom)"
        case staggeredFade = "Staggered Fade"
        case wave = "Wave Effect"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Effect picker
                        Picker("Animation Effect", selection: $selectedEffect) {
                            ForEach(TextEffect.allCases, id: \.self) { effect in
                                Text(effect.rawValue).tag(effect)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)

                        // Demo card
                        demoCard

                        // Toggle button
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "Collapse" : "Expand")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(DesignSystem.Colors.primaryAccent)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Text Animation Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Render text based on selected effect
            switch selectedEffect {
            case .fadeIn:
                fadeInText
            case .slideUp:
                slideUpText
            case .slideUpFade:
                slideUpFadeText
            case .scaleBlur:
                scaleBlurText
            case .offsetBlur:
                offsetBlurText
            case .staggeredFade:
                staggeredFadeText
            case .wave:
                waveText
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Effect 1: Simple Fade In
    private var fadeInText: some View {
        Text(isExpanded ? sampleText : String(sampleText.prefix(200)))
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(6)
            .opacity(isExpanded ? 1.0 : 0.9)
    }

    // MARK: - Effect 2: Slide Up
    private var slideUpText: some View {
        Text(isExpanded ? sampleText : String(sampleText.prefix(200)))
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(6)
            .offset(y: isExpanded ? 0 : 10)
    }

    // MARK: - Effect 3: Slide Up + Fade
    private var slideUpFadeText: some View {
        Text(isExpanded ? sampleText : String(sampleText.prefix(200)))
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(6)
            .offset(y: isExpanded ? 0 : 20)
            .opacity(isExpanded ? 1.0 : 0.85)
    }

    // MARK: - Effect 4: Scale + Blur
    private var scaleBlurText: some View {
        Text(isExpanded ? sampleText : String(sampleText.prefix(200)))
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.95))
            .lineSpacing(6)
            .scaleEffect(isExpanded ? 1.0 : 0.98)
            .blur(radius: isExpanded ? 0 : 2)
    }

    // MARK: - Effect 5: Offset + Blur (Custom - Like Video)
    private var offsetBlurText: some View {
        ZStack(alignment: .topLeading) {
            // Base text
            Text(isExpanded ? sampleText : String(sampleText.prefix(200)))
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(6)

            // Blur overlay when collapsed
            if !isExpanded {
                Text(String(sampleText.prefix(200)))
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineSpacing(6)
                    .blur(radius: 4)
                    .offset(y: 11)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Effect 6: Staggered Fade (Per Line)
    private var staggeredFadeText: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = (isExpanded ? sampleText : String(sampleText.prefix(200))).split(separator: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(String(line))
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.95))
                    .opacity(isExpanded ? 1.0 : (index < 3 ? 1.0 : 0.0))
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: isExpanded)
            }
        }
    }

    // MARK: - Effect 7: Wave Effect
    private var waveText: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = (isExpanded ? sampleText : String(sampleText.prefix(200))).split(separator: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(String(line))
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.95))
                    .offset(y: isExpanded ? 0 : CGFloat(index) * 5)
                    .opacity(isExpanded ? 1.0 : (index < 3 ? 1.0 : 0.3))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.03), value: isExpanded)
            }
        }
    }
}

#Preview {
    TextAnimationExperiments()
}
