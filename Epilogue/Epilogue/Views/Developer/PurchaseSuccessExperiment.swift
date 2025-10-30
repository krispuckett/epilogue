import SwiftUI
import MetalKit
import simd

/// Experimental design for successful purchase celebration
/// Access from Settings > Developer Options > Preview Purchase Success
struct PurchaseSuccessExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = true
    @State private var showSuccess = false
    @State private var selectedInterval: BillingInterval = .annual

    // Animation states for success screen
    @State private var orbAppeared = false
    @State private var checkmarkAppeared = false
    @State private var textAppeared = false
    @State private var featuresAppeared = false
    @State private var ctaAppeared = false
    @State private var orbPressed = false
    @State private var celebrationPulses: [PurchaseCelebrationPulse] = []

    var body: some View {
        NavigationStack {
            ZStack {
                if showPaywall {
                    // Show simplified paywall
                    simplifiedPaywallView
                } else if showSuccess {
                    // Show success celebration
                    successCelebrationView
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Reset to paywall for testing
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSuccess = false
                            showPaywall = true
                            resetSuccessAnimations()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Simplified Paywall View
    private var simplifiedPaywallView: some View {
        ZStack {
            // Minimal gradient background
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)

            VStack(spacing: 32) {
                Spacer()

                // Orb
                MetalShaderView(isPressed: $orbPressed, size: CGSize(width: 160, height: 160))
                    .frame(width: 160, height: 160)

                // Hero text
                VStack(spacing: 8) {
                    Text("Unlock a deeper reading experience")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .tracking(-0.5)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Billing interval picker
                billingIntervalPicker
                    .padding(.horizontal, 20)

                // CTA button
                Button {
                    handleContinue()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3),
                                        lineWidth: 1
                                    )
                            }

                        Text("Continue with Epilogue+")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var billingIntervalPicker: some View {
        HStack(spacing: 8) {
            ForEach(BillingInterval.allCases, id: \.self) { interval in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedInterval = interval
                    }
                    SensoryFeedback.light()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(interval == .monthly ? "$7.99" : "$67")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .tracking(-1)
                                .foregroundStyle(selectedInterval == interval ? .white.opacity(0.95) : .white.opacity(0.5))
                            Text(interval == .monthly ? "/mo" : "/yr")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedInterval == interval ? .white.opacity(0.5) : .white.opacity(0.3))
                        }

                        if interval == .annual {
                            Text("SAVE 30%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(selectedInterval == interval ? 0.9 : 0.5))
                                .kerning(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedInterval == interval ? Color.white.opacity(0.08) : Color.white.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selectedInterval == interval
                                    ? Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4)
                                    : Color.white.opacity(0.1),
                                lineWidth: selectedInterval == interval ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Success Celebration View
    private var successCelebrationView: some View {
        ZStack {
            // Atmospheric green gradient background
            LinearGradient(
                stops: [
                    .init(color: Color.green.opacity(0.3), location: 0.0),
                    .init(color: Color.green.opacity(0.15), location: 0.4),
                    .init(color: Color.black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            ScrollView {
                VStack(spacing: 0) {
                    // Animated orb with checkmark overlay
                    celebrationOrbHeader
                        .padding(.top, 40)
                        .padding(.bottom, 24)

                    // Success message
                    successHeroSection
                        .padding(.bottom, 32)

                    // Unlocked features
                    unlockedFeaturesSection
                        .padding(.bottom, 32)

                    // CTA to continue
                    continueCTASection
                        .padding(.bottom, 40)

                    Spacer(minLength: 60)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            triggerSuccessAnimations()
        }
    }

    private var celebrationOrbHeader: some View {
        ZStack {
            // Green animated orb
            GreenMetalShaderView(isPressed: $orbPressed, size: CGSize(width: 180, height: 180))
                .frame(width: 180, height: 180)
                .opacity(orbAppeared ? 1 : 0)
                .scaleEffect(orbAppeared ? 1 : 0.8)
                .overlay {
                    // Green water-ripple celebration pulses
                    ForEach(celebrationPulses) { pulse in
                        ZStack {
                            // Soft outer glow
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(pulse.opacity * 0.7),
                                            Color.green.opacity(pulse.opacity * 0.5),
                                            Color.green.opacity(pulse.opacity * 0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 12
                                )
                                .frame(width: 180 * pulse.scale, height: 180 * pulse.scale)
                                .blur(radius: 16)
                                .modifier(WaterWobbleModifier(wobblePhase: pulse.scale * 10.0))

                            // Sharp inner ring
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(pulse.opacity * 1.0),
                                            Color.green.opacity(pulse.opacity * 0.85),
                                            Color.green.opacity(pulse.opacity * 0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 5
                                )
                                .frame(width: 180 * pulse.scale, height: 180 * pulse.scale)
                                .blur(radius: 2)
                                .modifier(WaterWobbleModifier(wobblePhase: pulse.scale * 12.0))
                        }
                        .allowsHitTesting(false)
                    }
                }

            // Liquid glass checkmark - smaller size
            ZStack {
                // Glass effect background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.green.opacity(0.2))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(width: 48, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                Color.green.opacity(0.4),
                                lineWidth: 1.5
                            )
                    }

                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.green)
            }
            .opacity(checkmarkAppeared ? 1 : 0)
            .scaleEffect(checkmarkAppeared ? 1 : 0.5)
            .offset(y: checkmarkAppeared ? 0 : 10)
        }
    }

    private var successHeroSection: some View {
        VStack(spacing: 12) {
            Text("Welcome to Epilogue+")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .tracking(-0.5)

            Text("Your reading companion, unlimited")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
        .opacity(textAppeared ? 1 : 0)
        .offset(y: textAppeared ? 0 : -10)
    }

    private var unlockedFeaturesSection: some View {
        VStack(spacing: 16) {
            // Features card
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("NOW UNLOCKED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                        .kerning(1.4)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 16) {
                    unlockedFeatureItem(
                        icon: "infinity",
                        title: "Unlimited ambient mode conversations"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.4),
                                Color.green.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .padding(.horizontal, 20)
        .opacity(featuresAppeared ? 1 : 0)
        .offset(y: featuresAppeared ? 0 : -10)
    }

    private func unlockedFeatureItem(icon: String, title: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var continueCTASection: some View {
        VStack(spacing: 16) {
            // Primary CTA - Green liquid glass
            Button {
                dismiss()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green.opacity(0.2))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    Color.green.opacity(0.4),
                                    lineWidth: 1.5
                                )
                        }

                    Text("Start Reading")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 52)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Secondary info
            Text("Your subscription starts today. Manage anytime in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .opacity(ctaAppeared ? 1 : 0)
    }

    // MARK: - Actions
    private func handleContinue() {
        SensoryFeedback.success()

        // Simulate purchase success
        withAnimation(.easeOut(duration: 0.3)) {
            showPaywall = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSuccess = true
            }
        }
    }

    private func triggerSuccessAnimations() {
        // Reset all states
        orbAppeared = false
        checkmarkAppeared = false
        textAppeared = false
        featuresAppeared = false
        ctaAppeared = false
        celebrationPulses = []

        // Trigger animations in sequence
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            orbAppeared = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            SensoryFeedback.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkAppeared = true
            }
            // Trigger green water-ripple celebration
            triggerCelebrationPulses()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                textAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                featuresAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                ctaAppeared = true
            }
        }
    }

    private func triggerCelebrationPulses() {
        // Create 5 expanding green water-ripple pulse rings
        for i in 0..<5 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let pulse = PurchaseCelebrationPulse(id: UUID())
                celebrationPulses.append(pulse)

                // Water-ripple physics - each ring loses energy as it travels outward
                let waveNumber = Double(i)
                let baseResponse = 1.8
                let variableResponse = baseResponse + (waveNumber * 0.18)
                let variableDamping = 0.38 + (waveNumber * 0.04)
                let variableScale = 5.0 - (waveNumber * 0.15)

                // Add slight randomness for organic feel
                let randomOffset = Double.random(in: -0.05...0.05)
                let finalResponse = variableResponse + randomOffset

                // Animate with water-like spring physics
                withAnimation(.spring(response: finalResponse, dampingFraction: variableDamping)) {
                    if let index = celebrationPulses.firstIndex(where: { $0.id == pulse.id }) {
                        celebrationPulses[index].scale = variableScale
                        celebrationPulses[index].opacity = 0.0
                    }
                }

                // Remove pulse after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    celebrationPulses.removeAll(where: { $0.id == pulse.id })
                }
            }
        }
    }

    private func resetSuccessAnimations() {
        orbAppeared = false
        checkmarkAppeared = false
        textAppeared = false
        featuresAppeared = false
        ctaAppeared = false
        celebrationPulses = []
    }
}

// MARK: - Supporting Types
struct PurchaseCelebrationPulse: Identifiable {
    let id: UUID
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// MARK: - Green Metal Shader View
struct GreenMetalShaderView: UIViewRepresentable {
    @Binding var isPressed: Bool
    let size: CGSize

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: GreenMetalShaderView
        var renderer: OrbMetalRenderer!

        init(_ parent: GreenMetalShaderView) {
            self.parent = parent
            super.init()
            renderer = OrbMetalRenderer()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.viewSizeChanged(to: size)
        }

        func draw(in view: MTKView) {
            renderer.isPressed = parent.isPressed
            // Set green color
            renderer.themeColor = SIMD3<Float>(0.0, 0.8, 0.0) // Bright green
            renderer.draw(in: view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            return mtkView
        }

        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        // Proper configuration for transparency
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.layer.backgroundColor = UIColor.clear.cgColor
        mtkView.layer.isOpaque = false
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.parent = self
        uiView.isPaused = false
    }
}

#Preview {
    PurchaseSuccessExperiment()
}
