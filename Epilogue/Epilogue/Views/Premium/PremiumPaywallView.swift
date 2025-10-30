import SwiftUI
import StoreKit
import MetalKit
import simd

// MARK: - Premium Paywall View
struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = SimplifiedStoreKitManager.shared
    @State private var orbAppeared = false
    @State private var heroAppeared = false
    @State private var featuresAppeared = false
    @State private var ctaAppeared = false
    @State private var orbPressed = false
    @State private var isFreeCardExpanded = false
    @State private var selectedInterval: BillingInterval = .annual

    // Success celebration states
    @State private var showSuccess = false
    @State private var successOrbAppeared = false
    @State private var checkmarkAppeared = false
    @State private var successTextAppeared = false
    @State private var successFeaturesAppeared = false
    @State private var successCtaAppeared = false
    @State private var celebrationPulses: [PaywallCelebrationPulse] = []

    private var conversationsUsed: Int { storeKit.conversationsUsed }
    private var conversationsLimit: Int { 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                if showSuccess {
                    // Success celebration view
                    successCelebrationView
                } else {
                    // Paywall view
                    paywallView
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
                    .accessibilityLabel("Go back")
                    .accessibilityHint("Returns to previous screen")
                }
            }
            .onAppear {
                // Staggered animation for smooth entrance
                withAnimation(.easeOut(duration: 0.4)) {
                    orbAppeared = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        heroAppeared = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        featuresAppeared = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        ctaAppeared = true
                    }
                }
            }
        }
    }

    // MARK: - Paywall View
    private var paywallView: some View {
        ZStack {
            // Minimal gradient background (matching WhatsNewView)
            minimalGradientBackground

            ScrollView {
                VStack(spacing: 0) {
                    // Ambient orb decoration at top
                    decorativeOrbHeader
                        .padding(.top, 4)
                        .padding(.bottom, 12)

                    // Hero section
                    heroSection
                        .padding(.bottom, 32)

                    // Feature comparison
                    featureComparisonSection
                        .padding(.bottom, 32)

                    // CTA buttons
                    ctaSection
                        .padding(.bottom, 20)

                    // Footer
                    footerSection
                        .padding(.bottom, 40)

                    Spacer(minLength: 60)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Background
    private var minimalGradientBackground: some View {
        ZStack {
            // Permanent ambient gradient background
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Subtle darkening overlay for better readability
            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Decorative Orb Header
    private var decorativeOrbHeader: some View {
        MetalShaderView(isPressed: $orbPressed, size: CGSize(width: 160, height: 160))
            .frame(width: 160, height: 160)
            .opacity(orbAppeared ? 1 : 0)
            .offset(y: orbAppeared ? 0 : -20)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 8) {
            Text("Unlock a deeper reading experience")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .tracking(-0.5)
                .padding(.horizontal, 32)

            Text("You've used \(conversationsUsed) of \(conversationsLimit) free conversations this month".uppercased())
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
        .opacity(heroAppeared ? 1 : 0)
        .offset(y: heroAppeared ? 0 : -10)
    }

    // MARK: - Feature Comparison Section (Vertical Stack)
    private var featureComparisonSection: some View {
        VStack(spacing: 16) {
            plusCard
            freeCard
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .opacity(featuresAppeared ? 1 : 0)
        .offset(y: featuresAppeared ? 0 : -10)
    }

    private var plusCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text("EPILOGUE+")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .kerning(1.4)

                Spacer()
            }

            billingIntervalPicker

            VStack(alignment: .leading, spacing: 14) {
                featureItem(icon: "checkmark", text: "Unlimited ambient mode conversations")
                featureItem(icon: "checkmark", text: "Advanced AI models")
                featureItem(icon: "checkmark", text: "All core features")
                featureItem(icon: "checkmark", text: "On-device processing")
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
                            Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.4),
                            Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private var billingIntervalPicker: some View {
        HStack(spacing: 8) {
            ForEach(BillingInterval.allCases, id: \.self) { interval in
                        Button {
                            #if DEBUG
                            print("🎯 Billing interval tapped: \(interval.rawValue)")
                            #endif
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(interval.rawValue) subscription")
                        .accessibilityHint("Double tap to select \(interval == .monthly ? "monthly" : "annual") billing")
            }
        }
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isFreeCardExpanded.toggle()
                    }
                    SensoryFeedback.light()
                } label: {
                    HStack {
                        Text("FREE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .kerning(1.4)

                        Spacer()

                        Image(systemName: isFreeCardExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Free plan features")
                .accessibilityHint("Double tap to \(isFreeCardExpanded ? "collapse" : "expand") free plan details")
                .accessibilityValue(isFreeCardExpanded ? "Expanded" : "Collapsed")

                if isFreeCardExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        featureItem(icon: "checkmark", text: "2 ambient AI conversations/month", secondary: true)
                        featureItem(icon: "checkmark", text: "All core features", secondary: true)
                        featureItem(icon: "checkmark", text: "No account required", secondary: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func featureItem(icon: String, text: String, secondary: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(secondary ? Color.white.opacity(0.4) : Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.9))
                .frame(width: 16)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(secondary ? .white.opacity(0.6) : .white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - CTA Section
    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Primary button - Continue with Epilogue+
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

                    if storeKit.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue with Epilogue+")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(storeKit.isLoading)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .accessibilityLabel("Subscribe to Epilogue Plus")
            .accessibilityHint("Double tap to start subscription purchase")
            .accessibilityValue(storeKit.isLoading ? "Loading" : "Ready")

            // Error message
            if let error = storeKit.purchaseError {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

                    // Retry button when products fail to load
                    Button {
                        Task {
                            await storeKit.loadProducts()
                        }
                    } label: {
                        Text("Retry Loading Products")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .transition(.opacity)
            }

            // Secondary links
            HStack(spacing: 24) {
                Button {
                    dismiss()
                } label: {
                    Text("Stay Free")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(storeKit.isLoading)
                .accessibilityLabel("Continue with free plan")
                .accessibilityHint("Double tap to dismiss and use free plan with 2 conversations per month")

                Button {
                    handleRestorePurchases()
                } label: {
                    Text("Restore")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(storeKit.isLoading)
                .accessibilityLabel("Restore previous purchase")
                .accessibilityHint("Double tap to restore previously purchased subscription")
            }
        }
        .opacity(ctaAppeared ? 1 : 0)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Cancel anytime in Settings")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            // EULA and Privacy links (required for App Store subscriptions)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://readepilogue.com/privacy")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))

                Text("•")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))

                Link("Terms of Use", destination: URL(string: "https://readepilogue.com/terms")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
        .opacity(ctaAppeared ? 1 : 0)
    }

    // MARK: - Actions
    private func handleContinue() {
        #if DEBUG
        print("🎯 Continue button tapped - selectedInterval: \(selectedInterval.rawValue)")
        print("📦 Monthly product: \(storeKit.monthlyProduct?.id ?? "nil")")
        print("📦 Annual product: \(storeKit.annualProduct?.id ?? "nil")")
        print("⏳ isLoading: \(storeKit.isLoading)")
        #endif

        SensoryFeedback.light()

        Task {
            // Determine which product to purchase based on selected interval
            let product = selectedInterval == .annual ? storeKit.annualProduct : storeKit.monthlyProduct

            guard let product = product else {
                #if DEBUG
                print("❌ Product not available: \(selectedInterval.rawValue)")
                #endif

                // Show error to user if products aren't loaded
                await MainActor.run {
                    storeKit.purchaseError = "Subscription not available. Please try again in a moment."

                    // Try reloading products
                    Task {
                        await storeKit.loadProducts()
                    }
                }
                return
            }

            #if DEBUG
            print("🛒 Starting purchase for: \(product.id)")
            #endif
            let success = await storeKit.purchase(product)

            if success {
                #if DEBUG
                print("✅ Purchase completed successfully - showing celebration")
                #endif

                // Show success celebration instead of immediately dismissing
                await MainActor.run {
                    SensoryFeedback.success()
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSuccess = true
                    }

                    // Trigger success animations
                    triggerSuccessAnimations()
                }
            }
        }
    }

    private func handleRestorePurchases() {
        SensoryFeedback.light()

        Task {
            #if DEBUG
            print("🔄 Restoring purchases...")
            #endif
            await storeKit.restorePurchases()

            if storeKit.isPlus {
                #if DEBUG
                print("✅ Purchases restored - user is now Plus")
                #endif
                dismiss()
            } else {
                #if DEBUG
                print("ℹ️ No active subscriptions found")
                #endif
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
            PaywallGreenMetalShaderView(isPressed: $orbPressed, size: CGSize(width: 180, height: 180))
                .frame(width: 180, height: 180)
                .opacity(successOrbAppeared ? 1 : 0)
                .scaleEffect(successOrbAppeared ? 1 : 0.8)
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

            // Liquid glass checkmark
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
        .opacity(successTextAppeared ? 1 : 0)
        .offset(y: successTextAppeared ? 0 : -10)
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
                    successFeatureItem(
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
        .opacity(successFeaturesAppeared ? 1 : 0)
        .offset(y: successFeaturesAppeared ? 0 : -10)
    }

    private func successFeatureItem(icon: String, title: String) -> some View {
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
        .opacity(successCtaAppeared ? 1 : 0)
    }

    // MARK: - Success Animation Functions
    private func triggerSuccessAnimations() {
        // Reset all states
        successOrbAppeared = false
        checkmarkAppeared = false
        successTextAppeared = false
        successFeaturesAppeared = false
        successCtaAppeared = false
        celebrationPulses = []

        // Trigger animations in sequence
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            successOrbAppeared = true
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
                successTextAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                successFeaturesAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.4)) {
                successCtaAppeared = true
            }
        }
    }

    private func triggerCelebrationPulses() {
        // Create 5 expanding green water-ripple pulse rings
        for i in 0..<5 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let pulse = PaywallCelebrationPulse(id: UUID())
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
}

// MARK: - Billing Interval
enum BillingInterval: String, CaseIterable {
    case monthly = "Monthly"
    case annual = "Annual"
}

// MARK: - Supporting Types
struct PaywallCelebrationPulse: Identifiable {
    let id: UUID
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
}

// MARK: - Paywall Green Metal Shader View
struct PaywallGreenMetalShaderView: UIViewRepresentable {
    @Binding var isPressed: Bool
    let size: CGSize

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: PaywallGreenMetalShaderView
        var renderer: OrbMetalRenderer!

        init(_ parent: PaywallGreenMetalShaderView) {
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

// MARK: - Preview
#Preview {
    PremiumPaywallView()
}
