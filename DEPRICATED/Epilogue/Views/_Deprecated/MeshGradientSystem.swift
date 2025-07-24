import SwiftUI
import UIKit

// MARK: - Advanced Mesh Gradient View
struct AdvancedMeshGradient: View {
    let image: UIImage?
    @State private var dominantColors: [Color] = []
    @State private var animationPhase: Double = 0
    
    // Fallback colors for when no image is provided
    static let fallbackColors: [Color] = [
        Color(red: 0.7, green: 0.5, blue: 0.4),
        Color(red: 0.8, green: 0.6, blue: 0.5),
        Color(red: 0.6, green: 0.4, blue: 0.5),
        Color(red: 0.75, green: 0.55, blue: 0.45),
        Color(red: 0.65, green: 0.45, blue: 0.4),
        Color(red: 0.7, green: 0.5, blue: 0.55)
    ]
    
    var body: some View {
        ZStack {
            // Base gradient layer
            MeshGradientLayer(colors: dominantColors.isEmpty ? Self.fallbackColors : dominantColors)
                .ignoresSafeArea()
            
            // Animated overlay for subtle color shifting
            AnimatedMeshOverlay(colors: dominantColors.isEmpty ? Self.fallbackColors : dominantColors, phase: animationPhase)
                .blendMode(.screen)
                .opacity(0.2)
                .ignoresSafeArea()
        }
        .onAppear {
            if let image = image {
                extractColors(from: image)
            }
            startAnimation()
        }
    }
    
    private func extractColors(from image: UIImage) {
        print("🎨 Starting color extraction from image: \(image.size)")
        dominantColors = image.dominantColors(count: 6)
        
        print("🎨 Extracted colors for gradient:")
        for (index, color) in dominantColors.enumerated() {
            let uiColor = UIColor(color)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
            print("  Color \(index): R:\(Int(red*255)) G:\(Int(green*255)) B:\(Int(blue*255))")
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            animationPhase = 1
        }
    }
}

// MARK: - Mesh Gradient Layer
struct MeshGradientLayer: View {
    let colors: [Color]
    
    // Find the darkest color for background
    private var darkestColor: Color {
        guard !colors.isEmpty else { return Color.black }
        
        var darkest = colors[0]
        var minBrightness: CGFloat = 1.0
        
        for color in colors {
            let uiColor = UIColor(color)
            var brightness: CGFloat = 0
            uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
            if brightness < minBrightness {
                minBrightness = brightness
                darkest = color
            }
        }
        
        return darkest
    }
    
    var body: some View {
        Canvas { context, size in
            guard colors.count >= 4 else { return }
            
            // No background fill - let gradients create the entire effect
            
            // Create control points for mesh (4 corners)
            let points = generateMeshPoints(in: size)
            
            // Draw mesh gradients - use only first 4 colors for corners
            for i in 0..<min(4, colors.count) {
                let point = points[i]
                let color = colors[i]
                
                // Create vibrant gradient that reaches across more of the screen
                let gradient = Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: 0.4),
                    .init(color: color.opacity(0.6), location: 0.7),
                    .init(color: .clear, location: 1)
                ])
                
                // Larger radius for better coverage
                let radius = size.width * 1.0
                let path = Circle().path(in: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                
                context.fill(
                    path,
                    with: .radialGradient(
                        gradient,
                        center: point,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .blur(radius: 30)
        .background(Color.black)  // Black background like The Odyssey example
    }
    
    private func generateMeshPoints(in size: CGSize) -> [CGPoint] {
        // Create 4 corner points
        return [
            CGPoint(x: 0, y: 0),                          // Top left
            CGPoint(x: size.width, y: 0),                 // Top right
            CGPoint(x: 0, y: size.height),                // Bottom left
            CGPoint(x: size.width, y: size.height)        // Bottom right
        ]
    }
}

// MARK: - Animated Mesh Overlay
struct AnimatedMeshOverlay: View {
    let colors: [Color]
    let phase: Double
    
    var body: some View {
        Canvas { context, size in
            guard colors.count >= 4 else { return }
            
            // Create subtle color shift overlay
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            // Use phase to subtly shift the prominence of different colors
            for i in 0..<min(4, colors.count) {
                let color = colors[i]
                
                // Calculate animated opacity based on phase
                let animatedOpacity = 0.2 + 0.1 * sin(phase + Double(i) * .pi / 2)
                
                // Position for this color's gradient center (subtle movement)
                let offsetX = 50 * cos(phase + Double(i) * .pi / 2)
                let offsetY = 50 * sin(phase + Double(i) * .pi / 2)
                
                let gradient = Gradient(stops: [
                    .init(color: color.opacity(animatedOpacity), location: 0),
                    .init(color: color.opacity(animatedOpacity * 0.5), location: 0.5),
                    .init(color: .clear, location: 1)
                ])
                
                let center = CGPoint(
                    x: centerX + offsetX,
                    y: centerY + offsetY
                )
                
                context.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: size.width * 0.6
                    )
                )
            }
        }
        .blur(radius: 40)
    }
}

// MARK: - Color Extraction Extension
extension UIImage {
    func dominantColors(count: Int) -> [Color] {
        print("🔍 Starting color extraction from image size: \(self.size)")
        
        // Use CIImage for better color extraction
        guard let ciImage = CIImage(image: self) else {
            print("❌ Failed to create CIImage")
            return AdvancedMeshGradient.fallbackColors
        }
        
        var extractedColors: [Color] = []
        
        // Define regions to sample (normalized coordinates)
        let regions: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = [
            (0.4, 0.1, 0.2, 0.2),  // Top center
            (0.1, 0.4, 0.2, 0.2),  // Left middle
            (0.7, 0.4, 0.2, 0.2),  // Right middle
            (0.4, 0.4, 0.2, 0.2),  // Center
            (0.4, 0.7, 0.2, 0.2),  // Bottom center
            (0.2, 0.2, 0.2, 0.2),  // Top left
        ]
        
        for (index, region) in regions.enumerated() {
            let x = ciImage.extent.width * region.x
            let y = ciImage.extent.height * region.y
            let width = ciImage.extent.width * region.width
            let height = ciImage.extent.height * region.height
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            
            // Use CIAreaAverage filter to get average color of the region
            guard let filter = CIFilter(name: "CIAreaAverage") else { continue }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: rect), forKey: "inputExtent")
            
            guard let outputImage = filter.outputImage else { continue }
            
            // Get the color
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
            context.render(outputImage,
                          toBitmap: &bitmap,
                          rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: .RGBA8,
                          colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            
            let r = CGFloat(bitmap[0]) / 255.0
            let g = CGFloat(bitmap[1]) / 255.0
            let b = CGFloat(bitmap[2]) / 255.0
            
            print("  Region \(index) raw color: R:\(Int(r*255)) G:\(Int(g*255)) B:\(Int(b*255))")
            
            // Always add the color, but enhance it significantly
            let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
            
            // Aggressive enhancement for vibrant colors
            let enhancedSat = min(1.0, s * 2.0)  // Double saturation
            let enhancedBright = min(1.0, max(0.6, br * 1.5))  // At least 60% brightness
            
            let enhancedColor = UIColor(hue: h, saturation: enhancedSat, brightness: enhancedBright, alpha: 1.0)
            extractedColors.append(Color(uiColor: enhancedColor))
            
            var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0
            enhancedColor.getRed(&er, green: &eg, blue: &eb, alpha: nil)
            print("  Enhanced to: R:\(Int(er*255)) G:\(Int(eg*255)) B:\(Int(eb*255))")
        }
        
        // If we didn't get enough colors, add some variations
        if extractedColors.count < count && !extractedColors.isEmpty {
            let baseColor = UIColor(extractedColors[0])
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Add analogous colors
            while extractedColors.count < count {
                let hueShift = CGFloat(extractedColors.count) * 0.08
                let newHue = (h + hueShift).truncatingRemainder(dividingBy: 1.0)
                let variation = UIColor(hue: newHue, saturation: s * 0.9, brightness: b, alpha: 1.0)
                extractedColors.append(Color(uiColor: variation))
            }
        }
        
        // Fallback to vibrant defaults if needed
        while extractedColors.count < count {
            let vibrantColors = [
                Color(red: 0.9, green: 0.4, blue: 0.2),    // Warm orange
                Color(red: 0.8, green: 0.6, blue: 0.3),    // Golden
                Color(red: 0.7, green: 0.3, blue: 0.4),    // Rose
                Color(red: 0.4, green: 0.6, blue: 0.8),    // Sky blue
                Color(red: 0.5, green: 0.7, blue: 0.4),    // Green
                Color(red: 0.6, green: 0.4, blue: 0.7)     // Purple
            ]
            if extractedColors.count < vibrantColors.count {
                extractedColors.append(vibrantColors[extractedColors.count])
            } else {
                break
            }
        }
        
        print("✅ Final extracted colors:")
        for (index, color) in extractedColors.enumerated() {
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: nil)
            print("  Color \(index): R:\(Int(r*255)) G:\(Int(g*255)) B:\(Int(b*255))")
        }
        
        return extractedColors
    }
    
    // Helper function to resize image
    private func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Book Cover Gradient Wrapper
struct BookCoverMeshGradient: View {
    let coverURL: String?
    @State private var coverImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Show gradient (with or without image)
            AdvancedMeshGradient(image: coverImage)
            
            // Loading indicator (subtle)
            if isLoading && coverURL != nil {
                ProgressView()
                    .tint(.white.opacity(0.3))
                    .scaleEffect(0.8)
            }
        }
        .task {
            await loadCoverImage()
        }
    }
    
    private func loadCoverImage() async {
        guard let urlString = coverURL else {
            isLoading = false
            return
        }
        
        // Enhance URL for better quality
        var enhanced = urlString.replacingOccurrences(of: "http://", with: "https://")
        
        // Remove edge=curl parameter that affects colors
        enhanced = enhanced.replacingOccurrences(of: "&edge=curl", with: "")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl&", with: "?")
        enhanced = enhanced.replacingOccurrences(of: "?edge=curl", with: "")
        
        // For Google Books, ensure we get the highest quality
        if enhanced.contains("books.google.com") {
            // Remove any existing zoom parameters
            enhanced = enhanced.replacingOccurrences(of: "&zoom=0", with: "")
            enhanced = enhanced.replacingOccurrences(of: "&zoom=1", with: "")
            enhanced = enhanced.replacingOccurrences(of: "&zoom=2", with: "")
            enhanced = enhanced.replacingOccurrences(of: "&zoom=3", with: "")
            
            // Add highest quality parameters
            if !enhanced.contains("?") {
                enhanced += "?"
            } else if !enhanced.hasSuffix("&") {
                enhanced += "&"
            }
            enhanced += "zoom=3&w=800"
        }
        
        guard let url = URL(string: enhanced) else {
            isLoading = false
            return
        }
        
        do {
            print("📚 Loading book cover from: \(enhanced)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Response: \(httpResponse.statusCode)")
            }
            
            if let image = UIImage(data: data) {
                print("✅ Successfully loaded image: \(image.size)")
                print("   Scale: \(image.scale), CGImage size: \(image.cgImage?.width ?? 0)x\(image.cgImage?.height ?? 0)")
                await MainActor.run {
                    self.coverImage = image
                    self.isLoading = false
                }
            } else {
                print("❌ Failed to create UIImage from data")
            }
        } catch {
            print("❌ Failed to load cover image: \(error)")
            isLoading = false
        }
    }
}