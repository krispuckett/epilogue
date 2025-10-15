import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Simple Book Gradient
struct SimpleBookGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var animationPhase: Double = 0
    
    // Callback to pass accent color to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        ZStack {
            // Base layer: Blurred, scaled book cover
            Image(uiImage: bookCoverImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.5)
                .blur(radius: 80)
                .opacity(0.6)
                .ignoresSafeArea()
                .offset(y: scrollOffset * 0.15) // Subtle parallax
            
            // Color accent layer
            if extractedColors.count >= 3 {
                LinearGradient(
                    colors: [
                        extractedColors[0].opacity(0.4),
                        extractedColors[1].opacity(0.3),
                        extractedColors[2].opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
            }
            
            // Ambient movement
            if let firstColor = extractedColors.first {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                firstColor.opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 100,
                            endRadius: 300
                        )
                    )
                    .offset(
                        x: sin(animationPhase) * 50,
                        y: cos(animationPhase) * 30
                    )
                    .blur(radius: 60)
                    .blendMode(.screen)
            }
            
            // Subtle vignette
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.clear, location: 0.7),
                            .init(color: Color.black.opacity(0.2), location: 1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: UIScreen.main.bounds.height * 0.8
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            extractColors()
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
    
    private func extractColors() {
        #if DEBUG
        print("🎨 SimpleGradient - Extracting colors from: \(bookTitle ?? "Unknown")")
        #endif
        
        let size = bookCoverImage.size
        
        // Sample from key areas
        let samplePoints = [
            CGPoint(x: size.width * 0.5, y: size.height * 0.3),  // Upper center
            CGPoint(x: size.width * 0.5, y: size.height * 0.7),  // Lower center
            CGPoint(x: size.width * 0.2, y: size.height * 0.5),  // Left
            CGPoint(x: size.width * 0.8, y: size.height * 0.5),  // Right
            CGPoint(x: size.width * 0.5, y: size.height * 0.5),  // Center
        ]
        
        var colors: [Color] = []
        
        for point in samplePoints {
            if let uiColor = bookCoverImage.getPixelColor(at: point) {
                let color = Color(uiColor)
                colors.append(color)
                
                // Debug
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                #if DEBUG
                print("  Sampled color at \(point): \(hex)")
                #endif
            }
        }
        
        // Sort by vibrancy and uniqueness
        extractedColors = colors
            .filter { $0.saturation > 0.1 } // Remove grays
            .sorted { $0.saturation > $1.saturation }
            .uniqued()
            .prefix(4)
            .map { $0 }
        
        // Ensure we have at least 3 colors
        while extractedColors.count < 3 {
            extractedColors.append(Color(white: 0.3))
        }
        
        #if DEBUG
        print("🎨 Final extracted colors: \(extractedColors.count)")
        #endif
        
        // Use SmartAccentColorExtractor for intelligent accent color detection
        let smartAccent = SmartAccentColorExtractor.extractAccentColor(
            from: bookCoverImage,
            bookTitle: bookTitle
        )
        onAccentColorExtracted?(smartAccent)
    }
}

// MARK: - UIImage Color Sampling Extension
extension UIImage {
    func getPixelColor(at point: CGPoint) -> UIColor? {
        guard let cgImage = cgImage else { return nil }
        
        // Create a 1x1 bitmap context to extract the pixel
        let width = 1
        let height = 1
        let bitsPerComponent = 8
        let bytesPerRow = 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: 4)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw the pixel we want
        context.draw(cgImage, in: CGRect(x: -point.x, y: -point.y, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        let r = CGFloat(pixelData[0]) / 255.0
        let g = CGFloat(pixelData[1]) / 255.0
        let b = CGFloat(pixelData[2]) / 255.0
        let a = CGFloat(pixelData[3]) / 255.0
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Color Extensions
extension Color {
    var saturation: Double {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(s)
    }
    
    var brightness: Double {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(b)
    }
}

// MARK: - Array Extension for Unique Colors
extension Array where Element == Color {
    func uniqued() -> [Color] {
        var unique: [Color] = []
        for color in self {
            var isUnique = true
            for existing in unique {
                if colorsAreSimilar(color, existing) {
                    isUnique = false
                    break
                }
            }
            if isUnique {
                unique.append(color)
            }
        }
        return unique
    }
    
    private func colorsAreSimilar(_ color1: Color, _ color2: Color) -> Bool {
        let ui1 = UIColor(color1)
        let ui2 = UIColor(color2)
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
        ui1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
        ui2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
        
        let hueDiff = Swift.min(abs(h1 - h2), 1.0 - abs(h1 - h2))
        return hueDiff < 0.05 && abs(s1 - s2) < 0.15 && abs(b1 - b2) < 0.15
    }
}

// MARK: - Preview
struct SimpleBookGradient_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            SimpleBookGradient(
                bookCoverImage: image,
                bookTitle: "Sample Book",
                bookAuthor: "Author",
                scrollOffset: 0
            )
        }
    }
}