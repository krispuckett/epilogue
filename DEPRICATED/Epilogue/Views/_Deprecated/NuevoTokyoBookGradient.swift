import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Nuevo Tokyo Book Gradient (Japanese-inspired linear gradient)
struct NuevoTokyoBookGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var animationPhase: Double = 0
    
    // Callback to pass accent color to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base layer: Smooth linear gradient from extracted colors
                if !extractedColors.isEmpty {
                    LinearGradient(
                        colors: extractedColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .scaleEffect(1.0 + scrollOffset * 0.0001) // Very subtle scale on scroll
                    .offset(y: scrollOffset * 0.1) // Subtle parallax
                    
                    // Secondary layer: Subtle animated mesh overlay
                    Canvas { context, size in
                        // Draw very subtle organic shapes
                        for (index, color) in extractedColors.prefix(3).enumerated() {
                            let position = CGPoint(
                                x: size.width * (0.3 + Double(index) * 0.2 + sin(animationPhase + Double(index) * 0.5) * 0.03),
                                y: size.height * (0.2 + Double(index) * 0.3 + cos(animationPhase + Double(index) * 0.5) * 0.03)
                            )
                            
                            let gradient = Gradient(stops: [
                                .init(color: color.opacity(0.2), location: 0.0),
                                .init(color: color.opacity(0.1), location: 0.4),
                                .init(color: Color.clear, location: 1.0)
                            ])
                            
                            let radius = size.width * 0.5
                            
                            context.fill(
                                Circle().path(in: CGRect(
                                    x: position.x - radius,
                                    y: position.y - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                )),
                                with: .radialGradient(
                                    gradient,
                                    center: position,
                                    startRadius: 0,
                                    endRadius: radius
                                )
                            )
                        }
                    }
                    .blur(radius: 80)
                    .blendMode(.overlay)
                    .opacity(0.6)
                }
                
                // Dark vignette overlay
                Rectangle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: Color.clear, location: 0.3),
                                .init(color: Color.black.opacity(0.2), location: 0.6),
                                .init(color: Color.black.opacity(0.5), location: 0.85),
                                .init(color: Color.black.opacity(0.7), location: 1.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.height * 0.8
                        )
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // Subtle noise texture
                Canvas { context, size in
                    // Create very subtle noise pattern
                    for y in stride(from: 0, through: size.height, by: 4) {
                        for x in stride(from: 0, through: size.width, by: 4) {
                            let noise = Double.random(in: 0.45...0.55)
                            context.fill(
                                Rectangle()
                                    .path(in: CGRect(x: x, y: y, width: 1, height: 1)),
                                with: .color(.white.opacity(noise))
                            )
                        }
                    }
                }
                .blendMode(.overlay)
                .opacity(0.03) // Very subtle
            }
            .ignoresSafeArea()
            .onAppear {
                extractDominantColors()
                startSubtleAnimation()
            }
        }
    }
    
    // MARK: - Color Extraction
    private func extractDominantColors() {
        #if DEBUG
        print("🎌 Extracting colors for Nuevo Tokyo gradient")
        #endif
        
        // Resize image for processing
        let targetSize = CGSize(width: 200, height: 300)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        bookCoverImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        guard let cgImage = resizedImage.cgImage else { return }
        
        // Extract ALL vibrant colors
        let colors = extractAllVibrantColors(from: cgImage)
        
        #if DEBUG
        print("🎌 Found \(colors.count) colors before processing")
        #endif
        
        // Apply Japanese-inspired color processing
        extractedColors = processColorsForNuevoTokyo(colors)
        
        #if DEBUG
        print("🎌 Final Nuevo Tokyo colors: \(extractedColors.count)")
        #endif
        
        // Use SmartAccentColorExtractor for intelligent accent color detection
        let smartAccent = SmartAccentColorExtractor.extractAccentColor(
            from: bookCoverImage,
            bookTitle: bookTitle
        )
        onAccentColorExtracted?(smartAccent)
    }
    
    private func extractDominantColor(from cgImage: CGImage, in region: CGRect) -> Color? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(region.width),
                height: Int(region.height),
                bitsPerComponent: 8,
                bytesPerRow: Int(region.width) * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        
        // Draw the region
        context.draw(cgImage, in: CGRect(x: -region.minX, y: -region.minY, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        guard let pixelData = context.data else { return nil }
        
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: Int(region.width * region.height) * 4)
        
        // K-means clustering for better color extraction
        var clusters: [(r: CGFloat, g: CGFloat, b: CGFloat, count: Int)] = []
        
        for y in stride(from: 0, to: Int(region.height), by: 4) {
            for x in stride(from: 0, to: Int(region.width), by: 4) {
                let index = (y * Int(region.width) + x) * 4
                let r = CGFloat(pixels[index]) / 255.0
                let g = CGFloat(pixels[index + 1]) / 255.0
                let b = CGFloat(pixels[index + 2]) / 255.0
                
                // Skip very dark or very light pixels
                let brightness = (r + g + b) / 3.0
                if brightness > 0.1 && brightness < 0.9 {
                    // Find closest cluster or create new one
                    var foundCluster = false
                    for i in 0..<clusters.count {
                        let dr = clusters[i].r - r
                        let dg = clusters[i].g - g
                        let db = clusters[i].b - b
                        let distance = sqrt(dr*dr + dg*dg + db*db)
                        
                        if distance < 0.2 {
                            // Update cluster average
                            let count = CGFloat(clusters[i].count)
                            clusters[i].r = (clusters[i].r * count + r) / (count + 1)
                            clusters[i].g = (clusters[i].g * count + g) / (count + 1)
                            clusters[i].b = (clusters[i].b * count + b) / (count + 1)
                            clusters[i].count += 1
                            foundCluster = true
                            break
                        }
                    }
                    
                    if !foundCluster && clusters.count < 5 {
                        clusters.append((r: r, g: g, b: b, count: 1))
                    }
                }
            }
        }
        
        // Find the most prominent cluster
        if let dominantCluster = clusters.max(by: { $0.count < $1.count }) {
            return Color(red: dominantCluster.r, green: dominantCluster.g, blue: dominantCluster.b)
        }
        
        return nil
    }
    
    private func extractAllVibrantColors(from cgImage: CGImage) -> [Color] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Collect vibrant colors
        var colorMap: [String: (color: Color, count: Int)] = [:]
        
        // Sample every 8th pixel
        for y in stride(from: 0, to: height, by: 8) {
            for x in stride(from: 0, to: width, by: 8) {
                let index = ((width * y) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Keep ALL colors to preserve the book's actual palette
                if true {
                    // Round to group similar colors
                    let roundedH = round(h * 20) / 20
                    let roundedS = round(s * 10) / 10
                    let roundedB = round(br * 10) / 10
                    
                    let key = "\(roundedH)-\(roundedS)-\(roundedB)"
                    
                    if let existing = colorMap[key] {
                        colorMap[key] = (existing.color, existing.count + 1)
                    } else {
                        let color = Color(hue: Double(h), saturation: Double(s), brightness: Double(br))
                        colorMap[key] = (color, 1)
                    }
                }
            }
        }
        
        // Get the most common colors
        let sortedColors = colorMap.values
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0.color }
        
        return Array(sortedColors)
    }
    
    private func processColorsForNuevoTokyo(_ colors: [Color]) -> [Color] {
        var processedColors: [Color] = []
        
        // Process each color while maintaining vibrancy
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Nuevo Tokyo style: preserve original colors with slight enhancement
            let processedColor: Color
            
            if s < 0.1 {
                // For grayscale colors (like white/cream book covers), keep them as-is
                processedColor = Color(hue: Double(h), saturation: Double(s), brightness: Double(b))
            } else {
                // For colorful elements, slightly enhance
                processedColor = Color(
                    hue: Double(h),
                    saturation: Double(min(s * 1.1, 0.9)), // Slight boost
                    brightness: Double(b) // Keep original brightness
                )
            }
            processedColors.append(processedColor)
        }
        
        // Remove similar colors
        var uniqueColors: [Color] = []
        for color in processedColors {
            var isUnique = true
            for existing in uniqueColors {
                if colorsAreSimilar(color, existing) {
                    isUnique = false
                    break
                }
            }
            if isUnique {
                uniqueColors.append(color)
            }
        }
        
        // Ensure we have at least 3 colors for smooth gradient
        while uniqueColors.count < 3 {
            if let lastColor = uniqueColors.last {
                let uiColor = UIColor(lastColor)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                // Add subtle variations of the same color family (analogous only)
                let hueShift = CGFloat(uniqueColors.count) * 0.03 // Very small hue shift
                let newHue = (h + hueShift).truncatingRemainder(dividingBy: 1.0)
                    
                uniqueColors.append(Color(
                    hue: Double(newHue),
                    saturation: Double(s * (0.7 - CGFloat(uniqueColors.count) * 0.1)), // Gradually less saturated
                    brightness: Double(b * (1.0 + CGFloat(uniqueColors.count) * 0.1)) // Gradually brighter
                ))
            } else {
                // Fallback to a neutral gray instead of orange
                uniqueColors.append(Color(hue: 0, saturation: 0, brightness: 0.5))
            }
        }
        
        // Sort by brightness for smooth gradient
        return uniqueColors.sorted { color1, color2 in
            let ui1 = UIColor(color1)
            let ui2 = UIColor(color2)
            var b1: CGFloat = 0, b2: CGFloat = 0
            ui1.getHue(nil, saturation: nil, brightness: &b1, alpha: nil)
            ui2.getHue(nil, saturation: nil, brightness: &b2, alpha: nil)
            return b1 < b2
        }.prefix(5).map { $0 } // Take up to 5 colors
    }
    
    private func colorsAreSimilar(_ color1: Color, _ color2: Color) -> Bool {
        let ui1 = UIColor(color1)
        let ui2 = UIColor(color2)
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
        ui1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
        ui2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
        
        return abs(h1 - h2) < 0.05 && abs(s1 - s2) < 0.15 && abs(b1 - b2) < 0.15
    }
    
    
    private func startSubtleAnimation() {
        // Very slow, meditative animation
        withAnimation(.linear(duration: 40).repeatForever(autoreverses: true)) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Preview
struct NuevoTokyoBookGradient_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            NuevoTokyoBookGradient(
                bookCoverImage: image,
                bookTitle: "The Tale of Genji",
                bookAuthor: "Murasaki Shikibu",
                scrollOffset: 0
            )
        }
    }
}