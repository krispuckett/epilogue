import SwiftUI
import CryptoKit

// Global storage for displayed images (temporary for debugging)
class DisplayedImageStore {
    static let shared = DisplayedImageStore()
    var displayedImages: [String: UIImage] = [:]
    
    func store(image: UIImage, for url: String) {
        displayedImages[url] = image
        print("📸 Stored displayed image for URL: \(url)")
    }
    
    func getImage(for url: String) -> UIImage? {
        return displayedImages[url]
    }
    
    // Clear all caches
    static func clearAllCaches() {
        print("🧹 Clearing all image caches...")
        shared.displayedImages.removeAll()
        URLCache.shared.removeAllCachedResponses()
        
        // Also clear AsyncImage cache
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
        
        print("✅ All image caches cleared")
    }
    
    // Debug method to list all cached URLs
    func debugPrintCache() {
        print("📋 Cached images:")
        for (url, image) in displayedImages {
            print("  - URL: \(url)")
            print("    Size: \(image.size)")
        }
    }
}

struct SharedBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    let loadFullImage: Bool
    let isLibraryView: Bool
    
    @State private var thumbnailImage: UIImage?
    @State private var fullImage: UIImage?
    @State private var isLoadingStarted = false
    @State private var isLoading = true
    
    // Simple in-memory cache to avoid state recreation
    private static let quickImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Configure quick cache - small, for immediate reuse
        cache.countLimit = 30 // Only keep 30 most recent
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB max
        return cache
    }()
    
    // Callback to notify when image is loaded
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(
        coverURL: String?,
        width: CGFloat = 170,
        height: CGFloat = 255,
        loadFullImage: Bool = true,
        isLibraryView: Bool = false,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.loadFullImage = loadFullImage
        self.isLibraryView = isLibraryView
        self.onImageLoaded = onImageLoaded
    }
    
    private func loadImage() {
        guard !isLoadingStarted, let urlString = coverURL else { return }
        
        // Check quick cache first for immediate display
        let cacheKey = "\(urlString)_\(loadFullImage ? "full" : "thumb")" as NSString
        if let cachedImage = Self.quickImageCache.object(forKey: cacheKey) {
            print("📚 Using quick cached image for: \(urlString.suffix(50))")
            if loadFullImage {
                self.fullImage = cachedImage
            } else {
                self.thumbnailImage = cachedImage
            }
            self.isLoading = false
            self.onImageLoaded?(cachedImage)
            return
        }
        
        isLoadingStarted = true
        
        if loadFullImage {
            // Progressive loading for detail views
            SharedBookCoverManager.shared.loadProgressiveImage(
                from: urlString,
                onThumbnailLoaded: { image in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.thumbnailImage = image
                        self.isLoading = false
                    }
                    if self.fullImage == nil {
                        self.onImageLoaded?(image)
                    }
                },
                onFullImageLoaded: { image in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.fullImage = image
                        self.isLoading = false
                    }
                    self.onImageLoaded?(image)
                    DisplayedImageStore.shared.store(image: image, for: urlString)
                    // Store in quick cache
                    Self.quickImageCache.setObject(image, forKey: "\(urlString)_full" as NSString)
                }
            )
        } else {
            // Only load thumbnail for grid views
            Task {
                let thumbnail: UIImage?
                if isLibraryView {
                    // Use larger thumbnails for library grid (200x300 max)
                    thumbnail = await SharedBookCoverManager.shared.loadLibraryThumbnail(from: urlString)
                } else {
                    // Use standard thumbnails for other views
                    thumbnail = await SharedBookCoverManager.shared.loadThumbnail(from: urlString)
                }
                
                if let thumbnail = thumbnail {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.thumbnailImage = thumbnail
                            self.isLoading = false
                        }
                        self.onImageLoaded?(thumbnail)
                        // Store in quick cache
                        Self.quickImageCache.setObject(thumbnail, forKey: cacheKey)
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Lightweight placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
                .onAppear {
                    loadImage()
                }
                .onChange(of: coverURL) { _, _ in
                    // Reset state and reload when URL changes
                    thumbnailImage = nil
                    fullImage = nil
                    isLoadingStarted = false
                    isLoading = true
                    loadImage()
                }
            
            // Display the best available image
            if let image = fullImage ?? thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity)
            } else if coverURL != nil && isLoading {
                // Loading state - show gradient placeholder instead of spinner
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.3, blue: 0.35),
                        Color(red: 0.25, green: 0.25, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // No cover URL
                Image(systemName: "book.closed.fill")
                    .font(.system(size: min(width, height) * 0.25))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .drawingGroup() // Cache the shadow rendering
    }
}

// MARK: - Convenience Views

/// Thumbnail version for grid views (120x180)
struct BookCoverThumbnailView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(
        coverURL: String?,
        width: CGFloat = 120,
        height: CGFloat = 180,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
    }
    
    var body: some View {
        SharedBookCoverView(
            coverURL: coverURL,
            width: width,
            height: height,
            loadFullImage: false,
            onImageLoaded: onImageLoaded
        )
    }
}

/// Full image version for detail views
struct BookCoverFullView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(
        coverURL: String?,
        width: CGFloat = 170,
        height: CGFloat = 255,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
    }
    
    var body: some View {
        SharedBookCoverView(
            coverURL: coverURL,
            width: width,
            height: height,
            loadFullImage: true,
            onImageLoaded: onImageLoaded
        )
    }
}