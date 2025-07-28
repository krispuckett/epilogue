import SwiftUI
import SwiftData

// DEPRECATED: This view is replaced by UnifiedChatView
// Keeping temporarily for reference during migration
struct ChatThreadListView: View {
    @Query(filter: #Predicate<ChatThread> { thread in
        thread.isArchived == false
    }) private var threads: [ChatThread]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var showingDeleteConfirmation = false
    @State private var threadToDelete: ChatThread?
    @State private var showingBookPicker = false
    @State private var isAmbientModeActive = false
    @State private var ambientSelectedBook: Book?
    @State private var ambientSession: AmbientSession?
    @State private var isSelectionMode = false
    @State private var selectedThreads: Set<ChatThread> = []
    @State private var showingBulkDeleteConfirmation = false
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ZStack {
            // ALWAYS show the background, not conditionally
            backgroundView
            
            // Content layer
            contentView
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !threads.isEmpty {
                    Button(isSelectionMode ? "Done" : "Select") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedThreads.removeAll()
                            }
                        }
                        HapticManager.shared.lightTap()
                    }
                }
            }
            
            if isSelectionMode && !selectedThreads.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button {
                            HapticManager.shared.lightTap()
                            archiveSelectedThreads()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            HapticManager.shared.lightTap()
                            showingBulkDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                onStartGeneralChat: {
                    let generalThread = threads.first { $0.bookId == nil } ?? ChatThread()
                    if !threads.contains(where: { $0.bookId == nil }) {
                        modelContext.insert(generalThread)
                        try? modelContext.save()
                    }
                    navigationPath.append(generalThread)
                },
                onSelectBook: {
                    showingBookPicker = true
                },
                onStartAmbient: {
                    isAmbientModeActive = true
                }
            )
            .environmentObject(libraryViewModel)
        }
        .fullScreenCover(isPresented: $isAmbientModeActive, onDismiss: {
            // Clean up when dismissed
            ambientSelectedBook = nil
            ambientSession = nil
        }) {
            AmbientChatOverlay(
                isActive: $isAmbientModeActive,
                selectedBook: $ambientSelectedBook,
                session: $ambientSession
            )
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
        .alert("Delete \(selectedThreads.count) conversations?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedThreads()
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
        
        // Show enhanced ambient background when no book threads
        if bookThreads.isEmpty {
            AmbientChatBackground(
                audioLevel: .constant(0),
                isListening: .constant(false)
            )
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
                        if isSelectionMode {
                            SwipeableGeneralChatCard(
                                messageCount: general.messages.count,
                                lastMessage: general.messages.last,
                                isSelected: selectedThreads.contains(general),
                                isSelectionMode: isSelectionMode,
                                onDelete: {
                                    threadToDelete = general
                                    showingDeleteConfirmation = true
                                },
                                onArchive: {
                                    archiveThread(general)
                                },
                                onToggleSelection: {
                                    toggleThreadSelection(general)
                                }
                            )
                            .padding(.horizontal)
                        } else {
                            NavigationLink(value: general) {
                                SwipeableGeneralChatCard(
                                    messageCount: general.messages.count,
                                    lastMessage: general.messages.last,
                                    isSelected: false,
                                    isSelectionMode: false,
                                    onDelete: {
                                        threadToDelete = general
                                        showingDeleteConfirmation = true
                                    },
                                    onArchive: {
                                        archiveThread(general)
                                    },
                                    onToggleSelection: {}
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    
                    // Book discussions
                    if !bookThreads.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Book Discussions")
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal)
                            
                            ForEach(bookThreads) { thread in
                                if isSelectionMode {
                                    SwipeableChatCard(
                                        thread: thread,
                                        isSelected: selectedThreads.contains(thread),
                                        isSelectionMode: isSelectionMode,
                                        onDelete: {
                                            threadToDelete = thread
                                            showingDeleteConfirmation = true
                                        },
                                        onArchive: {
                                            archiveThread(thread)
                                        },
                                        onToggleSelection: {
                                            toggleThreadSelection(thread)
                                        }
                                    )
                                    .environmentObject(libraryViewModel)
                                    .padding(.horizontal)
                                } else {
                                    NavigationLink(value: thread) {
                                        SwipeableChatCard(
                                            thread: thread,
                                            isSelected: false,
                                            isSelectionMode: false,
                                            onDelete: {
                                                threadToDelete = thread
                                                showingDeleteConfirmation = true
                                            },
                                            onArchive: {
                                                archiveThread(thread)
                                            },
                                            onToggleSelection: {}
                                        )
                                        .environmentObject(libraryViewModel)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal)
                                }
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
        print("Selected book: \(book.title)")
        print("Book cover URL: \(book.coverImageURL ?? "nil")")
        
        if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
            navigationPath.append(existingThread)
        } else {
            let newThread = ChatThread(book: book)
            print("New thread cover URL: \(newThread.bookCoverURL ?? "nil")")
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
    
    private func toggleThreadSelection(_ thread: ChatThread) {
        if selectedThreads.contains(thread) {
            selectedThreads.remove(thread)
        } else {
            selectedThreads.insert(thread)
        }
    }
    
    private func archiveThread(_ thread: ChatThread) {
        // TODO: Implement archive functionality
        // For now, just mark as archived
        thread.isArchived = true
        try? modelContext.save()
        HapticManager.shared.success()
    }
    
    private func archiveSelectedThreads() {
        for thread in selectedThreads {
            thread.isArchived = true
        }
        try? modelContext.save()
        selectedThreads.removeAll()
        isSelectionMode = false
        HapticManager.shared.success()
    }
    
    private func deleteSelectedThreads() {
        for thread in selectedThreads {
            modelContext.delete(thread)
        }
        try? modelContext.save()
        selectedThreads.removeAll()
        isSelectionMode = false
        HapticManager.shared.success()
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
    
    private var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: thread.sessionDuration) ?? "0s"
    }
    
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
                    if thread.isAmbientSession {
                        // Ambient session info
                        Image(systemName: "waveform.bubble")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange.opacity(0.6))
                        
                        Text("\(thread.capturedItems) items • \(formattedDuration)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Text(thread.lastMessageDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        // Regular chat info
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