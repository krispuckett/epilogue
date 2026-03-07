import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AppStateManager")

// MARK: - App-wide State Manager
@MainActor
@Observable
final class AppStateManager {
    static let shared = AppStateManager()

    // Global sheet presentations
    var showingBookSearch = false
    var showingGoodreadsImport = false
    var showingEnhancedScanner = false
    var showingSettings = false

    // Selected book for actions
    var selectedBook: Book?

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

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