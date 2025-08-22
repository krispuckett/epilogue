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
                    withAnimation(.easeInOut(duration: 0.2)) {
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

/// Convenience initializer for phase-based content
extension CachedAsyncImage where Content == _ConditionalContent<Image, Placeholder> {
    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) where Placeholder == ProgressView {
        self.init(
            url: url,
            scale: scale,
            content: { image in
                content(.success(image))
            },
            placeholder: {
                content(.empty)
            }
        )
    }
}

/// Simple convenience initializer with default placeholder
extension CachedAsyncImage where Placeholder == ProgressView, Content == Image {
    init(url: URL?, scale: CGFloat = 1) {
        self.init(
            url: url,
            scale: scale,
            content: { $0.resizable() },
            placeholder: { ProgressView() }
        )
    }
}