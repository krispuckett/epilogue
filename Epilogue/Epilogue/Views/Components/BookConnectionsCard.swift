import SwiftUI
import SwiftData

// MARK: - Book Connections Card
/// Shows thematic connections between the current book and other books in the library.
/// Uses the knowledge graph to find shared themes, characters, and concepts.

struct BookConnectionsCard: View {
    let book: Book
    let bookModel: BookModel?
    let accentColor: Color
    let textColor: Color

    @State private var connections: [BookConnection] = []
    @State private var isLoading = true
    @State private var sharedThemes: [String] = []

    var body: some View {
        Group {
            if !connections.isEmpty || !sharedThemes.isEmpty {
                connectionContent
            } else if isLoading {
                loadingState
            }
            // Empty state - don't show the card at all if no connections
        }
        .task {
            await loadConnections()
        }
    }

    @ViewBuilder
    private var connectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                    .frame(width: 28, height: 28)

                Text("Connected Books")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)

                Spacer()

                if !sharedThemes.isEmpty {
                    Text("\(sharedThemes.count) shared themes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.5))
                }
            }

            // Shared themes
            if !sharedThemes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sharedThemes.prefix(5), id: \.self) { theme in
                            HStack(spacing: 4) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10))
                                Text(theme)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Connected books
            if !connections.isEmpty {
                VStack(spacing: 12) {
                    ForEach(connections.prefix(3)) { connection in
                        ConnectionRow(
                            connection: connection,
                            accentColor: accentColor,
                            textColor: textColor
                        )
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(accentColor.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
    }

    private var loadingState: some View {
        HStack {
            ProgressView()
                .tint(accentColor)
            Text("Finding connections...")
                .font(.system(size: 14))
                .foregroundColor(textColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @MainActor
    private func loadConnections() async {
        isLoading = true
        defer { isLoading = false }

        let graphService = KnowledgeGraphService.shared

        // Find themes for this book
        guard let bookModel = bookModel else { return }

        do {
            // Get themes from the knowledge graph
            let allThemes = try graphService.getTopThemes(limit: 20)
            let bookThemes = allThemes.filter { theme in
                theme.sourceBooks.contains { $0.id == bookModel.id }
            }

            // Find books that share themes
            var connectedBooks: [String: (book: BookModel, themes: [String])] = [:]

            for theme in bookThemes {
                for relatedBook in theme.sourceBooks {
                    guard relatedBook.id != bookModel.id else { continue }

                    let bookIdString = relatedBook.id
                    if var existing = connectedBooks[bookIdString] {
                        existing.themes.append(theme.label)
                        connectedBooks[bookIdString] = existing
                    } else {
                        connectedBooks[bookIdString] = (relatedBook, [theme.label])
                    }
                }
            }

            // Sort by number of shared themes
            let sortedConnections = connectedBooks.values
                .sorted { $0.themes.count > $1.themes.count }
                .prefix(5)
                .map { BookConnection(
                    bookTitle: $0.book.title,
                    author: $0.book.author,
                    sharedThemes: $0.themes,
                    coverURL: $0.book.coverImageURL
                )}

            connections = Array(sortedConnections)

            // Get unique shared themes
            let allSharedThemes = Set(sortedConnections.flatMap { $0.sharedThemes })
            sharedThemes = Array(allSharedThemes).sorted()

        } catch {
            // Silent failure - just don't show connections
            connections = []
        }
    }
}

// MARK: - Book Connection Model

struct BookConnection: Identifiable {
    let id = UUID()
    let bookTitle: String
    let author: String
    let sharedThemes: [String]
    let coverURL: String?
}

// MARK: - Connection Row

struct ConnectionRow: View {
    let connection: BookConnection
    let accentColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Small cover thumbnail
            if let urlString = connection.coverURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Rectangle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 14))
                            .foregroundColor(accentColor.opacity(0.5))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(connection.bookTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Text(connection.author)
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.6))
                    .lineLimit(1)

                // Shared themes
                Text(connection.sharedThemes.prefix(2).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundColor(accentColor.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            // Connection strength indicator
            HStack(spacing: 2) {
                ForEach(0..<min(3, connection.sharedThemes.count), id: \.self) { _ in
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)
                }
                ForEach(0..<max(0, 3 - connection.sharedThemes.count), id: \.self) { _ in
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(10)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue, .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        BookConnectionsCard(
            book: Book(
                id: "preview-id",
                title: "The Great Gatsby",
                author: "F. Scott Fitzgerald"
            ),
            bookModel: nil,
            accentColor: .orange,
            textColor: .white
        )
        .padding(20)
    }
}
