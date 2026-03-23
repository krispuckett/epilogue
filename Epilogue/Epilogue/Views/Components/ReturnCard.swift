import SwiftUI
import SwiftData

// MARK: - Welcome Back Sheet (Half-sheet, book-aware fluid gradient)
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

    @Query(
        sort: [SortDescriptor(\ReadingSession.startDate, order: .reverse)]
    ) private var recentSessions: [ReadingSession]

    /// Optional: pass a specific book (e.g. from BookDetailView).
    /// When nil, falls back to @Query (currently reading / most recent).
    let specificBook: BookModel?
    let onContinueReading: ((BookModel) -> Void)?

    @State private var quote = LiteraryQuotes.randomQuote()

    // Fluid gradient state
    @State private var fluidColorSet = FluidLabColorSet.fallback
    @State private var fluidConfig = FluidAmbientConfig.golden

    init(book: BookModel? = nil, onContinueReading: ((BookModel) -> Void)? = nil) {
        self.specificBook = book
        self.onContinueReading = onContinueReading
    }

    private var currentBook: BookModel? {
        specificBook ?? currentlyReadingBooks.first ?? allBooks.first
    }

    private var lastSession: ReadingSession? {
        guard let book = currentBook else { return nil }
        return recentSessions.first(where: { $0.bookModel?.id == book.id })
    }

    private var timeAwayText: String {
        let lastActive = UserDefaults.standard.double(forKey: "returnCard.lastActiveTimestamp")
        guard lastActive > 0 else { return "a while" }
        let seconds = Date().timeIntervalSince1970 - lastActive
        let hours = Int(seconds / 3600)
        let days = hours / 24
        let weeks = days / 7
        if weeks > 0 { return "\(weeks) week\(weeks == 1 ? "" : "s")" }
        else if days > 0 { return "\(days) day\(days == 1 ? "" : "s")" }
        else if hours > 0 { return "\(hours) hour\(hours == 1 ? "" : "s")" }
        else { return "< 1 hour" }
    }

    private var lastSessionDuration: String? {
        guard let session = lastSession else { return nil }
        let minutes = Int(session.duration / 60)
        if minutes < 1 { return "< 1 min" }
        return "\(minutes) min"
    }

    private var progressPercent: Double {
        guard let book = currentBook,
              let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }

    private var coverImage: UIImage? {
        guard let book = currentBook,
              let data = book.coverImageData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Book-aware fluid gradient background
                FluidAmbientGradientView(
                    colorSet: fluidColorSet,
                    config: $fluidConfig
                )
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
                .id(currentBook?.id)

                // Content
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Centered content
                    VStack(spacing: 12) {
                        // Book cover
                        if let image = coverImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                        }

                        // Title + author
                        if let book = currentBook {
                            VStack(spacing: 6) {
                                Text(book.title)
                                    .font(.system(size: 22, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text("by \(book.author)")
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .kerning(1.2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        // Stats row — contextual, centered
                        HStack(spacing: 32) {
                            if let book = currentBook, let total = book.pageCount, total > 0, book.currentPage > 0 {
                                VStack(spacing: 2) {
                                    Text("\(Int(progressPercent * 100))%")
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("COMPLETE")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .tracking(1)
                                }
                            }

                            if let duration = lastSessionDuration {
                                VStack(spacing: 2) {
                                    Text(duration)
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("LAST SESSION")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .tracking(1)
                                }
                            }

                            if let book = currentBook, let total = book.pageCount, total > 0, book.currentPage > 0 {
                                VStack(spacing: 2) {
                                    Text("\(total - book.currentPage)")
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("PAGES LEFT")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                        .tracking(1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Quote
                        VStack(spacing: 6) {
                            Text("\u{201C}\(quote.text)\u{201D}")
                                .font(.custom("Georgia", size: 15))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                            Text("— \(quote.author)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)

                    // Continue reading — glass button, bottom-pinned
                    if currentBook != nil {
                        Button {
                            SensoryFeedback.light()
                            if let book = currentBook {
                                onContinueReading?(book)
                            }
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                Text("Continue reading")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .capsule)
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Welcome Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await extractBookColors()
            }
        }
    }

    // MARK: - Color Extraction

    private func extractBookColors() async {
        guard let book = currentBook else { return }
        let bookID = book.localId

        // Try AtmosphereEngine first (cached DisplayPalette)
        if AtmosphereEngine.isEnabled {
            // Try from cover URL
            if let coverURL = book.coverImageURL,
               let dp = await AtmosphereEngine.shared.extractDisplayPalette(
                   bookID: bookID,
                   coverURL: coverURL
               ) {
                await MainActor.run {
                    fluidColorSet = FluidLabColorSet.from(dp)
                    var config = FluidAmbientConfig(for: dp.coverType)
                    config.darkFadeStart = 0.600       // Fill the half-sheet with color
                    config.vignetteStrength = 0.3       // Softer edge darkening for small sheet
                    config.fadeExponent = 0.537
                    fluidConfig = config
                }
                return
            }

            // Try from cover image data
            if let image = coverImage,
               let dp = await AtmosphereEngine.shared.extractDisplayPalette(
                   from: image,
                   bookID: bookID
               ) {
                await MainActor.run {
                    fluidColorSet = FluidLabColorSet.from(dp)
                    var config = FluidAmbientConfig(for: dp.coverType)
                    config.darkFadeStart = 0.600
                    config.vignetteStrength = 0.3
                    config.fadeExponent = 0.537
                    fluidConfig = config
                }
                return
            }
        }

        // Fallback: cached ColorPalette
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                fluidColorSet = FluidLabColorSet.from(cachedPalette)
                fluidConfig.darkFadeStart = 0.600
                fluidConfig.vignetteStrength = 0.3
                fluidConfig.fadeExponent = 0.537
            }
        }
    }
}

// MARK: - Legacy Alias
typealias ReturnCardOverlay = WelcomeBackSheet

// MARK: - Preview
#Preview {
    Text("Library")
        .sheet(isPresented: .constant(true)) {
            WelcomeBackSheet(onContinueReading: nil)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .modelContainer(for: BookModel.self)
        }
}
