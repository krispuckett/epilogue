import SwiftUI

// MARK: - Companion Progress View
/// Shows your reading companion's progress on a book.
/// Displayed in book detail view when an active companionship exists.
/// Uses Epilogue's Liquid Glass design language.

struct CompanionProgressView: View {
    let companionship: SocialCompanionship
    let isOwner: Bool
    let onLeaveMarker: () -> Void

    var companionName: String {
        isOwner
            ? (companionship.companionDisplayName ?? "Your companion")
            : companionship.ownerDisplayName
    }

    var companionProgress: Double {
        isOwner ? companionship.companionProgress : companionship.ownerProgress
    }

    var companionChapter: String? {
        isOwner ? companionship.companionChapter : companionship.ownerChapter
    }

    var myProgress: Double {
        isOwner ? companionship.ownerProgress : companionship.companionProgress
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)

                    Text("Reading with \(companionName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Leave marker button
                Button {
                    SensoryFeedback.light()
                    onLeaveMarker()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12))
                        Text("Leave marker")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(in: Capsule())
                }
            }

            // Progress visualization
            VStack(spacing: 12) {
                // Dual progress bars
                HStack(spacing: 16) {
                    // You
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOU")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(1)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.1))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignSystem.Colors.primaryAccent)
                                    .frame(width: max(4, geo.size.width * myProgress))
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(myProgress * 100))%")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    // Companion
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(companionName.uppercased().prefix(10))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(1)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .trailing) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.1))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange)
                                    .frame(width: max(4, geo.size.width * companionProgress))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(companionProgress * 100))%")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }

                // Status message
                if let statusMessage = statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var statusMessage: String? {
        if myProgress > companionProgress + 0.05 {
            return "You're ahead — leave a trail marker for \(companionName.components(separatedBy: " ").first ?? "them")?"
        } else if companionProgress > myProgress + 0.05 {
            return "\(companionName.components(separatedBy: " ").first ?? "They")'s ahead — trail markers may be waiting"
        } else if let chapter = companionChapter {
            return "\(companionName.components(separatedBy: " ").first ?? "They")'s at \(chapter)"
        }
        return nil
    }
}

// MARK: - Compact Companion Badge
/// Small badge showing companion reading status, for use in lists

struct CompanionBadge: View {
    let companionName: String
    let companionProgress: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.2")
                .font(.system(size: 10, weight: .medium))

            Text("\(companionName.components(separatedBy: " ").first ?? "Friend") \(Int(companionProgress * 100))%")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(Color.orange.opacity(0.15)), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            CompanionProgressView(
                companionship: {
                    let c = SocialCompanionship(
                        book: BookModel(id: "123", title: "Test", author: "Test"),
                        ownerDisplayName: "Kris",
                        ownerRecordName: "owner123"
                    )
                    c.companionDisplayName = "Sarah"
                    c.ownerProgress = 0.45
                    c.companionProgress = 0.32
                    c.ownerChapter = "Chapter 12"
                    c.companionChapter = "Chapter 9"
                    return c
                }(),
                isOwner: true,
                onLeaveMarker: {}
            )
            .padding(.horizontal)

            CompanionBadge(companionName: "Sarah", companionProgress: 0.32)
        }
    }
}
