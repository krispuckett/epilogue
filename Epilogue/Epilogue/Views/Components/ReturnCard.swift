import SwiftUI
import SwiftData

// MARK: - Welcome Back Sheet (Half-sheet, dense data layout)
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

    // Last reading session for "where you left off"
    @Query(
        sort: [SortDescriptor(\ReadingSession.startDate, order: .reverse)]
    ) private var recentSessions: [ReadingSession]

    let onContinueReading: ((BookModel) -> Void)?

    @State private var quote = LiteraryQuotes.randomQuote()

    private var currentBook: BookModel? {
        currentlyReadingBooks.first ?? allBooks.first
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

    private var lastSessionDate: String? {
        guard let session = lastSession else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: session.startDate)
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

    var body: some View {
        VStack(spacing: 0) {
                // Title row
                HStack {
                    Text("Welcome back")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 4)

                // Subtitle — time away + book name
                if let book = currentBook {
                    HStack {
                        Text("It's been \(timeAwayText) since your last session with ")
                            .foregroundStyle(.white.opacity(0.6))
                        + Text(book.title)
                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                            .bold()
                    }
                    .font(.system(size: 14))
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // WHERE YOU LEFT OFF section
                if lastSession != nil || currentBook != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHERE YOU LEFT OFF")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(1.5)

                        HStack(spacing: 16) {
                            if let date = lastSessionDate {
                                HStack(spacing: 5) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text(date)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }

                            if let duration = lastSessionDuration {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text(duration)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }

                            if let book = currentBook, let total = book.pageCount, total > 0 {
                                HStack(spacing: 5) {
                                    Image(systemName: "book")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                    Text("p. \(book.currentPage) of \(total)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }

                        // Progress bar
                        if let book = currentBook, let total = book.pageCount, total > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.6))
                                        .frame(width: geo.size.width * progressPercent)
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                // Quote card (compact)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{201C}\(quote.text)\u{201D}")
                        .font(.custom("Georgia", size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(4)
                        .lineLimit(3)

                    Text("— \(quote.author)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // CTA — prominent, full-width
                if currentBook != nil {
                    Button {
                        SensoryFeedback.light()
                        if let book = currentBook {
                            onContinueReading?(book)
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Continue reading")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignSystem.Colors.primaryAccent.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Secondary actions
                    HStack(spacing: 0) {
                        Button {
                            SensoryFeedback.light()
                            dismiss()
                        } label: {
                            Text("Dismiss")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
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
