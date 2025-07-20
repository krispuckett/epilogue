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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Navigate to gradient test view
                        navigationPath.append("gradient-showcase")
                    } label: {
                        Label("Gradient Showcase", systemImage: "paintbrush.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
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
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}

// MARK: - Book Chat Card
struct BookChatCard: View {
    let thread: ChatThread
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
                        print("BookChatCard - No cover URL for book: \(thread.bookTitle ?? "Unknown")")
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
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
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