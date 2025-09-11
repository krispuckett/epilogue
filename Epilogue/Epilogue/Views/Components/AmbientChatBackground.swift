import SwiftUI

// MARK: - Enhanced Ambient Chat Background
struct AmbientChatBackground: View {
    @Binding var audioLevel: Float
    @Binding var isListening: Bool
    @State private var breathe = false
    @State private var morph = false
    
    var body: some View {
        BreathingAmberGradient(
            breathe: breathe,
            morph: morph
        )
        .onAppear {
            startBreathingAnimations()
        }
    }
    
    private func startBreathingAnimations() {
        // Slightly slower animations for better performance
        withAnimation(.easeInOut(duration: 5).repeatForever()) {
            breathe = true
        }
        withAnimation(.easeInOut(duration: 8).repeatForever()) {
            morph = true
        }
    }
}

// MARK: - Breathing Amber Gradient
struct BreathingAmberGradient: View {
    let breathe: Bool
    let morph: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Top breathing gradient
            RadialGradient(
                colors: [
                    DesignSystem.Colors.primaryAccent,
                    DesignSystem.Colors.primaryAccent.opacity(0.6),
                    DesignSystem.Colors.primaryAccent.opacity(0.3),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: breathe ? -0.1 : 0.1),
                startRadius: breathe ? 50 : 100,
                endRadius: breathe ? 400 : 350
            )
            .ignoresSafeArea()
            
            // Bottom breathing gradient
            RadialGradient(
                colors: [
                    DesignSystem.Colors.primaryAccent,
                    DesignSystem.Colors.primaryAccent.opacity(0.6),
                    DesignSystem.Colors.primaryAccent.opacity(0.3),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: breathe ? 1.1 : 0.9),
                startRadius: breathe ? 50 : 100,
                endRadius: breathe ? 400 : 350
            )
            .ignoresSafeArea()
            
            // Morphing center blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignSystem.Colors.primaryAccent.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .scaleEffect(morph ? 1.5 : 1.0)
                .offset(y: morph ? -50 : 50)
                .blur(radius: 30)
        }
    }
}

// MARK: - Raycast-Inspired Input Bar
struct RaycastInputBar: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    let onSubmit: () -> Void
    let onVoiceMode: () -> Void
    let onBookSelect: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showingSuggestions = false
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Smart suggestions (when typing)
            if showingSuggestions && !text.isEmpty {
                SmartSuggestionsView(
                    currentText: text,
                    onSelectSuggestion: { suggestion in
                        text = suggestion
                        showingSuggestions = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main input bar
            HStack(spacing: 12) {
                // Voice mode button
                Button(action: onVoiceMode) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.orange)
                        
                        // Orange glow for voice mode
                        Circle()
                            .stroke(Color.orange.opacity(glowOpacity), lineWidth: 2)
                            .frame(width: 38, height: 38)
                            .blur(radius: 2)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Input field with glass effect
                HStack(spacing: 8) {
                    TextField("Ask anything...", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .accentColor(DesignSystem.Colors.primaryAccent)
                        .focused($isFocused)
                        .lineLimit(isExpanded ? 5 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            if !text.isEmpty {
                                onSubmit()
                            }
                        }
                    
                    Spacer()
                    
                    // Action buttons
                    if !text.isEmpty {
                        Button(action: onSubmit) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white, Color.orange)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Button(action: onBookSelect) {
                            Image(systemName: "book")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.orange.opacity(0.7))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isFocused ? 0.2 : 0.1),
                                    Color.orange.opacity(isFocused ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
        }
        .onChange(of: text) { _, newValue in
            withAnimation(DesignSystem.Animation.easeQuick) {
                showingSuggestions = !newValue.isEmpty && isFocused
            }
        }
        .onChange(of: isFocused) { _, focused in
            withAnimation(DesignSystem.Animation.easeQuick) {
                showingSuggestions = focused && !text.isEmpty
                isExpanded = focused
            }
        }
        .onAppear {
            // Subtle glow animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - Smart Suggestions View
struct SmartSuggestionsView: View {
    let currentText: String
    let onSelectSuggestion: (String) -> Void
    
    // Dynamic suggestions based on input
    var suggestions: [String] {
        let lowercased = currentText.lowercased()
        
        if lowercased.contains("what") {
            return [
                "What themes connect my recent books?",
                "What insights can you share about my reading patterns?",
                "What book should I read next based on my interests?"
            ]
        } else if lowercased.contains("how") {
            return [
                "How does this book compare to others I've read?",
                "How can I apply these concepts to my life?",
                "How has my reading evolved over time?"
            ]
        } else if lowercased.contains("why") {
            return [
                "Why did this passage resonate with me?",
                "Why do I gravitate toward certain genres?",
                "Why is this theme recurring in my reading?"
            ]
        } else {
            return [
                "Find quotes about \(currentText)",
                "Show my notes related to \(currentText)",
                "Explore connections with \(currentText)"
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            
            // Suggestions
            VStack(spacing: 8) {
                ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.orange.opacity(0.7))
                            
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(12)
        }
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.bottom, 8)
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animation.springStandard, value: configuration.isPressed)
    }
}