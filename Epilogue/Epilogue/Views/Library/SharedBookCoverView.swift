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
    @State private var loadFailed = false
    
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
            // For detail views, skip thumbnail and load full quality directly
            Task {
                print("🎯 BookDetailView: Loading FULL quality image directly")
                if let fullImage = await SharedBookCoverManager.shared.loadFullImage(from: urlString) {
                    print("🖼️ BookDetailView full image loaded: \(fullImage.size)")
                    await MainActor.run {
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            self.fullImage = fullImage
                            self.isLoading = false
                        }
                        self.onImageLoaded?(fullImage)
                        DisplayedImageStore.shared.store(image: fullImage, for: urlString)
                        // Store in quick cache
                        Self.quickImageCache.setObject(fullImage, forKey: "\(urlString)_full" as NSString)
                    }
                } else {
                    print("❌ Failed to load full image")
                    await MainActor.run {
                        self.isLoading = false
                        self.loadFailed = true
                    }
                }
            }
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
                
                await MainActor.run {
                    if let thumbnail = thumbnail {
                        withAnimation(DesignSystem.Animation.easeStandard) {
                            self.thumbnailImage = thumbnail
                            self.isLoading = false
                        }
                        self.onImageLoaded?(thumbnail)
                        // Store in quick cache
                        Self.quickImageCache.setObject(thumbnail, forKey: cacheKey)
                    } else {
                        // Image failed to load - don't mark as failed yet
                        // Just set loading to false, will show placeholder
                        self.isLoading = false
                        print("❌ Failed to load image from: \(urlString)")
                        
                        // Note: We could try fallback sources here but that would require
                        // passing the full Book object, not just the URL
                        // For now, the placeholder will show
                        self.loadFailed = true
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Lightweight placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
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
                    .interpolation(.high) // Force high quality rendering
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity)
            } else if loadFailed || (coverURL == nil) {
                // Failed to load or no URL - just show gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.25, blue: 0.3),
                        Color(red: 0.2, green: 0.2, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if isLoading {
                // Loading state - subtle solid color (no shimmer)
                // Just slightly lighter than the base placeholder
                Color(red: 0.28, green: 0.28, blue: 0.32)
                    .opacity(0.9)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
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