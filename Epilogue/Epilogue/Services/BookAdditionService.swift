import Foundation
import SwiftUI

/// Unified service for adding books to the library
/// Ensures consistent behavior between manual and bulk additions
@MainActor
class BookAdditionService {
    static let shared = BookAdditionService()
    
    private init() {}
    
    // MARK: - Single Book Addition
    
    /// Core method for adding a single book with all enhancements
    func addBook(
        _ book: Book,
        to libraryViewModel: LibraryViewModel,
        extractColors: Bool = true,
        preloadCover: Bool = true,
        overwriteIfExists: Bool = false
    ) async {
        print("📚 BookAdditionService: Adding \(book.title)")
        
        // Add to library
        libraryViewModel.addBook(book, overwriteIfExists: overwriteIfExists)
        
        // Preload cover image
        if preloadCover, let coverURL = book.coverImageURL {
            print("🖼️ Pre-loading cover for \(book.title)")
            _ = await SharedBookCoverManager.shared.loadThumbnail(from: coverURL)
        }
        
        // Extract colors
        if extractColors {
            await extractAndCacheColors(for: book)
        }
        
        print("✅ Successfully added: \(book.title)")
    }
    
    // MARK: - Batch Book Addition
    
    /// Add multiple books with progress tracking
    func addBooks(
        _ books: [Book],
        to libraryViewModel: LibraryViewModel,
        extractColors: Bool = true,
        preloadCovers: Bool = true,
        overwriteIfExists: Bool = true,
        progressHandler: ((Int, Int, String) -> Void)? = nil
    ) async {
        print("📚 BookAdditionService: Adding \(books.count) books")
        
        for (index, book) in books.enumerated() {
            // Update progress
            progressHandler?(index + 1, books.count, book.title)
            
            // Add book using single book method
            await addBook(
                book,
                to: libraryViewModel,
                extractColors: false, // We'll extract colors in batch after
                preloadCover: preloadCovers,
                overwriteIfExists: overwriteIfExists
            )
            
            // Small delay to avoid overwhelming the system
            if index < books.count - 1 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }
        
        // Extract colors for all books in batch
        if extractColors {
            print("🎨 Starting batch color extraction...")
            progressHandler?(0, books.count, "Extracting colors...")
            await extractColorsInBatch(for: books, progressHandler: progressHandler)
        }
        
        print("✅ Batch addition complete: \(books.count) books added")
    }
    
    // MARK: - Color Extraction
    
    private func extractAndCacheColors(for book: Book) async {
        guard let coverURL = book.coverImageURL else { return }
        
        let bookID = book.localId.uuidString
        
        // Check if colors are already cached
        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            // Check if it's a placeholder palette (gray/monochromatic with low quality)
            if cachedPalette.extractionQuality < 0.5 || (cachedPalette.isMonochromatic && cachedPalette.luminance < 0.4) {
                print("⚠️ Found low-quality/placeholder palette for: \(book.title), re-extracting...")
                // Continue to re-extract
            } else {
                print("✅ Colors already cached for: \(book.title)")
                return
            }
        }
        
        print("🎨 Extracting colors for: \(book.title)")
        print("📔 Book ID for caching: \(bookID)")
        
        // Load the full image for color extraction
        guard let coverImage = await SharedBookCoverManager.shared.loadFullImage(from: coverURL) else {
            print("❌ Failed to load cover for color extraction: \(book.title)")
            return
        }
        
        print("📐 Loaded image size for color extraction: \(coverImage.size)")
        
        do {
            // Use OKLABColorExtractor directly (same as BookDetailView)
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: coverImage)
            
            print("🎨 Extracted palette for \(book.title):")
            print("  Primary: \(palette.primary)")
            print("  Secondary: \(palette.secondary)")
            print("  Accent: \(palette.accent)")
            print("  Background: \(palette.background)")
            print("  Is Monochromatic: \(palette.isMonochromatic)")
            
            // Cache the result
            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: coverURL)
            
            print("✅ Colors extracted and cached for: \(book.title) with ID: \(bookID)")
        } catch {
            print("❌ Error extracting colors for \(book.title): \(error)")
        }
    }
    
    private func extractColorsInBatch(
        for books: [Book],
        progressHandler: ((Int, Int, String) -> Void)? = nil
    ) async {
        // Process in batches to avoid memory pressure
        let batchSize = 5
        var processedCount = 0
        
        for i in stride(from: 0, to: books.count, by: batchSize) {
            let batch = Array(books[i..<min(i + batchSize, books.count)])
            
            await withTaskGroup(of: Void.self) { group in
                for book in batch {
                    group.addTask {
                        await self.extractAndCacheColors(for: book)
                    }
                }
                
                // Wait for batch to complete
                await group.waitForAll()
            }
            
            processedCount += batch.count
            
            // Update progress
            progressHandler?(processedCount, books.count, "Extracting colors...")
            
            // Small delay between batches
            if processedCount < books.count {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Pre-warm color cache for visible books in library
    func warmColorCache(for books: [Book]) async {
        print("🔥 Warming color cache for \(books.count) books")
        
        // Only process books without cached colors
        var booksNeedingColors: [Book] = []
        
        for book in books {
            let bookID = book.localId.uuidString
            if await BookColorPaletteCache.shared.getCachedPalette(for: bookID) == nil {
                booksNeedingColors.append(book)
            }
        }
        
        if !booksNeedingColors.isEmpty {
            print("📊 \(booksNeedingColors.count) books need color extraction")
            await extractColorsInBatch(for: booksNeedingColors)
        } else {
            print("✅ All books already have cached colors")
        }
    }
}