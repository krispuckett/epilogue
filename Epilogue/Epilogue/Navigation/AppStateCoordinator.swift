import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AppState")

/// Coordinates app-wide state and sheet presentations
@MainActor
final class AppStateCoordinator: ObservableObject {
    // MARK: - Sheet Presentations
    @Published var showingBookSearch = false
    @Published var showingBatchBookSearch = false
    @Published var showingBookScanner = false
    @Published var showingCommandInput = false
    @Published var showingLibraryCommandPalette = false
    @Published var showingPrivacySettings = false
    @Published var showingGlassToast = false
    @Published var toastMessage = ""

    // MARK: - Book Search State
    @Published var bookSearchQuery = ""
    @Published var batchBookTitles: [String] = []
    @Published var pendingBookSearch = false

    // MARK: - Command Input State
    @Published var commandText = ""

    // MARK: - Weak References to Prevent Cycles
    weak var libraryViewModel: LibraryViewModel?
    weak var notesViewModel: NotesViewModel?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNotificationObservers()
    }

    deinit {
        logger.debug("AppStateCoordinator deallocated")
        cancellables.removeAll()
    }

    // MARK: - Public Methods

    func showToast(_ message: String) {
        logger.debug("Showing toast: \(message)")
        toastMessage = message
        showingGlassToast = true
    }

    func openBookSearch(with query: String? = nil) {
        logger.debug("Opening book search with query: \(query ?? "none")")
        if let query = query {
            bookSearchQuery = query
        }
        showingBookSearch = true
    }

    func openBatchBookSearch(with titles: [String]) {
        logger.debug("Opening batch book search with \(titles.count) titles")
        batchBookTitles = titles
        showingBatchBookSearch = true
        showToast("Adding \(titles.count) books to library...")
    }

    func openCommandInput() {
        logger.debug("Opening command input")
        showingCommandInput = true
        HapticManager.shared.commandPaletteOpen()
    }

    func dismissCommandInput() {
        logger.debug("Dismissing command input")
        showingCommandInput = false
        commandText = ""
        showingLibraryCommandPalette = false
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Show book scanner
        NotificationCenter.default.publisher(for: Notification.Name("ShowBookScanner"))
            .sink { [weak self] _ in
                self?.showingBookScanner = true
                self?.dismissCommandInput()
            }
            .store(in: &cancellables)

        // Show book search
        NotificationCenter.default.publisher(for: Notification.Name("ShowBookSearch"))
            .compactMap { $0.object as? String }
            .sink { [weak self] query in
                self?.handleBookSearchRequest(query: query)
            }
            .store(in: &cancellables)

        // Show batch book search
        NotificationCenter.default.publisher(for: Notification.Name("ShowBatchBookSearch"))
            .compactMap { $0.object as? [String] }
            .sink { [weak self] titles in
                self?.openBatchBookSearch(with: titles)
                self?.dismissCommandInput()
            }
            .store(in: &cancellables)

        // Show command input
        NotificationCenter.default.publisher(for: Notification.Name("ShowCommandInput"))
            .sink { [weak self] _ in
                self?.openCommandInput()
            }
            .store(in: &cancellables)

        // Show glass toast
        NotificationCenter.default.publisher(for: Notification.Name("ShowGlassToast"))
            .compactMap { $0.object as? [String: Any] }
            .compactMap { $0["message"] as? String }
            .sink { [weak self] message in
                self?.showToast(message)
            }
            .store(in: &cancellables)
    }

    private func handleBookSearchRequest(query: String) {
        logger.debug("Handling book search request: '\(query)'")

        guard !showingBookSearch && !pendingBookSearch else {
            logger.warning("Book search already showing or pending")
            return
        }

        bookSearchQuery = query
        pendingBookSearch = true

        // Dismiss command input with animation
        withAnimation(DesignSystem.Animation.springStandard) {
            dismissCommandInput()
        }

        // Delay to allow animation to complete
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if pendingBookSearch && !bookSearchQuery.isEmpty && !showingBookSearch {
                logger.debug("Opening book search sheet")
                pendingBookSearch = false
                showingBookSearch = true
            }
        }
    }
}