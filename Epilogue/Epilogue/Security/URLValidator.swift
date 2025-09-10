import Foundation

/// Secure URL validation and sanitization for the app
enum URLValidator {
    
    /// Allowed URL schemes for the app
    private static let allowedSchemes = Set(["https", "http"])
    
    /// Allowed domains for API calls
    private static let allowedAPIDomains = Set([
        "www.googleapis.com",
        "googleapis.com",
        "books.google.com",
        "api.perplexity.ai",  // Keep for validation even though we use proxy
        "perplexity.ai",
        "workers.dev",  // CloudFlare Workers domain
        "epilogue-proxy.kris-puckett.workers.dev",  // Your specific proxy
        "kris-puckett.workers.dev"  // Your workers subdomain
    ])
    
    /// Validates a URL string for general use (e.g., book covers)
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              url.host != nil else {
            return false
        }
        
        // Additional checks for suspicious patterns
        let suspiciousPatterns = [
            "javascript:",
            "file://",
            "data:",
            "<script",
            "onclick",
            "onerror"
        ]
        
        let lowercased = urlString.lowercased()
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    /// Validates a URL for API calls with stricter domain checking
    static func isValidAPIURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https", // API calls must use HTTPS
              let host = url.host?.lowercased(),
              allowedAPIDomains.contains(host) else {
            return false
        }
        
        return true
    }
    
    /// Sanitizes a URL string by removing potentially dangerous parameters
    static func sanitizeURL(_ urlString: String) -> String? {
        guard var components = URLComponents(string: urlString) else {
            return nil
        }
        
        // Remove potentially dangerous query parameters
        let dangerousParams = Set(["callback", "jsonp", "script", "eval"])
        
        components.queryItems = components.queryItems?.filter { item in
            !dangerousParams.contains(item.name.lowercased())
        }
        
        return components.string
    }
    
    /// Creates a safe URL for book cover images
    static func createSafeBookCoverURL(from urlString: String?) -> URL? {
        guard let urlString = urlString,
              !urlString.isEmpty,
              isValidURL(urlString),
              let sanitized = sanitizeURL(urlString),
              let url = URL(string: sanitized) else {
            return nil
        }
        
        // For book covers, ensure it's from a known good source
        if let host = url.host?.lowercased() {
            let trustedImageHosts = [
                // Google Books official hosts
                "books.google.com",
                "www.googleapis.com",
                "googleapis.com",
                // Google image delivery hosts often used by imageLinks
                "books.googleusercontent.com",
                "lh3.googleusercontent.com",
                "books.gstatic.com",
                // Open Library
                "covers.openlibrary.org",
                "openlibrary.org",
                // Amazon (occasionally used)
                "images-na.ssl-images-amazon.com",
                "m.media-amazon.com"
            ]
            
            if trustedImageHosts.contains(where: { host.contains($0) }) {
                return url
            }
        }
        
        return nil
    }
}
