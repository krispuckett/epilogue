import Foundation
import NaturalLanguage
import Accelerate

class SemanticSimilarityMatcher {
    
    private let embedder = NLEmbedding.wordEmbedding(for: .english)
    private let tokenizer = NLTokenizer(unit: .word)
    
    // MARK: - Embedding Generation
    
    func generateEmbedding(for text: String) async throws -> [Float] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                let embedding = self.createLocalEmbedding(for: text)
                continuation.resume(returning: embedding)
            }
        }
    }
    
    private func createLocalEmbedding(for text: String) -> [Float] {
        // Tokenize the text
        tokenizer.string = text
        var tokens: [String] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange]).lowercased()
            tokens.append(token)
            return true
        }
        
        // Get embeddings for each token
        var embeddings: [[Float]] = []
        
        for token in tokens {
            if let vector = embedder?.vector(for: token) {
                embeddings.append(vector)
            }
        }
        
        // Average the embeddings
        guard !embeddings.isEmpty else {
            // Return a zero vector if no embeddings found
            return Array(repeating: 0, count: 300)
        }
        
        let dimension = embeddings[0].count
        var averaged = Array(repeating: Float(0), count: dimension)
        
        for embedding in embeddings {
            for (index, value) in embedding.enumerated() {
                averaged[index] += value
            }
        }
        
        let count = Float(embeddings.count)
        for index in 0..<dimension {
            averaged[index] /= count
        }
        
        // Normalize the vector
        return normalize(averaged)
    }
    
    // MARK: - Similarity Calculation
    
    func cosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0 }
        
        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0
        
        vDSP_dotpr(vectorA, 1, vectorB, 1, &dotProduct, vDSP_Length(vectorA.count))
        vDSP_svesq(vectorA, 1, &magnitudeA, vDSP_Length(vectorA.count))
        vDSP_svesq(vectorB, 1, &magnitudeB, vDSP_Length(vectorB.count))
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        
        guard magnitude > 0 else { return 0 }
        
        return Double(dotProduct / magnitude)
    }
    
    func semanticSimilarity(between textA: String, and textB: String) async -> Double {
        guard let embeddingA = try? await generateEmbedding(for: textA),
              let embeddingB = try? await generateEmbedding(for: textB) else {
            return 0
        }
        
        return cosineSimilarity(embeddingA, embeddingB)
    }
    
    // MARK: - Batch Similarity
    
    func findMostSimilar(
        query: String,
        from candidates: [String],
        threshold: Double = 0.7
    ) async -> [(text: String, similarity: Double)] {
        
        guard let queryEmbedding = try? await generateEmbedding(for: query) else {
            return []
        }
        
        var results: [(text: String, similarity: Double)] = []
        
        await withTaskGroup(of: (String, Double)?.self) { group in
            for candidate in candidates {
                group.addTask { [weak self] in
                    guard let self = self,
                          let candidateEmbedding = try? await self.generateEmbedding(for: candidate) else {
                        return nil
                    }
                    
                    let similarity = self.cosineSimilarity(queryEmbedding, candidateEmbedding)
                    
                    if similarity >= threshold {
                        return (candidate, similarity)
                    }
                    
                    return nil
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }
        
        return results.sorted { $0.similarity > $1.similarity }
    }
    
    // MARK: - Smart Query Matching
    
    func findBestMatch(
        for query: String,
        in cachedQueries: [(query: String, response: String, embedding: [Float]?)],
        minSimilarity: Double = 0.8
    ) async -> (query: String, response: String, similarity: Double)? {
        
        guard let queryEmbedding = try? await generateEmbedding(for: query) else {
            return nil
        }
        
        var bestMatch: (query: String, response: String, similarity: Double)?
        var highestSimilarity = minSimilarity
        
        for cached in cachedQueries {
            let similarity: Double
            
            if let cachedEmbedding = cached.embedding {
                // Use pre-computed embedding
                similarity = cosineSimilarity(queryEmbedding, cachedEmbedding)
            } else {
                // Compute on the fly
                similarity = await semanticSimilarity(between: query, and: cached.query)
            }
            
            if similarity > highestSimilarity {
                highestSimilarity = similarity
                bestMatch = (cached.query, cached.response, similarity)
            }
        }
        
        return bestMatch
    }
    
    // MARK: - Query Expansion
    
    func expandQuery(original: String) -> [String] {
        var expanded: [String] = [original]
        
        // Add common variations
        let variations = generateVariations(for: original)
        expanded.append(contentsOf: variations)
        
        return expanded
    }
    
    private func generateVariations(for query: String) -> [String] {
        var variations: [String] = []
        
        // Question word variations
        let questionWords = [
            ("what", ["what's", "what is"]),
            ("how", ["how do", "how to", "how can"]),
            ("why", ["why is", "why does"]),
            ("when", ["when did", "when does"]),
            ("where", ["where is", "where does"])
        ]
        
        for (word, replacements) in questionWords {
            if query.lowercased().hasPrefix(word) {
                for replacement in replacements {
                    let variation = query.replacingOccurrences(
                        of: word,
                        with: replacement,
                        options: [.caseInsensitive, .anchored]
                    )
                    variations.append(variation)
                }
            }
        }
        
        return variations
    }
    
    // MARK: - Helper Methods
    
    private func normalize(_ vector: [Float]) -> [Float] {
        var normalized = vector
        var magnitude: Float = 0
        
        vDSP_svesq(vector, 1, &magnitude, vDSP_Length(vector.count))
        magnitude = sqrt(magnitude)
        
        guard magnitude > 0 else { return vector }
        
        var divisor = 1 / magnitude
        vDSP_vsmul(vector, 1, &divisor, &normalized, 1, vDSP_Length(vector.count))
        
        return normalized
    }
    
    // MARK: - Clustering Similar Queries
    
    func clusterQueries(_ queries: [String], threshold: Double = 0.8) async -> [[String]] {
        var clusters: [[String]] = []
        var processed = Set<String>()
        
        for query in queries {
            if processed.contains(query) { continue }
            
            var cluster = [query]
            processed.insert(query)
            
            for otherQuery in queries {
                if processed.contains(otherQuery) { continue }
                
                let similarity = await semanticSimilarity(between: query, and: otherQuery)
                if similarity >= threshold {
                    cluster.append(otherQuery)
                    processed.insert(otherQuery)
                }
            }
            
            clusters.append(cluster)
        }
        
        return clusters
    }
}