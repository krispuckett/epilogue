import SwiftUI

// MARK: - What's New Sheet (Ambient Session Summary Style)
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Minimal gradient background (matching session summary)
                minimalGradientBackground

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                            .padding(.top, 40)
                            .padding(.bottom, 24)

                        // Highlight insight card
                        highlightCard
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .padding(.bottom, 32)

                        // New capabilities
                        newCapabilitiesSection
                            .padding(.bottom, 32)

                        // Improvements
                        improvementsSection
                            .padding(.bottom, 32)

                        // Metrics
                        metricsSection
                            .padding(.bottom, 32)

                        Spacer(minLength: 60)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                hasAppeared = true
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

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Header removed - just using navigation title
        }
    }

    // MARK: - Highlight Card
    private var highlightCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("HIGHLIGHT")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()
            }

            Text("New Quick Reading Session - start reading without ambient intelligence, track progress, all with a single tap.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    // MARK: - New Capabilities Section
    private var newCapabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("NEW CAPABILITIES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            VStack(spacing: 1) {
                FeatureRow(
                    number: 1,
                    title: "AI with Memory",
                    description: "Ambient mode can now answer questions about past discussions, find mentions of characters, and search your saved quotes. Powered by iOS 26 tool calling.",
                    detail: "Ask 'What did I say about Gandalf?' or 'Show my quotes about power'"
                )

                FeatureRow(
                    number: 2,
                    title: "Better Book Context",
                    description: "Books get AI-generated summaries that capture their essence without spoilers. Automatically enriched when you view them.",
                    detail: "Works for fiction and non-fiction"
                )

                FeatureRow(
                    number: 3,
                    title: "Personal Recommendations",
                    description: "After 5 books, get recommendations based on your library's themes and authors. Analyzed privately on-device.",
                    detail: "Available in Search"
                )

                FeatureRow(
                    number: 4,
                    title: "Smarter Ambient Mode",
                    description: "Detects when you're refining questions, prevents duplicates, and classifies captures automatically.",
                    detail: "Understands corrections and context"
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }

    // MARK: - Improvements Section
    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("UNDER THE HOOD")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            VStack(spacing: 12) {
                ImprovementItem(text: "Offline cover caching")
                ImprovementItem(text: "Question queue with retry logic")
                ImprovementItem(text: "Reading sessions persist your progress")
                ImprovementItem(text: "Context-aware AI responses")
                ImprovementItem(text: "Better edition selection from Google Books")
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }

    // MARK: - Metrics Section
    private var metricsSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 32) {
                metricItem(value: "5", label: "AI\nTOOLS")
                metricItem(value: "3", label: "INTELLIGENCE\nLAYERS")
                metricItem(value: "100%", label: "OFFLINE\nSUPPORT")
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            // Start Reading button - PROPER GLASS PATTERN
            Button {
                dismiss()
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

                    Text("Start Reading")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 52)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 60)
        }
    }

    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let number: Int
    let title: String
    let description: String
    let detail: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row (always visible)
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(DesignSystem.Animation.easeQuick) {
                    isExpanded.toggle()
                }
            }

            // Description (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.9))
                            .padding(.top, 4)
                    }
                    .padding(.leading, 40)
                    .padding(.vertical, 12)

                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Improvement Item
struct ImprovementItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.8))

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    WhatsNewView()
}
