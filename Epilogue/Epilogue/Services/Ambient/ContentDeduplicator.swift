import Foundation
import NaturalLanguage

/// High-performance content deduplication with fuzzy matching
/// Designed for iOS 26 with O(1) exact matching and intelligent similarity detection
@MainActor
public class ContentDeduplicator {
    // MARK: - Properties
    private let exactMatchCache = NSCache<NSString, NSNumber>()
    private var recentContent: [(text: String, timestamp: Date)] = []
    private let maxRecentItems = 10
    private let similarityThreshold: Double = 0.85
    
    // iOS 26 NL embedding for semantic similarity
    private let embedder = NLEmbedding.sentenceEmbedding(for: .english)
    
    // MARK: - Initialization
    init() {
        exactMatchCache.countLimit = 1000
        exactMatchCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    // MARK: - Public Methods
    
    /// Check if content is duplicate using exact and fuzzy matching
    /// - Parameter text: The text to check
    /// - Returns: true if duplicate, false if unique
    public func isDuplicate(_ text: String) -> Bool {
        let normalized = normalize(text)
        
        // 1. Exact match check (O(1))
        if exactMatchCache.object(forKey: normalized as NSString) != nil {
            print("🔁 Exact duplicate found: \(text.prefix(30))...")
            return true
        }
        
        // 2. Fuzzy match only for recent items (O(10) max)
        for recent in recentContent.suffix(maxRecentItems) {
            if isSimilar(normalized, to: recent.text) {
                print("🔄 Similar content found: \(text.prefix(30))...")
                return true
            }
        }
        
        // 3. Not a duplicate - cache it
        markAsSeen(normalized)
        return false
    }
    
    /// Mark content as seen for future deduplication
    public func markAsSeen(_ text: String) {
        let normalized = normalize(text)
        
        // Add to exact match cache
        exactMatchCache.setObject(1, forKey: normalized as NSString)
        
        // Add to recent content for fuzzy matching
        recentContent.append((text: normalized, timestamp: Date()))
        
        // Trim old content
        if recentContent.count > maxRecentItems * 2 {
            recentContent = Array(recentContent.suffix(maxRecentItems))
        }
    }
    
    /// Clear all deduplication history
    public func clearHistory() {
        exactMatchCache.removeAllObjects()
        recentContent.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Normalize text for comparison
    private func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// Check if two texts are similar using multiple strategies
    private func isSimilar(_ text1: String, to text2: String) -> Bool {
        // Quick length check
        let lengthRatio = Double(min(text1.count, text2.count)) / Double(max(text1.count, text2.count))
        if lengthRatio < 0.5 { return false }
        
        // Try iOS 26 semantic similarity first
        if let similarity = semanticSimilarity(text1, text2), similarity > similarityThreshold {
            return true
        }
        
        // Fallback to Levenshtein distance for short texts
        if text1.count < 100 {
            let distance = levenshteinDistance(text1, text2)
            let maxLength = max(text1.count, text2.count)
            let similarity = 1.0 - (Double(distance) / Double(maxLength))
            return similarity > similarityThreshold
        }
        
        return false
    }
    
    /// Calculate semantic similarity using iOS 26 NL embeddings
    private func semanticSimilarity(_ text1: String, _ text2: String) -> Double? {
        guard let embedder = embedder else { return nil }
        
        guard let vector1 = embedder.vector(for: text1),
              let vector2 = embedder.vector(for: text2) else {
            return nil
        }
        
        // Cosine similarity
        var dotProduct = 0.0
        var norm1 = 0.0
        var norm2 = 0.0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            norm1 += vector1[i] * vector1[i]
            norm2 += vector2[i] * vector2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    
    /// Optimized Levenshtein distance for short strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1[s1.index(s1.startIndex, offsetBy: i-1)] == 
                          s2[s2.index(s2.startIndex, offsetBy: j-1)] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Question-Specific Deduplication
extension ContentDeduplicator {
    /// Special handling for questions to prevent duplicate AI calls
    public func isQuestionDuplicate(_ question: String, within timeWindow: TimeInterval = 1.0) -> Bool {
        // Don't deduplicate questions at all - let them flow through
        // The AI orchestrator handles caching and deduplication internally
        // This allows natural question evolution and re-asking
        
        // Mark as seen for tracking but never block
        markAsSeen(normalize(question))
        return false
    }
}