import SwiftUI
import UIKit
import Combine

/// Manager for progressive book cover image loading with caching
@MainActor
public class SharedBookCoverManager: ObservableObject {
    static let shared = SharedBookCoverManager()
    
    // Cache for both quality levels
    private var imageCache: [String: UIImage] = [:]
    
    // Active loading tasks to prevent duplicate requests
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    
    private init() {}
    
    /// Load image progressively - first low quality, then high quality
    /// - Parameters:
    ///   - coverURL: The base cover URL from the book
    ///   - onLowQualityLoaded: Called when low quality image is ready
    ///   - onHighQualityLoaded: Called when high quality image is ready
    public func loadProgressiveImage(
        from coverURL: String?,
        onLowQualityLoaded: @escaping (UIImage) -> Void,
        onHighQualityLoaded: @escaping (UIImage) -> Void
    ) {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return }
        
        // Clean the base URL by removing ALL zoom parameters
        let cleanURL = cleanURL(coverURL)
        
        // Generate cache keys
        let lowQualityCacheKey = "\(cleanURL)_low"
        let highQualityCacheKey = "\(cleanURL)_high"
        
        // Check cache first
        if let cachedHighQuality = imageCache[highQualityCacheKey] {
            print("✅ Found cached high quality image")
            onLowQualityLoaded(cachedHighQuality)
            onHighQualityLoaded(cachedHighQuality)
            return
        }
        
        if let cachedLowQuality = imageCache[lowQualityCacheKey] {
            print("✅ Found cached low quality image")
            onLowQualityLoaded(cachedLowQuality)
        }
        
        // Load low quality first (no zoom parameter)
        Task {
            if let lowQualityImage = await loadImage(from: cleanURL, cacheKey: lowQualityCacheKey) {
                onLowQualityLoaded(lowQualityImage)
            }
        }
        
        // Load high quality in background (with zoom=5)
        Task {
            let highQualityURL = appendZoomParameter(to: cleanURL, zoom: 5)
            if let highQualityImage = await loadImage(from: highQualityURL, cacheKey: highQualityCacheKey) {
                onHighQualityLoaded(highQualityImage)
            }
        }
    }
    
    /// Load a single image with caching
    private func loadImage(from urlString: String, cacheKey: String) async -> UIImage? {
        // Check if already loading
        if let existingTask = activeTasks[cacheKey] {
            return await existingTask.value
        }
        
        // Check cache
        if let cachedImage = imageCache[cacheKey] {
            return cachedImage
        }
        
        // Create loading task
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                return nil
            }
            
            do {
                print("📥 Loading image from: \(urlString)")
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let image = UIImage(data: data) {
                    // Cache the image
                    imageCache[cacheKey] = image
                    print("✅ Loaded and cached image (\(cacheKey)): \(image.size)")
                    return image
                }
            } catch {
                print("❌ Failed to load image: \(error)")
            }
            
            return nil
        }
        
        // Store active task
        activeTasks[cacheKey] = task
        
        // Wait for result
        let result = await task.value
        
        // Clean up
        activeTasks.removeValue(forKey: cacheKey)
        
        return result
    }
    
    /// Clean URL by removing ALL zoom parameters
    private func cleanURL(_ urlString: String) -> String {
        var cleaned = urlString
            .replacingOccurrences(of: "http://", with: "https://")
        
        // Remove all zoom parameters
        let zoomPatterns = [
            "&zoom=5", "&zoom=4", "&zoom=3", "&zoom=2", "&zoom=1",
            "?zoom=5", "?zoom=4", "?zoom=3", "?zoom=2", "?zoom=1",
            "zoom=5", "zoom=4", "zoom=3", "zoom=2", "zoom=1"
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
    
    /// Append zoom parameter to URL
    private func appendZoomParameter(to urlString: String, zoom: Int) -> String {
        let separator = urlString.contains("?") ? "&" : "?"
        return "\(urlString)\(separator)zoom=\(zoom)"
    }
    
    /// Clear all caches
    public func clearCache() {
        imageCache.removeAll()
        print("Cleared SharedBookCoverManager cache")
    }
    
    /// Get cached image if available
    public func getCachedImage(for coverURL: String?, quality: ImageQuality = .high) -> UIImage? {
        guard let coverURL = coverURL else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        let cacheKey = quality == .high ? "\(cleanedURL)_high" : "\(cleanedURL)_low"
        
        return imageCache[cacheKey]
    }
    
    /// Image quality levels
    public enum ImageQuality {
        case low   // No zoom parameter
        case high  // zoom=5
    }
}

// MARK: - Convenience Extensions

extension SharedBookCoverManager {
    /// Load image with async/await interface
    public func loadImage(from coverURL: String?, quality: ImageQuality = .high) async -> UIImage? {
        guard let coverURL = coverURL else { return nil }
        
        let cleanedURL = cleanURL(coverURL)
        let urlString = quality == .high ? appendZoomParameter(to: cleanedURL, zoom: 5) : cleanedURL
        let cacheKey = quality == .high ? "\(cleanedURL)_high" : "\(cleanedURL)_low"
        
        return await loadImage(from: urlString, cacheKey: cacheKey)
    }
    
    /// Simple method to get URL without zoom parameter
    public func getCleanURL(from coverURL: String?) -> String? {
        guard let coverURL = coverURL else { return nil }
        return cleanURL(coverURL)
    }
}