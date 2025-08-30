import SwiftUI
import Combine

// MARK: - Optimized Library Grid with Virtualization
struct OptimizedLibraryGrid: View {
    let books: [Book]
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var loadedImages: Set<UUID> = []
    @State private var pendingLoads: Set<UUID> = []
    @Namespace private var gridAnimation
    
    // Performance settings
    private let preloadBuffer = 4 // Number of items to preload
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(Array(books.enumerated()), id: \.element.localId) { index, book in
                        OptimizedGridItem(
                            book: book,
                            isLoaded: loadedImages.contains(book.localId),
                            viewModel: viewModel,
                            highlightedBookId: highlightedBookId,
                            onChangeCover: onChangeCover
                        )
                        .id(book.localId)
                        .onAppear {
                            handleItemAppear(book: book, at: index)
                        }
                        .onDisappear {
                            handleItemDisappear(book: book)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            preloadInitialBatch()
        }
    }
    
    // MARK: - Visibility Management
    
    private func handleItemAppear(book: Book, at index: Int) {
        // Update visible range
        let newRange = max(0, index - preloadBuffer)..<min(books.count, index + preloadBuffer + 1)
        visibleRange = newRange
        
        // Mark as loaded
        withAnimation(.easeIn(duration: 0.2)) {
            loadedImages.insert(book.localId)
        }
        
        // Preload nearby items
        preloadNearbyItems(around: index)
    }
    
    private func handleItemDisappear(book: Book) {
        // Keep in memory for a bit to prevent reload on quick scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !isBookVisible(book) {
                loadedImages.remove(book.localId)
            }
        }
    }
    
    private func isBookVisible(_ book: Book) -> Bool {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return false }
        return visibleRange.contains(index)
    }
    
    // MARK: - Preloading
    
    private func preloadInitialBatch() {
        // Preload first 6 items immediately
        let initialCount = min(6, books.count)
        for i in 0..<initialCount {
            loadedImages.insert(books[i].localId)
            preloadBookCover(books[i])
        }
    }
    
    private func preloadNearbyItems(around index: Int) {
        let preloadRange = max(0, index - preloadBuffer)..<min(books.count, index + preloadBuffer + 1)
        
        for i in preloadRange {
            let book = books[i]
            if !pendingLoads.contains(book.localId) {
                pendingLoads.insert(book.localId)
                preloadBookCover(book)
            }
        }
    }
    
    private func preloadBookCover(_ book: Book) {
        Task(priority: .background) {
            if let coverURL = book.coverImageURL {
                _ = await SharedBookCoverManager.shared.loadLibraryThumbnail(from: coverURL)
            }
            await MainActor.run {
                pendingLoads.remove(book.localId)
            }
        }
    }
}

// MARK: - Optimized Grid Item
struct OptimizedGridItem: View {
    let book: Book
    let isLoaded: Bool
    let viewModel: LibraryViewModel
    let highlightedBookId: UUID?
    let onChangeCover: (Book) -> Void
    
    @State private var isPressed = false
    @State private var imageLoaded = false
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            ZStack {
                if isLoaded {
                    BookCard(book: book)
                        .environmentObject(viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(imageLoaded ? 1 : 0)
                        .animation(.easeIn(duration: 0.3), value: imageLoaded)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.2)) {
                                imageLoaded = true
                            }
                        }
                } else {
                    // Skeleton placeholder
                    OptimizedBookCardSkeleton()
                }
                
                // Highlight overlay
                if highlightedBookId == book.localId {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color.orange, lineWidth: 3)
                        .animation(DesignSystem.Animation.easeStandard, value: highlightedBookId)
                }
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            isPressed = pressing
            if pressing {
                DesignSystem.HapticFeedback.light()
            }
        } perform: {}
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            bookContextMenu
        }
    }
    
    @ViewBuilder
    private var bookContextMenu: some View {
        Button {
            DesignSystem.HapticFeedback.light()
            withAnimation {
                viewModel.toggleReadingStatus(for: book)
            }
        } label: {
            Label(
                book.readingStatus == .read ? "Mark as Want to Read" : "Mark as Read",
                systemImage: book.readingStatus == .read ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }
        
        Divider()
        
        Button {
            DesignSystem.HapticFeedback.light()
            shareBook()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button {
            DesignSystem.HapticFeedback.light()
            onChangeCover(book)
        } label: {
            Label("Change Cover", systemImage: "photo")
        }
        
        Divider()
        
        Button(role: .destructive) {
            DesignSystem.HapticFeedback.light()
            withAnimation {
                viewModel.deleteBook(book)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func shareBook() {
        let text = "Check out \"\(book.title)\" by \(book.author)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Optimized Book Card Skeleton
struct OptimizedBookCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 240)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            DesignSystem.Colors.textQuaternary,
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 80)
                    .rotationEffect(.degrees(25))
                    .offset(x: isAnimating ? 200 : -200)
                )
                .clipped()
            
            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 16)
            
            // Author placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 14)
                .frame(maxWidth: 120)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}