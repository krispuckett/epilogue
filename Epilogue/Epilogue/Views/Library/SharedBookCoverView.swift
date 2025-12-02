import SwiftUI
import CryptoKit

// Global storage for displayed images (temporary for debugging)
class DisplayedImageStore {
    static let shared = DisplayedImageStore()
    var displayedImages: [String: UIImage] = [:]
    
    func store(image: UIImage, for url: String) {
        displayedImages[url] = image
        #if DEBUG
        print("📸 Stored displayed image for URL: \(url)")
        #endif
    }
    
    func getImage(for url: String) -> UIImage? {
        return displayedImages[url]
    }
    
    // Clear all caches
    static func clearAllCaches() {
        #if DEBUG
        print("🧹 Clearing all image caches...")
        #endif
        shared.displayedImages.removeAll()
        URLCache.shared.removeAllCachedResponses()
        
        // Also clear AsyncImage cache
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
        
        #if DEBUG
        print("✅ All image caches cleared")
        #endif
    }
    
    // Debug method to list all cached URLs
    func debugPrintCache() {
        #if DEBUG
        print("📋 Cached images:")
        #endif
        for (url, image) in displayedImages {
            #if DEBUG
            print("  - URL: \(url)")
            #endif
            #if DEBUG
            print("    Size: \(image.size)")
            #endif
        }
    }
}

struct SharedBookCoverView: View {
    private let LOG_COVER_DEBUG = false
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    let loadFullImage: Bool
    let isLibraryView: Bool
    
    @State private var thumbnailImage: UIImage?
    @State private var fullImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var currentLoadingURL: String?
    
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
        // Debug logging for import issue
        if LOG_COVER_DEBUG {
            if let url = coverURL {
                #if DEBUG
                print("🖼️ SharedBookCoverView init:")
                #endif
                #if DEBUG
                print("   Original URL: \(url)")
                #endif
                #if DEBUG
                print("   Contains zoom? \(url.contains("zoom="))")
                #endif
                #if DEBUG
                print("   URL is empty string? \(url.isEmpty)")
                #endif
                #if DEBUG
                print("   URL length: \(url.count)")
                #endif
            } else {
                #if DEBUG
                print("🖼️ SharedBookCoverView init with NIL URL")
                #endif
                #if DEBUG
                print("   ⚠️ This will result in no cover image!")
                #endif
            }
        }
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.loadFullImage = loadFullImage
        self.isLibraryView = isLibraryView
        self.onImageLoaded = onImageLoaded
    }
    
    // Clean URL to match SharedBookCoverManager's cache key format
    private func cleanURL(_ urlString: String) -> String {
        var cleaned = urlString
            .replacingOccurrences(of: "http://", with: "https://")
        
        // IMPORTANT: Don't remove zoom parameters from Google Books URLs
        // Google Books requires zoom parameter to function properly
        if !cleaned.contains("books.google.com") && !cleaned.contains("googleapis.com") {
            // Only remove zoom parameters from non-Google URLs
            let zoomPatterns = [
                "&zoom=10", "&zoom=9", "&zoom=8", "&zoom=7", "&zoom=6",
                "&zoom=5", "&zoom=4", "&zoom=3", "&zoom=2", "&zoom=1", "&zoom=0",
                "?zoom=10", "?zoom=9", "?zoom=8", "?zoom=7", "?zoom=6",
                "?zoom=5", "?zoom=4", "?zoom=3", "?zoom=2", "?zoom=1", "?zoom=0"
            ]
            
            for pattern in zoomPatterns {
                cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
            }
        }
        
        // Clean up any double & or trailing &
        cleaned = cleaned.replacingOccurrences(of: "&&", with: "&")
        if cleaned.hasSuffix("&") {
            cleaned = String(cleaned.dropLast())
        }
        if cleaned.hasSuffix("?") {
            cleaned = String(cleaned.dropLast())
        }
        
        return cleaned
    }
    
    private func loadImage() {
        guard let urlString = coverURL else { 
            // No URL provided, mark as failed
            loadFailed = true
            return 
        }
        
        // If we're already loading this exact URL, don't start another load
        if currentLoadingURL == urlString && isLoading {
            return
        }
        
        // Optional debug URL test removed for performance
        
        // Clean URL to match SharedBookCoverManager's cache key format
        let cleanedURL = cleanURL(urlString)
        if LOG_COVER_DEBUG {
            #if DEBUG
            print("   Cleaned URL: \(cleanedURL)")
            #endif
            #if DEBUG
            print("   URL changed? \(urlString != cleanedURL)")
            #endif
        }
        
        // Check quick cache first for immediate display
        let cacheKey = "\(cleanedURL)_\(loadFullImage ? "full" : "thumb")" as NSString
        if let cachedImage = Self.quickImageCache.object(forKey: cacheKey) {
            if LOG_COVER_DEBUG { print("📚 Using quick cached image for: \(cleanedURL)") }
            if loadFullImage {
                self.fullImage = cachedImage
            } else {
                self.thumbnailImage = cachedImage
            }
            self.isLoading = false
            self.currentLoadingURL = nil
            self.onImageLoaded?(cachedImage)
            return
        }
        
        // Check SharedBookCoverManager's cache
        if let cachedImage = SharedBookCoverManager.shared.getCachedImage(for: urlString) {
            if LOG_COVER_DEBUG { print("📚 Found image in SharedBookCoverManager cache for: \(cleanedURL)") }
            if loadFullImage {
                self.fullImage = cachedImage
            } else {
                self.thumbnailImage = cachedImage
            }
            // Store in quick cache for next time
            Self.quickImageCache.setObject(cachedImage, forKey: cacheKey)
            self.isLoading = false
            self.currentLoadingURL = nil
            self.onImageLoaded?(cachedImage)
            return
        }
        
        isLoading = true
        loadFailed = false
        currentLoadingURL = urlString
        
        if loadFullImage {
            // For detail views, skip thumbnail and load full quality directly
            // Capture the URL and callback at task creation to avoid stale references
            let expectedURL = urlString
            let callback = onImageLoaded  // Capture callback now, before async work
            Task {
                if LOG_COVER_DEBUG { print("🎯 BookDetailView: Loading FULL quality image directly for: \(expectedURL)") }
                if let fullImage = await SharedBookCoverManager.shared.loadFullImage(from: expectedURL) {
                    if LOG_COVER_DEBUG { print("🖼️ BookDetailView full image loaded: \(fullImage.size)") }
                    await MainActor.run {
                        // Always update state and call callback - the callback was captured at task creation
                        // so it has the correct closure from when loadImage() was called
                        self.fullImage = fullImage
                        self.isLoading = false
                        self.currentLoadingURL = nil

                        // Call the captured callback
                        callback?(fullImage)

                        DisplayedImageStore.shared.store(image: fullImage, for: expectedURL)
                        // Store in quick cache
                        let cleanedURL = cleanURL(expectedURL)
                        Self.quickImageCache.setObject(fullImage, forKey: "\(cleanedURL)_full" as NSString)
                        if LOG_COVER_DEBUG { print("   ✅ Updated fullImage and called onImageLoaded") }
                    }
                } else {
                    if LOG_COVER_DEBUG { print("❌ Failed to load full image") }
                    await MainActor.run {
                        self.isLoading = false
                        self.loadFailed = true
                        self.currentLoadingURL = nil
                    }
                }
            }
        } else {
            // Only load thumbnail for grid views
            // Capture callback before async work to avoid stale references
            let callback = onImageLoaded
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
                        self.thumbnailImage = thumbnail
                        self.isLoading = false
                        self.currentLoadingURL = nil
                        // Call the captured callback
                        callback?(thumbnail)
                        // Store in quick cache
                        let cleanedURL = cleanURL(urlString)
                        let cacheKey = "\(cleanedURL)_thumb" as NSString
                        Self.quickImageCache.setObject(thumbnail, forKey: cacheKey)
                    } else {
                        // Image failed to load
                        self.isLoading = false
                        self.loadFailed = true
                        self.currentLoadingURL = nil
                        if LOG_COVER_DEBUG { print("❌ Failed to load image from: \(urlString)") }
                    }
                }
            }
        }
    }
    
    // Add a static method to clear cache for a specific URL
    static func clearCacheForURL(_ urlString: String?) {
        guard let urlString = urlString else { return }
        
        // Clean the URL first
        var cleaned = urlString
            .replacingOccurrences(of: "http://", with: "https://")
        
        // IMPORTANT: Don't remove zoom parameters from Google Books URLs
        if !cleaned.contains("books.google.com") && !cleaned.contains("googleapis.com") {
            let zoomPatterns = [
                "&zoom=10", "&zoom=9", "&zoom=8", "&zoom=7", "&zoom=6",
                "&zoom=5", "&zoom=4", "&zoom=3", "&zoom=2", "&zoom=1", "&zoom=0",
                "?zoom=10", "?zoom=9", "?zoom=8", "?zoom=7", "?zoom=6",
                "?zoom=5", "?zoom=4", "?zoom=3", "?zoom=2", "?zoom=1", "?zoom=0"
            ]
            
            for pattern in zoomPatterns {
                cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
            }
        }
        
        cleaned = cleaned.replacingOccurrences(of: "&&", with: "&")
        if cleaned.hasSuffix("&") {
            cleaned = String(cleaned.dropLast())
        }
        if cleaned.hasSuffix("?") {
            cleaned = String(cleaned.dropLast())
        }
        
        // Clear from quick cache
        let thumbKey = "\(cleaned)_thumb" as NSString
        let fullKey = "\(cleaned)_full" as NSString
        quickImageCache.removeObject(forKey: thumbKey)
        quickImageCache.removeObject(forKey: fullKey)
    }
    
    var body: some View {
        ZStack {
            // Lightweight placeholder
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
                .onAppear {
                    loadImage()
                }
                .onChange(of: coverURL) { oldURL, newURL in
                    // Only reload if URL actually changed
                    if newURL != oldURL {
                        // Clear old cache entries if URL changed
                        if let oldURL = oldURL {
                            SharedBookCoverView.clearCacheForURL(oldURL)
                        }
                        
                        // Cancel any in-progress load
                        if currentLoadingURL == oldURL {
                            currentLoadingURL = nil
                        }
                        
                        // Reset state completely
                        thumbnailImage = nil
                        fullImage = nil
                        isLoading = false
                        loadFailed = false
                        
                        // Load new image if URL is not nil
                        if newURL != nil {
                            loadImage()
                        }
                    }
                }
            
            // Display the best available image
            if let image = fullImage ?? thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high) // Force high quality rendering
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
