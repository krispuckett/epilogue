import SwiftUI
import SwiftData

// MARK: - Chat Message Model (for legacy compatibility)
struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
    var isNew: Bool = true
}

// MARK: - Chat View
struct ChatView: View {
    @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    
    private let bookToChat: Book?
    
    init(bookToChat: Book? = nil) {
        self.bookToChat = bookToChat
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ChatThreadListView(navigationPath: $navigationPath)
                .navigationDestination(for: ChatThread.self) { thread in
                    ChatConversationView(thread: thread)
                }
        }
        .onAppear {
            // If we have a book to chat about, find or create its thread
            if let book = bookToChat {
                findOrCreateThreadForBook(book)
            }
        }
    }
    
    private func findOrCreateThreadForBook(_ book: Book) {
        // Check if thread already exists for this book
        if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
            navigationPath.append(existingThread)
        } else {
            // Create new thread for this book
            let newThread = ChatThread(book: book)
            modelContext.insert(newThread)
            try? modelContext.save()
            navigationPath.append(newThread)
        }
    }
}

// MARK: - Preview
#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}