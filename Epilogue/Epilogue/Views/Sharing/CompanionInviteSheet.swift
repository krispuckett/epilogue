import SwiftUI
import SwiftData

// MARK: - Companion Invite Sheet
/// Sheet for inviting a friend to read a book together.
/// Redesigned with Epilogue's Liquid Glass design language.

struct CompanionInviteSheet: View {
    let book: BookModel
    let onInviteSent: (SocialCompanionship) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var displayName: String = ""
    @State private var isCreating: Bool = false
    @State private var createdCompanionship: SocialCompanionship?
    @State private var error: String?
    @State private var showShareSheet: Bool = false

    @AppStorage("userDisplayName") private var savedDisplayName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background
                ambientBackground

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero section with book cover
                        heroSection
                            .padding(.top, 24)

                        // Feature highlights
                        featuresSection
                            .padding(.top, 32)

                        // Name input (if needed)
                        if savedDisplayName.isEmpty {
                            nameInputSection
                                .padding(.top, 24)
                        }

                        // Error message
                        if let error = error {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                                .padding(.top, 12)
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Read Together")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .safeAreaBar(edge: .bottom) {
                createButton
            }
            .sheet(isPresented: $showShareSheet) {
                if let companionship = createdCompanionship {
                    ShareInvitationSheet(
                        companionship: companionship,
                        onDismiss: {
                            showShareSheet = false
                            onInviteSent(companionship)
                        }
                    )
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        AmbientRadialGlowBackground()
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Book cover with glow
            ZStack {
                // Glow behind cover (cached for offline)
                if let coverURL = book.coverImageURL, !coverURL.isEmpty {
                    SharedBookCoverView(
                        coverURL: coverURL,
                        width: 100,
                        height: 150
                    )
                    .blur(radius: 40)
                    .opacity(0.5)
                }

                // Actual cover
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 100,
                    height: 150
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            }

            // Book info
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("by \(book.author)")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, 20)

            // Tagline
            Text("Invite a friend to read this book with you")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 12) {
            CompanionFeatureCard(
                icon: "figure.2",
                title: "Reading together",
                description: "See each other's approximate progress"
            )

            CompanionFeatureCard(
                icon: "bookmark.fill",
                title: "Trail markers",
                description: "Leave thoughts for each other to discover"
            )

            CompanionFeatureCard(
                icon: "eye.slash",
                title: "Spoiler-safe",
                description: "Only see markers up to your progress"
            )

            CompanionFeatureCard(
                icon: "clock",
                title: "No pressure",
                description: "Read at your own pace, always"
            )
        }
    }

    // MARK: - Name Input Section

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR NAME")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            TextField("How should your friend see you?", text: $displayName)
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

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            createInvitation()
        } label: {
            HStack(spacing: 10) {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 17, weight: .semibold))
                }

                Text("Create Invitation")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .frame(height: 52)
        }
        .disabled(isCreating || (savedDisplayName.isEmpty && displayName.isEmpty))
        .opacity((isCreating || (savedDisplayName.isEmpty && displayName.isEmpty)) ? 0.5 : 1.0)
        .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func createInvitation() {
        isCreating = true
        error = nil
        SensoryFeedback.medium()

        // Save display name if new
        let name = savedDisplayName.isEmpty ? displayName : savedDisplayName
        if savedDisplayName.isEmpty && !displayName.isEmpty {
            savedDisplayName = displayName
        }

        Task {
            do {
                let companionship = try await SocialCompanionService.shared.createCompanionship(
                    for: book,
                    ownerDisplayName: name,
                    context: modelContext
                )

                await MainActor.run {
                    isCreating = false
                    createdCompanionship = companionship
                    SensoryFeedback.success()
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    self.error = error.localizedDescription
                    SensoryFeedback.error()
                }
            }
        }
    }
}

// MARK: - Companion Feature Card

private struct CompanionFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon in glass circle
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

// MARK: - Share Invitation Sheet

struct ShareInvitationSheet: View {
    let companionship: SocialCompanionship
    let onDismiss: () -> Void

    @State private var hasCopied: Bool = false
    @State private var animateSuccess: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Success glow
                RadialGradient(
                    colors: [
                        Color.green.opacity(0.15),
                        Color.green.opacity(0.05),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    // Success animation - simple fade in, no scaling
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                    }
                    .opacity(animateSuccess ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: animateSuccess)

                    Text("Invitation Created")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 24)

                    // Book info
                    VStack(spacing: 4) {
                        Text(companionship.bookTitle)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("by \(companionship.bookAuthor)")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 32)

                    // Link card
                    if let url = companionship.invitationURL {
                        VStack(spacing: 16) {
                            Text("SHARE THIS LINK")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1.2)

                            HStack {
                                Text(url.absoluteString)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = url.absoluteString
                                    hasCopied = true
                                    SensoryFeedback.success()
                                } label: {
                                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(hasCopied ? .green : DesignSystem.Colors.primaryAccent)
                                }
                            }
                            .padding(16)
                            .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            }
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    }

                    // Expiration note
                    if let expiresAt = companionship.invitationExpiresAt {
                        let formatter = RelativeDateTimeFormatter()
                        Text("Expires \(formatter.localizedString(for: expiresAt, relativeTo: Date()))")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            .padding(.top, 12)
                    }

                    Spacer()

                    // Share button
                    if let url = companionship.invitationURL {
                        ShareLink(
                            item: url,
                            message: Text("Join me in reading \"\(companionship.bookTitle)\" together on Epilogue!")
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 17, weight: .semibold))

                                Text("Share Invitation")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .frame(height: 52)
                        }
                        .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)), in: RoundedRectangle(cornerRadius: 26))
                        .overlay {
                            RoundedRectangle(cornerRadius: 26)
                                .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    }

                    // Done button
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                animateSuccess = true
            }
            SensoryFeedback.success()
        }
    }
}

// MARK: - Preview

#Preview("Invite Sheet") {
    let book = BookModel(
        id: "123",
        title: "The Brothers Karamazov",
        author: "Fyodor Dostoevsky"
    )

    CompanionInviteSheet(
        book: book,
        onInviteSent: { _ in },
        onDismiss: {}
    )
}
