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

            Text("Advanced camera quote capture with intelligent multi-column text detection. Perfect for capturing quotes from two-column layouts and complex book pages.")
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
                    title: "Camera Quote Capture",
                    description: "Point your camera at any book page and instantly select text from individual columns. Multi-column detection works with textbooks, magazines, and reference books. Live text recognition with glass overlay highlights shows exactly what will be captured.",
                    detail: "Access from Developer Options > Experimental Quote Capture"
                )

                FeatureRow(
                    number: 2,
                    title: "Siri & Shortcuts Integration",
                    description: "Complete voice control with 10+ App Intents. Ask Siri to continue reading, save quotes, add notes, update book status, log pages, rate books, search your library, export notes, and more. Works from anywhere in iOS.",
                    detail: "Try: 'Hey Siri, continue reading Meditations' or 'Save this quote to Epilogue'"
                )

                FeatureRow(
                    number: 3,
                    title: "Siri Examples",
                    description: "'Continue reading The Odyssey' jumps into Ambient Mode. 'Add a quote to Epilogue' saves text with Siri dictation. 'Log 25 pages in Meditations' updates reading progress hands-free.",
                    detail: "All intents work system-wide from Siri, Shortcuts, and Spotlight"
                )

                FeatureRow(
                    number: 4,
                    title: "Enhanced Google Books Search",
                    description: "Infinite scrolling and ISBN-based search for better book discovery. Improved cover quality and metadata accuracy.",
                    detail: "Search when adding books to your library"
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
                ImprovementItem(text: "Multi-column OCR with 15% gap detection algorithm")
                ImprovementItem(text: "Live text recognition with liquid glass overlays")
                ImprovementItem(text: "iOS 26 App Intents with system-wide Siri access")
                ImprovementItem(text: "Intelligent column sorting prevents text mixing")
                ImprovementItem(text: "Spotlight integration for voice-activated search")
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
