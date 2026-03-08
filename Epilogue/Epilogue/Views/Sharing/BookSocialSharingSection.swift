import SwiftUI
import SwiftData

// MARK: - Book Social Sharing Section
/// A section component for BookDetailView that adds social sharing features.
/// Shows: Share Book button, Read Together button, and companion progress (if active).

struct BookSocialSharingSection: View {
    let book: BookModel
    let accentColor: Color

    @Environment(\.modelContext) private var modelContext
    @State private var showingCompanionInvite: Bool = false
    @State private var showingShareOptions: Bool = false
    @State private var showingLeaveMarker: Bool = false
    @State private var showingDisplayNameSetup: Bool = false
    @State private var activeCompanionship: SocialCompanionship?
    @State private var isOwner: Bool = true

    @AppStorage("userDisplayName") private var displayName: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // If there's an active companionship, show progress
            if let companionship = activeCompanionship {
                CompanionProgressView(
                    companionship: companionship,
                    isOwner: isOwner,
                    onLeaveMarker: {
                        showingLeaveMarker = true
                    }
                )
            }

            // Action buttons
            GlassEffectContainer {
            HStack(spacing: 12) {
                // Share Book button
                Button {
                    SensoryFeedback.light()
                    showingShareOptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(.regular.tint(accentColor.opacity(0.2)), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Read Together button (only if no active companionship)
                if activeCompanionship == nil {
                    Button {
                        SensoryFeedback.light()
                        if displayName.isEmpty {
                            showingDisplayNameSetup = true
                        } else {
                            showingCompanionInvite = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.2")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Read Together")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassEffect(.regular.tint(Color.orange.opacity(0.2)), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            } // GlassEffectContainer
        }
        .task {
            await loadCompanionship()
        }
        .sheet(isPresented: $showingCompanionInvite) {
            CompanionInviteSheet(
                book: book,
                onInviteSent: { companionship in
                    activeCompanionship = companionship
                    showingCompanionInvite = false
                },
                onDismiss: {
                    showingCompanionInvite = false
                }
            )
        }
        .sheet(isPresented: $showingShareOptions) {
            BookShareOptionsSheet(
                book: book,
                onDismiss: {
                    showingShareOptions = false
                }
            )
        }
        .sheet(isPresented: $showingLeaveMarker) {
            if let companionship = activeCompanionship {
                LeaveMarkerSheet(
                    book: book,
                    companionship: companionship,
                    currentProgress: isOwner ? companionship.ownerProgress : companionship.companionProgress,
                    onSave: { _ in
                        showingLeaveMarker = false
                    },
                    onDismiss: {
                        showingLeaveMarker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingDisplayNameSetup) {
            DisplayNameSetupSheet(
                onComplete: { name in
                    showingDisplayNameSetup = false
                    // After setting name, show companion invite
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingCompanionInvite = true
                    }
                },
                onDismiss: {
                    showingDisplayNameSetup = false
                }
            )
        }
    }

    private func loadCompanionship() async {
        do {
            if let companionship = try SocialCompanionService.shared.getCompanionship(
                forBookLocalId: book.localId,
                context: modelContext
            ) {
                activeCompanionship = companionship

                // Determine if user is owner
                let userRecordName = try await SocialCompanionService.shared.getCurrentUserRecordName()
                isOwner = companionship.ownerRecordName == userRecordName
            }
        } catch {
            // No companionship found - that's fine
        }
    }
}

// MARK: - Book Share Options Sheet
/// Bottom sheet showing sharing options for a book.

struct BookShareOptionsSheet: View {
    let book: BookModel
    let onDismiss: () -> Void

    @State private var showingQuoteGift: Bool = false
    @State private var showingPostcard: Bool = false
    @State private var selectedQuote: CapturedQuote?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                // Share book link
                Section {
                    ShareLink(
                        item: shareURL,
                        subject: Text(book.title),
                        message: Text("Check out \"\(book.title)\" by \(book.author)")
                    ) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Book Link")
                                    .font(.body)
                                Text("Share a link to this book")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "link")
                        }
                    }
                }

                // Share a quote
                Section {
                    Button {
                        // If book has quotes, let user pick one
                        showingQuoteGift = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share a Quote")
                                    .font(.body)
                                Text("Gift a quote to a friend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "quote.opening")
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Create a postcard (for completion or session)
                if book.readingStatus == ReadingStatus.read.rawValue {
                    Section {
                        Button {
                            showingPostcard = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create Literary Postcard")
                                        .font(.body)
                                    Text("Share a reflection on finishing this book")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showingQuoteGift) {
            QuotePickerForGifting(
                book: book,
                onQuoteSelected: { quote in
                    selectedQuote = quote
                    showingQuoteGift = false
                },
                onDismiss: {
                    showingQuoteGift = false
                }
            )
        }
        .sheet(item: $selectedQuote) { quote in
            QuoteGiftSheet(
                quote: quote,
                onShare: { gift in
                    shareQuoteGift(gift)
                    selectedQuote = nil
                    onDismiss()
                },
                onDismiss: {
                    selectedQuote = nil
                }
            )
        }
        .sheet(isPresented: $showingPostcard) {
            PostcardGeneratorSheet(
                book: book,
                onDismiss: {
                    showingPostcard = false
                    onDismiss()
                }
            )
        }
    }

    private var shareURL: URL {
        // TODO: Replace with actual readepilogue.com URL when web is ready
        if let isbn = book.isbn, !isbn.isEmpty {
            return URL(string: "https://readepilogue.com/book/\(isbn)")!
        } else {
            return URL(string: "https://readepilogue.com/book/\(book.id)")!
        }
    }

    private func shareQuoteGift(_ gift: QuoteGift) {
        if gift.shareAsImage {
            // Generate image and share
            Task { @MainActor in
                let card = ShareableQuoteGiftCard(
                    quote: gift.quote,
                    personalNote: gift.personalNote,
                    senderName: gift.senderName,
                    theme: gift.theme
                )
                let image = ImageRenderer.renderModern(view: card)
                shareImage(image)
            }
        } else {
            // Share as text
            shareText(gift.formattedText)
        }
    }

    private func shareImage(_ image: UIImage) {
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        }
    }

    private func shareText(_ text: String) {
        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        }
    }
}

// MARK: - Quote Picker for Gifting

struct QuotePickerForGifting: View {
    let book: BookModel
    let onQuoteSelected: (CapturedQuote) -> Void
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var quotes: [CapturedQuote] = []

    var body: some View {
        NavigationStack {
            Group {
                if quotes.isEmpty {
                    ContentUnavailableView(
                        "No Quotes Yet",
                        systemImage: "quote.opening",
                        description: Text("Capture some quotes from this book first, then you can share them with friends.")
                    )
                } else {
                    List(quotes, id: \.id) { quote in
                        Button {
                            onQuoteSelected(quote)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\"\(quote.text ?? "")\"")
                                    .font(.body)
                                    .lineLimit(3)

                                if let page = quote.pageNumber {
                                    Text("p. \(page)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Choose a Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .task {
                loadQuotes()
            }
        }
    }

    private func loadQuotes() {
        let bookLocalId = book.localId
        var descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.bookLocalId == bookLocalId }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        quotes = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Postcard Generator Sheet

struct PostcardGeneratorSheet: View {
    let book: BookModel
    let onDismiss: () -> Void

    @State private var isGenerating: Bool = true
    @State private var postcardContent: PostcardContent?
    @State private var showingPreview: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)

                        Text("Creating your reflection...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let content = postcardContent {
                    PostcardPreview(content: content, theme: .warm, senderName: nil)
                        .padding()

                    Button {
                        showingPreview = true
                    } label: {
                        Text("Customize & Share")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Literary Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .task {
                await generatePostcard()
            }
            .sheet(isPresented: $showingPreview) {
                if let content = postcardContent {
                    PostcardPreviewSheet(
                        content: content,
                        onShare: { image, theme in
                            shareImage(image)
                            showingPreview = false
                            onDismiss()
                        },
                        onDismiss: {
                            showingPreview = false
                        }
                    )
                }
            }
        }
    }

    private func generatePostcard() async {
        let content = await LiteraryPostcardService.shared.generateCompletionPostcard(book: book)
        await MainActor.run {
            postcardContent = content
            isGenerating = false
        }
    }

    private func shareImage(_ image: UIImage) {
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let book = BookModel(
        id: "123",
        title: "The Brothers Karamazov",
        author: "Fyodor Dostoevsky"
    )

    BookSocialSharingSection(
        book: book,
        accentColor: .orange
    )
    .padding()
    .background(Color.black)
}
