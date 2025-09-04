import SwiftUI
import Combine

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
    
    private init() {}
    
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