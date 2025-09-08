import Foundation

@MainActor
enum DisplayCoverURLResolver {
    struct Context {
        let googleID: String
        let isbn: String?
        let thumbnailURL: String?
    }

    /// Resolve a canonical, high-quality display URL for a book cover.
    static func resolveDisplayURL(googleID: String, isbn: String? = nil, thumbnailURL: String? = nil) async -> String? {
        let ctx = Context(googleID: googleID, isbn: isbn, thumbnailURL: thumbnailURL)
        for candidate in candidates(for: ctx) {
            if await validateImageURL(candidate) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Candidates
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
    private static func validateImageURL(_ urlString: String) async -> Bool {
        guard let url = URLValidator.createSafeBookCoverURL(from: urlString) else { return false }

        // Prefer HEAD
        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        headReq.timeoutInterval = 8
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
        getReq.timeoutInterval = 10
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

