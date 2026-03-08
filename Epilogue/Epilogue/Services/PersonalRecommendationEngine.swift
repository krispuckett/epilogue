import Foundation
import SwiftData

// MARK: - Personal Recommendation Engine
/// Finds books that "feel like" a given book based on the reader's personal engagement,
/// not generic metadata. Uses BookDNA profiles to compute similarity.

@MainActor
final class PersonalRecommendationEngine {
    static let shared = PersonalRecommendationEngine()

    private init() {}

    // MARK: - Public API

    /// Find books similar to a given BookDNA from a pool of all BookDNAs.
    /// Returns (BookDNA, similarity score) pairs sorted by descending similarity.
    func findSimilarBooks(
        to sourceDNA: BookDNA,
        allDNAs: [BookDNA],
        limit: Int = 5
    ) -> [(BookDNA, Double)] {
        let candidates = allDNAs.filter { $0.bookModelId != sourceDNA.bookModelId }

        let scored: [(BookDNA, Double)] = candidates.compactMap { candidate in
            let score = computeSimilarity(source: sourceDNA, candidate: candidate)
            // Only include meaningful matches (> 10% similarity)
            guard score > 0.1 else { return nil }
            return (candidate, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    /// High-level recommendation call: fetch BookDNA for a book, compare against all others,
    /// return human-readable recommendations.
    func getRecommendations(
        for bookModelId: String,
        modelContext: ModelContext
    ) -> [(bookTitle: String, bookAuthor: String, similarity: Double, reason: String)] {

        // Fetch source BookDNA
        var sourceDescriptor = FetchDescriptor<BookDNA>(
            predicate: #Predicate { $0.bookModelId == bookModelId }
        )
        sourceDescriptor.fetchLimit = 1
        guard let sourceDNA = try? modelContext.fetch(sourceDescriptor).first else {
            return []
        }

        // Fetch all BookDNAs
        let allDescriptor = FetchDescriptor<BookDNA>()
        guard let allDNAs = try? modelContext.fetch(allDescriptor), allDNAs.count > 1 else {
            return []
        }

        let matches = findSimilarBooks(to: sourceDNA, allDNAs: allDNAs)

        return matches.map { (dna, score) in
            let reason = buildReason(source: sourceDNA, match: dna)
            return (
                bookTitle: dna.bookTitle,
                bookAuthor: dna.bookAuthor,
                similarity: score,
                reason: reason
            )
        }
    }

    // MARK: - Similarity Computation

    /// Weighted similarity: themes 40%, tone 30%, pace 15%, resonance 15%.
    private func computeSimilarity(source: BookDNA, candidate: BookDNA) -> Double {
        let themeScore = themeOverlap(source: source, candidate: candidate)
        let toneScore = toneOverlap(source: source, candidate: candidate)
        let paceScore = paceMatch(source: source, candidate: candidate)
        let resonanceScore = resonanceMatch(source: source, candidate: candidate)

        return themeScore * 0.40
             + toneScore * 0.30
             + paceScore * 0.15
             + resonanceScore * 0.15
    }

    /// Jaccard similarity on theme keys (ignoring weights for now).
    private func themeOverlap(source: BookDNA, candidate: BookDNA) -> Double {
        let sourceThemes = Set(source.themeWeights.map { extractThemeKey($0) })
        let candidateThemes = Set(candidate.themeWeights.map { extractThemeKey($0) })

        guard !sourceThemes.isEmpty || !candidateThemes.isEmpty else { return 0 }

        let intersection = sourceThemes.intersection(candidateThemes).count
        let union = sourceThemes.union(candidateThemes).count

        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    /// Jaccard similarity on tone tags.
    private func toneOverlap(source: BookDNA, candidate: BookDNA) -> Double {
        let sourceTones = Set(source.toneTags)
        let candidateTones = Set(candidate.toneTags)

        guard !sourceTones.isEmpty || !candidateTones.isEmpty else { return 0 }

        let intersection = sourceTones.intersection(candidateTones).count
        let union = sourceTones.union(candidateTones).count

        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    /// Pace profile match: exact = 1.0, adjacent = 0.5, opposite = 0.
    private func paceMatch(source: BookDNA, candidate: BookDNA) -> Double {
        if source.paceProfile == candidate.paceProfile { return 1.0 }

        // Define adjacency
        let paceOrder = ["fast", "moderate", "meditative"]
        guard let sourceIdx = paceOrder.firstIndex(of: source.paceProfile),
              let candidateIdx = paceOrder.firstIndex(of: candidate.paceProfile) else {
            // "variable" is partially compatible with everything
            if source.paceProfile == "variable" || candidate.paceProfile == "variable" {
                return 0.4
            }
            return 0
        }

        let distance = abs(sourceIdx - candidateIdx)
        return distance == 1 ? 0.5 : 0.0
    }

    /// Resonance match: 1.0 minus the absolute difference between resonance scores.
    private func resonanceMatch(source: BookDNA, candidate: BookDNA) -> Double {
        return max(0, 1.0 - abs(source.personalResonance - candidate.personalResonance))
    }

    // MARK: - Helpers

    /// Extract just the theme key from a "theme:weight" string.
    private func extractThemeKey(_ themeWeight: String) -> String {
        let parts = themeWeight.split(separator: ":")
        return parts.first.map(String.init) ?? themeWeight
    }

    /// Build a human-readable reason for why two books are similar.
    private func buildReason(source: BookDNA, match: BookDNA) -> String {
        var reasons: [String] = []

        // Shared themes
        let sourceThemes = Set(source.themeWeights.map { extractThemeKey($0) })
        let matchThemes = Set(match.themeWeights.map { extractThemeKey($0) })
        let sharedThemes = sourceThemes.intersection(matchThemes)
        if !sharedThemes.isEmpty {
            let themeList = sharedThemes.prefix(3).joined(separator: ", ")
            reasons.append("Similar themes: \(themeList)")
        }

        // Shared tone
        let sharedTones = Set(source.toneTags).intersection(Set(match.toneTags))
        if !sharedTones.isEmpty {
            let toneList = sharedTones.prefix(2).joined(separator: ", ")
            reasons.append("Shared tone: \(toneList)")
        }

        // Same pace
        if source.paceProfile == match.paceProfile {
            reasons.append("Same reading pace")
        }

        // Similar engagement
        if abs(source.personalResonance - match.personalResonance) < 0.2 {
            reasons.append("Similar engagement level")
        }

        if reasons.isEmpty {
            return "Related reading experience"
        }

        return reasons.joined(separator: ". ")
    }
}
