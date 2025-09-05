import SwiftUI
import UIKit
import Combine

/// Manager for progressive book cover image loading with proper caching
@MainActor
public class SharedBookCoverManager: ObservableObject {
    static let shared = SharedBookCoverManager()
    
    // MARK: - Caches
    private static let imageCache = NSCache<NSString, UIImage>()
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    
    // Active loading tasks to prevent duplicate requests
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    // Disk cache directory
    private let diskCacheURL: URL? = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return cacheDir?.appendingPathComponent("BookCovers", isDirectory: true)
    }()
    
    private init() {
        configureCaches()
        setupDiskCache()
        registerForMemoryWarnings()
    }
    
    deinit {
        // Cancel all active tasks when manager is deallocated
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Configuration
    
    private func configureCaches() {
        // Configure image cache (50MB limit, 100 images max)
        Self.imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        Self.imageCache.countLimit = 100
        Self.imageCache.name = "FullImageCache"
        
        // Configure thumbnail cache (10MB limit, 200 thumbnails max)
        Self.thumbnailCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        Self.thumbnailCache.countLimit = 200
        Self.thumbnailCache.name = "ThumbnailCache"
        
        print("✅ Configured caches with memory limits")
    }
    
    private func setupDiskCache() {
        guard let diskCacheURL = diskCacheURL else { return }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Clean old cache files (older than 7 days)
        cleanDiskCache()
    }
    
    private func registerForMemoryWarnings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing image caches")
        Self.imageCache.removeAllObjects()
        Self.thumbnailCache.removeAllObjects()
        // Also clean up active tasks
        cleanupCompletedTasks()
    }
    
    private func cleanupCompletedTasks() {
        let completedKeys = activeTasks.compactMap { key, task in
            task.isCancelled ? key : nil
        }
        completedKeys.forEach { activeTasks.removeValue(forKey: $0) }
    }
    
    // MARK: - Public Methods
    
    /// Load thumbnail for grid views
    public func loadThumbnail(from coverURL: String?, targetSize: CGSize = CGSize(width: 120, height: 180)) async -> UIImage? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        let cacheKey = "\(cleanedURL)_thumb" as NSString
        
        // Check memory cache
        if let cached = Self.thumbnailCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Check disk cache
        if let diskCached = loadFromDisk(key: cacheKey as String) {
            Self.thumbnailCache.setObject(diskCached, forKey: cacheKey, cost: diskCached.jpegData(compressionQuality: 0.8)?.count ?? 0)
            return diskCached
        }
        
        // Load from network
        return await loadAndCacheImage(
            from: cleanedURL,
            cacheKey: cacheKey as String,
            targetSize: targetSize,
            isThumbnail: true
        )
    }
    
    /// Load full image only when needed (detail views)
    public func loadFullImage(from coverURL: String?) async -> UIImage? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        // Use zoom=10 for maximum quality from Google Books
        let highQualityURL = appendZoomParameter(to: cleanedURL, zoom: 10)
        let cacheKey = "\(cleanedURL)_full" as NSString
        
        print("📱 Loading full image from: \(highQualityURL.suffix(100))")
        
        // Check memory cache
        if let cached = Self.imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Check disk cache
        if let diskCached = loadFromDisk(key: cacheKey as String) {
            Self.imageCache.setObject(diskCached, forKey: cacheKey, cost: diskCached.jpegData(compressionQuality: 0.8)?.count ?? 0)
            return diskCached
        }
        
        // Load from network
        return await loadAndCacheImage(
            from: highQualityURL,
            cacheKey: cacheKey as String,
            targetSize: nil, // Full size
            isThumbnail: false
        )
    }
    
    /// Load library thumbnail (200x300 max) for library grid views
    public func loadLibraryThumbnail(from coverURL: String?) async -> UIImage? {
        return await loadThumbnail(from: coverURL, targetSize: CGSize(width: 200, height: 300))
    }
    
    /// Progressive loading - thumbnail first, then full image
    public func loadProgressiveImage(
        from coverURL: String?,
        thumbnailSize: CGSize = CGSize(width: 120, height: 180),
        onThumbnailLoaded: @escaping (UIImage) -> Void,
        onFullImageLoaded: @escaping (UIImage) -> Void
    ) {
        guard let coverURL = coverURL else { return }
        
        Task {
            // Load thumbnail first at requested size
            if let thumbnail = await loadThumbnail(from: coverURL, targetSize: thumbnailSize) {
                await MainActor.run {
                    onThumbnailLoaded(thumbnail)
                }
            }
            
            // Then load full image
            if let fullImage = await loadFullImage(from: coverURL) {
                await MainActor.run {
                    onFullImageLoaded(fullImage)
                }
            }
        }
    }
    
    /// Get cached image if available (checks both thumbnail and full caches)
    public func getCachedImage(for coverURL: String?) -> UIImage? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        
        // Check full image cache first
        let fullCacheKey = "\(cleanedURL)_full" as NSString
        if let cached = Self.imageCache.object(forKey: fullCacheKey) {
            print("✅ Found full image in cache for: \(cleanedURL.suffix(50))")
            return cached
        }
        
        // Check thumbnail cache
        let thumbCacheKey = "\(cleanedURL)_thumb" as NSString
        if let cached = Self.thumbnailCache.object(forKey: thumbCacheKey) {
            print("✅ Found thumbnail in cache for: \(cleanedURL.suffix(50))")
            return cached
        }
        
        // Check disk cache for full image
        if let diskCached = loadFromDisk(key: fullCacheKey as String) {
            // Store back in memory cache for quick access
            Self.imageCache.setObject(diskCached, forKey: fullCacheKey, cost: diskCached.jpegData(compressionQuality: 0.8)?.count ?? 0)
            print("✅ Found full image on disk for: \(cleanedURL.suffix(50))")
            return diskCached
        }
        
        // Check disk cache for thumbnail
        if let diskCached = loadFromDisk(key: thumbCacheKey as String) {
            // Store back in memory cache for quick access
            Self.thumbnailCache.setObject(diskCached, forKey: thumbCacheKey, cost: diskCached.jpegData(compressionQuality: 0.8)?.count ?? 0)
            print("✅ Found thumbnail on disk for: \(cleanedURL.suffix(50))")
            return diskCached
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func loadAndCacheImage(
        from urlString: String,
        cacheKey: String,
        targetSize: CGSize?,
        isThumbnail: Bool
    ) async -> UIImage? {
        // Check if already loading
        if let existingTask = activeTasks[cacheKey] {
            return await existingTask.value
        }
        
        // Create loading task with retry logic
        let task = Task<UIImage?, Never> {
            guard let url = URLValidator.createSafeBookCoverURL(from: urlString) else {
                print("❌ Invalid or unsafe URL")
                return nil
            }
            
            // Try up to 3 times with exponential backoff
            for attempt in 1...3 {
                do {
                    print("📥 Loading book cover from: \(url.absoluteString.suffix(100)) (attempt \(attempt))")
                    
                    // Create request with timeout
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10.0 // 10 second timeout
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    // Check HTTP status
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📊 HTTP Status: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode == 404 {
                            print("⚠️ Cover image not found (404)")
                            // Don't retry 404s - they won't magically appear
                            break
                        }
                        
                        // Retry on server errors
                        if httpResponse.statusCode >= 500 {
                            print("⚠️ Server error \(httpResponse.statusCode), will retry...")
                            if attempt < 3 {
                                // Exponential backoff: 1s, 2s, 4s
                                let delay = pow(2.0, Double(attempt - 1))
                                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                continue
                            }
                        }
                        
                        // Rate limiting
                        if httpResponse.statusCode == 429 {
                            print("⚠️ Rate limited, waiting longer...")
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                            continue
                        }
                    }
                    
                    guard let originalImage = UIImage(data: data) else { 
                        print("❌ Failed to decode image data")
                        if attempt < 3 {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            continue
                        }
                        return nil 
                    }
                    
                    print("✅ Successfully decoded image: \(originalImage.size)")
                    
                    // Resize if needed
                    let processedImage: UIImage
                    if let targetSize = targetSize {
                        processedImage = resizeImage(originalImage, targetSize: targetSize) ?? originalImage
                    } else {
                        processedImage = originalImage
                    }
                    
                    // Cache in memory
                    let cost = processedImage.jpegData(compressionQuality: 0.8)?.count ?? 0
                    if isThumbnail {
                        Self.thumbnailCache.setObject(processedImage, forKey: cacheKey as NSString, cost: cost)
                    } else {
                        Self.imageCache.setObject(processedImage, forKey: cacheKey as NSString, cost: cost)
                    }
                    
                    // Save to disk
                    saveToDisk(image: processedImage, key: cacheKey)
                    
                    print("✅ Loaded and cached image (\(cacheKey)): \(processedImage.size)")
                    return processedImage
                    
                } catch let error as URLError where error.code == .timedOut {
                    print("⏱️ Request timed out, attempt \(attempt)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        continue
                    }
                } catch {
                    print("❌ Failed to load image (attempt \(attempt)): \(error.localizedDescription)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    }
                }
            }
            
            return nil
        }
        
        // Store active task
        activeTasks[cacheKey] = task
        
        // Wait for result
        let result = await task.value
        
        // Clean up
        activeTasks.removeValue(forKey: cacheKey)
        
        // Periodic cleanup every 10 tasks
        if activeTasks.count % 10 == 0 {
            cleanupCompletedTasks()
        }
        
        return result
    }
    
    // MARK: - Image Processing
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out aspect fill ratio
        let ratio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Resize the image
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2,
            width: newSize.width,
            height: newSize.height
        )
        
        image.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Disk Cache
    
    private func saveToDisk(image: UIImage, key: String) {
        guard let diskCacheURL = diskCacheURL,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        Task.detached(priority: .background) {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        guard let diskCacheURL = diskCacheURL else { return nil }
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else { return nil }
        
        // Update file modification date for LRU
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        
        return image
    }
    
    private func cleanDiskCache() {
        guard let diskCacheURL = diskCacheURL else { return }
        
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
            
            guard let enumerator = fileManager.enumerator(
                at: diskCacheURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else { return }
            
            let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
            let maxSize: Int64 = 100 * 1024 * 1024 // 100MB total
            var totalSize: Int64 = 0
            var filesToDelete: [(URL, Date)] = []
            
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let modificationDate = resourceValues.contentModificationDate,
                      let fileSize = resourceValues.fileSize else { continue }
                
                totalSize += Int64(fileSize)
                
                // Mark old files for deletion
                if Date().timeIntervalSince(modificationDate) > maxAge {
                    filesToDelete.append((fileURL, modificationDate))
                }
            }
            
            // If still over size limit, delete oldest files
            if totalSize > maxSize {
                // Get all files sorted by date
                var allFiles: [(URL, Date, Int64)] = []
                
                if let enumerator2 = fileManager.enumerator(
                    at: diskCacheURL,
                    includingPropertiesForKeys: resourceKeys,
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator2 {
                        if let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                           let modificationDate = resourceValues.contentModificationDate,
                           let fileSize = resourceValues.fileSize {
                            allFiles.append((fileURL, modificationDate, Int64(fileSize)))
                        }
                    }
                }
                
                // Sort by date (oldest first)
                allFiles.sort { $0.1 < $1.1 }
                
                // Delete until under limit
                var currentSize = totalSize
                for (fileURL, _, fileSize) in allFiles {
                    if currentSize <= maxSize { break }
                    try? fileManager.removeItem(at: fileURL)
                    currentSize -= fileSize
                }
            } else {
                // Just delete old files
                for (fileURL, _) in filesToDelete {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
    
    // MARK: - URL Utilities
    
    private func cleanURL(_ urlString: String) -> String {
        var cleaned = urlString
            .replacingOccurrences(of: "http://", with: "https://")
        
        // Remove all zoom parameters
        let zoomPatterns = [
            "&zoom=10", "&zoom=9", "&zoom=8", "&zoom=7", "&zoom=6",
            "&zoom=5", "&zoom=4", "&zoom=3", "&zoom=2", "&zoom=1", "&zoom=0",
            "?zoom=10", "?zoom=9", "?zoom=8", "?zoom=7", "?zoom=6",
            "?zoom=5", "?zoom=4", "?zoom=3", "?zoom=2", "?zoom=1", "?zoom=0"
        ]
        
        for pattern in zoomPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
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
    
    private func appendZoomParameter(to urlString: String, zoom: Int) -> String {
        let separator = urlString.contains("?") ? "&" : "?"
        return "\(urlString)\(separator)zoom=\(zoom)"
    }
    
    // MARK: - Public Utilities
    
    /// Clear all caches (memory and disk)
    public func clearAllCaches() {
        Self.imageCache.removeAllObjects()
        Self.thumbnailCache.removeAllObjects()
        
        // Clear disk cache
        if let diskCacheURL = diskCacheURL {
            try? FileManager.default.removeItem(at: diskCacheURL)
            setupDiskCache()
        }
        
        print("✅ Cleared all caches")
    }
    
    /// Batch preload covers for better performance
    public func preloadCovers(_ urls: [String]) {
        Task {
            // Limit concurrent loads to prevent overwhelming the server
            let maxConcurrent = 3
            
            await withTaskGroup(of: Void.self) { group in
                for (index, url) in urls.enumerated() {
                    // Throttle the requests
                    if index % maxConcurrent == 0 && index > 0 {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay every 3 requests
                    }
                    
                    group.addTask {
                        _ = await self.loadThumbnail(from: url, targetSize: CGSize(width: 200, height: 300))
                    }
                }
            }
        }
    }
    
    /// Force refresh a cover image (useful for broken URLs)
    public func refreshCover(for urlString: String) async -> UIImage? {
        let cleanedURL = cleanURL(urlString)
        
        // Clear from all caches
        let thumbKey = "\(cleanedURL)_thumb" as NSString
        let fullKey = "\(cleanedURL)_full" as NSString
        
        Self.thumbnailCache.removeObject(forKey: thumbKey)
        Self.imageCache.removeObject(forKey: fullKey)
        // Note: quickImageCache is in SharedBookCoverView, not here
        
        // Remove from disk
        if let diskCacheURL = diskCacheURL {
            let thumbPath = diskCacheURL.appendingPathComponent(thumbKey as String)
            let fullPath = diskCacheURL.appendingPathComponent(fullKey as String)
            try? FileManager.default.removeItem(at: thumbPath)
            try? FileManager.default.removeItem(at: fullPath)
        }
        
        print("🔄 Refreshing cover: \(urlString.suffix(50))")
        
        // Re-download
        return await loadFullImage(from: urlString)
    }
    
    /// Get cache statistics
    public func getCacheStats() -> (memoryUsage: Int, diskUsage: Int64) {
        // This is approximate - NSCache doesn't expose actual usage
        let memoryUsage = (Self.imageCache.totalCostLimit / 2) + (Self.thumbnailCache.totalCostLimit / 2)
        
        var diskUsage: Int64 = 0
        if let diskCacheURL = diskCacheURL,
           let enumerator = FileManager.default.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey]
           ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    diskUsage += Int64(size)
                }
            }
        }
        
        return (memoryUsage, diskUsage)
    }
}

// MARK: - Backward Compatibility

extension SharedBookCoverManager {
    /// Backward compatible method
    public func getCachedImage(for coverURL: String?, quality: ImageQuality = .high) -> UIImage? {
        guard let coverURL = coverURL else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        let cacheKey = quality == .high ? "\(cleanedURL)_full" : "\(cleanedURL)_thumb"
        
        if quality == .high {
            return Self.imageCache.object(forKey: cacheKey as NSString)
        } else {
            return Self.thumbnailCache.object(forKey: cacheKey as NSString)
        }
    }
    
    public enum ImageQuality {
        case low   // Thumbnail
        case high  // Full image
    }
}