import SwiftUI
import SwiftData

/// Sheet for selecting books to add to an existing reading journey
struct BookSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let journey: ReadingJourney
    let manager: ReadingJourneyManager

    @Query(
        filter: #Predicate<BookModel> { $0.isInLibrary && $0.readingStatus != "Read" },
        sort: \BookModel.dateAdded
    )
    private var libraryBooks: [BookModel]

    @State private var selectedBooks: Set<String> = []

    // Books not already in the journey
    private var availableBooks: [BookModel] {
        let journeyBookIDs = Set((journey.books ?? []).compactMap { $0.bookModel?.id })

        // Deduplicate and filter out books already in journey
        var seen = Set<String>()
        return libraryBooks.filter { book in
            // Skip if already in journey
            guard !journeyBookIDs.contains(book.id) else { return false }

            // Skip duplicates
            if seen.contains(book.id) {
                return false
            } else {
                seen.insert(book.id)
                return true
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Minimal gradient background
                minimalGradientBackground

                VStack(spacing: 0) {
                    if availableBooks.isEmpty {
                        emptyState
                    } else {
                        booksList

                        // Add to Journey button
                        addBooksButton
                    }
                }
            }
            .navigationTitle("Add Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Components

    private var minimalGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.1),
                Color(red: 0.04, green: 0.04, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var booksList: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Select books to add to your journey")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                ForEach(availableBooks) { book in
                    BookSelectionRow(
                        book: book,
                        isSelected: selectedBooks.contains(book.id),
                        onToggle: { toggleBookSelection(book) }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.bottom, 100) // Space for button
        }
    }

    private var addBooksButton: some View {
        VStack(spacing: 0) {
            // Gradient fade at top of button area
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.08).opacity(0),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            Button(action: addSelectedBooks) {
                Text("Add \(selectedBooks.count) Book\(selectedBooks.count == 1 ? "" : "s")")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .glassEffect(.regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.3)), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent.opacity(0.5),
                                DesignSystem.Colors.primaryAccent.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.2), radius: 8, y: 4)
            .buttonStyle(.plain)
            .disabled(selectedBooks.isEmpty)
            .opacity(selectedBooks.isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.bottom, 20)
            .background(
                Color(red: 0.04, green: 0.04, blue: 0.08)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("No Books Available")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("All your library books are already in this journey or marked as read.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func toggleBookSelection(_ book: BookModel) {
        if selectedBooks.contains(book.id) {
            selectedBooks.remove(book.id)
        } else {
            selectedBooks.insert(book.id)
        }
    }

    private func addSelectedBooks() {
        let booksToAdd = availableBooks.filter { selectedBooks.contains($0.id) }
        manager.addBooksToJourney(booksToAdd, to: journey)
        dismiss()
    }
}
