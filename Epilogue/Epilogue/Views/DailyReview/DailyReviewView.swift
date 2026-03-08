import SwiftUI
import SwiftData

// MARK: - Daily Review View
/// Card stack review UI for spaced repetition of quotes, notes, and insights.
/// Presents memory cards with atmospheric gradients derived from book covers.

struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var reviewCards: [MemoryCard] = []
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1.0
    @State private var isComplete: Bool = false
    @State private var reviewedCount: Int = 0
    @State private var totalToReview: Int = 0

    var body: some View {
        ZStack {
            // Atmospheric gradient background
            atmosphericBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentIndex)

            // Dark overlay for readability
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            if isComplete {
                completionView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if reviewCards.isEmpty {
                emptyStateView
            } else {
                reviewContent
            }
        }
        .task {
            loadCards()
        }
    }

    // MARK: - Atmospheric Background

    @ViewBuilder
    private var atmosphericBackground: some View {
        if let currentCard = currentCard, let palette = palette(for: currentCard) {
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: 0.8,
                audioLevel: 0
            )
        } else {
            // Fallback gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.1),
                    Color(red: 0.08, green: 0.06, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        VStack(spacing: 0) {
            // Header
            reviewHeader
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)

            Spacer()

            // Card
            if let card = currentCard {
                MemoryCardView(card: card)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .offset(cardOffset)
                    .opacity(cardOpacity)
                    .gesture(swipeGesture)
                    .animation(DesignSystem.Animation.springStandard, value: cardOffset)
            }

            Spacer()

            // Rating buttons
            ratingButtons
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    // MARK: - Header

    private var reviewHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(.white.opacity(0.1)))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close daily review")

            Spacer()

            // Progress indicator
            Text("\(reviewedCount + 1) of \(totalToReview)")
                .font(.system(size: DesignSystem.Typography.footnote, weight: .medium, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            // Progress bar
            ProgressView(value: Double(reviewedCount), total: Double(max(1, totalToReview)))
                .tint(DesignSystem.Colors.primaryAccent)
                .frame(width: 60)
        }
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(ReviewQuality.allCases, id: \.rawValue) { quality in
                ratingButton(for: quality)
            }
        }
    }

    private func ratingButton(for quality: ReviewQuality) -> some View {
        Button {
            rateCard(quality: quality)
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: quality.icon)
                    .font(.system(size: 18, weight: .medium))
                Text(quality.label)
                    .font(.system(size: DesignSystem.Typography.caption2, weight: .medium, design: .rounded))
                if let card = currentCard {
                    Text(intervalPreview(for: card, quality: quality))
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(DesignSystem.Colors.textQuaternary)
                }
            }
            .foregroundStyle(buttonColor(for: quality))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .glassEffect(.regular.tint(buttonColor(for: quality).opacity(0.1)))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .accessibilityLabel("Rate as \(quality.label)")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text("No reviews due")
                .font(.system(size: DesignSystem.Typography.title2, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Your highlights will appear here as they become due for review. Capture quotes and notes to build your memory library.")
                .font(.system(size: DesignSystem.Typography.body, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: DesignSystem.Typography.body, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.15)))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DesignSystem.Colors.success)

            Text("Review Complete")
                .font(.system(size: DesignSystem.Typography.title2, weight: .bold, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("\(reviewedCount) highlight\(reviewedCount == 1 ? "" : "s") reviewed")
                .font(.system(size: DesignSystem.Typography.body, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: DesignSystem.Typography.body, weight: .semibold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.15)))
                    .clipShape(Capsule())
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                cardOffset = value.translation
                // Fade as card is dragged further
                let progress = abs(value.translation.width) / 200
                cardOpacity = max(0.3, 1.0 - progress * 0.5)
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if value.translation.width > threshold {
                    // Swiped right = Good
                    animateCardOut(direction: .trailing) {
                        rateCard(quality: .good)
                    }
                } else if value.translation.width < -threshold {
                    // Swiped left = Again
                    animateCardOut(direction: .leading) {
                        rateCard(quality: .again)
                    }
                } else {
                    // Snap back
                    withAnimation(DesignSystem.Animation.springStandard) {
                        cardOffset = .zero
                        cardOpacity = 1.0
                    }
                }
            }
    }

    // MARK: - Actions

    private func loadCards() {
        reviewCards = MemoryResurfacingService.shared.getCardsForReview(modelContext: modelContext)
        totalToReview = reviewCards.count
        currentIndex = 0
        reviewedCount = 0
        isComplete = reviewCards.isEmpty && totalToReview == 0 ? false : false
    }

    private func rateCard(quality: ReviewQuality) {
        guard let card = currentCard else { return }

        // Apply SM-2 update
        MemoryResurfacingService.shared.reviewCard(card, quality: quality)

        // Haptic feedback
        switch quality {
        case .again:
            SensoryFeedback.impact(.light)
        case .hard:
            SensoryFeedback.impact(.medium)
        case .good:
            SensoryFeedback.impact(.medium)
        case .easy:
            SensoryFeedback.impact(.rigid)
        }

        // Save changes
        try? modelContext.save()

        // Advance to next card
        reviewedCount += 1

        if reviewedCount >= totalToReview {
            withAnimation(DesignSystem.Animation.springSmooth) {
                isComplete = true
            }
        } else {
            // Animate card transition
            withAnimation(DesignSystem.Animation.springStandard) {
                currentIndex += 1
                cardOffset = .zero
                cardOpacity = 1.0
            }
        }
    }

    private func animateCardOut(direction: Edge, completion: @escaping () -> Void) {
        let offsetX: CGFloat = direction == .trailing ? 400 : -400

        withAnimation(.easeIn(duration: 0.25)) {
            cardOffset = CGSize(width: offsetX, height: 0)
            cardOpacity = 0
        }

        // Execute completion after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            cardOffset = .zero
            cardOpacity = 1.0
            completion()
        }
    }

    // MARK: - Helpers

    private var currentCard: MemoryCard? {
        guard currentIndex < reviewCards.count else { return nil }
        return reviewCards[currentIndex]
    }

    private func palette(for card: MemoryCard) -> ColorPalette? {
        guard let hexColors = card.bookColors, hexColors.count >= 4 else { return nil }
        return ColorPalette(
            primary: Color(hex: hexColors[0]),
            secondary: Color(hex: hexColors[1]),
            accent: Color(hex: hexColors[2]),
            background: Color(hex: hexColors[3]),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: false,
            extractionQuality: 0.8
        )
    }

    private func buttonColor(for quality: ReviewQuality) -> Color {
        switch quality {
        case .again: return DesignSystem.Colors.error
        case .hard: return DesignSystem.Colors.warning
        case .good: return DesignSystem.Colors.success
        case .easy: return DesignSystem.Colors.info
        }
    }

    /// Shows a preview of what the next interval would be for each rating.
    private func intervalPreview(for card: MemoryCard, quality: ReviewQuality) -> String {
        if quality.rawValue < 3 {
            return "1d"
        }

        let simulatedInterval: Int
        switch card.reviewCount {
        case 0:
            simulatedInterval = 1
        case 1:
            simulatedInterval = 6
        default:
            simulatedInterval = max(1, Int(Double(card.interval) * card.easeFactor))
        }

        if simulatedInterval < 30 {
            return "\(simulatedInterval)d"
        } else {
            let months = simulatedInterval / 30
            return "\(months)mo"
        }
    }
}
