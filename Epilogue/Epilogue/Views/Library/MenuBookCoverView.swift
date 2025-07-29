import SwiftUI

/// Lightweight book cover view optimized for menu dropdowns
/// Only loads low-quality images for fast rendering
struct MenuBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Ultra-lightweight placeholder with dark color
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.15)) // Darker to match menu background
                .opacity(image == nil ? 1 : 0)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard !isLoading, let coverURL = coverURL else { return }
        isLoading = true
        
        // Check cache first
        if let cachedImage = SharedBookCoverManager.shared.getCachedImage(for: coverURL, quality: .low) {
            withAnimation(.easeOut(duration: 0.15)) {
                self.image = cachedImage
            }
            return
        }
        
        // Load low quality image only
        if let loadedImage = await SharedBookCoverManager.shared.loadImage(from: coverURL, quality: .low) {
            withAnimation(.easeOut(duration: 0.15)) {
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Pre-caching Extension

extension SharedBookCoverManager {
    /// Pre-cache thumbnails for menu performance
    @MainActor
    func preCacheThumbnails(for books: [Book]) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Load thumbnails in background with lower priority
            for book in books.prefix(10) { // Limit to first 10 books for faster initial load
                if await self.getCachedImage(for: book.coverImageURL, quality: .low) == nil {
                    // Smaller delay for faster pre-caching
                    try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                    _ = await self.loadImage(from: book.coverImageURL, quality: .low)
                }
            }
        }
    }
}

// MARK: - Optimized Menu Style

struct OptimizedMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .preferredColorScheme(.dark) // Force dark mode for menu
            .tint(.white) // Ensure text stays white
            .transaction { transaction in
                // Reduce animation complexity
                transaction.animation = .easeOut(duration: 0.2)
            }
    }
}