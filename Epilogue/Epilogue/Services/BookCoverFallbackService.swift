import Foundation
import SwiftUI

@MainActor
class BookCoverFallbackService {
    static let shared = BookCoverFallbackService()
    
    // Try alternative cover sources if Google Books fails
    func getFallbackCoverURL(for book: Book) async -> String? {
        // Try Open Library first (free, reliable API)
        if let isbn = book.isbn {
            let openLibraryURL = "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg"
            if await validateImageURL(openLibraryURL) {
                #if DEBUG
                print("📚 Using Open Library cover for ISBN: \(isbn)")
                #endif
                return openLibraryURL
            }
        }
        
        // Try searching by title and author on Open Library
        let query = "\(book.title) \(book.author)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://openlibrary.org/search.json?q=\(query)&limit=1"
        
        do {
            let (data, _) = try await URLSession.shared.data(from: URL(string: searchURL)!)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["docs"] as? [[String: Any]],
               let firstResult = docs.first,
               let coverId = firstResult["cover_i"] as? Int {
                
                let openLibraryCover = "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg"
                if await validateImageURL(openLibraryCover) {
                    #if DEBUG
                    print("📚 Using Open Library cover by search for: \(book.title)")
                    #endif
                    return openLibraryCover
                }
            }
        } catch {
            #if DEBUG
            print("❌ Open Library search failed: \(error)")
            #endif
        }
        
        return nil
    }
    
    // Validate that an image URL actually returns an image
    private func validateImageURL(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if response is successful and content type is image
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               contentType.contains("image"),
               data.count > 1000 { // Ensure it's not a placeholder image
                return true
            }
        } catch {
            #if DEBUG
            print("❌ Failed to validate image URL: \(urlString)")
            #endif
        }
        
        return false
    }
    
    // Generate a fallback cover with book title and author
    func generateFallbackCover(for book: Book) -> UIImage? {
        let size = CGSize(width: 300, height: 450)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let colors = [
                UIColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 1),
                UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: [0, 1]
            )!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Draw book icon
            let iconRect = CGRect(x: size.width/2 - 40, y: 80, width: 80, height: 80)
            if let bookIcon = UIImage(systemName: "book.closed.fill") {
                bookIcon.withTintColor(.white.withAlphaComponent(0.3)).draw(in: iconRect)
            }
            
            // Draw title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            
            let titleRect = CGRect(x: 20, y: 200, width: size.width - 40, height: 100)
            let truncatedTitle = book.title.count > 50 ? 
                String(book.title.prefix(47)) + "..." : book.title
            truncatedTitle.draw(in: titleRect, withAttributes: titleAttributes)
            
            // Draw author
            let authorAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            
            let authorRect = CGRect(x: 20, y: 320, width: size.width - 40, height: 50)
            book.author.draw(in: authorRect, withAttributes: authorAttributes)
        }
    }
}