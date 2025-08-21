import SwiftUI

// MARK: - Accessible Transcription View
struct AccessibleTranscriptionView: View {
    let transcription: String
    let isLive: Bool
    let isDissolving: Bool
    
    @StateObject private var motionManager = MotionSensitivityManager.shared
    @State private var revealedText = ""
    @State private var pulsePhase: Double = 0
    @State private var glowIntensity: Double = 0.5
    
    private var parameters: AdaptiveAnimationParameters {
        AdaptiveAnimationParameters(motionLevel: motionManager.effectivePreference)
    }
    
    var body: some View {
        Group {
            switch motionManager.effectivePreference {
            case .none:
                noMotionTranscription
            case .subtle:
                subtleMotionTranscription
            case .full, .system:
                fullMotionTranscription
            }
        }
        .onAppear {
            if isLive {
                startLiveAnimation()
            }
        }
        .onChange(of: isDissolving) { _, dissolving in
            if dissolving {
                startDissolveAnimation()
            }
        }
    }
    
    // MARK: - No Motion Version
    private var noMotionTranscription: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLive {
                // Typing indicator with gentle pulse
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white.opacity(0.6 + pulsePhase * 0.3))
                            .frame(width: 6, height: 6)
                            .animation(
                                .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: pulsePhase
                            )
                    }
                }
                .padding(.bottom, 2)
            }
            
            Text(revealedText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(isDissolving ? 0 : 1)
                .animation(.easeOut(duration: 1.2), value: isDissolving)
                .glassEffect()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Subtle Motion Version
    private var subtleMotionTranscription: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(revealedText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .blur(radius: isLive ? 1 : 0)
                .foregroundStyle(
                    LinearGradient(
                        colors: temperatureColors(),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(isDissolving ? 0.95 : 1.0)
                .opacity(isDissolving ? 0 : 1)
                .offset(y: isDissolving ? -5 : 0)
                .animation(.easeInOut(duration: 0.8), value: isDissolving)
                .animation(.easeOut(duration: 0.3), value: isLive)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .blur(radius: isLive ? 3 : 1)
        )
        .glassEffect()
    }
    
    // MARK: - Full Motion Version
    private var fullMotionTranscription: some View {
        HStack(spacing: 0) {
            ForEach(Array(transcription.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .blur(radius: characterBlur(for: index))
                    .opacity(characterOpacity(for: index))
                    .scaleEffect(characterScale(for: index))
                    .offset(y: characterOffset(for: index))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7),
                        value: revealedText.count
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .glassEffect()
                .blur(radius: isLive ? 2 : 0)
                .animation(.easeInOut(duration: 0.6), value: isLive)
        )
    }
    
    // MARK: - Animation Helpers
    private func characterBlur(for index: Int) -> Double {
        guard index >= revealedText.count else { return 0 }
        let distance = index - revealedText.count
        return min(Double(distance) * 2, parameters.maxBlur)
    }
    
    private func characterOpacity(for index: Int) -> Double {
        guard index >= revealedText.count else {
            return isDissolving ? 0 : 1
        }
        return 0.3
    }
    
    private func characterScale(for index: Int) -> Double {
        if isDissolving && index < revealedText.count {
            return 0.8
        }
        return index < revealedText.count ? 1.0 : 0.9
    }
    
    private func characterOffset(for index: Int) -> Double {
        if isDissolving && index < revealedText.count {
            return -10
        }
        return 0
    }
    
    private func temperatureColors() -> [Color] {
        let warmth = isLive ? glowIntensity : 0.8
        return [
            Color(red: 1.0, green: 0.95 * warmth, blue: 0.88 * warmth),
            Color(red: 1.0, green: 0.98, blue: 0.95)
        ]
    }
    
    private func startLiveAnimation() {
        // Progressive text reveal
        revealedText = ""
        var currentIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: parameters.characterRevealDuration, repeats: true) { timer in
            guard currentIndex < transcription.count else {
                timer.invalidate()
                return
            }
            
            let index = transcription.index(transcription.startIndex, offsetBy: currentIndex)
            revealedText.append(transcription[index])
            currentIndex += 1
        }
        
        // Pulse animation for no-motion mode
        if motionManager.effectivePreference == .none {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
        }
        
        // Glow animation for subtle mode
        if motionManager.effectivePreference == .subtle {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
    
    private func startDissolveAnimation() {
        switch motionManager.effectivePreference {
        case .none:
            // Simple fade out
            withAnimation(.easeOut(duration: 1.2)) {
                revealedText = ""
            }
            
        case .subtle:
            // Fade with scale
            withAnimation(.easeInOut(duration: 0.8)) {
                glowIntensity = 0
            }
            
        case .full, .system:
            // Character-by-character dissolve
            var removalIndex = revealedText.count
            Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
                guard removalIndex > 0 else {
                    timer.invalidate()
                    return
                }
                removalIndex -= 1
                revealedText = String(transcription.prefix(removalIndex))
            }
        }
    }
}

// MARK: - Accessible Thinking Indicator
struct AccessibleThinkingIndicator: View {
    let bookColor: Color
    @Binding var shouldCollapse: Bool
    @StateObject private var motionManager = MotionSensitivityManager.shared
    @State private var dotScale: [Double] = [1, 1, 1]
    @State private var glowPhase: Double = 0
    
    var body: some View {
        Group {
            switch motionManager.effectivePreference {
            case .none:
                staticThinking
            case .subtle:
                subtleThinking
            case .full, .system:
                dynamicThinking
            }
        }
        .onChange(of: shouldCollapse) { _, collapse in
            if collapse {
                performCollapse()
            }
        }
    }
    
    private var staticThinking: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(bookColor.opacity(0.7))
                    .frame(width: 8 * dotScale[index], height: 8 * dotScale[index])
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2)
                        ) {
                            dotScale[index] = 1.3
                        }
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(bookColor.opacity(0.1))
        )
    }
    
    private var subtleThinking: some View {
        ZStack {
            // Subtle glow effect
            Circle()
                .fill(bookColor.opacity(0.1))
                .frame(width: 60, height: 60)
                .blur(radius: 10)
                .scaleEffect(1 + glowPhase * 0.2)
            
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(bookColor.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScale[index])
                        .blur(radius: glowPhase)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPhase = 2
            }
            
            for index in 0..<3 {
                withAnimation(
                    .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2)
                ) {
                    dotScale[index] = 1.4
                }
            }
        }
    }
    
    private var dynamicThinking: some View {
        SubtleLiquidThinking(bookColor: bookColor, shouldCollapse: $shouldCollapse)
    }
    
    private func performCollapse() {
        switch motionManager.effectivePreference {
        case .none:
            withAnimation(.easeOut(duration: 0.3)) {
                dotScale = [0.5, 0.5, 0.5]
            }
            
        case .subtle:
            withAnimation(.easeIn(duration: 0.4)) {
                glowPhase = 0
                dotScale = [0.5, 0.5, 0.5]
            }
            
        case .full, .system:
            // Handled by SubtleLiquidThinking
            break
        }
    }
}

// MARK: - Onboarding Sheet
struct AmbientAccessibilityOnboarding: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Ambient Effects")
                    .font(.title2.bold())
                
                Spacer()
                
                Button("Done") {
                    isPresented = false
                }
                .font(.body.bold())
            }
            
            TabView(selection: $currentPage) {
                // Page 1: Introduction
                IntroductionPage()
                    .tag(0)
                
                // Page 2: Motion Levels
                MotionLevelsPage()
                    .tag(1)
                
                // Page 3: Customization
                CustomizationPage()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Try it now button
            if currentPage == 2 {
                Button(action: { isPresented = false }) {
                    Label("Start Reading", systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}

struct IntroductionPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Welcome to Ambient Mode")
                .font(.title3.bold())
            
            Text("Experience your books through contemplative, ethereal effects designed to enhance focus and immersion.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureItem(
                    icon: "wand.and.rays",
                    text: "Ethereal text animations"
                )
                FeatureItem(
                    icon: "accessibility",
                    text: "Fully accessible design"
                )
                FeatureItem(
                    icon: "slider.horizontal.3",
                    text: "Customizable motion levels"
                )
            }
            .padding(.top)
        }
        .padding()
    }
}

struct MotionLevelsPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Motion Preferences")
                .font(.title3.bold())
            
            Text("Choose your comfort level")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 16) {
                MotionLevelCard(
                    level: .none,
                    color: .blue
                )
                
                MotionLevelCard(
                    level: .subtle,
                    color: .purple
                )
                
                MotionLevelCard(
                    level: .full,
                    color: .indigo
                )
            }
        }
        .padding()
    }
}

struct CustomizationPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 50))
                .foregroundStyle(.tint)
            
            Text("Your Preferences")
                .font(.title3.bold())
            
            Text("You can change motion settings anytime in Settings > Ambient Mode")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            MotionPreferencePicker()
                .padding(.top)
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.tint)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct MotionLevelCard: View {
    let level: MotionPreference
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: level.iconName)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(level.rawValue)
                    .font(.subheadline.bold())
                Text(level.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}