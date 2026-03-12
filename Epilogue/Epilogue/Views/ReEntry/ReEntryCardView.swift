import SwiftUI

// MARK: - Re-Entry Card View
/// A personalized recap card shown when a reader returns to a book after 3+ days.
/// Surfaces their own captured data — last quote, note, open question — to ease re-entry.

struct ReEntryCardView: View {
    let recap: ReEntryIntelligenceService.ReEntryRecap
    let bookColors: [String]?
    let onContinue: () -> Void
    let onStartAmbient: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed

    private var tintColor: Color {
        guard let hex = bookColors?.first else {
            return DesignSystem.Colors.primaryAccent
        }
        return Color(hex: hex)
    }

    private var dayLabel: String {
        let days = recap.daysSinceLastSession
        if days == 1 { return "1 day" }
        if days < 7 { return "\(days) days" }
        let weeks = days / 7
        if weeks == 1 { return "1 week" }
        return "\(weeks) weeks"
    }

    private var durationLabel: String {
        let minutes = Int(recap.lastSessionDuration / 60)
        if minutes < 1 { return "< 1 min" }
        if minutes == 1 { return "1 min" }
        return "\(minutes) min"
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: recap.lastSessionDate)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                headerSection
                whereYouLeftOffSection
                if recap.lastQuote != nil || recap.lastNote != nil || recap.openQuestion != nil {
                    capturedDataSection
                }
                actionButtons
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular, in: Circle())
            }
            .padding(DesignSystem.Spacing.md)
        }
        .glassEffect(.regular.tint(.black.opacity(0.3)))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Welcome back")
                .font(.system(size: DesignSystem.Typography.title2, weight: .semibold, design: .serif))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("It's been \(dayLabel) since your last session with")
                .font(.system(size: DesignSystem.Typography.body))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            +
            Text(" \(recap.bookTitle)")
                .font(.system(size: DesignSystem.Typography.body, weight: .semibold, design: .serif))
                .foregroundStyle(tintColor)
        }
    }

    // MARK: - Where You Left Off

    private var whereYouLeftOffSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionLabel("Where you left off")

            HStack(spacing: DesignSystem.Spacing.md) {
                if let page = recap.lastPage, page > 0 {
                    metadataPill(icon: "book", text: "Page \(page)")
                }
                metadataPill(icon: "calendar", text: dateLabel)
                metadataPill(icon: "clock", text: durationLabel)
            }
        }
    }

    // MARK: - Captured Data

    private var capturedDataSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if let quote = recap.lastQuote {
                capturedItem(
                    label: "Your last highlight",
                    icon: "quote.opening",
                    content: quote,
                    isQuote: true
                )
            }

            if let note = recap.lastNote {
                capturedItem(
                    label: "Your last thought",
                    icon: "note.text",
                    content: note,
                    isQuote: false
                )
            }

            if let question = recap.openQuestion {
                capturedItem(
                    label: "Open question",
                    icon: "questionmark.circle",
                    content: question,
                    isQuote: false
                )
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Primary: Continue reading
            Button {
                onContinue()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                    Text("Continue reading")
                        .font(.system(size: DesignSystem.Typography.body, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .fill(tintColor.opacity(0.8))
                )
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                // Secondary: Start ambient session
                Button {
                    onStartAmbient()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "waveform")
                            .font(.system(size: 13))
                        Text("Ambient session")
                            .font(.system(size: DesignSystem.Typography.footnote, weight: .medium))
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                }

                // Tertiary: Dismiss
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: DesignSystem.Typography.footnote, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                }
            }
        }
    }

    // MARK: - Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: DesignSystem.Typography.caption, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .kerning(DesignSystem.Typography.wideKerning)
    }

    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: DesignSystem.Typography.caption))
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .glassEffect(.regular, in: Capsule())
    }

    private func capturedItem(label: String, icon: String, content: String, isQuote: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(tintColor.opacity(0.8))
                Text(label.uppercased())
                    .font(.system(size: DesignSystem.Typography.caption2, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .kerning(DesignSystem.Typography.wideKerning)
            }

            Text(content)
                .font(isQuote
                    ? .system(size: DesignSystem.Typography.body, design: .serif)
                    : .system(size: DesignSystem.Typography.footnote))
                .foregroundStyle(isQuote
                    ? DesignSystem.Colors.textPrimary
                    : DesignSystem.Colors.textSecondary)
                .lineLimit(3)
                .italic(isQuote)
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .strokeBorder(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}
