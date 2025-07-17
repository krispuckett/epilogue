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
    @State private var selectedThread: ChatThread?
    @State private var showingThreadList = true
    @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    
    private let bookToChat: Book?
    
    init(bookToChat: Book? = nil) {
        self.bookToChat = bookToChat
    }
    
    var body: some View {
        Group {
            if showingThreadList {
                ChatThreadListView(
                    selectedThread: $selectedThread,
                    showingThreadList: $showingThreadList
                )
            } else if let thread = selectedThread {
                ChatConversationView(
                    thread: thread,
                    showingThreadList: $showingThreadList
                )
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
            selectedThread = existingThread
            showingThreadList = false
        } else {
            // Create new thread for this book
            let newThread = ChatThread(book: book)
            modelContext.insert(newThread)
            try? modelContext.save()
            selectedThread = newThread
            showingThreadList = false
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ChatView()
    }
    .preferredColorScheme(.dark)
}