import SwiftUI

// MARK: - Memory Card View
/// Individual card display for a memory resurfacing review.
/// Shows quote/note content with book attribution and source indicator.

struct MemoryCardView: View {
    let card: MemoryCard

    // Palette derived from card's cached book colors
    private var cardPalette: ColorPalette? {
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

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Source type indicator
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: sourceIcon)
                    .font(.system(size: 12, weight: .medium))
                Text(sourceLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .textCase(.uppercase)
                    .kerning(DesignSystem.Typography.wideKerning)
            }
            .foregroundStyle(accentColor.opacity(0.8))
            .padding(.bottom, DesignSystem.Spacing.lg)

            // Main content
            Text(formattedContent)
                .font(contentFont)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(DesignSystem.Typography.relaxedLineSpacing)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            // Book attribution
            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text(card.bookTitle)
                    .font(.system(size: DesignSystem.Typography.footnote, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text(card.bookAuthor)
                    .font(.system(size: DesignSystem.Typography.caption, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Captured date
            if let reviewCount = card.reviewCount as Int?, reviewCount > 0 {
                Text("Reviewed \(reviewCount) time\(reviewCount == 1 ? "" : "s")")
                    .font(.system(size: DesignSystem.Typography.caption2, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
                    .padding(.bottom, DesignSystem.Spacing.xs)
            }

            // Reflection prompt
            if let prompt = card.reflectionPrompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.system(size: DesignSystem.Typography.caption, weight: .medium, design: .rounded))
                    .foregroundStyle(accentColor.opacity(0.7))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: - Computed Properties

    private var sourceIcon: String {
        switch card.sourceType {
        case "quote": return "quote.opening"
        case "note": return "note.text"
        case "insight": return "lightbulb.fill"
        default: return "doc.text"
        }
    }

    private var sourceLabel: String {
        switch card.sourceType {
        case "quote": return "Quote"
        case "note": return "Note"
        case "insight": return "Insight"
        default: return "Memory"
        }
    }

    private var accentColor: Color {
        if let palette = cardPalette {
            return palette.accent
        }
        return DesignSystem.Colors.primaryAccent
    }

    private var contentFont: Font {
        let length = card.content.count
        if card.sourceType == "quote" {
            // Serif for quotes, size adapts to length
            if length > 300 {
                return .system(size: DesignSystem.Typography.body, weight: .regular, design: .serif)
            } else if length > 150 {
                return .system(size: DesignSystem.Typography.callout, weight: .regular, design: .serif)
            } else {
                return .system(size: DesignSystem.Typography.title3, weight: .regular, design: .serif)
            }
        } else {
            // Rounded for notes/insights
            if length > 300 {
                return .system(size: DesignSystem.Typography.body, weight: .regular, design: .rounded)
            } else if length > 150 {
                return .system(size: DesignSystem.Typography.callout, weight: .regular, design: .rounded)
            } else {
                return .system(size: DesignSystem.Typography.title3, weight: .regular, design: .rounded)
            }
        }
    }

    private var formattedContent: String {
        if card.sourceType == "quote" {
            return "\u{201C}\(card.content)\u{201D}"
        }
        return card.content
    }
}
