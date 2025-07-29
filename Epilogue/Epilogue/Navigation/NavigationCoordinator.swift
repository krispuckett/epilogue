import SwiftUI
import Combine

// MARK: - Navigation Coordinator

@MainActor
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    // Tab selection
    @Published var selectedTab: TabItem = .library
    
    // Deep linking IDs
    @Published var highlightedNoteID: UUID?
    @Published var highlightedQuoteID: UUID?
    @Published var scrollToBookID: String?
    
    // Navigation flags
    @Published var shouldNavigateToNotes = false
    @Published var shouldNavigateToLibrary = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Tab Items
    
    enum TabItem: String, CaseIterable {
        case library = "Library"
        case notes = "Notes"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .notes: return "note.text"
            case .chat: return "bubble.left.and.bubble.right"
            }
        }
    }
    
    // MARK: - Navigation Methods
    
    func navigateToNote(_ note: Note) {
        print("[NavigationCoordinator] Navigating to note: \(note.id)")
        highlightedNoteID = note.id
        selectedTab = .notes
        shouldNavigateToNotes = true
    }
    
    func navigateToQuote(_ quote: Quote) {
        print("[NavigationCoordinator] Navigating to quote: \(quote.id)")
        highlightedQuoteID = quote.id
        selectedTab = .notes
        shouldNavigateToNotes = true
    }
    
    func navigateToBook(_ bookID: String) {
        print("[NavigationCoordinator] Navigating to book: \(bookID)")
        scrollToBookID = bookID
        selectedTab = .library
        shouldNavigateToLibrary = true
    }
    
    func navigateToChat(with book: Book? = nil) {
        print("[NavigationCoordinator] Navigating to chat with book: \(book?.title ?? "none")")
        selectedTab = .chat
        // Book context will be handled by chat view
    }
    
    // MARK: - Clear Navigation State
    
    func clearNavigationState() {
        highlightedNoteID = nil
        highlightedQuoteID = nil
        scrollToBookID = nil
        shouldNavigateToNotes = false
        shouldNavigateToLibrary = false
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Navigate to note
        NotificationCenter.default.publisher(for: .navigateToNote)
            .compactMap { $0.object as? Note }
            .sink { [weak self] note in
                self?.navigateToNote(note)
            }
            .store(in: &cancellables)
        
        // Navigate to quote
        NotificationCenter.default.publisher(for: .navigateToQuote)
            .compactMap { $0.object as? Quote }
            .sink { [weak self] quote in
                self?.navigateToQuote(quote)
            }
            .store(in: &cancellables)
        
        // Navigate to book
        NotificationCenter.default.publisher(for: .navigateToBook)
            .compactMap { $0.object as? String }
            .sink { [weak self] bookID in
                self?.navigateToBook(bookID)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let navigateToBook = Notification.Name("navigateToBook")
}