import SwiftUI
import CryptoKit

// Global storage for displayed images (temporary for debugging)
class DisplayedImageStore {
    static let shared = DisplayedImageStore()
    var displayedImages: [String: UIImage] = [:]
    
    func store(image: UIImage, for url: String) {
        displayedImages[url] = image
        #if DEBUG
        print("📸 Stored displayed image for URL: \(url)")
        #endif
    }
    
    func getImage(for url: String) -> UIImage? {
        return displayedImages[url]
    }
}

struct SharedBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    @State private var isImageLoaded = false
    @State private var displayedImage: UIImage?
    
    // Callback to notify when image is loaded
    var onImageLoaded: ((UIImage) -> Void)?
    
    init(coverURL: String?, width: CGFloat = 170, height: CGFloat = 255, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        self.onImageLoaded = onImageLoaded
        #if DEBUG
        print("📚 SharedBookCoverView init - URL: \(coverURL ?? "nil"), dimensions: \(width)x\(height)")
        #endif
    }
    
    // Simplified URL enhancement
    private var imageURL: URL? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        
        // Quick enhancement without regex
        var enhanced = coverURL.replacingOccurrences(of: "http://", with: "https://")
        
        // Log to verify zoom parameter
        if enhanced.contains("zoom=1") {
            #if DEBUG
            print("⚠️ WARNING: URL still has zoom=1: \(enhanced)")
            #endif
        } else if enhanced.contains("zoom=3") {
            #if DEBUG
            print("✅ URL correctly has zoom=3: \(enhanced)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ URL has no zoom parameter: \(enhanced)")
            #endif
        }
        
        #if DEBUG
        print("🔗 Final URL: \(enhanced)")
        #endif
        return URL(string: enhanced)
    }
    
    private func calculateChecksum(for image: UIImage) -> String {
        guard let data = image.pngData() else { return "no-data" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
    }
    
    private func saveImageForDebug(_ image: UIImage, suffix: String) {
        Task {
            guard let data = image.pngData() else { return }
            let fileName = "DISPLAYED_\(suffix)_\(Date().timeIntervalSince1970).png"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                #if DEBUG
                print("💾 Saved displayed image to: \(tempURL.path)")
                #endif
                
                // Save to Photos for easy inspection
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } catch {
                #if DEBUG
                print("❌ Failed to save displayed image: \(error)")
                #endif
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Lightweight placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
            
            if let url = imageURL {
                AsyncImage(url: url, scale: 2) { phase in
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
                                        #if DEBUG
                                        print("✅ DISPLAYED Image loaded - Checksum: \(checksum)")
                                        #endif
                                        #if DEBUG
                                        print("   URL: \(url.absoluteString)")
                                        #endif
                                        #if DEBUG
                                        print("   Size: \(uiImage.size)")
                                        #endif
                                        
                                        // Store the image
                                        displayedImage = uiImage
                                        DisplayedImageStore.shared.store(image: uiImage, for: coverURL ?? "")
                                        
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
                                #if DEBUG
                                print("❌ Failed to load image from URL: \(url)")
                                #endif
                                #if DEBUG
                                print("   Error: \(error)")
                                #endif
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