import SwiftUI
import SwiftData

struct ChatThreadListView: View {
    @Binding var selectedThread: ChatThread?
    @Binding var showingThreadList: Bool
    @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var showingDeleteConfirmation = false
    @State private var threadToDelete: ChatThread?
    @State private var showingBookPicker = false
    
    var body: some View {
        ZStack {
            // Show literary empty state when no book threads exist (even if general exists)
            if bookThreads.isEmpty {
                LiteraryCompanionEmptyState()
                    .ignoresSafeArea()
            } else {
                // Background for when we have book threads
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
            }
            
            VStack {
                // Only show "Chat with Epilogue" text in the center
                if threads.isEmpty {
                    Spacer()
                    
                    Text("Chat with Epilogue")
                        .font(.system(size: 36, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.95))
                    
                    Spacer()
                } else {
                    // Regular scroll view when threads exist
                    ScrollView {
                        VStack(spacing: 16) {
                            // Only show General Chat if it has messages
                            if let general = generalThread, !general.messages.isEmpty {
                                GeneralChatCard(
                                    messageCount: general.messages.count,
                                    lastMessage: general.messages.last
                                ) {
                                    selectedThread = general
                                    showingThreadList = false
                                }
                                .padding(.horizontal)
                            }
                            
                            // Book Chats Section
                            if !bookThreads.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Book Discussions")
                                        .font(.system(size: 20, weight: .medium, design: .serif))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .padding(.horizontal)
                                    
                                    ForEach(bookThreads) { thread in
                                        BookChatCard(thread: thread) {
                                            selectedThread = thread
                                            showingThreadList = false
                                        } onDelete: {
                                            threadToDelete = thread
                                            showingDeleteConfirmation = true
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("Epilogue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingBookPicker = true
                } label: {
                    Image(systemName: "book.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                onStartGeneralChat: {
                    // Create or select general thread
                    if let general = generalThread {
                        selectedThread = general
                    } else {
                        selectedThread = createGeneralThread()
                    }
                    showingThreadList = false
                },
                onSelectBook: {
                    showingBookPicker = true
                }
            )
            .padding([.horizontal], 16)
            .padding([.bottom], 8)
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(
                onBookSelected: { book in
                    // Create or select thread for this book
                    if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
                        selectedThread = existingThread
                    } else {
                        let newThread = ChatThread(book: book)
                        modelContext.insert(newThread)
                        try? modelContext.save()
                        selectedThread = newThread
                    }
                    showingThreadList = false
                    showingBookPicker = false
                }
            )
            .environmentObject(libraryViewModel)
        }
        .alert("Delete this conversation?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete {
                    deleteThread(thread)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private var generalThread: ChatThread? {
        threads.first { $0.bookId == nil }
    }
    
    private var bookThreads: [ChatThread] {
        threads.filter { $0.bookId != nil }
            .sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    
    private func createGeneralThread() -> ChatThread {
        let thread = ChatThread()
        modelContext.insert(thread)
        try? modelContext.save()
        return thread
    }
    
    private func deleteThread(_ thread: ChatThread) {
        modelContext.delete(thread)
        try? modelContext.save()
        threadToDelete = nil
    }
}

// MARK: - General Chat Card
struct GeneralChatCard: View {
    let messageCount: Int
    let lastMessage: ThreadedChatMessage?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon and title
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("General Discussion")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        
                        Text("Book recommendations & literary chat")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                // Last message preview
                if let lastMessage = lastMessage {
                    HStack {
                        Text(lastMessage.content)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(lastMessage.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.top, -8)
                }
                
                // Message count
                if messageCount > 0 {
                    HStack {
                        Text("\(messageCount) messages")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Book Chat Card
struct BookChatCard: View {
    let thread: ChatThread
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Book icon or cover
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: "book.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(thread.bookTitle ?? "Unknown Book")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let author = thread.bookAuthor, !author.isEmpty {
                        Text(author)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    if let lastMessage = thread.messages.last {
                        Text(lastMessage.content)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    
                    Text(thread.lastMessageDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Chat", systemImage: "trash")
            }
        }
    }
}

