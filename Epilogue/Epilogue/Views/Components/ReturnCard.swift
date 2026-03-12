import SwiftUI
import SwiftData

// MARK: - Welcome Back Sheet (Half-sheet, WhatsNew design language)
struct WelcomeBackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<BookModel> { $0.readingStatus == "Currently Reading" },
        sort: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
    ) private var currentlyReadingBooks: [BookModel]

    @Query(
        sort: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
    ) private var allBooks: [BookModel]

    let onContinueReading: ((BookModel) -> Void)?

    @State private var quote = LiteraryQuotes.randomQuote()

    private var currentBook: BookModel? {
        currentlyReadingBooks.first ?? allBooks.first
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Welcome back"
        }
    }

    private var timeAwayFormatted: String {
        let lastActive = UserDefaults.standard.double(forKey: "returnCard.lastActiveTimestamp")
        guard lastActive > 0 else { return "—" }
        let seconds = Date().timeIntervalSince1970 - lastActive
        let hours = Int(seconds / 3600)
        let days = hours / 24
        if days > 0 { return "\(days)d" }
        else if hours > 0 { return "\(hours)h" }
        else { return "<1h" }
    }

    private var progressPercent: Double {
        guard let book = currentBook,
              let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background — matches WhatsNew/SessionSummary
                minimalGradientBackground

                ScrollView {
                    VStack(spacing: 0) {
                        // Header with book
                        headerSection
                            .padding(.top, 20)
                            .padding(.bottom, 24)

                        // Reading stats
                        metricsSection
                            .padding(.bottom, 28)

                        // Quote card
                        quoteCard
                            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                            .padding(.bottom, 28)

                        // CTA button
                        if currentBook != nil {
                            continueReadingButton
                                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                .padding(.bottom, 32)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle(greeting)
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
        }
    }

    // MARK: - Background

    private var minimalGradientBackground: some View {
        ZStack {
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Header (Book Cover + Title)

    private var headerSection: some View {
        VStack(spacing: 16) {
            if let book = currentBook {
                // Book cover
                if let coverURL = book.coverImageURL {
                    SharedBookCoverView(
                        coverURL: coverURL,
                        width: 80,
                        height: 120
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }

                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)

                    Text(book.author)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Metrics (matches session summary)

    private var metricsSection: some View {
        HStack(spacing: 24) {
            metricItem(value: "\(Int(progressPercent * 100))%", label: "PROGRESS")

            if let book = currentBook, book.pageCount != nil {
                metricItem(value: "\(book.currentPage)", label: "PAGE")
            }

            metricItem(value: timeAwayFormatted, label: "AWAY")
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
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
        }
    }

    // MARK: - Quote Card

    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("INSPIRATION")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()
            }

            Text("\u{201C}\(quote.text)\u{201D}")
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(quote.author)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .kerning(0.8)
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

    // MARK: - Continue Reading CTA

    private var continueReadingButton: some View {
        Button {
            SensoryFeedback.light()
            if let book = currentBook {
                onContinueReading?(book)
            }
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .font(.system(size: 15, weight: .medium))

                Text("Continue Reading")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(
                .regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Alias (backward compatibility)
typealias ReturnCardOverlay = WelcomeBackSheet

// MARK: - Preview
#Preview {
    Text("Library")
        .sheet(isPresented: .constant(true)) {
            WelcomeBackSheet(onContinueReading: nil)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
                .modelContainer(for: BookModel.self)
        }
}
