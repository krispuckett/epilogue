import SwiftUI
import SwiftData

/// UI component for switching between generic and book-specific ambient modes
struct AmbientModeSelector: View {
    @ObservedObject var coordinator: EpilogueAmbientCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Book> { book in
            book.readingStatus == .reading
        },
        sort: \Book.lastRead,
        order: .reverse
    ) private var currentlyReadingBooks: [Book]

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Current mode header (always visible)
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    modeIcon
                        .font(.system(size: 20))
                        .foregroundStyle(modeColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(modeTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(modeSubtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(modeColor.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(modeColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Mode options (when expanded)
            if isExpanded {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical, 8)

                    // Generic mode option
                    if !coordinator.currentMode.isGeneric {
                        modeOptionButton(
                            icon: "text.bubble.fill",
                            title: "Reading Companion",
                            subtitle: "General reading chat",
                            color: Color(hex: "#E8B65F"),
                            isSelected: false
                        ) {
                            switchToMode(.generic)
                        }
                    }

                    // Book-specific mode options
                    ForEach(currentlyReadingBooks, id: \.persistentModelID) { book in
                        let isSelected = coordinator.currentMode.bookID == book.persistentModelID

                        modeOptionButton(
                            icon: "book.fill",
                            title: book.title,
                            subtitle: "Page \(book.currentPage)",
                            color: .blue,
                            isSelected: isSelected
                        ) {
                            switchToMode(.bookSpecific(bookID: book.persistentModelID), book: book)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Account for safe area
    }

    // MARK: - Computed Properties

    private var modeIcon: Image {
        switch coordinator.currentMode {
        case .generic:
            return Image(systemName: "text.bubble.fill")
        case .bookSpecific:
            return Image(systemName: "book.fill")
        }
    }

    private var modeTitle: String {
        switch coordinator.currentMode {
        case .generic:
            return "Reading Companion"
        case .bookSpecific(let bookID):
            if let book = try? modelContext.existingObject(for: bookID) as? Book {
                return book.title
            }
            return "Book Mode"
        }
    }

    private var modeSubtitle: String {
        switch coordinator.currentMode {
        case .generic:
            return "General reading chat"
        case .bookSpecific(let bookID):
            if let book = try? modelContext.existingObject(for: bookID) as? Book {
                return "Page \(book.currentPage)"
            }
            return "Reading a book"
        }
    }

    private var modeColor: Color {
        switch coordinator.currentMode {
        case .generic:
            return Color(hex: "#E8B65F") // Warm amber
        case .bookSpecific:
            return .blue
        }
    }

    // MARK: - Sub-Views

    private func modeOptionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func switchToMode(_ mode: AmbientModeType, book: Book? = nil) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let book = book {
                coordinator.switchToBookMode(book: book)
            } else {
                coordinator.switchToGenericMode()
            }

            isExpanded = false
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
