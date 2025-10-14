import SwiftUI
import StoreKit

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

    private var conversationsUsed: Int { storeKit.conversationsUsed }
    private var conversationsLimit: Int { 2 }

    var body: some View {
        NavigationStack {
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
            // EPILOGUE+ card (primary)
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Text("EPILOGUE+")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .kerning(1.4)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$7.99")
                                .font(.system(size: 30, weight: .bold, design: .monospaced))
                                .tracking(-1.5)
                                .foregroundStyle(.white.opacity(0.95))
                            Text("/mo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Text("or $67/yr  save 30%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.9))
                    }
                }

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

            // FREE card (collapsible)
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
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .opacity(featuresAppeared ? 1 : 0)
        .offset(y: featuresAppeared ? 0 : -10)
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
            }
            .buttonStyle(.plain)
            .disabled(storeKit.isLoading)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            // Error message
            if let error = storeKit.purchaseError {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
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

                Button {
                    handleRestorePurchases()
                } label: {
                    Text("Restore")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(storeKit.isLoading)
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
        }
        .opacity(ctaAppeared ? 1 : 0)
    }

    // MARK: - Actions
    private func handleContinue() {
        SensoryFeedback.light()

        Task {
            // Determine which product to purchase based on selected interval
            let product = selectedInterval == .annual ? storeKit.annualProduct : storeKit.monthlyProduct

            guard let product = product else {
                print("❌ Product not available: \(selectedInterval.rawValue)")
                return
            }

            print("🛒 Starting purchase for: \(product.id)")
            let success = await storeKit.purchase(product)

            if success {
                print("✅ Purchase completed successfully")
                dismiss()
            }
        }
    }

    private func handleRestorePurchases() {
        SensoryFeedback.light()

        Task {
            print("🔄 Restoring purchases...")
            await storeKit.restorePurchases()

            if storeKit.isPlus {
                print("✅ Purchases restored - user is now Plus")
                dismiss()
            } else {
                print("ℹ️ No active subscriptions found")
            }
        }
    }
}

// MARK: - Billing Interval
enum BillingInterval: String, CaseIterable {
    case monthly = "Monthly"
    case annual = "Annual"
}

// MARK: - Preview
#Preview {
    PremiumPaywallView()
}
