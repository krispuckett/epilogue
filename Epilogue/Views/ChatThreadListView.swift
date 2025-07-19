import SwiftUI
import SwiftData
import CoreImage
import CoreImage.CIFilterBuiltins

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
                MetalLiteraryView()
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
                                        .environmentObject(libraryViewModel)
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
                    // Debug: Check if book has cover URL
                    print("Selected book: \(book.title)")
                    print("Book cover URL: \(book.coverImageURL ?? "nil")")
                    
                    // Create or select thread for this book
                    if let existingThread = threads.first(where: { $0.bookId == book.localId }) {
                        selectedThread = existingThread
                    } else {
                        let newThread = ChatThread(book: book)
                        print("New thread cover URL: \(newThread.bookCoverURL ?? "nil")")
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
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var dominantColor: Color = Color(red: 0.11, green: 0.105, blue: 0.102)
    @State private var coverImage: UIImage?
    
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
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Book cover
                if let coverURL = effectiveCoverURL {
                    SharedBookCoverView(coverURL: coverURL, width: 50, height: 70)
                        .onAppear {
                            print("BookChatCard - Book: \(thread.bookTitle ?? "Unknown"), Cover URL: \(coverURL)")
                            loadAndExtractColors(from: coverURL)
                        }
                } else {
                    // Fallback icon
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                        .frame(width: 50, height: 70)
                        .overlay {
                            Image(systemName: "book.fill")
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                        .onAppear {
                            print("BookChatCard - Book: \(thread.bookTitle ?? "Unknown"), Cover URL is nil (thread: \(thread.bookCoverURL ?? "nil"), effective: nil)")
                        }
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
            .background {
                ZStack {
                    // Gradient background based on book cover color
                    LinearGradient(
                        colors: [
                            dominantColor.opacity(0.3),
                            dominantColor.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Glass effect on top
                    Color.white.opacity(0.05)
                        .background(.ultraThinMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
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
    
    private func loadAndExtractColors(from urlString: String) {
        // Enhance URL for better quality
        var enhanced = urlString.replacingOccurrences(of: "http://", with: "https://")
        if !enhanced.contains("zoom=") {
            enhanced += enhanced.contains("?") ? "&zoom=2" : "?zoom=2"
        }
        
        guard let url = URL(string: enhanced) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.coverImage = uiImage
                    self.extractDominantColor(from: uiImage)
                }
            }
        }.resume()
    }
    
    private func extractDominantColor(from image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        let context = CIContext()
        let size = CGSize(width: 20, height: 20) // Smaller for performance
        
        // Scale down
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(size.width / ciImage.extent.width, forKey: kCIInputScaleKey)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        // Simple color extraction - get average color
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmapContext = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return }
        
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Find the most vibrant color
        var bestColor = UIColor.gray
        var maxSaturation: CGFloat = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let index = ((width * y) + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Pick vibrant colors
                if s > maxSaturation && br > 0.3 && br < 0.9 {
                    maxSaturation = s
                    bestColor = color
                }
            }
        }
        
        // Convert to SwiftUI Color and boost saturation
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        bestColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        let boostedS = min(s * 1.5, 1.0)
        let boostedB = min(b * 1.2, 0.85)
        
        withAnimation(.easeInOut(duration: 0.8)) {
            dominantColor = Color(hue: Double(h), saturation: Double(boostedS), brightness: Double(boostedB))
        }
    }
}

