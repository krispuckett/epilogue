import SwiftUI

// MARK: - Text Animation Experiments - Exact Note Card Replica
struct TextAnimationExperiments: View {
    @State private var isExpanded = false
    @State private var selectedEffect = TextEffect.slideUpFade

    // Animation parameters
    @State private var animationDuration: Double = 0.3
    @State private var offsetY: Double = 20
    @State private var blurRadius: Double = 2
    @State private var opacityStart: Double = 0.8
    @State private var scaleStart: Double = 0.98
    @State private var staggerDelay: Double = 0.03

    enum TextEffect: String, CaseIterable {
        case none = "None (Just LineLimit)"
        case fadeIn = "Fade In"
        case slideUp = "Slide Up"
        case slideUpFade = "Slide Up + Fade"
        case scaleBlur = "Scale + Blur"
        case offsetBlur = "Offset + Blur (Custom)"
        case staggeredFade = "Staggered Fade"
    }

    private let sampleText = """
So you can see that I'm talking and it's pulling up real time and this is using the Apple speech for the real time transcription a piece to it but the actual questions I would ask would pull up using whisper kit so I've got this dual routed transcription service in order to accomplish the speed visually as well as the accuracy from whisper kit. The other piece of this is that the gradient are responding to my voice, so I wanted it to be kind of ambient and polished and atmospheric, but not necessarily super new it.
"""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background - exact match
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

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

                        // Exact note card replica
                        noteCard

                        // Parameter controls
                        parameterControls
                    }
                    .padding()
                }
            }
            .navigationTitle("Text Animation Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Exact Note Card Replica
    @ViewBuilder
    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content text with selected effect
            switch selectedEffect {
            case .none:
                noneEffect
            case .fadeIn:
                fadeInEffect
            case .slideUp:
                slideUpEffect
            case .slideUpFade:
                slideUpFadeEffect
            case .scaleBlur:
                scaleBlurEffect
            case .offsetBlur:
                offsetBlurEffect
            case .staggeredFade:
                staggeredFadeEffect
            }

            // Show More pill - exact replica
            if !isExpanded {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Show More")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.05))
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    }
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Book context
            VStack(alignment: .leading, spacing: 2) {
                Text("THE ODYSSEY".uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("HOMER".uppercased())
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .kerning(0.6)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.top, 12)
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: animationDuration)) {
                isExpanded.toggle()
            }
            SensoryFeedback.light()
        }
    }

    // MARK: - Effects (Collapsed state is ALWAYS readable)

    private var noneEffect: some View {
        Text(sampleText)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 5)
            .lineSpacing(6)
    }

    private var fadeInEffect: some View {
        Text(sampleText)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 5)
            .lineSpacing(6)
            .opacity(isExpanded ? 1.0 : opacityStart)
            .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    private var slideUpEffect: some View {
        Text(sampleText)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 5)
            .lineSpacing(6)
            .offset(y: isExpanded ? 0 : offsetY)
            .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    private var slideUpFadeEffect: some View {
        Text(sampleText)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineLimit(isExpanded ? nil : 5)
            .lineSpacing(6)
            .offset(y: isExpanded ? 0 : offsetY)
            .opacity(isExpanded ? 1.0 : opacityStart)
            .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    private var scaleBlurEffect: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = sampleText.split(separator: "\n")
            let previewLines = 5

            if isExpanded {
                // Show all lines when expanded
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(String(line))
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                }
            } else {
                // Show first 5 lines with progressive blur
                ForEach(Array(lines.prefix(previewLines).enumerated()), id: \.offset) { index, line in
                    Text(String(line))
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .blur(radius: index < 4 ? 0 : (index == 4 ? blurRadius * 0.3 : 0))
                        .scaleEffect(scaleStart)
                }

                // Blurred preview of line 6+ below
                if lines.count > previewLines {
                    Text(lines[previewLines...].joined(separator: "\n"))
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(opacityStart * 0.5))
                        .blur(radius: blurRadius)
                        .scaleEffect(scaleStart * 0.95)
                        .offset(y: -6)
                }
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    private var offsetBlurEffect: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = sampleText.split(separator: "\n")
            let previewLines = 4

            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if isExpanded || index < previewLines {
                    Text(String(line))
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .offset(y: isExpanded ? 0 : (index >= previewLines ? offsetY : 0))
                        .blur(radius: isExpanded ? 0 : (index >= previewLines ? blurRadius : 0))
                        .opacity(isExpanded ? 1.0 : (index < previewLines ? 1.0 : 0.0))
                        .animation(.easeInOut(duration: animationDuration).delay(Double(index) * 0.02), value: isExpanded)
                }
            }
        }
    }

    private var staggeredFadeEffect: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = sampleText.split(separator: "\n")
            let previewLines = 5

            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if isExpanded || index < previewLines {
                    Text(String(line))
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .opacity(isExpanded ? 1.0 : (index < previewLines ? 1.0 : 0.0))
                        .animation(.easeInOut(duration: animationDuration).delay(Double(index) * staggerDelay), value: isExpanded)
                }
            }
        }
    }

    // MARK: - Parameter Controls
    @ViewBuilder
    private var parameterControls: some View {
        VStack(spacing: 20) {
            Text("ANIMATION PARAMETERS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.2fs", animationDuration))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $animationDuration, in: 0.1...1.0, step: 0.05)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                Divider().background(Color.white.opacity(0.1))

                // Offset Y (for slide/offset effects)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Offset Y")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.0f", offsetY))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $offsetY, in: 0...50, step: 1)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                Divider().background(Color.white.opacity(0.1))

                // Blur Radius
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Blur Radius")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.1f", blurRadius))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $blurRadius, in: 0...10, step: 0.5)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                Divider().background(Color.white.opacity(0.1))

                // Opacity Start
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity Start")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.2f", opacityStart))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $opacityStart, in: 0.5...1.0, step: 0.05)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                Divider().background(Color.white.opacity(0.1))

                // Scale Start
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scale Start")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.2f", scaleStart))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $scaleStart, in: 0.9...1.0, step: 0.01)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                Divider().background(Color.white.opacity(0.1))

                // Stagger Delay (for staggered effect)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stagger Delay")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(String(format: "%.2fs", staggerDelay))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Slider(value: $staggerDelay, in: 0.01...0.1, step: 0.01)
                        .tint(DesignSystem.Colors.primaryAccent)
                }

                // Reset button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        resetToDefaults()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Reset to Defaults")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.primaryAccent.opacity(0.12))
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func resetToDefaults() {
        animationDuration = 0.3
        offsetY = 20
        blurRadius = 2
        opacityStart = 0.8
        scaleStart = 0.98
        staggerDelay = 0.03
    }
}

#Preview {
    TextAnimationExperiments()
}
