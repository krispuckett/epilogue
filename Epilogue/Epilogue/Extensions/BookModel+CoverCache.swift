import UIKit
import SwiftData

extension BookModel {
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