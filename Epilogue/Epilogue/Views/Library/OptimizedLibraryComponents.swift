import SwiftUI

// MARK: - Optimized Library Grid Item
struct OptimizedLibraryGridItem: View {
    let book: Book
    let viewModel: LibraryViewModel
    let isHighlighted: Bool
    let onChangeCover: (Book) -> Void
    
    @State private var colorPalette: ColorPalette?
    @State private var isLoadingPalette = false
    @Environment(\.isScrolling) private var isScrolling
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            BookCard(book: book)
                .environmentObject(viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(highlightOverlay)
                .skeleton(isLoading: colorPalette == nil && isLoadingPalette)
        }
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .buttonStyle(PlainButtonStyle())
        .task {
            // Only load palette if not scrolling
            if !isScrolling {
                await loadColorPalette()
            }
        }
        .contextMenu {
            bookContextMenu
        }
        .performanceOptimized()
    }
    
    @ViewBuilder
    private var highlightOverlay: some View {
        if isHighlighted {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 2)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        }
    }
    
    @ViewBuilder
    private var bookContextMenu: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChangeCover(book)
        } label: {
            Label("Change Cover", systemImage: "photo")
        }
        
        Divider()
        
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation {
                viewModel.deleteBook(book)
            }
        } label: {
            Label("Delete from Library", systemImage: "trash")
        }
    }
    
    private func loadColorPalette() async {
        guard colorPalette == nil,
              !isLoadingPalette,
              let coverURL = book.coverImageURL else { return }
        
        isLoadingPalette = true
        
        // Check cache first
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: book.id) {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    colorPalette = cachedPalette
                }
                isLoadingPalette = false
            }
            return
        }
        
        // Load in background
        if let image = await SharedBookCoverManager.shared.loadLibraryThumbnail(from: coverURL) {
            do {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image, imageSource: book.id)
                
                await BookColorPaletteCache.shared.cachePalette(palette, for: book.id, coverURL: coverURL)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        colorPalette = palette
                    }
                    isLoadingPalette = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPalette = false
                }
            }
        }
    }
}

// MARK: - Optimized Book List Row
struct OptimizedBookListRow: View {
    let book: Book
    let viewModel: LibraryViewModel
    let colorPalette: ColorPalette?
    let isHighlighted: Bool
    let onChangeCover: (Book) -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.isScrolling) private var isScrolling
    
    private var progress: Double {
        guard let pageCount = book.pageCount, pageCount > 0 else { return 0 }
        return Double(book.currentPage) / Double(pageCount)
    }
    
    var body: some View {
        NavigationLink(destination: BookDetailView(book: book).environmentObject(viewModel)) {
            rowContent
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                .onHover { hovering in
                    if !isScrolling {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovered = hovering
                        }
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in 
                    isPressed = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .contextMenu {
            contextMenuContent
        }
        .performanceOptimized()
    }
    
    @ViewBuilder
    private var rowContent: some View {
        ZStack {
            // Simplified background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
            
            // Gradient overlay only when not scrolling
            if !isScrolling, let palette = colorPalette {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        palette.primary.opacity(0.15),
                        palette.primary.opacity(0.25)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blur(radius: 20)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(isHovered ? 1 : 0.7)
            }
            
            // Border
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isHighlighted ? Color(red: 1.0, green: 0.55, blue: 0.26) : Color.white.opacity(0.1),
                    lineWidth: isHighlighted ? 2 : 1
                )
            
            // Content
            HStack(spacing: 0) {
                // Book cover - use shared view for caching
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 60,
                    height: 80,
                    loadFullImage: false,
                    isLibraryView: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .padding(.trailing, 12)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Progress bar - simplified for performance
                    if book.pageCount != nil && book.currentPage > 0 && !isScrolling {
                        progressBar
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 104)
    }
    
    @ViewBuilder
    private var progressBar: some View {
        HStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colorPalette?.primary ?? Color(red: 1.0, green: 0.55, blue: 0.26),
                                    colorPalette?.secondary ?? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(width: 80, height: 4)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChangeCover(book)
        } label: {
            Label("Change Cover", systemImage: "photo")
        }
        
        Divider()
        
        Button(role: .destructive) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            OptimisticUpdateManager.shared.performOptimisticUpdate(
                id: "delete-\(book.id)",
                immediate: {
                    withAnimation {
                        viewModel.deleteBook(book)
                    }
                },
                commit: {
                    // Actual deletion would happen here
                },
                rollback: {
                    // Restore book if deletion fails
                }
            )
        } label: {
            Label("Delete from Library", systemImage: "trash")
        }
    }
}