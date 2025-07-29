import SwiftUI
import CryptoKit

// Global storage for displayed images (temporary for debugging)
class DisplayedImageStore {
    static let shared = DisplayedImageStore()
    var displayedImages: [String: UIImage] = [:]
    
    func store(image: UIImage, for url: String) {
        displayedImages[url] = image
        print("📸 Stored displayed image for URL: \(url)")
    }
    
    func getImage(for url: String) -> UIImage? {
        return displayedImages[url]
    }
    
    // Clear all caches
    static func clearAllCaches() {
        print("🧹 Clearing all image caches...")
        shared.displayedImages.removeAll()
        URLCache.shared.removeAllCachedResponses()
        
        // Also clear AsyncImage cache
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
        
        print("✅ All image caches cleared")
    }
    
    // Debug method to list all cached URLs
    func debugPrintCache() {
        print("📋 Cached images:")
        for (url, image) in displayedImages {
            print("  - URL: \(url)")
            print("    Size: \(image.size)")
        }
    }
}

struct SharedBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    @State private var lowQualityImage: UIImage?
    @State private var highQualityImage: UIImage?
    @State private var isLoadingStarted = false
    
    // Callback to notify when image is loaded
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(coverURL: String?, width: CGFloat = 170, height: CGFloat = 255, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
    }
    
    
    private func calculateChecksum(for image: UIImage) -> String {
        guard let data = image.pngData() else { return "no-data" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
    }
    
    private func saveImageForDebug(_ image: UIImage, suffix: String) {
        // DEBUG IMAGE SAVING DISABLED
        /*
        Task {
            guard let data = image.pngData() else { return }
            let fileName = "DISPLAYED_\(suffix)_\(Date().timeIntervalSince1970).png"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                print("💾 Saved displayed image to: \(tempURL.path)")
                
                // Save to Photos for easy inspection
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } catch {
                print("❌ Failed to save displayed image: \(error)")
            }
        }
        */
    }
    
    var body: some View {
        ZStack {
            // Lightweight placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
                .onAppear {
                    // Start progressive loading only once
                    guard !isLoadingStarted else { return }
                    isLoadingStarted = true
                    
                    SharedBookCoverManager.shared.loadProgressiveImage(
                        from: coverURL,
                        onLowQualityLoaded: { image in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                lowQualityImage = image
                            }
                            // Only notify if high quality hasn't loaded yet
                            if highQualityImage == nil {
                                onImageLoaded?(image)
                            }
                        },
                        onHighQualityLoaded: { image in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                highQualityImage = image
                            }
                            onImageLoaded?(image)
                            
                            // Store in legacy cache for compatibility
                            if let url = coverURL {
                                DisplayedImageStore.shared.store(image: image, for: url)
                            }
                        }
                    )
                }
            
            // Display the best available image
            if let image = highQualityImage ?? lowQualityImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity)
            } else if coverURL != nil {
                // Loading state
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(.white.opacity(0.5))
            } else {
                // No cover URL
                Image(systemName: "book.closed.fill")
                    .font(.system(size: min(width, height) * 0.25))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}