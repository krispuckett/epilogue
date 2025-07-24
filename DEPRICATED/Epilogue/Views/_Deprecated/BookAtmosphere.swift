import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Book Atmosphere
// Creates a sophisticated, gallery-like gradient atmosphere for any book

struct BookAtmosphere: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var meshPhase: Double = 0
    @State private var colorScheme: AtmosphereColorScheme = .init()
    
    // Callbacks
    var onColorSchemeExtracted: ((AtmosphereColorScheme) -> Void)?
    
    // MARK: - Color Scheme
    struct AtmosphereColorScheme {
        var backgroundColor: Color = Color(white: 0.95)
        var textColor: Color = .black
        var secondaryTextColor: Color = Color.black.opacity(0.6)
        var accentColor: Color = Color.black.opacity(0.8)
        var isDark: Bool = false
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Soft gradient mesh background
                atmosphericGradientMesh(in: geometry.size)
                
                // Layer 2: iOS 26 Liquid Glass overlay for depth
                Rectangle()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .opacity(0.3)
                
                // Layer 3: Subtle vignette
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.7),
                        .init(color: .black.opacity(0.06), location: 0.9),
                        .init(color: .black.opacity(0.12), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.8
                )
                
                // Layer 4: Parallax depth
                if scrollOffset != 0 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    colorScheme.isDark ? .black.opacity(0.1) : .white.opacity(0.2),
                                    .clear
                                ]),
                                startPoint: scrollOffset > 0 ? .top : .bottom,
                                endPoint: scrollOffset > 0 ? .bottom : .top
                            )
                        )
                        .opacity(min(abs(scrollOffset) / CGFloat(200), CGFloat(0.3)))
                }
            }
            .ignoresSafeArea()
            .onAppear {
                extractSoftenedColors()
                startSubtleAnimation()
            }
        }
    }
    
    // MARK: - Atmospheric Gradient Mesh
    @ViewBuilder
    private func atmosphericGradientMesh(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard extractedColors.count >= 3 else { return }
            
            // Create 3-4 soft gradient orbs positioned aesthetically
            let positions: [(x: CGFloat, y: CGFloat)] = [
                (0.25, 0.3),  // Top left
                (0.75, 0.4),  // Top right
                (0.5, 0.7),   // Bottom center
                (0.3, 0.9)    // Bottom left (if we have 4 colors)
            ]
            
            for (index, color) in extractedColors.prefix(4).enumerated() {
                guard index < positions.count else { continue }
                
                let position = positions[index]
                
                // Animated position with very subtle movement
                let animatedX = position.x + sin(meshPhase + Double(index)) * 0.02
                let animatedY = position.y + cos(meshPhase + Double(index) * 0.7) * 0.02
                
                let center = CGPoint(
                    x: canvasSize.width * animatedX,
                    y: canvasSize.height * animatedY
                )
                
                // Soft radial gradient
                let gradient = Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color.opacity(0.8), location: 0.3),
                    .init(color: color.opacity(0.4), location: 0.6),
                    .init(color: color.opacity(0.1), location: 0.9),
                    .init(color: .clear, location: 1.0)
                ])
                
                let radius = canvasSize.width * 0.5
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .blur(radius: 80) // Heavy blur for ultra-soft gradients
        .opacity(colorScheme.isDark ? 0.8 : 1.0)
    }
    
    // MARK: - Color Extraction and Softening
    private func extractSoftenedColors() {
        guard let cgImage = bookCoverImage.cgImage else { return }
        
        // Extract dominant colors
        var colors = extractDominantColors(from: cgImage)
        
        // Take 3-4 most prominent colors
        colors = Array(colors.prefix(4))
        
        // Soften each color
        extractedColors = colors.map { softenColor($0) }
        
        // Determine color scheme
        determineColorScheme()
    }
    
    private func extractDominantColors(from cgImage: CGImage) -> [Color] {
        // Resize for performance
        let maxDimension: CGFloat = 200
        let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height))
        let width = Int(CGFloat(cgImage.width) * scale)
        let height = Int(CGFloat(cgImage.height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // K-means clustering to find dominant colors
        var colorClusters: [String: (color: Color, count: Int)] = [:]
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Quantize to reduce similar colors
                let quantizedR = round(r * 10) / 10
                let quantizedG = round(g * 10) / 10
                let quantizedB = round(b * 10) / 10
                
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
                
                if let existing = colorClusters[key] {
                    colorClusters[key] = (existing.color, existing.count + 1)
                } else {
                    colorClusters[key] = (Color(red: r, green: g, blue: b), 1)
                }
            }
        }
        
        // Sort by frequency and return top colors
        return colorClusters.values
            .filter { $0.count > 10 }
            .sorted { $0.count > $1.count }
            .prefix(6)
            .map { $0.color }
    }
    
    private func softenColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Reduce saturation by 40%
        let softSaturation = s * 0.6
        
        // Compress brightness range
        let softBrightness: CGFloat
        if b > 0.8 {
            // Very light colors -> keep light but not pure white
            softBrightness = 0.85 + (b - 0.8) * 0.5
        } else if b < 0.3 {
            // Very dark colors -> keep dark but not pure black
            softBrightness = 0.15 + b * 0.5
        } else {
            // Mid-range -> gentle compression
            softBrightness = 0.4 + (b - 0.3) * 0.6
        }
        
        return Color(
            hue: Double(h),
            saturation: Double(softSaturation),
            brightness: Double(softBrightness)
        )
    }
    
    // MARK: - Color Scheme Determination
    private func determineColorScheme() {
        guard !extractedColors.isEmpty else { return }
        
        // Calculate average brightness
        var totalBrightness: CGFloat = 0
        var count = 0
        
        for color in extractedColors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            totalBrightness += b
            count += 1
        }
        
        let averageBrightness = totalBrightness / CGFloat(count)
        let isDark = averageBrightness < 0.5
        
        // Create color scheme
        var scheme = AtmosphereColorScheme()
        scheme.isDark = isDark
        
        if isDark {
            // Dark atmosphere
            scheme.backgroundColor = extractedColors.first ?? Color(white: 0.15)
            scheme.textColor = .white
            scheme.secondaryTextColor = Color.white.opacity(0.7)
            scheme.accentColor = findAccentColor(for: .dark)
        } else {
            // Light atmosphere
            scheme.backgroundColor = extractedColors.first ?? Color(white: 0.95)
            scheme.textColor = .black
            scheme.secondaryTextColor = Color.black.opacity(0.6)
            scheme.accentColor = findAccentColor(for: .light)
        }
        
        colorScheme = scheme
        onColorSchemeExtracted?(scheme)
    }
    
    private func findAccentColor(for mode: ColorSchemeMode) -> Color {
        // Find the most saturated color for accent
        var bestAccent = extractedColors.first ?? Color.gray
        var maxSaturation: CGFloat = 0
        
        for color in extractedColors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            if s > maxSaturation {
                maxSaturation = s
                
                // Adjust accent for contrast
                if mode == .dark && b < 0.5 {
                    // Brighten dark accents for dark mode
                    bestAccent = Color(hue: Double(h), saturation: Double(s), brightness: Double(min(b * 1.5, 0.8)))
                } else if mode == .light && b > 0.6 {
                    // Darken light accents for light mode
                    bestAccent = Color(hue: Double(h), saturation: Double(s), brightness: Double(b * 0.7))
                } else {
                    bestAccent = color
                }
            }
        }
        
        return bestAccent
    }
    
    private enum ColorSchemeMode {
        case light, dark
    }
    
    // MARK: - Animation
    private func startSubtleAnimation() {
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            meshPhase = .pi * 2
        }
    }
}

// MARK: - Preview
struct BookAtmosphere_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            BookAtmosphere(
                bookCoverImage: image,
                bookTitle: "Sample Book",
                bookAuthor: "Author",
                scrollOffset: 0
            )
        }
    }
}