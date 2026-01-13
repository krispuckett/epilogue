import Foundation

@MainActor
enum DisplayCoverURLResolver {
    /// Resolution mode - quick for search results, full for imports
    enum ResolveMode {
        case full   // All 12 candidates (for imports, detail views)
        case quick  // Only 3 best candidates (for search results)
    }

    struct Context {
        let googleID: String
        let isbn: String?
        let thumbnailURL: String?
    }

    /// Resolve a canonical, high-quality display URL for a book cover.
    /// - Parameter mode: Use `.quick` for search results (faster), `.full` for imports (more thorough)
    static func resolveDisplayURL(
        googleID: String,
        isbn: String? = nil,
        thumbnailURL: String? = nil,
        mode: ResolveMode = .full
    ) async -> String? {
        let ctx = Context(googleID: googleID, isbn: isbn, thumbnailURL: thumbnailURL)
        let candidateList = mode == .quick ? quickCandidates(for: ctx) : candidates(for: ctx)

        for candidate in candidateList {
            if await validateImageURL(candidate, quickMode: mode == .quick) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Candidates

    /// Quick candidates for search results - only 3 most reliable URLs
    private static func quickCandidates(for ctx: Context) -> [String] {
        var list: [String] = []
        let id = ctx.googleID

        // 1. Content API with zoom=1 (most reliable)
        list.append("https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&zoom=1&source=gbs_api")

        // 2. Google imageLinks thumbnail (if provided - already validated by Google)
        if let thumb = ctx.thumbnailURL, URLValidator.isValidURL(thumb) {
            list.append(thumb.replacingOccurrences(of: "http://", with: "https://"))
        }

        // 3. Publisher frontcover medium quality
        list.append("https://books.google.com/books/publisher/content/images/frontcover/\(id)?fife=w800-h1200&source=gbs_api")

        return list
    }

    /// Full candidates for imports and detail views - all 12 URLs
    private static func candidates(for ctx: Context) -> [String] {
        var list: [String] = []
        let id = ctx.googleID

        // Publisher frontcover with fife (highest quality)
        let fifeBase = "https://books.google.com/books/publisher/content/images/frontcover/\(id)"
        let fifeSizes = [
            "w1600-h2400", "w1200-h1800", "w1080-h1620", "w800-h1200"
        ]
        list.append(contentsOf: fifeSizes.map { "\(fifeBase)?fife=\($0)&source=gbs_api" })

        // Publisher without fife
        list.append("\(fifeBase)?img=1&source=gbs_api")

        // Content API with zoom fallbacks
        let contentBase = "https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&source=gbs_api"
        list.append(contentBase)
        list.append(contentBase + "&zoom=1")
        list.append(contentBase + "&zoom=2")

        // Google imageLinks thumbnail (if provided)
        if let thumb = ctx.thumbnailURL, URLValidator.isValidURL(thumb) {
            list.append(thumb.replacingOccurrences(of: "http://", with: "https://"))
        }

        // Open Library by ISBN
        if let isbn = ctx.isbn, !isbn.isEmpty {
            let openLib = "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg"
            list.append(openLib)
        }

        // Deduplicate while keeping order
        var seen = Set<String>()
        let deduped = list.filter { seen.insert($0).inserted }
        return deduped
    }

    // MARK: - Validation

    /// Validate that a URL points to a real image with sufficient size
    /// - Parameter quickMode: If true, uses shorter timeouts (3s/5s vs 8s/10s)
    private static func validateImageURL(_ urlString: String, quickMode: Bool = false) async -> Bool {
        guard let url = URLValidator.createSafeBookCoverURL(from: urlString) else { return false }

        // Timeouts: quick mode uses shorter timeouts for search responsiveness
        let headTimeout: TimeInterval = quickMode ? 3 : 8
        let getTimeout: TimeInterval = quickMode ? 5 : 10

        // Prefer HEAD
        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        headReq.timeoutInterval = headTimeout
        do {
            let (_, response) = try await URLSession.shared.data(for: headReq)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let type = http.value(forHTTPHeaderField: "Content-Type"), type.starts(with: "image/") {
                    if let lenStr = http.value(forHTTPHeaderField: "Content-Length"), let len = Int(lenStr), len > 4_000 {
                        return true
                    }
                }
            }
        } catch {
            // Fall through to GET
        }

        // Small GET fallback (first 16KB)
        var getReq = URLRequest(url: url)
        getReq.timeoutInterval = getTimeout
        getReq.setValue("bytes=0-16383", forHTTPHeaderField: "Range")
        do {
            let (data, response) = try await URLSession.shared.data(for: getReq)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 206 {
                if let type = http.value(forHTTPHeaderField: "Content-Type"), type.starts(with: "image/") {
                    return data.count > 4_000
                }
            }
        } catch {
            return false
        }
        return false
    }
}

