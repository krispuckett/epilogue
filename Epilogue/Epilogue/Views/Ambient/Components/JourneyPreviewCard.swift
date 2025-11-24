import SwiftUI

struct JourneyPreviewCard: View {
    let preview: JourneyPreviewModel
    let onCreateJourney: () -> Void

    @State private var expandedBooks: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // Books
            booksSection

            // Action
            actionButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.02))
                .glassEffect()
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JOURNEY")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            Text(preview.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    // MARK: - Books

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BOOKS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.bottom, 12)

            ForEach(Array(preview.books.enumerated()), id: \.offset) { index, book in
                bookRow(book: book, index: index)

                if index < preview.books.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.05))
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func bookRow(book: JourneyBookPreview, index: Int) -> some View {
        let isExpanded = expandedBooks.contains(index)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedBooks.remove(index)
                    } else {
                        expandedBooks.insert(index)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))

                        Text("\(book.duration) • \(book.author)")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            if isExpanded {
                Text(book.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.leading, 36)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Action

    private var actionButton: some View {
        Button {
            onCreateJourney()
        } label: {
            HStack {
                Spacer()
                Text("Create Journey")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color(red: 1.0, green: 0.549, blue: 0.259))
            .cornerRadius(10)
            .foregroundStyle(.black)
        }
    }
}
