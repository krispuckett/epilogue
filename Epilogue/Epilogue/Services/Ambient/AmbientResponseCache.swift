import Foundation
import CryptoKit
import UIKit

/// High-performance response cache for instant AI responses
/// Uses iOS 26 capabilities for optimal memory management
@MainActor
public class AmbientResponseCache {
    public static let shared = AmbientResponseCache()
    
    // MARK: - Properties
    private let memoryCache = NSCache<NSString, CachedResponse>()
    private let diskCacheURL: URL?
    private let cacheQueue = DispatchQueue(label: "ambient.cache", qos: .userInitiated)
    
    // Cache configuration
    private let maxMemoryItems = 100
    private let maxDiskSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Types
    public class CachedResponse: NSObject {
        let response: String
        let timestamp: Date
        let bookContext: String?
        let confidence: Float
        let source: ResponseSource
        
        public enum ResponseSource {
            case local      // iOS 26 Foundation Models
            case cloud      // Perplexity Sonar
            case cached     // Previously cached
        }
        
        init(response: String, bookContext: String? = nil, confidence: Float = 1.0, source: ResponseSource = .cached) {
            self.response = response
            self.timestamp = Date()
            self.bookContext = bookContext
            self.confidence = confidence
            self.source = source
        }
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 24 * 60 * 60
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Configure memory cache
        memoryCache.countLimit = maxMemoryItems
        memoryCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        // Setup disk cache
        if let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            diskCacheURL = cacheDir.appendingPathComponent("AmbientResponses", isDirectory: true)
            setupDiskCache()
        } else {
            diskCacheURL = nil
        }
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Get cached response instantly if available
    public func getCachedResponse(for question: String, bookContext: String? = nil) -> String? {
        let key = cacheKey(for: question, bookContext: bookContext)
        
        // Check memory cache first (instant)
        if let cached = memoryCache.object(forKey: key as NSString) {
            if !cached.isExpired {
                print("💨 Instant cache hit for: \(question.prefix(30))...")
                return cached.response
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }
        
        // Check disk cache (fast)
        if let response = loadFromDisk(key: key) {
            print("💾 Disk cache hit for: \(question.prefix(30))...")
            return response
        }
        
        return nil
    }
    
    /// Precache response for instant future display
    public func cacheResponse(_ response: String, for question: String, bookContext: String? = nil, source: CachedResponse.ResponseSource = .cached) {
        let key = cacheKey(for: question, bookContext: bookContext)
        
        // Create cached response
        let cached = CachedResponse(
            response: response,
            bookContext: bookContext,
            confidence: 1.0,
            source: source
        )
        
        // Store in memory (instant access)
        memoryCache.setObject(cached, forKey: key as NSString, cost: response.count)
        
        // Store on disk (persistent)
        Task { @MainActor [weak self] in
            self?.saveToDisk(response: response, key: key)
        }
        
        print("✅ Cached response for: \(question.prefix(30))...")
    }
    
    /// Preload common questions for a book
    public func preloadCommonQuestions(for bookTitle: String) async {
        let commonQuestions = [
            "What are the main themes?",
            "What is the significance of the title?",
            "How does this chapter relate to the overall narrative?",
            "What symbolism is present?",
            "What is the author trying to convey?"
        ]
        
        // Generate contextual responses using iOS 26 Foundation Models
        for question in commonQuestions {
            let contextualQuestion = "\(question) (Context: \(bookTitle))"
            
            // Check if already cached
            if getCachedResponse(for: contextualQuestion, bookContext: bookTitle) != nil {
                continue
            }
            
            // Generate and cache response
            // This would use Foundation Models in production
            let response = generateLocalResponse(for: contextualQuestion, bookContext: bookTitle)
            cacheResponse(response, for: contextualQuestion, bookContext: bookTitle, source: .local)
        }
    }
    
    /// Clear expired cache entries
    public func cleanExpiredEntries() {
        memoryCache.removeAllObjects()
        
        Task { @MainActor [weak self] in
            self?.cleanDiskCache()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDiskCache() {
        guard let diskCacheURL = diskCacheURL else { return }
        
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func cacheKey(for question: String, bookContext: String?) -> String {
        var hasher = SHA256()
        hasher.update(data: question.lowercased().data(using: .utf8) ?? Data())
        if let context = bookContext {
            hasher.update(data: context.data(using: .utf8) ?? Data())
        }
        let hash = hasher.finalize()
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func saveToDisk(response: String, key: String) {
        guard let diskCacheURL = diskCacheURL else { return }
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        let data = response.data(using: .utf8)
        
        try? data?.write(to: fileURL)
    }
    
    private func loadFromDisk(key: String) -> String? {
        guard let diskCacheURL = diskCacheURL else { return nil }
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let response = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Check if expired
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxAge {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        
        // Cache in memory for next access
        let cached = CachedResponse(response: response)
        memoryCache.setObject(cached, forKey: key as NSString, cost: response.count)
        
        return response
    }
    
    private func cleanDiskCache() {
        guard let diskCacheURL = diskCacheURL else { return }
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        
        var totalSize: Int64 = 0
        var filesToDelete: [URL] = []
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = resourceValues.contentModificationDate,
                  let fileSize = resourceValues.fileSize else { continue }
            
            // Remove expired files
            if Date().timeIntervalSince(modificationDate) > maxAge {
                filesToDelete.append(fileURL)
            } else {
                totalSize += Int64(fileSize)
            }
        }
        
        // Delete expired files
        for fileURL in filesToDelete {
            try? fileManager.removeItem(at: fileURL)
        }
        
        // If still over size limit, remove oldest files
        if totalSize > maxDiskSize {
            // Implementation would sort by date and remove oldest
        }
    }
    
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        print("⚠️ Memory warning: Cleared response cache")
    }
    
    // Placeholder for local response generation
    private func generateLocalResponse(for question: String, bookContext: String?) -> String {
        // In production, this would use iOS 26 Foundation Models
        return "This would be a thoughtful response about \(bookContext ?? "your reading") generated using on-device AI."
    }
}