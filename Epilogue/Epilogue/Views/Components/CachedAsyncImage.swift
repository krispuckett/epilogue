import SwiftUI

/// Drop-in replacement for AsyncImage that uses SharedBookCoverManager for caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(Image(uiImage: loadedImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        isLoading = true
        
        Task {
            // Use thumbnail for smaller images (typical AsyncImage use case)
            if let image = await SharedBookCoverManager.shared.loadThumbnail(from: url.absoluteString) {
                await MainActor.run {
                    withAnimation(DesignSystem.Animation.easeQuick) {
                        self.loadedImage = image
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Simple convenience initializer with default placeholder
extension CachedAsyncImage {
    init(
        url: URL?,
        scale: CGFloat = 1
    ) where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
        self.init(
            url: url,
            scale: scale,
            content: { $0.resizable() },
            placeholder: { ProgressView() }
        )
    }
}