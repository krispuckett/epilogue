import SwiftUI
import SwiftData

struct AmbientBookView: View {
    let book: Book
    @Binding var scrollOffset: CGFloat
    let onPaletteExtracted: (AmbientPalette) -> Void  // Callback instead of binding
    @State private var palette: AmbientPalette?
    @State private var coverImage: UIImage?
    @State private var phase: Double = 0
    @State private var isLoading = true
    
    @StateObject private var colorEngine = ColorIntelligenceEngine()
    
    // Computed property for text color based on luminance
    var computedTextColor: Color {
        (palette?.luminance ?? 0.5) < 0.5 ? .white : .black
    }
    
    // Computed property for background brightness
    var backgroundBrightness: Double {
        palette?.luminance ?? 0.5
    }
    
    var body: some View {
        ZStack {
            if let palette = palette, let image = coverImage {
                // Layer 1: Diffused cover essence
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.15) // Extra scale for parallax headroom
                    .blur(radius: 120)
                    .opacity(palette.luminance > 0.7 ? 0.2 : 0.4)  // Lower values
                    .offset(y: scrollOffset * 0.15)
                    .ignoresSafeArea()
                
                // Layer 2: Gradient orbs with golden ratio positioning
                ZStack {
                    ForEach(Array(palette.colors.enumerated()), id: \.offset) { index, color in
                        GradientOrb(
                            color: color,
                            index: index,
                            phase: phase,
                            scrollOffset: scrollOffset,
                            isMainColor: index == 0
                        )
                    }
                }
                .drawingGroup() // Performance optimization
                
                // Layer 3: Glass effect for iOS 17+
                if #available(iOS 17.0, *) {
                    GlassLayer(scrollOffset: scrollOffset)
                }
                
                // Layer 4: Enhanced vignette for depth
                VignetteLayer()
            } else {
                // Loading state with subtle animation
                Color.black
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    )
                    .ignoresSafeArea()
            }
        }
        .task {
            await loadAndExtractColors()
        }
        .onAppear {
            // Start ambient animation
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
        .onChange(of: book.id) { _ in
            // Reload colors if book changes
            Task {
                await loadAndExtractColors()
            }
        }
        .onChange(of: palette) { newPalette in
            if let palette = newPalette {
                onPaletteExtracted(palette)
                print("🎨 Palette extracted with luminance: \(palette.luminance)")
            }
        }
    }
    
    private func loadAndExtractColors() async {
        isLoading = true
        
        // Try to load from cache first
        if let cachedPalette = ColorPaletteCache.shared.palette(for: book.id) {
            self.palette = cachedPalette
            self.coverImage = await loadCoverImage()
            isLoading = false
            return
        }
        
        // Load cover image
        guard let image = await loadCoverImage() else {
            print("Failed to load cover image for \(book.title)")
            isLoading = false
            return
        }
        
        self.coverImage = image
        
        // Extract colors
        let extractedPalette = await colorEngine.extractAmbientPalette(from: image)
        
        // Cache the palette
        ColorPaletteCache.shared.cache(extractedPalette, for: book.id)
        
        // Animate palette change
        withAnimation(.easeInOut(duration: 0.5)) {
            self.palette = extractedPalette
            isLoading = false
        }
        
        // Debug logging
        print("🎨 COLORS FOR \(book.title):")
        for (i, color) in extractedPalette.colors.enumerated() {
            let ui = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            ui.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            print("  Color \(i): H:\(Int(h*360))° S:\(Int(s*100))% B:\(Int(b*100))%")
        }
        
        // Notify immediately when palette is loaded
        DispatchQueue.main.async {
            self.onPaletteExtracted(extractedPalette)
            print("🎨 Initial palette extracted with luminance: \(extractedPalette.luminance)")
        }
    }
    
    private func loadCoverImage() async -> UIImage? {
        guard let urlString = book.coverImageURL else { 
            print("❌ No cover URL available for book: \(book.title)")
            return nil 
        }
        
        // Convert HTTP to HTTPS and enhance quality
        var httpsURLString = urlString.replacingOccurrences(of: "http://", with: "https://")
        
        // Enhance Google Books image quality
        if httpsURLString.contains("books.google.com") {
            httpsURLString = httpsURLString.replacingOccurrences(of: "&edge=curl", with: "")
            httpsURLString = httpsURLString.replacingOccurrences(of: "&zoom=1", with: "&zoom=3")
            httpsURLString = httpsURLString.replacingOccurrences(of: "&zoom=2", with: "&zoom=3")
            
            // Add zoom=3 if no zoom parameter exists
            if !httpsURLString.contains("&zoom=") && !httpsURLString.contains("?zoom=") {
                httpsURLString += httpsURLString.contains("?") ? "&zoom=3" : "?zoom=3"
            }
            
            // Add width parameter for high quality
            if !httpsURLString.contains("&w=") {
                httpsURLString += "&w=1080"
            }
        }
        
        guard let url = URL(string: httpsURLString) else { 
            print("❌ Invalid URL: \(httpsURLString)")
            return nil 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                print("✅ Image loaded successfully for \(book.title), size: \(image.size)")
                print("   URL: \(httpsURLString)")
                return image
            }
        } catch {
            print("❌ Error loading image: \(error)")
        }
        
        return nil
    }
}

// MARK: - Gradient Orb Component

struct GradientOrb: View {
    let color: Color
    let index: Int
    let phase: Double
    let scrollOffset: CGFloat
    let isMainColor: Bool
    
    private var position: CGPoint {
        goldenRatioPosition(index: index)
    }
    
    private var size: CGFloat {
        isMainColor ? 500 : 350
    }
    
    private var opacity: Double {
        isMainColor ? 0.9 : 0.7  // Even higher opacity
    }
    
    var body: some View {
        RadialGradient(
            colors: [
                color,
                color.opacity(0.4),
                color.opacity(0.1),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
        .frame(width: size, height: size)
        .blur(radius: 80)  // Reduced from 100
        .opacity(opacity)
        .offset(
            x: sin(phase * .pi + Double(index) * 0.5) * 30,
            y: cos(phase * .pi * 0.7 + Double(index) * 0.3) * 30
        )
        .offset(y: scrollOffset * (0.25 + Double(index) * 0.05))
        .position(
            x: position.x * UIScreen.main.bounds.width,
            y: position.y * UIScreen.main.bounds.height
        )
    }
    
    private func goldenRatioPosition(index: Int) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.382),    // Top center - primary
            CGPoint(x: 0.236, y: 0.618),  // Bottom left
            CGPoint(x: 0.764, y: 0.618),  // Bottom right
            CGPoint(x: 0.382, y: 0.5),    // Mid left
            CGPoint(x: 0.618, y: 0.5)     // Mid right
        ]
        return positions[safe: index] ?? CGPoint(x: 0.5, y: 0.5)
    }
}

// MARK: - Glass Layer

@available(iOS 17.0, *)
struct GlassLayer: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        ZStack {
            // Multiple glass rectangles at different depths
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .opacity(0.1)
                    .frame(width: 300, height: 200)
                    .offset(
                        x: CGFloat(index - 1) * 100,
                        y: {
                            let baseY: CGFloat = 200
                            let indexOffset = CGFloat(index) * 100
                            let scrollFactor = 0.4 + Double(index) * 0.1
                            return baseY + indexOffset + scrollOffset * CGFloat(scrollFactor)
                        }()
                    )
                    .rotationEffect(.degrees(Double(index - 1) * 15))
                    .blur(radius: 5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Vignette Layer

struct VignetteLayer: View {
    var body: some View {
        ZStack {
            // Radial vignette for depth
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.3)
                ],
                center: .center,
                startRadius: 150,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Bottom gradient for text readability
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Color Palette Cache

class ColorPaletteCache {
    static let shared = ColorPaletteCache()
    private var cache: [String: AmbientPalette] = [:]
    private let cacheLimit = 20
    
    private init() {}
    
    func palette(for bookId: String) -> AmbientPalette? {
        return cache[bookId]
    }
    
    func cache(_ palette: AmbientPalette, for bookId: String) {
        // Simple LRU: if over limit, remove first item
        if cache.count >= cacheLimit {
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[bookId] = palette
    }
    
    func clear() {
        cache.removeAll()
    }
}

// MARK: - Extensions

extension AmbientBookView {
    // Computed properties for parent views
    func getTextColor() -> Color {
        return computedTextColor
    }
    
    func getBrightness() -> Double {
        return backgroundBrightness
    }
}

// MARK: - Safe Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return index >= 0 && index < count ? self[index] : nil
    }
}