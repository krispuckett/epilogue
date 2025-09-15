import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AppStateManager")

// MARK: - App-wide State Manager
@MainActor
final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    // Global sheet presentations
    @Published var showingBookSearch = false
    @Published var showingGoodreadsImport = false
    @Published var showingEnhancedScanner = false
    @Published var showingSettings = false

    // Selected book for actions
    @Published var selectedBook: Book?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        logger.debug("AppStateManager initialized")
    }

    deinit {
        logger.debug("AppStateManager deallocated")
        cancellables.removeAll()
    }
    
    // MARK: - Actions
    func openBookSearch() {
        showingBookSearch = true
    }
    
    func openGoodreadsImport() {
        showingGoodreadsImport = true
    }
    
    func openScanner() {
        showingEnhancedScanner = true
    }
    
    func openSettings() {
        showingSettings = true
    }
}