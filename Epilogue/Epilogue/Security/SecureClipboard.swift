import UIKit

/// Secure clipboard handler with privacy protection
enum SecureClipboard {
    
    /// Copy text to clipboard with optional expiration
    static func copyText(_ text: String, expiresAfter: TimeInterval? = 300) { // 5 minutes default
        // Set the text
        UIPasteboard.general.string = text
        
        // Set expiration if specified
        if let expiresAfter = expiresAfter {
            // Set expiration date for clipboard content
            let expirationDate = Date().addingTimeInterval(expiresAfter)
            UIPasteboard.general.setItems(
                [[UIPasteboard.typeAutomatic: text]],
                options: [.expirationDate: expirationDate]
            )
            
            // Also schedule a timer to clear clipboard after expiration
            Timer.scheduledTimer(withTimeInterval: expiresAfter, repeats: false) { _ in
                clearIfMatches(text)
            }
        }
        
        // Log the action (without exposing content)
        #if DEBUG
        print("📋 Copied to clipboard [\(text.count) characters] - expires in \(Int(expiresAfter ?? 0)) seconds")
        #endif
    }
    
    /// Copy sensitive content with automatic expiration and warning
    static func copySensitiveText(_ text: String) {
        // For sensitive content, use shorter expiration (60 seconds)
        copyText(text, expiresAfter: 60)
    }
    
    /// Clear clipboard if it contains the specified text
    private static func clearIfMatches(_ text: String) {
        if UIPasteboard.general.string == text {
            UIPasteboard.general.string = ""
            #if DEBUG
            print("📋 Clipboard cleared (expired)")
            #endif
        }
    }
    
    /// Clear clipboard immediately
    static func clear() {
        UIPasteboard.general.string = ""
        #if DEBUG
        print("📋 Clipboard cleared")
        #endif
    }
    
    /// Format quote for clipboard with attribution
    static func formatQuoteForClipboard(content: String, author: String?, bookTitle: String?, pageNumber: Int?) -> String {
        var formatted = "\"\(content)\""
        
        if let author = author {
            formatted += "\n\n— \(author)"
            if let bookTitle = bookTitle {
                formatted += ", \(bookTitle)"
            }
            if let pageNumber = pageNumber {
                formatted += ", p. \(pageNumber)"
            }
        }
        
        return formatted
    }
    
    /// Check if clipboard contains potentially sensitive data
    static func containsSensitiveData() -> Bool {
        guard let content = UIPasteboard.general.string else { return false }
        
        // Check for patterns that might indicate sensitive data
        let sensitivePatterns = [
            #"(?i)(password|pwd|pass)[:=]\s*\S+"#,  // Password patterns
            #"(?i)(api[_-]?key|apikey)[:=]\s*\S+"#, // API key patterns
            #"(?i)(token|auth)[:=]\s*\S+"#,         // Token patterns
            #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, // Email
            #"\b\d{3}-\d{2}-\d{4}\b"#,              // SSN pattern
            #"\b\d{16}\b"#                          // Credit card pattern
        ]
        
        for pattern in sensitivePatterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Get a privacy-safe preview of clipboard content
    static func getClipboardPreview(maxLength: Int = 30) -> String? {
        guard let content = UIPasteboard.general.string else { return nil }
        
        if containsSensitiveData() {
            return "[Sensitive content hidden]"
        }
        
        if content.count <= maxLength {
            return content
        }
        
        return String(content.prefix(maxLength)) + "..."
    }
}