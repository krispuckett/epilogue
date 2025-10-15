import SwiftUI
import SwiftData
import CoreImage
import CoreImage.CIFilterBuiltins

struct ChatThreadListView: View {
    @Query private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var showingDeleteConfirmation = false
    @State private var threadToDelete: ChatThread?
    @State private var showingBookPicker = false
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ZStack {
            // ALWAYS show the background, not conditionally
            backgroundView
            
            // Content layer
            contentView
        }
        .navigationTitle("Epilogue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                onStartGeneralChat: {
                    // Don't auto-navigate, just focus the input
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
                    handleBookSelection(book)
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
    
    // MARK: - Background View (ALWAYS visible)
    @ViewBuilder
    private var backgroundView: some View {
        // Base midnight color
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea()
        
        // Show literary background when no book threads
        if bookThreads.isEmpty {
            MetalLiteraryView()
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))
        }
        
        // Subtle vignette overlay
        RadialGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.15)
            ]),
            center: .center,
            startRadius: 200,
            endRadius: 400
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if threads.isEmpty {
            // Empty state
            VStack {
                Spacer()
                
                Text("Chat with Epilogue")
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.95))
                
                Spacer()
            }
        } else {
            // Thread list
            ScrollView {
                VStack(spacing: 16) {
                    // General chat (if has messages)
                    if let general = generalThread, !general.messages.isEmpty {
                        NavigationLink(value: general) {
                            GeneralChatCard(
                                messageCount: general.messages.count,
                                lastMessage: general.messages.last
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                    
                    // Book discussions
                    if !bookThreads.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Book Discussions")
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal)
                            
                            ForEach(bookThreads) { thread in
                                NavigationLink(value: thread) {
                                    BookChatCard(
                                        thread: thread,
                                        onDelete: {
                                            threadToDelete = thread
                                            showingDeleteConfirmation = true
                                        }
                                    )
                                    .environmentObject(libraryViewModel)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
    }
    
    // MARK: - Helper Properties
    private var generalThread: ChatThread? {
        threads.first { $0.bookId == nil }
    }
    
    private var bookThreads: [ChatThread] {
        threads.filter { $0.bookId != nil }
            .sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    
    // MARK: - Helper Methods
    private func handleBookSelection(_ book: Book) {
        #if DEBUG
        print("Selected book: \(book.title)")
        #endif
        #if DEBUG
        print("Book cover URL: \(book.coverImageURL ?? "nil")")
        #endif
        
        if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
            navigationPath.append(existingThread)
        } else {
            let newThread = ChatThread(book: book)
            #if DEBUG
            print("New thread cover URL: \(newThread.bookCoverURL ?? "nil")")
            #endif
            modelContext.insert(newThread)
            try? modelContext.save()
            navigationPath.append(newThread)
        }
        showingBookPicker = false
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
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "message.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("General Discussion")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                if let lastMessage = lastMessage {
                    Text(lastMessage.content)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    Text("\(messageCount) messages")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    if let date = lastMessage?.timestamp {
                        Text("• \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // Subtle dark background
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// MARK: - Book Chat Card
struct BookChatCard: View {
    let thread: ChatThread
    let onDelete: () -> Void
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Try to get cover URL from thread or find matching book in library
    private var effectiveCoverURL: String? {
        if let url = thread.bookCoverURL {
            return url
        }
        
        // Fallback: try to find book in library by ID or title
        if let bookId = thread.bookId,
           let book = libraryViewModel.books.first(where: { $0.localId == bookId }) {
            return book.coverImageURL
        } else if let title = thread.bookTitle,
                  let book = libraryViewModel.books.first(where: { $0.title == title }) {
            return book.coverImageURL
        }
        
        return nil
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Book cover
            if let coverURL = effectiveCoverURL {
                SharedBookCoverView(coverURL: coverURL, width: 50, height: 70)
            } else {
                // Fallback icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: "book.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.bookTitle ?? "Unknown Book")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let author = thread.bookAuthor {
                    Text(author)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                HStack {
                    if let lastMessage = thread.messages.last {
                        Image(systemName: lastMessage.isUser ? "person.fill" : "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Text(lastMessage.content)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    
                    Text(thread.lastMessageDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)) // Subtle dark background
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Chat", systemImage: "trash")
            }
        }
    }
}