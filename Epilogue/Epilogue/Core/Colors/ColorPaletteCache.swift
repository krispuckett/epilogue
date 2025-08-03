import Foundation
import SwiftUI
import UIKit

/// Two-tier caching system for color palettes
@MainActor
public class BookColorPaletteCache {
    static let shared = BookColorPaletteCache()
    
    // MARK: - Properties
    
    /// Memory cache for quick access
    private let memoryCache = NSCache<NSString, CachedPalette>()
    
    /// Background queue for disk operations
    private let cacheQueue = DispatchQueue(label: "com.epilogue.colorpalette.cache", qos: .background)
    
    /// Directory for disk cache
    private lazy var cacheDirectory: URL? = {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let colorCacheDir = cachesDir.appendingPathComponent("ColorPalettes")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: colorCacheDir, withIntermediateDirectories: true)
        
        return colorCacheDir
    }()
    
    /// Cache warming queue
    private var warmingQueue: [String] = []
    private var isWarming = false
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryCache()
        cleanExpiredCache()
        registerForMemoryWarnings()
    }
    
    private func setupMemoryCache() {
        // Configure memory cache
        memoryCache.countLimit = 50 // Store last 50 palettes
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // Assume ~1MB per palette (very conservative)
        memoryCache.name = "ColorPaletteCache"
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
        print("⚠️ Memory warning - reducing color palette cache")
        // Reduce cache to half capacity
        memoryCache.countLimit = 25
        // This will automatically evict LRU items
    }
    
    // MARK: - Cache Operations
    
    /// Get cached palette for book ID
    public func getCachedPalette(for bookID: String) async -> ColorPalette? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: bookID as NSString) {
            print("🎨 Memory cache hit for \(bookID)")
            return cached.palette
        }
        
        // Check disk cache
        if let diskPalette = await loadFromDisk(bookID: bookID) {
            // Add to memory cache
            memoryCache.setObject(diskPalette, forKey: bookID as NSString)
            print("💾 Disk cache hit for \(bookID)")
            return diskPalette.palette
        }
        
        print("❌ Cache miss for \(bookID)")
        return nil
    }
    
    /// Cache a palette
    public func cachePalette(_ palette: ColorPalette, for bookID: String, coverURL: String? = nil) async {
        let cached = CachedPalette(
            bookID: bookID,
            palette: palette,
            coverURL: coverURL,
            timestamp: Date(),
            extractionVersion: "1.0"
        )
        
        // Add to memory cache with cost estimation
        // Rough estimate: ~1KB per palette (colors + metadata)
        let estimatedCost = 1024
        memoryCache.setObject(cached, forKey: bookID as NSString, cost: estimatedCost)
        
        // Save to disk in background
        await saveToDisk(cached)
        
        print("✅ Cached palette for \(bookID)")
    }
    
    /// Clear all caches
    public func clearCache() async {
        // Clear memory
        memoryCache.removeAllObjects()
        
        // Clear disk
        if let cacheDir = cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        print("🧹 Cleared all color palette caches")
    }
    
    // MARK: - Disk Cache Operations
    
    private func diskCacheURL(for bookID: String) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }
        
        // Use book ID as filename, sanitized for filesystem
        let sanitizedID = bookID.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        
        return cacheDir.appendingPathComponent("\(sanitizedID).json")
    }
    
    private func loadFromDisk(bookID: String) async -> CachedPalette? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let url = self?.diskCacheURL(for: bookID),
                      FileManager.default.fileExists(atPath: url.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let cached = try JSONDecoder().decode(CachedPalette.self, from: data)
                    
                    // Check if expired (30 days)
                    if cached.isExpired {
                        try? FileManager.default.removeItem(at: url)
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: cached)
                    }
                } catch {
                    print("❌ Failed to load cached palette: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func saveToDisk(_ cached: CachedPalette) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let url = self?.diskCacheURL(for: cached.bookID) else {
                    continuation.resume()
                    return
                }
                
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(cached)
                    try data.write(to: url)
                } catch {
                    print("❌ Failed to save palette to disk: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private func cleanExpiredCache() {
        cacheQueue.async { [weak self] in
            guard let cacheDir = self?.cacheDirectory else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
                let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                
                for file in files {
                    if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                       let creationDate = attributes.creationDate,
                       creationDate < thirtyDaysAgo {
                        try? FileManager.default.removeItem(at: file)
                        print("🧹 Cleaned expired cache: \(file.lastPathComponent)")
                    }
                }
            } catch {
                print("❌ Failed to clean cache: \(error)")
            }
        }
    }
    
    // MARK: - Cache Warming
    
    /// Warm cache for visible books
    public func warmCache(for bookIDs: [String], coverURLs: [String: String]) async {
        // Add to warming queue
        warmingQueue.append(contentsOf: bookIDs)
        
        guard !isWarming else { return }
        isWarming = true
        
        // Process queue
        while !warmingQueue.isEmpty {
            let bookID = warmingQueue.removeFirst()
            
            // Skip if already cached
            if await getCachedPalette(for: bookID) != nil {
                continue
            }
            
            // Extract colors if we have a cover URL
            if let coverURL = coverURLs[bookID] {
                await extractAndCachePalette(bookID: bookID, coverURL: coverURL)
            }
            
            // Small delay to avoid overwhelming the system
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        isWarming = false
    }
    
    private func extractAndCachePalette(bookID: String, coverURL: String) async {
        // Load full image using SharedBookCoverManager
        guard let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL) else {
            return
        }
        
        // Extract colors
        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: image, imageSource: bookID)
            
            // Cache the result
            await cachePalette(palette, for: bookID, coverURL: coverURL)
        } catch {
            print("❌ Failed to extract colors for warming: \(error)")
        }
    }
    
    // MARK: - Debug Methods
    
    /// Get cache statistics
    public func getCacheStats() -> CacheStats {
        // We can't get exact memory cache count from NSCache
        // So we'll just track disk cache for now
        let memoryCacheCount = 0 // NSCache doesn't expose count
        var diskCacheCount = 0
        var totalDiskSize: Int64 = 0
        
        if let cacheDir = cacheDirectory {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
                diskCacheCount = files.count
                
                for file in files {
                    if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
                       let size = attributes.fileSize {
                        totalDiskSize += Int64(size)
                    }
                }
            } catch {
                print("❌ Failed to get cache stats: \(error)")
            }
        }
        
        return CacheStats(
            memoryCacheCount: memoryCacheCount,
            diskCacheCount: diskCacheCount,
            totalDiskSizeBytes: totalDiskSize
        )
    }
}

// MARK: - Supporting Types

/// Cached palette with metadata
private class CachedPalette: NSObject, Codable {
    let bookID: String
    let palette: ColorPalette
    let coverURL: String?
    let timestamp: Date
    let extractionVersion: String
    
    var isExpired: Bool {
        timestamp.timeIntervalSinceNow < -30 * 24 * 60 * 60 // 30 days
    }
    
    init(bookID: String, palette: ColorPalette, coverURL: String?, timestamp: Date, extractionVersion: String) {
        self.bookID = bookID
        self.palette = palette
        self.coverURL = coverURL
        self.timestamp = timestamp
        self.extractionVersion = extractionVersion
    }
}

/// Cache statistics
public struct CacheStats {
    let memoryCacheCount: Int
    let diskCacheCount: Int
    let totalDiskSizeBytes: Int64
    
    var totalDiskSizeMB: Double {
        Double(totalDiskSizeBytes) / 1024 / 1024
    }
}

// MARK: - NSCache Extension

// Note: NSCache doesn't expose count directly, so we track it separately in BookColorPaletteCache

// MARK: - ColorPalette Codable Extension

extension ColorPalette: Codable {
    enum CodingKeys: String, CodingKey {
        case primary, secondary, accent, background, textColor
        case luminance, isMonochromatic, extractionQuality
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode colors as hex strings
        let primaryHex = try container.decode(String.self, forKey: .primary)
        let secondaryHex = try container.decode(String.self, forKey: .secondary)
        let accentHex = try container.decode(String.self, forKey: .accent)
        let backgroundHex = try container.decode(String.self, forKey: .background)
        let textColorHex = try container.decode(String.self, forKey: .textColor)
        
        self.init(
            primary: Color(hex: primaryHex) ?? .black,
            secondary: Color(hex: secondaryHex) ?? .gray,
            accent: Color(hex: accentHex) ?? .blue,
            background: Color(hex: backgroundHex) ?? .black,
            textColor: Color(hex: textColorHex) ?? .white,
            luminance: try container.decode(Double.self, forKey: .luminance),
            isMonochromatic: try container.decode(Bool.self, forKey: .isMonochromatic),
            extractionQuality: try container.decode(Double.self, forKey: .extractionQuality)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode colors as hex strings
        try container.encode(primary.bookHexString, forKey: .primary)
        try container.encode(secondary.bookHexString, forKey: .secondary)
        try container.encode(accent.bookHexString, forKey: .accent)
        try container.encode(background.bookHexString, forKey: .background)
        try container.encode(textColor.bookHexString, forKey: .textColor)
        try container.encode(luminance, forKey: .luminance)
        try container.encode(isMonochromatic, forKey: .isMonochromatic)
        try container.encode(extractionQuality, forKey: .extractionQuality)
    }
}

// MARK: - Color Hex Extensions

extension Color {
    // Using different name to avoid conflicts
    var bookHexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format: "#%06x", rgb)
    }
}