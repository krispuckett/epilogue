import SwiftUI
import SwiftData

// MARK: - Companion Invitation Accept Sheet
/// Sheet shown when user opens a companion invitation deep link.
/// Allows them to accept and join the reading companionship.
/// Uses Epilogue's Liquid Glass design language.

struct CompanionInvitationAcceptSheet: View {
    let token: String
    let onAccept: (SocialCompanionship) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isLoading: Bool = true
    @State private var companionship: SocialCompanionship?
    @State private var error: String?
    @State private var isAccepting: Bool = false
    @State private var displayName: String = ""

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient background
                ambientBackground

                Group {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else if let companionship = companionship {
                        invitationContent(companionship)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .task {
                await loadInvitation()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        AmbientRadialGlowBackground(glowOpacity: 0.2)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(DesignSystem.Colors.primaryAccent)

            Text("Loading invitation...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.red.opacity(0.8))
            }

            VStack(spacing: 8) {
                Text("Invitation Not Found")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                onDismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 48)
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            .padding(.top, 8)
        }
    }

    // MARK: - Invitation Content

    private func invitationContent(_ companionship: SocialCompanionship) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section
                VStack(spacing: 24) {
                    // Invitation badge
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "figure.2")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    }

                    // Who invited you
                    VStack(spacing: 6) {
                        Text("\(companionship.ownerDisplayName)")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)

                        Text("invited you to read together")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.top, 40)

                // Book card
                bookCard(companionship)
                    .padding(.top, 32)
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)

                // What you'll get
                whatYouGetSection
                    .padding(.top, 32)
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)

                // Name input if needed
                if savedDisplayName.isEmpty {
                    nameInputSection(companionName: companionship.ownerDisplayName)
                        .padding(.top, 24)
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                }

                Spacer(minLength: 140)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) {
            acceptButton(companionship)
        }
    }

    // MARK: - Book Card

    private func bookCard(_ companionship: SocialCompanionship) -> some View {
        HStack(spacing: 16) {
            // Book cover
            ZStack {
                // Glow (cached for offline)
                if let coverURL = companionship.bookCoverURL, !coverURL.isEmpty {
                    SharedBookCoverView(
                        coverURL: coverURL,
                        width: 70,
                        height: 105
                    )
                    .blur(radius: 25)
                    .opacity(0.4)
                }

                // Cover
                SharedBookCoverView(
                    coverURL: companionship.bookCoverURL,
                    width: 70,
                    height: 105
                )
            }

            // Book info
            VStack(alignment: .leading, spacing: 6) {
                Text(companionship.bookTitle)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("by \(companionship.bookAuthor)")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    // MARK: - What You Get Section

    private var whatYouGetSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHEN YOU JOIN")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            VStack(spacing: 10) {
                FeatureBullet(icon: "eye", text: "See each other's reading progress")
                FeatureBullet(icon: "bookmark.fill", text: "Discover trail markers they leave")
                FeatureBullet(icon: "bookmark", text: "Leave your own thoughts for them")
            }
        }
    }

    // MARK: - Name Input Section

    private func nameInputSection(companionName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR NAME")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            TextField("How should \(companionName) see you?", text: $displayName)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(16)
                .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        }
    }

    // MARK: - Accept Button

    private func acceptButton(_ companionship: SocialCompanionship) -> some View {
        Button {
            acceptInvitation(companionship)
        } label: {
            HStack(spacing: 10) {
                if isAccepting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17, weight: .semibold))
                }

                Text("Join \(companionship.ownerDisplayName)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .frame(height: 52)
        }
        .disabled(isAccepting || (savedDisplayName.isEmpty && displayName.isEmpty))
        .opacity((isAccepting || (savedDisplayName.isEmpty && displayName.isEmpty)) ? 0.5 : 1.0)
        .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func loadInvitation() async {
        do {
            let foundCompanionship = try await SocialCompanionService.shared.lookupInvitation(
                token: token,
                context: modelContext
            )

            await MainActor.run {
                companionship = foundCompanionship
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "This invitation may have expired or already been used."
                isLoading = false
            }
        }
    }

    private func acceptInvitation(_ companionship: SocialCompanionship) {
        isAccepting = true
        SensoryFeedback.medium()

        // Save display name if new
        let name = savedDisplayName.isEmpty ? displayName : savedDisplayName
        if savedDisplayName.isEmpty && !displayName.isEmpty {
            savedDisplayName = displayName
        }

        Task {
            do {
                let updatedCompanionship = try await SocialCompanionService.shared.acceptInvitation(
                    companionship: companionship,
                    companionDisplayName: name,
                    context: modelContext
                )

                await MainActor.run {
                    isAccepting = false
                    SensoryFeedback.success()
                    onAccept(updatedCompanionship)
                }
            } catch {
                await MainActor.run {
                    isAccepting = false
                    self.error = error.localizedDescription
                    SensoryFeedback.error()
                }
            }
        }
    }
}

// MARK: - Feature Bullet

private struct FeatureBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    CompanionInvitationAcceptSheet(
        token: "ABC123",
        onAccept: { _ in },
        onDismiss: {}
    )
}
