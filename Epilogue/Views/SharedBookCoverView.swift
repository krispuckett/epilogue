import SwiftUI

struct SharedBookCoverView: View {
    let coverURL: String?
    let width: CGFloat
    let height: CGFloat
    @State private var isImageLoaded = false
    
    init(coverURL: String?, width: CGFloat = 170, height: CGFloat = 255) {
        self.coverURL = coverURL
        self.width = width
        self.height = height
        print("SharedBookCoverView init - URL: \(coverURL ?? "nil"), dimensions: \(width)x\(height)")
    }
    
    // Simplified URL enhancement
    private var imageURL: URL? {
        guard let coverURL = coverURL, !coverURL.isEmpty else { return nil }
        
        // Quick enhancement without regex
        var enhanced = coverURL.replacingOccurrences(of: "http://", with: "https://")
        if !enhanced.contains("zoom=") {
            enhanced += enhanced.contains("?") ? "&zoom=2" : "?zoom=2"
        }
        
        return URL(string: enhanced)
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
                            .onAppear { isImageLoaded = true }
                    case .failure:
                        // Simple failure state
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: min(width, height) * 0.25))
                            .foregroundStyle(.white.opacity(0.2))
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
}