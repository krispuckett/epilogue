import Foundation
import SwiftData
import UIKit
import CryptoKit

/// Multi-source cover acquisition service with fallback chain:
/// 1. Local cache (CoverRecord)
/// 2. Google Books (enhanced resolution)
/// 3. Open Library (ISBN-based)
/// 4. iTunes Search (title+author ebook artwork)
///
/// Infrastructure only — does NOT replace existing cover display code.
@MainActor
final class CoverAcquisitionService {
    static let shared = CoverAcquisitionService()

    private var modelContainer: ModelContainer?
    private var isProcessing = false

    /// Shared URLSession with reasonable timeouts
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        #if DEBUG
        print("[CoverPipeline] Configured with ModelContainer")
        #endif
    }

    // MARK: - Public API

    /// Fetch or retrieve a cached cover for a book.
    /// Returns an existing CoverRecord from cache, or fetches from the fallback chain.
    func fetchCover(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        // 1. Local cache check
        if let cached = getCachedCover(for: bookModel.localId, modelContext: modelContext) {
            #if DEBUG
            print("[CoverPipeline] Cache hit for '\(bookModel.title)'")
            #endif
            return cached
        }

        // 2. Fetch from network sources
        return await fetchFromSources(for: bookModel, modelContext: modelContext)
    }

    /// Quick cache lookup — no network calls.
    func getCachedCover(for bookLocalId: String, modelContext: ModelContext) -> CoverRecord? {
        let predicate = #Predicate<CoverRecord> { record in
            record.bookLocalId == bookLocalId && record.imageData != nil
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        // Prefer user overrides, then highest confidence
        descriptor.sortBy = [
            SortDescriptor(\.confidenceScore, order: .reverse)
        ]

        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Force re-fetch from network, skipping cache.
    func refreshCover(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        return await fetchFromSources(for: bookModel, modelContext: modelContext)
    }

    /// Background task: fetch covers for books that have no coverImageData.
    /// Limits to `batchSize` books per launch to avoid overwhelming the network.
    func fetchMissingCovers(container: ModelContainer) async {
        let context = ModelContext(container)
        let batchSize = 10

        let predicate = #Predicate<BookModel> { book in
            book.isInLibrary && book.coverImageData == nil
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = batchSize

        guard let booksNeedingCovers = try? context.fetch(descriptor),
              !booksNeedingCovers.isEmpty else {
            #if DEBUG
            print("[CoverPipeline] No books need cover fetching")
            #endif
            return
        }

        #if DEBUG
        print("[CoverPipeline] Fetching covers for \(booksNeedingCovers.count) books")
        #endif

        for book in booksNeedingCovers {
            let _ = await fetchCover(for: book, modelContext: context)

            // Brief pause between fetches to be a good network citizen
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }

        try? context.save()

        #if DEBUG
        print("[CoverPipeline] Missing covers batch complete")
        #endif
    }

    // MARK: - Fallback Chain

    private func fetchFromSources(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        // Source 1: Google Books (enhanced resolution)
        if let record = await fetchFromGoogleBooks(for: bookModel, modelContext: modelContext) {
            #if DEBUG
            print("[CoverPipeline] Google Books cover found for '\(bookModel.title)'")
            #endif
            return record
        }

        // Source 2: Open Library (ISBN-based)
        if let record = await fetchFromOpenLibrary(for: bookModel, modelContext: modelContext) {
            #if DEBUG
            print("[CoverPipeline] Open Library cover found for '\(bookModel.title)'")
            #endif
            return record
        }

        // Source 3: iTunes Search (ebook artwork)
        if let record = await fetchFromiTunes(for: bookModel, modelContext: modelContext) {
            #if DEBUG
            print("[CoverPipeline] iTunes cover found for '\(bookModel.title)'")
            #endif
            return record
        }

        #if DEBUG
        print("[CoverPipeline] No cover found from any source for '\(bookModel.title)'")
        #endif
        return nil
    }

    // MARK: - Source 1: Google Books

    private func fetchFromGoogleBooks(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        guard let coverURL = bookModel.coverImageURL, !coverURL.isEmpty else {
            return nil
        }

        // Enhance URL for higher resolution
        let enhancedURL = enhanceGoogleBooksURL(coverURL)

        guard let url = URL(string: enhancedURL) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Validate: reject tiny images (likely placeholders)
            guard data.count >= 5_000 else {
                #if DEBUG
                print("[CoverPipeline] Google Books image too small (\(data.count) bytes), likely placeholder")
                #endif
                return nil
            }

            guard let image = UIImage(data: data) else { return nil }

            // Validate dimensions
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)

            guard width >= 200 && height >= 300 else {
                #if DEBUG
                print("[CoverPipeline] Google Books image too small: \(width)x\(height)")
                #endif
                return nil
            }

            // Compress to JPEG for storage efficiency
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

            return createAndSaveCoverRecord(
                bookModel: bookModel,
                imageData: jpegData,
                image: image,
                sourceProvider: "googleBooks",
                confidenceScore: 0.8,
                modelContext: modelContext
            )
        } catch {
            #if DEBUG
            print("[CoverPipeline] Google Books fetch error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Enhance a Google Books cover URL for higher resolution.
    private func enhanceGoogleBooksURL(_ urlString: String) -> String {
        var enhanced = urlString

        // Ensure HTTPS
        enhanced = enhanced.replacingOccurrences(of: "http://", with: "https://")

        // Add high-res parameter if it's a Google Books content URL
        if enhanced.contains("books.google.com") || enhanced.contains("googleapis.com") {
            // Replace zoom=1 with zoom=3 for higher res, or append it
            if enhanced.contains("zoom=") {
                enhanced = enhanced.replacingOccurrences(
                    of: #"zoom=\d"#,
                    with: "zoom=3",
                    options: .regularExpression
                )
            } else {
                enhanced += "&zoom=3"
            }

            // Add fife parameter for Google Books URLs
            if !enhanced.contains("fife=") {
                enhanced += "&fife=w800-h1200"
            }
        }

        return enhanced
    }

    // MARK: - Source 2: Open Library

    private func fetchFromOpenLibrary(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        guard let isbn = bookModel.isbn, !isbn.isEmpty else {
            return nil
        }

        // Open Library cover API — returns 404 if no cover (no placeholder)
        let urlString = "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Validate it's actually an image (not an error page)
            guard data.count >= 5_000 else {
                #if DEBUG
                print("[CoverPipeline] Open Library image too small (\(data.count) bytes)")
                #endif
                return nil
            }

            guard let image = UIImage(data: data) else { return nil }
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

            return createAndSaveCoverRecord(
                bookModel: bookModel,
                imageData: jpegData,
                image: image,
                sourceProvider: "openLibrary",
                confidenceScore: 0.7,
                modelContext: modelContext
            )
        } catch {
            #if DEBUG
            print("[CoverPipeline] Open Library fetch error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Source 3: iTunes Search

    private func fetchFromiTunes(for bookModel: BookModel, modelContext: ModelContext) async -> CoverRecord? {
        // Build search query from title + author
        let searchTerm = "\(bookModel.title) \(bookModel.author)"
        guard let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "https://itunes.apple.com/search?term=\(encodedTerm)&entity=ebook&limit=1"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse iTunes response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let firstResult = results.first,
                  let artworkURL = firstResult["artworkUrl100"] as? String else {
                return nil
            }

            // Replace 100x100 with 600x600 for higher resolution
            let highResURL = artworkURL.replacingOccurrences(of: "100x100", with: "600x600")
            guard let imageURL = URL(string: highResURL) else { return nil }

            let (imageData, imageResponse) = try await session.data(from: imageURL)

            guard let imgHttpResponse = imageResponse as? HTTPURLResponse,
                  imgHttpResponse.statusCode == 200,
                  imageData.count >= 5_000 else {
                return nil
            }

            guard let image = UIImage(data: imageData) else { return nil }
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

            // Lower confidence for iTunes since it's less reliable for book matching
            return createAndSaveCoverRecord(
                bookModel: bookModel,
                imageData: jpegData,
                image: image,
                sourceProvider: "iTunes",
                confidenceScore: 0.5,
                modelContext: modelContext
            )
        } catch {
            #if DEBUG
            print("[CoverPipeline] iTunes fetch error: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - CoverRecord Creation & Persistence

    private func createAndSaveCoverRecord(
        bookModel: BookModel,
        imageData: Data,
        image: UIImage,
        sourceProvider: String,
        confidenceScore: Double,
        modelContext: ModelContext
    ) -> CoverRecord {
        let record = CoverRecord(bookLocalId: bookModel.localId, sourceProvider: sourceProvider)
        record.imageData = imageData
        record.width = Int(image.size.width * image.scale)
        record.height = Int(image.size.height * image.scale)
        record.confidenceScore = confidenceScore
        record.isbn10 = extractISBN10(from: bookModel.isbn)
        record.isbn13 = extractISBN13(from: bookModel.isbn)
        record.googleVolumeId = bookModel.id
        record.imageHash = computeImageHash(imageData)

        // Generate thumbnail (200px wide)
        if let thumbnail = generateThumbnail(from: image, maxWidth: 200),
           let thumbData = thumbnail.jpegData(compressionQuality: 0.7) {
            record.thumbnailData = thumbData
        }

        // Extract dominant colors
        record.dominantColors = extractSimpleColors(from: image)

        // Persist
        modelContext.insert(record)

        // Backward compatibility: update BookModel fields
        bookModel.coverImageData = imageData
        if bookModel.extractedColors == nil || bookModel.extractedColors?.isEmpty == true {
            bookModel.extractedColors = record.dominantColors
        }

        try? modelContext.save()

        #if DEBUG
        print("[CoverPipeline] Saved CoverRecord: \(sourceProvider), \(record.width)x\(record.height), \(imageData.count / 1024)KB")
        #endif

        return record
    }

    // MARK: - Color Extraction (Simplified)

    /// Extract dominant colors from an image using a simplified approach.
    /// Returns an array of hex color strings (primary, secondary, accent, background).
    private func extractSimpleColors(from image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        // Downsample to 50x50 for fast color analysis
        let sampleSize = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        // Build simple color histogram using quantized buckets
        var colorBuckets: [String: (r: Int, g: Int, b: Int, count: Int)] = [:]

        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                let offset = (y * sampleSize + x) * 4
                let r = Int(pixelData[offset])
                let g = Int(pixelData[offset + 1])
                let b = Int(pixelData[offset + 2])
                let a = Int(pixelData[offset + 3])

                guard a > 128 else { continue }
                // Skip very dark pixels
                guard r + g + b > 30 else { continue }

                // Quantize to 8 levels per channel
                let qr = (r / 32) * 32
                let qg = (g / 32) * 32
                let qb = (b / 32) * 32
                let key = "\(qr),\(qg),\(qb)"

                if let existing = colorBuckets[key] {
                    colorBuckets[key] = (
                        r: existing.r + r,
                        g: existing.g + g,
                        b: existing.b + b,
                        count: existing.count + 1
                    )
                } else {
                    colorBuckets[key] = (r: r, g: g, b: b, count: 1)
                }
            }
        }

        // Sort buckets by frequency
        let sorted = colorBuckets.values.sorted { $0.count > $1.count }

        // Take top 4 colors, convert to hex
        var hexColors: [String] = []
        for bucket in sorted.prefix(4) {
            let avgR = bucket.r / bucket.count
            let avgG = bucket.g / bucket.count
            let avgB = bucket.b / bucket.count
            hexColors.append(String(format: "#%02X%02X%02X", avgR, avgG, avgB))
        }

        // Pad to 4 if needed
        while hexColors.count < 4 {
            hexColors.append(hexColors.last ?? "#333333")
        }

        return hexColors
    }

    // MARK: - Helpers

    private func generateThumbnail(from image: UIImage, maxWidth: CGFloat) -> UIImage? {
        let scale = maxWidth / image.size.width
        guard scale < 1.0 else { return image }

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func computeImageHash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16))
    }

    private func extractISBN10(from isbn: String?) -> String? {
        guard let isbn = isbn else { return nil }
        let digits = isbn.filter { $0.isNumber || $0 == "X" }
        return digits.count == 10 ? digits : nil
    }

    private func extractISBN13(from isbn: String?) -> String? {
        guard let isbn = isbn else { return nil }
        let digits = isbn.filter { $0.isNumber }
        return digits.count == 13 ? digits : nil
    }
}
