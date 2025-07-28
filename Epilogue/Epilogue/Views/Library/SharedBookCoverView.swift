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
    @State private var isImageLoaded = false
    @State private var displayedImage: UIImage?
    @State private var lowResLoaded = false
    
    // Callback to notify when image is loaded
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(coverURL: String?, width: CGFloat = 170, height: CGFloat = 255, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
        print("📚 SharedBookCoverView init - URL: \(coverURL ?? "nil"), dimensions: \(width)x\(height)")
    }
    
    // Low resolution URL for fast loading
    private var lowResURL: URL? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        let enhanced = coverURL
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=3", with: "")
            .replacingOccurrences(of: "&zoom=2", with: "")
            .replacingOccurrences(of: "&zoom=1", with: "")
            .replacingOccurrences(of: "?zoom=3", with: "?")
            .replacingOccurrences(of: "?zoom=2", with: "?")
            .replacingOccurrences(of: "?zoom=1", with: "?")
        return URL(string: enhanced)
    }
    
    // High resolution URL for quality - REMOVED zoom to get full cover
    private var highResURL: URL? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        let enhanced = coverURL
            .replacingOccurrences(of: "http://", with: "https://")
            .replacingOccurrences(of: "&zoom=5", with: "")
            .replacingOccurrences(of: "&zoom=4", with: "")
            .replacingOccurrences(of: "&zoom=3", with: "")
            .replacingOccurrences(of: "&zoom=2", with: "")
            .replacingOccurrences(of: "&zoom=1", with: "")
            .replacingOccurrences(of: "zoom=5", with: "")
            .replacingOccurrences(of: "zoom=4", with: "")
            .replacingOccurrences(of: "zoom=3", with: "")
            .replacingOccurrences(of: "zoom=2", with: "")
            .replacingOccurrences(of: "zoom=1", with: "")
        return URL(string: enhanced)
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
                    // Check for cached image immediately with enhanced URL
                    let enhancedURL = coverURL?
                        .replacingOccurrences(of: "http://", with: "https://")
                        .replacingOccurrences(of: "&zoom=5", with: "")
                        .replacingOccurrences(of: "&zoom=4", with: "")
                        .replacingOccurrences(of: "&zoom=3", with: "")
                        .replacingOccurrences(of: "&zoom=2", with: "")
                        .replacingOccurrences(of: "&zoom=1", with: "")
                        .replacingOccurrences(of: "zoom=5", with: "")
                        .replacingOccurrences(of: "zoom=4", with: "")
                        .replacingOccurrences(of: "zoom=3", with: "")
                        .replacingOccurrences(of: "zoom=2", with: "")
                        .replacingOccurrences(of: "zoom=1", with: "") ?? ""
                    
                    if let cachedImage = DisplayedImageStore.shared.getImage(for: enhancedURL) {
                        print("📦 Found cached image on appear for: \(enhancedURL)")
                        print("📐 Cached image size: \(cachedImage.size)")
                        onImageLoaded?(cachedImage)
                    }
                }
            
            // Load low-res first for fast display
            if !lowResLoaded, let lowUrl = lowResURL {
                AsyncImage(url: lowUrl) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                            .onAppear {
                                lowResLoaded = true
                            }
                    }
                }
                .opacity(lowResLoaded && isImageLoaded ? 0 : 1)
            }
            
            // Load high-res on top
            if let url = highResURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Minimal loading state
                        if !isImageLoaded {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(.white.opacity(0.5))
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                            .onAppear {
                                isImageLoaded = true
                                
                                // Convert SwiftUI Image to UIImage
                                Task {
                                    if let uiImage = await convertToUIImage(image: image) {
                                        let checksum = calculateChecksum(for: uiImage)
                                        print("✅ DISPLAYED Image loaded - Checksum: \(checksum)")
                                        print("   URL: \(url.absoluteString)")
                                        print("   Size: \(uiImage.size)")
                                        
                                        // Store the image with enhanced URL for consistency
                                        displayedImage = uiImage
                                        let enhancedURL = coverURL?
                                            .replacingOccurrences(of: "http://", with: "https://")
                                            .replacingOccurrences(of: "&zoom=5", with: "")
                                            .replacingOccurrences(of: "&zoom=4", with: "")
                                            .replacingOccurrences(of: "&zoom=3", with: "")
                                            .replacingOccurrences(of: "&zoom=2", with: "")
                                            .replacingOccurrences(of: "&zoom=1", with: "")
                                            .replacingOccurrences(of: "zoom=5", with: "")
                                            .replacingOccurrences(of: "zoom=4", with: "")
                                            .replacingOccurrences(of: "zoom=3", with: "")
                                            .replacingOccurrences(of: "zoom=2", with: "")
                                            .replacingOccurrences(of: "zoom=1", with: "") ?? ""
                                        DisplayedImageStore.shared.store(image: uiImage, for: enhancedURL)
                                        
                                        // Save for debugging
                                        let bookName = coverURL?.components(separatedBy: "/").last ?? "unknown"
                                        saveImageForDebug(uiImage, suffix: bookName)
                                        
                                        // Notify callback
                                        onImageLoaded?(uiImage)
                                    }
                                }
                            }
                    case .failure(let error):
                        // Simple failure state
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: min(width, height) * 0.25))
                            .foregroundStyle(.white.opacity(0.2))
                            .onAppear {
                                print("❌ Failed to load image from URL: \(url)")
                                print("   Error: \(error)")
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
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
    
    @MainActor
    private func convertToUIImage(image: Image) async -> UIImage? {
        let controller = UIHostingController(rootView: image)
        controller.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        controller.view.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: controller.view.frame.size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}