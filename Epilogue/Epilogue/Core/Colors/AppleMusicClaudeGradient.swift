import SwiftUI
// TODO: Add UIImageColors via SPM - see ADD_UIIMAGECOLORS.md
// import UIImageColors

// MARK: - Main Gradient View
struct BookCoverGradientView: View {
    let book: Book
    @State private var colorPalette: AppleMusicColorPalette?
    
    var body: some View {
        ZStack {
            // Black base layer
            Color.black.ignoresSafeArea()
            
            // Claude-style smooth linear gradient
            if let palette = colorPalette {
                LinearGradient(
                    stops: [
                        // Vibrant colors at top
                        .init(color: palette.primary, location: 0.0),
                        .init(color: palette.primary.opacity(0.85), location: 0.08),
                        .init(color: palette.secondary.opacity(0.7), location: 0.15),
                        .init(color: palette.detail.opacity(0.5), location: 0.25),
                        .init(color: palette.background.opacity(0.3), location: 0.35),
                        .init(color: Color.black.opacity(0.5), location: 0.45),
                        // Complete fade to black
                        .init(color: Color.black, location: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .blur(radius: 30) // Subtle atmospheric blur
                
                // Optional: Very subtle noise texture overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
        .task {
            await extractColors()
        }
    }
    
    private func extractColors() async {
        guard let coverURL = book.coverImageURL else { return }
        
        // Force high quality image
        let highQualityURL = coverURL
            .replacingOccurrences(of: "zoom=1", with: "zoom=3")
            .replacingOccurrences(of: "zoom=2", with: "zoom=3")
        
        guard let url = URL(string: highQualityURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data) else { return }
        
        // For now, use our existing color extraction until UIImageColors is added
        // TODO: Replace with UIImageColors once added via SPM
        let extractor = OKLABColorExtractor()
        if let extractedPalette = try? await extractor.extractPalette(from: image, imageSource: "BookCover") {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.8)) {
                    colorPalette = AppleMusicColorPalette(
                        background: enhanceColor(extractedPalette.background),
                        primary: enhanceColor(extractedPalette.primary),
                        secondary: enhanceColor(extractedPalette.secondary),
                        detail: enhanceColor(extractedPalette.accent)
                    )
                }
            }
        }
    }
    
    // Make colors vibrant like Claude's UI
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy significantly
        saturation = min(saturation * 1.6, 1.0)
        brightness = max(brightness, 0.5) // Ensure minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}

// MARK: - Color Palette Model
struct AppleMusicColorPalette {
    let background: Color
    let primary: Color
    let secondary: Color
    let detail: Color
}

// MARK: - Book Detail View with Gradient
struct ModernBookDetailView: View {
    let book: Book
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // The gradient background
            BookCoverGradientView(book: book)
            
            // Content on top
            ScrollView {
                VStack(spacing: 24) {
                    // Book cover image
                    AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                    }
                    .frame(maxHeight: 350)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(.top, 60)
                    
                    // Book information
                    VStack(alignment: .leading, spacing: 16) {
                        Text(book.title)
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        Text("by \(book.author)")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Reading status
                        HStack {
                            ModernStatusPill(status: book.readingStatus.rawValue)
                            Spacer()
                            if let totalPages = book.pageCount {
                                Text("\(book.currentPage) of \(totalPages) pages")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Description with glass effect
                        if let description = book.description {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Summary", systemImage: "book.pages")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                            }
                            .padding(20)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            ModernActionButton(icon: "note.text", title: "Notes")
                            ModernActionButton(icon: "quote.opening", title: "Quotes")
                            ModernActionButton(icon: "bubble.left.and.bubble.right", title: "Chat")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Supporting Views
struct ModernStatusPill: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(in: Capsule())
    }
}

struct ModernActionButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Simplified Gradient for existing views
extension BookCoverBackgroundView {
    static func modernGradient(from palette: AppleMusicColorPalette?) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let palette = palette {
                LinearGradient(
                    stops: [
                        .init(color: palette.primary, location: 0.0),
                        .init(color: palette.primary.opacity(0.85), location: 0.08),
                        .init(color: palette.secondary.opacity(0.7), location: 0.15),
                        .init(color: palette.detail.opacity(0.5), location: 0.25),
                        .init(color: palette.background.opacity(0.3), location: 0.35),
                        .init(color: Color.black.opacity(0.5), location: 0.45),
                        .init(color: Color.black, location: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .blur(radius: 30)
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
    }
}