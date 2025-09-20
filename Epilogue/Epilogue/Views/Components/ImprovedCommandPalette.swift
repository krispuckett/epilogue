import SwiftUI

// MARK: - Improved Command Palette with Glass Cards
struct ImprovedCommandPalette: View {
    @Binding var isPresented: Bool
    @Binding var commandText: String
    @State private var searchText = ""
    @State private var selectedCategory: CommandCategory = .all
    @FocusState private var isSearchFocused: Bool

    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel

    // Command categories for better organization
    enum CommandCategory: String, CaseIterable {
        case all = "All"
        case books = "Books"
        case notes = "Notes"
        case reading = "Reading"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .books: return "books.vertical"
            case .notes: return "note.text"
            case .reading: return "book.circle"
            }
        }
    }

    // Enhanced command structure
    struct Command: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let category: CommandCategory
        let color: Color
        let action: CommandAction

        enum CommandAction {
            case scanBook
            case searchBooks
            case importGoodreads
            case createNote
            case createQuote
            case searchNotes
            case startReading
            case viewTimeline
            case exportLibrary
        }
    }

    // All available commands
    let allCommands = [
        // Book commands
        Command(
            icon: "camera.viewfinder",
            title: "Scan Book Cover",
            description: "Use Visual Intelligence or ISBN",
            category: .books,
            color: DesignSystem.Colors.primaryAccent,
            action: .scanBook
        ),
        Command(
            icon: "magnifyingglass",
            title: "Search Books",
            description: "Find books to add to library",
            category: .books,
            color: DesignSystem.Colors.primaryAccent,
            action: .searchBooks
        ),
        Command(
            icon: "square.and.arrow.down",
            title: "Import Library",
            description: "Import from Goodreads CSV",
            category: .books,
            color: DesignSystem.Colors.primaryAccent,
            action: .importGoodreads
        ),

        // Note commands
        Command(
            icon: "note.text",
            title: "Create Note",
            description: "Capture thoughts and ideas",
            category: .notes,
            color: Color.blue,
            action: .createNote
        ),
        Command(
            icon: "quote.bubble",
            title: "Save Quote",
            description: "Remember important passages",
            category: .notes,
            color: Color.blue,
            action: .createQuote
        ),
        Command(
            icon: "doc.text.magnifyingglass",
            title: "Search Notes",
            description: "Find your notes and quotes",
            category: .notes,
            color: Color.blue,
            action: .searchNotes
        ),

        // Reading commands
        Command(
            icon: "book.circle",
            title: "Start Reading",
            description: "Begin ambient reading mode",
            category: .reading,
            color: Color.purple,
            action: .startReading
        ),
        Command(
            icon: "chart.line.uptrend.xyaxis",
            title: "Reading Timeline",
            description: "View your reading progress",
            category: .reading,
            color: Color.purple,
            action: .viewTimeline
        ),
        Command(
            icon: "square.and.arrow.up",
            title: "Export Library",
            description: "Export your library data",
            category: .reading,
            color: Color.purple,
            action: .exportLibrary
        )
    ]

    private var filteredCommands: [Command] {
        let categoryFiltered = selectedCategory == .all
            ? allCommands
            : allCommands.filter { $0.category == selectedCategory }

        if searchText.isEmpty {
            return categoryFiltered
        }

        return categoryFiltered.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 16) {
                // Drag handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                // Search bar with glass effect
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)

                    TextField("What would you like to do?", text: $searchText)
                        .font(.system(size: 16))
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

                // Category filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CommandCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.interactiveSpring(response: 0.3)) {
                                    selectedCategory = category
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Commands grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredCommands) { command in
                        CommandCard(command: command) {
                            handleCommandSelection(command)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 400)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground {
            Color.clear.glassEffect()
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Category Chip
    private struct CategoryChip: View {
        let category: CommandCategory
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.system(size: 14))

                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(isSelected ? .white : Color.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        DesignSystem.Colors.primaryAccent
                            .opacity(0.2)
                    }
                }
                .glassEffect(.regular, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected ? DesignSystem.Colors.primaryAccent.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Command Card (Rectangular Glass)
    private struct CommandCard: View {
        let command: Command
        let action: () -> Void

        @State private var isPressed = false

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    // Icon and title
                    HStack(spacing: 12) {
                        // Icon with colored background
                        Image(systemName: command.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(command.color)
                            .frame(width: 36, height: 36)
                            .background {
                                command.color.opacity(0.15)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Spacer()

                        // Arrow indicator
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }

                    // Text content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(command.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Text(command.description)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 110)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
                .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(.interactiveSpring(response: 0.3)) {
                        isPressed = pressing
                    }
                },
                perform: {}
            )
        }
    }

    // MARK: - Actions
    private func handleCommandSelection(_ command: Command) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Dismiss first for smooth transition
        dismiss()

        // Execute action after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch command.action {
            case .scanBook:
                NotificationCenter.default.post(name: Notification.Name("ShowEnhancedBookScanner"), object: nil)

            case .searchBooks:
                NotificationCenter.default.post(name: Notification.Name("ShowBookSearch"), object: nil)

            case .importGoodreads:
                NotificationCenter.default.post(name: Notification.Name("ShowGoodreadsImport"), object: nil)

            case .createNote:
                NotificationCenter.default.post(name: Notification.Name("CreateNewNote"), object: nil)

            case .createQuote:
                NotificationCenter.default.post(name: Notification.Name("ShowQuoteCapture"), object: nil)

            case .searchNotes:
                NotificationCenter.default.post(name: Notification.Name("SearchNotes"), object: nil)

            case .startReading:
                if let currentBook = libraryViewModel.currentDetailBook {
                    SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
                } else {
                    SimplifiedAmbientCoordinator.shared.openAmbientReading()
                }

            case .viewTimeline:
                NotificationCenter.default.post(name: Notification.Name("ShowReadingTimeline"), object: nil)

            case .exportLibrary:
                NotificationCenter.default.post(name: Notification.Name("ExportLibrary"), object: nil)
            }
        }
    }

    private func dismiss() {
        withAnimation(.interactiveSpring(response: 0.3)) {
            isPresented = false
        }
    }
}