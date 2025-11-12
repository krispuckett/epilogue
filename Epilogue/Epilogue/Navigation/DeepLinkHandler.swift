import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "DeepLink")

/// Handles deep linking and notification-based navigation
@MainActor
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    @Published var highlightedBookId: UUID?
    @Published var scrollToBookId: UUID?

    weak var navigationCoordinator: NavigationCoordinator?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationObservers()
    }

    deinit {
        logger.debug("DeepLinkHandler deallocated")
        cancellables.removeAll()
    }

    // MARK: - Public Methods

    func handle(url: URL) {
        handleURL(url)
    }

    func handleURL(_ url: URL) {
        logger.info("Handling URL: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Failed to parse URL components")
            return
        }

        switch components.host {
        case "book":
            handleBookDeepLink(components)
        case "note":
            handleNoteDeepLink(components)
        case "quote":
            handleQuoteDeepLink(components)
        case "chat":
            handleChatDeepLink(components)
        case "continueReading":
            handleContinueReading()
        default:
            logger.warning("Unknown deep link host: \(components.host ?? "nil")")
        }
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Navigate to book
        NotificationCenter.default.publisher(for: Notification.Name("NavigateToBook"))
            .sink { [weak self] notification in
                if let book = notification.object as? Book {
                    self?.navigateToBook(book)
                } else if let bookId = notification.object as? String {
                    self?.navigateToBookById(bookId)
                }
            }
            .store(in: &cancellables)

        // Navigate to note
        NotificationCenter.default.publisher(for: Notification.Name("NavigateToNote"))
            .compactMap { $0.object as? Note }
            .sink { [weak self] note in
                self?.navigateToNote(note)
            }
            .store(in: &cancellables)

        // Navigate to tab
        NotificationCenter.default.publisher(for: Notification.Name("NavigateToTab"))
            .compactMap { $0.object as? Int }
            .sink { [weak self] tabIndex in
                self?.navigateToTab(tabIndex)
            }
            .store(in: &cancellables)

        // Share quote
        NotificationCenter.default.publisher(for: Notification.Name("ShareQuote"))
            .compactMap { $0.object as? Note }
            .sink { quote in
                ShareQuoteService.shareQuote(quote)
            }
            .store(in: &cancellables)

        // Voice note
        NotificationCenter.default.publisher(for: Notification.Name("StartVoiceNote"))
            .sink { _ in
                HapticManager.shared.voiceModeStart()
                // Voice note handling would go here
            }
            .store(in: &cancellables)
    }

    private func handleBookDeepLink(_ components: URLComponents) {
        guard let bookId = components.queryItems?.first(where: { $0.name == "id" })?.value else {
            logger.error("Book deep link missing id parameter")
            return
        }
        navigateToBookById(bookId)
    }

    private func handleNoteDeepLink(_ components: URLComponents) {
        guard let noteId = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let uuid = UUID(uuidString: noteId) else {
            logger.error("Note deep link missing or invalid id parameter")
            return
        }
        navigationCoordinator?.highlightedNoteID = uuid
        navigationCoordinator?.selectedTab = .notes
    }

    private func handleQuoteDeepLink(_ components: URLComponents) {
        guard let quoteId = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let uuid = UUID(uuidString: quoteId) else {
            logger.error("Quote deep link missing or invalid id parameter")
            return
        }
        navigationCoordinator?.highlightedQuoteID = uuid
        navigationCoordinator?.selectedTab = .notes
    }

    private func handleChatDeepLink(_ components: URLComponents) {
        navigationCoordinator?.selectedTab = .chat

        if let bookId = components.queryItems?.first(where: { $0.name == "book" })?.value {
            logger.debug("Opening chat with book context: \(bookId)")
            // Book context would be handled by chat view
        }
    }

    private func navigateToBook(_ book: Book) {
        logger.debug("Navigating to book: \(book.title)")
        highlightedBookId = book.localId
        navigationCoordinator?.selectedTab = .library
    }

    private func navigateToBookById(_ bookId: String) {
        logger.debug("Navigating to book by ID: \(bookId)")
        navigationCoordinator?.scrollToBookID = bookId
        navigationCoordinator?.selectedTab = .library
    }

    private func navigateToNote(_ note: Note) {
        logger.debug("Navigating to note: \(note.id)")
        navigationCoordinator?.selectedTab = .notes
    }

    private func navigateToTab(_ index: Int) {
        logger.debug("Navigating to tab: \(index)")
        switch index {
        case 0: navigationCoordinator?.selectedTab = .library
        case 1: navigationCoordinator?.selectedTab = .notes
        case 2: navigationCoordinator?.selectedTab = .chat
        default: logger.warning("Invalid tab index: \(index)")
        }
    }

    private func handleContinueReading() {
        logger.info("🎯 Widget tapped: Continue Reading")

        // Load currently reading book from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data),
              let currentBook = books.first(where: { $0.readingStatus == .currentlyReading }) else {
            logger.warning("No currently reading book found")
            return
        }

        logger.info("📚 Opening Ambient Mode with: \(currentBook.title)")

        // Post notification to trigger ambient mode (same as Siri intent)
        NotificationCenter.default.post(
            name: Notification.Name("OpenAmbientModeFromIntent"),
            object: currentBook.id,
            userInfo: [
                "bookId": currentBook.id,
                "bookTitle": currentBook.title
            ]
        )
    }
}