import UIKit
import SwiftData

extension BookModel {

    // MARK: - Custom Cover Upload

    /// Set a custom cover image from user-provided UIImage
    /// Stores the image, marks as custom, and extracts colors for gradient
    @MainActor
    func setCustomCover(_ image: UIImage) async {
        // Resize for storage (max 1200px on longest side, ~500KB-1MB target)
        let resized = resizeForStorage(image, maxDimension: 1200)

        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            #if DEBUG
            print("❌ Failed to compress custom cover image")
            #endif
            return
        }

        // Store the image data
        self.coverImageData = data
        self.coverSource = "custom"

        #if DEBUG
        print("✅ Custom cover set for '\(title)' (\(data.count / 1024)KB)")
        #endif

        // Extract colors for atmospheric gradient
        await extractColorsFromCustomCover(resized)
    }

    /// Revert to API cover (if available)
    @MainActor
    func revertToAPICover() async {
        guard coverImageURL != nil else {
            #if DEBUG
            print("⚠️ No API cover URL to revert to for '\(title)'")
            #endif
            return
        }

        // Mark as API-sourced
        self.coverSource = "api"

        // Clear cached custom cover data so it reloads from URL
        self.coverImageData = nil

        // Clear cached color palette to force re-extraction
        self.extractedColors = nil
        await BookColorPaletteCache.shared.invalidatePalette(for: localId)

        #if DEBUG
        print("✅ Reverted to API cover for '\(title)'")
        #endif
    }

    /// Extract colors from custom cover and cache them
    @MainActor
    private func extractColorsFromCustomCover(_ image: UIImage) async {
        let extractor = OKLABColorExtractor()

        do {
            let palette = try await extractor.extractPalette(from: image, imageSource: "CustomCover-\(title)")

            // Store extracted colors as hex strings for persistence
            self.extractedColors = [
                palette.primary.toHexString(),
                palette.secondary.toHexString(),
                palette.accent.toHexString(),
                palette.background.toHexString()
            ]

            // Cache the palette
            await BookColorPaletteCache.shared.cachePalette(palette, for: localId, coverURL: nil)

            #if DEBUG
            print("✅ Extracted colors from custom cover for '\(title)'")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to extract colors from custom cover: \(error)")
            #endif
        }
    }

    /// Resize image for storage - maintains aspect ratio, limits max dimension
    private func resizeForStorage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Don't upscale small images
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Cover Loading
    /// Load cover image - prefers cached data, falls back to network
    @MainActor
    func loadCoverImage() async -> UIImage? {
        // First try cached data (works offline)
        if let data = coverImageData,
           let image = UIImage(data: data) {
            return image
        }

        // Fall back to network via SharedBookCoverManager
        guard let coverURL = coverImageURL else { return nil }

        let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL)

        // Cache the data for offline use
        if let image = image,
           let data = image.jpegData(compressionQuality: 0.8) {
            self.coverImageData = data
        }

        return image
    }

    /// Load thumbnail - prefers cached data, falls back to network
    @MainActor
    func loadThumbnail(targetSize: CGSize = CGSize(width: 120, height: 180)) async -> UIImage? {
        // First try cached data (works offline)
        if let data = coverImageData,
           let image = UIImage(data: data) {
            // Resize if needed
            if image.size.width > targetSize.width * 2 {
                return resizeImage(image, targetSize: targetSize)
            }
            return image
        }

        // Fall back to network via SharedBookCoverManager
        guard let coverURL = coverImageURL else { return nil }

        let image = await SharedBookCoverManager.shared.loadThumbnail(from: coverURL, targetSize: targetSize)

        // Cache the data for offline use (if not already cached)
        if coverImageData == nil,
           let image = image,
           let data = image.jpegData(compressionQuality: 0.8) {
            self.coverImageData = data
        }

        return image
    }

    /// Pre-cache cover image data for offline use
    @MainActor
    func preCacheCover() async {
        guard coverImageData == nil else { return }
        guard let coverURL = coverImageURL else { return }

        let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL)

        if let image = image,
           let data = image.jpegData(compressionQuality: 0.8) {
            self.coverImageData = data
        }
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        let ratio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        let rect = CGRect(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2,
            width: newSize.width,
            height: newSize.height
        )

        image.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}