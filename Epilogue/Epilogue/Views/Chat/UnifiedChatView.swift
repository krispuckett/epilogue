import SwiftUI
import SwiftData

struct UnifiedChatView: View {
    @State private var currentBookContext: Book?
    @State private var messages: [UnifiedChatMessage] = []
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Color extraction state - reuse from BookDetailView
    @State private var colorPalette: ColorPalette?
    @State private var coverImage: UIImage?
    
    var body: some View {
        ZStack {
            // REUSE THE EXACT SAME GRADIENT SYSTEM FROM BookDetailView
            if let book = currentBookContext {
                // Use the same BookAtmosphericGradientView with extracted colors
                BookAtmosphericGradientView(colorPalette: colorPalette ?? generatePlaceholderPalette(for: book))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .id(book.id) // Force view recreation when book changes
            } else {
                // Use existing ambient gradient for empty state
                AmbientChatGradientView()
                    .ignoresSafeArea()
            }
            
            // Chat UI overlay
            VStack(spacing: 0) {
                // Book context indicator (like Perplexity's model selector)
                bookContextPill
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // Messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyStateView
                                    .padding(.top, 100)
                            } else {
                                ForEach(messages) { message in
                                    MessageBubbleView(message: message, book: currentBookContext)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for input area
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
                
                Spacer()
                
                // Input area placeholder
                inputAreaPlaceholder
            }
        }
        .onChange(of: currentBookContext) { oldBook, newBook in
            // Extract colors when book context changes
            if let book = newBook {
                Task {
                    await extractColorsForBook(book)
                }
            } else {
                colorPalette = nil
                coverImage = nil
            }
        }
    }
    
    // MARK: - Book Context Pill
    
    private var bookContextPill: some View {
        HStack(spacing: 12) {
            if let book = currentBookContext {
                // Book context active
                HStack(spacing: 8) {
                    // Mini book cover
                    if let coverURL = book.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 24,
                            height: 36
                        )
                        .cornerRadius(3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        
                        Text(book.author)
                            .font(.system(size: 11))
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentBookContext = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 350)
                .glassEffect(.regular) // Using .regular as specified
                .clipShape(Capsule())
            } else {
                // No book context - show selector
                Button {
                    // TODO: Show book picker
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 14))
                        
                        Text("Select a book")
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: currentBookContext != nil ? "book.and.wrench" : "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(currentBookContext != nil ? "Start a conversation about \(currentBookContext!.title)" : "Start a new conversation")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            if currentBookContext != nil {
                Text("Ask questions, explore themes, or discuss characters")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Input Area Placeholder
    
    private var inputAreaPlaceholder: some View {
        HStack {
            Text("Message placeholder...")
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Color Extraction (Reused from BookDetailView)
    
    private func extractColorsForBook(_ book: Book) async {
        // Check cache first
        let bookID = book.id ?? book.title
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            await MainActor.run {
                self.colorPalette = cachedPalette
            }
            return
        }
        
        // Extract colors if not cached
        guard let coverURLString = book.coverImageURL,
              let coverURL = URL(string: coverURLString) else {
            return
        }
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: coverURL)
            guard let uiImage = UIImage(data: imageData) else { return }
            
            self.coverImage = uiImage
            
            // Use the same extraction as BookDetailView
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: uiImage, imageSource: book.title)
            
            await MainActor.run {
                self.colorPalette = palette
            }
            
            // Cache the result
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
            
        } catch {
            print("Failed to extract colors: \(error)")
        }
    }
    
    private func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        // Same neutral placeholder as BookDetailView
        return ColorPalette(
            primary: Color(white: 0.3),
            secondary: Color(white: 0.25),
            accent: Color.warmAmber.opacity(0.3),
            background: Color(white: 0.1),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: true,
            extractionQuality: 0.1
        )
    }
}

// MARK: - Message Model

struct UnifiedChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: UnifiedChatMessage
    let book: Book?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.isUser {
                                // User messages with glass effect
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.clear)
                                    .glassEffect(.regular)
                            } else {
                                // AI messages with subtle background
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.white.opacity(0.1))
                            }
                        }
                    )
                
                // Book context indicator if different from current
                if let messageBook = message.bookContext,
                   messageBook.id != book?.id {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text(messageBook.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Ambient Chat Gradient (Fallback)

struct AmbientChatGradientView: View {
    var body: some View {
        ZStack {
            Color.black
            
            // Subtle amber gradient for empty state
            LinearGradient(
                stops: [
                    .init(color: Color.warmAmber.opacity(0.15), location: 0.0),
                    .init(color: Color.warmAmber.opacity(0.08), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedChatView()
        .environmentObject(LibraryViewModel())
}