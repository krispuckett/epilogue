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
                    LazyVStack(spacing: 0, pinnedViews: []) {
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
                            .padding(.bottom, 60)

                        Spacer(minLength: 60)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
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

            Text("Smarter conversations powered by Claude, thematic connections across your library, and a more polished experience throughout.")
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
            Text("NEW")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            VStack(spacing: 1) {
                FeatureRow(
                    number: 1,
                    title: "Smarter Intelligence",
                    description: "Epilogue now uses Claude for all AI conversations. Expect more thoughtful responses, better book recommendations, and more natural dialogue during ambient sessions.",
                    detail: "Just start a conversation—you'll notice the difference"
                )

                FeatureRow(
                    number: 2,
                    title: "Discover Connections",
                    description: "A new recommendation flow helps you discover books based on your mood. Tell Epilogue what you're in the mood for and get personalized suggestions drawn from your reading patterns.",
                    detail: "Tap the recommendation prompt in any session"
                )

                FeatureRow(
                    number: 3,
                    title: "Thematic Connections",
                    description: "Epilogue now maps themes, characters, and ideas across your entire library. See how your books connect to each other through shared threads you might not have noticed.",
                    detail: "Look for connection cards on book detail pages"
                )

                FeatureRow(
                    number: 4,
                    title: "Custom Book Covers",
                    description: "Upload your own cover images for any book in your library. Perfect for editions with covers that don't match, self-published books, or ARCs.",
                    detail: "Edit any book → tap the cover image"
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
                ImprovementItem(text: "Offline book covers — cached for when you're without signal")
                ImprovementItem(text: "Books auto-enrich after iCloud sync")
                ImprovementItem(text: "Improved Goodreads import with direct export link")
                ImprovementItem(text: "Crash fixes and performance improvements")
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
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
