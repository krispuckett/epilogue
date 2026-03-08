import SwiftUI
import Combine
import Observation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AppState")

/// Coordinates app-wide state and sheet presentations
@MainActor
@Observable
final class AppStateCoordinator {
    // MARK: - Sheet Presentations
    var showingBookSearch = false
    var showingBatchBookSearch = false
    var showingBookScanner = false
    var showingCommandInput = false
    var showingLibraryCommandPalette = false
    var showingPrivacySettings = false
    var showingGlassToast = false
    var toastMessage = ""

    // MARK: - Book Search State
    var bookSearchQuery = ""
    var batchBookTitles: [String] = []
    var pendingBookSearch = false

    // MARK: - Command Input State
    var commandText = ""
    var isBookNoteContext = false  // Track if we're opening input for book notes

    // MARK: - Weak References to Prevent Cycles
    @ObservationIgnored weak var libraryViewModel: LibraryViewModel?
    @ObservationIgnored weak var notesViewModel: NotesViewModel?

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

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

    func openCommandInput(bookNoteContext: Bool = false) {
        logger.debug("Opening command input, bookNote: \(bookNoteContext)")
        isBookNoteContext = bookNoteContext
        showingCommandInput = true
        HapticManager.shared.commandPaletteOpen()
    }

    func dismissCommandInput() {
        logger.debug("Dismissing command input")
        showingCommandInput = false
        commandText = ""
        showingLibraryCommandPalette = false
        isBookNoteContext = false  // Reset context
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        // Show book scanner
        NotificationCenter.default.publisher(for: .showBookScanner)
            .sink { [weak self] _ in
                self?.showingBookScanner = true
                self?.dismissCommandInput()
            }
            .store(in: &cancellables)

        // Show book search
        NotificationCenter.default.publisher(for: .showBookSearch)
            .compactMap { $0.object as? String }
            .sink { [weak self] query in
                self?.handleBookSearchRequest(query: query)
            }
            .store(in: &cancellables)

        // Show batch book search
        NotificationCenter.default.publisher(for: .showBatchBookSearch)
            .compactMap { $0.object as? [String] }
            .sink { [weak self] titles in
                self?.openBatchBookSearch(with: titles)
                self?.dismissCommandInput()
            }
            .store(in: &cancellables)

        // Show command input with optional custom prompt
        NotificationCenter.default.publisher(for: .showCommandInput)
            .sink { [weak self] notification in
                var isBookNote = false
                if let data = notification.object as? [String: Any] {
                    if let prompt = data["prompt"] as? String {
                        // Custom prompt for specific context
                        self?.commandText = data["text"] as? String ?? ""
                    }
                    // Check if this is for book notes
                    isBookNote = data["bookNote"] as? Bool ?? false
                } else if let text = notification.object as? String {
                    // Simple string passed
                    self?.commandText = text
                }
                self?.openCommandInput(bookNoteContext: isBookNote)
            }
            .store(in: &cancellables)

        // Show glass toast
        NotificationCenter.default.publisher(for: .showGlassToast)
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