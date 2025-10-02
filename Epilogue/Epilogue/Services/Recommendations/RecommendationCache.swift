import Foundation

/// Caches taste profiles and recommendations for 30 days
actor RecommendationCache {
    static let shared = RecommendationCache()

    private init() {}

    // MARK: - Cache Entry

    struct CachedEntry: Codable {
        let profile: LibraryTasteAnalyzer.TasteProfile
        let recommendations: [RecommendationEngine.Recommendation]
        let libraryBookCount: Int  // Detect significant library changes
        let createdAt: Date

        var isExpired: Bool {
            let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: createdAt) ?? createdAt
            return Date() > expiryDate
        }

        func needsRefresh(currentBookCount: Int) -> Bool {
            // Refresh if library grew by 25% or more
            let growthPercentage = abs(Double(currentBookCount - libraryBookCount) / Double(libraryBookCount))
            return growthPercentage >= 0.25
        }
    }

    // MARK: - Storage

    private let cacheKey = "personalizedRecommendationsCache"

    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("\(cacheKey).json")
    }

    // MARK: - Save

    func save(profile: LibraryTasteAnalyzer.TasteProfile, recommendations: [RecommendationEngine.Recommendation], bookCount: Int) async {
        let entry = CachedEntry(
            profile: profile,
            recommendations: recommendations,
            libraryBookCount: bookCount,
            createdAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL)
            print("✅ Cached recommendations (30 day expiry)")
        } catch {
            print("❌ Failed to cache recommendations: \(error)")
        }
    }

    // MARK: - Load

    func load(currentBookCount: Int) async -> CachedEntry? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️ No cached recommendations found")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let entry = try JSONDecoder().decode(CachedEntry.self, from: data)

            // Check expiry
            if entry.isExpired {
                print("⏰ Cache expired (30 days old)")
                await clear()
                return nil
            }

            // Check if library changed significantly
            if entry.needsRefresh(currentBookCount: currentBookCount) {
                print("📚 Library changed significantly (+25%), refreshing...")
                await clear()
                return nil
            }

            print("✅ Loaded cached recommendations (\(entry.recommendations.count) books)")
            let age = Date().timeIntervalSince(entry.createdAt)
            let daysOld = Int(age / 86400)
            print("   Cache age: \(daysOld) days old")

            return entry

        } catch {
            print("❌ Failed to load cache: \(error)")
            await clear()
            return nil
        }
    }

    // MARK: - Clear

    func clear() async {
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Cleared recommendation cache")
    }
}
