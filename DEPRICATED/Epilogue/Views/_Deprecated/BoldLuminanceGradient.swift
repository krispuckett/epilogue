import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Bold Luminance Gradient
struct BoldLuminanceGradient: View {
    let bookCoverImage: UIImage
    @State private var extractedColors: [Color] = []
    @State private var breathingPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Full screen gradient - no dark base
            if !extractedColors.isEmpty {
                // Layer 1: Base color wash
                Canvas { context, size in
                    // Create 3-4 large orbs positioned to cover entire screen
                    let positions = [
                        CGPoint(x: size.width * 0.2, y: size.height * 0.2),
                        CGPoint(x: size.width * 0.8, y: size.height * 0.3),
                        CGPoint(x: size.width * 0.5, y: size.height * 0.7),
                        CGPoint(x: size.width * 0.3, y: size.height * 0.9)
                    ]
                    
                    for (index, position) in positions.enumerated() {
                        let colorIndex = index % extractedColors.count
                        let color = extractedColors[colorIndex]
                        
                        // Gentle breathing effect
                        let breathScale = 1.0 + 0.05 * sin(breathingPhase + Double(index) * 0.5)
                        let radius = min(size.width, size.height) * 0.8 * breathScale
                        
                        let gradient = Gradient(stops: [
                            .init(color: color, location: 0),
                            .init(color: color.opacity(0.8), location: 0.3),
                            .init(color: color.opacity(0.4), location: 0.7),
                            .init(color: color.opacity(0.1), location: 1)
                        ])
                        
                        context.fill(
                            Circle()
                                .path(in: CGRect(
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
                .blur(radius: 120) // Ultra heavy blur for smooth blending
                
                // Layer 2: Color richness overlay
                LinearGradient(
                    colors: [
                        extractedColors.first?.opacity(0.3) ?? .clear,
                        extractedColors.last?.opacity(0.2) ?? .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
                
                // Film grain texture
                GrainOverlay()
                    .opacity(0.05)
            } else {
                // Fallback gradient while colors load
                LinearGradient(
                    colors: [
                        Color(red: 0.8, green: 0.2, blue: 0.2),
                        Color(red: 0.2, green: 0.2, blue: 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            extractBoldColors()
            startBreathing()
        }
    }
    
    private func extractBoldColors() {
        let analyzer = BoldColorAnalyzer()
        extractedColors = analyzer.extractVibrantColors(from: bookCoverImage, count: 4)
    }
    
    private func startBreathing() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathingPhase = .pi * 2
        }
    }
}

// MARK: - Grain Overlay
struct GrainOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                for _ in 0..<150 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0.3...0.7)
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
        }
        .blendMode(.overlay)
    }
}

// MARK: - Bold Color Analyzer
struct BoldColorAnalyzer {
    func extractVibrantColors(from image: UIImage, count: Int) -> [Color] {
        guard let cgImage = image.cgImage else { 
            return defaultColors() 
        }
        
        // Smaller size for faster processing
        let maxDimension: CGFloat = 50
        let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height))
        let width = Int(CGFloat(cgImage.width) * scale)
        let height = Int(CGFloat(cgImage.height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { 
            return defaultColors() 
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { 
            return defaultColors() 
        }
        
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Collect vibrant colors
        var vibrantColors: [UIColor] = []
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * 4
                let r = CGFloat(pixels[index]) / 255.0
                let g = CGFloat(pixels[index + 1]) / 255.0
                let b = CGFloat(pixels[index + 2]) / 255.0
                
                // Convert to HSB to check saturation
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
                
                // Only keep vibrant colors (high saturation)
                if s > 0.4 && br > 0.3 && br < 0.9 {
                    vibrantColors.append(color)
                }
            }
        }
        
        // If not enough vibrant colors, add some defaults
        if vibrantColors.count < count {
            vibrantColors.append(contentsOf: defaultUIColors())
        }
        
        // Cluster and select most prominent
        let selectedColors = selectMostVibrant(from: vibrantColors, count: count)
        
        // Convert to SwiftUI colors with enhanced saturation
        return selectedColors.map { uiColor in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Boost saturation significantly for bold colors
            let enhancedSaturation = min(1.0, s * 2.0)
            let adjustedBrightness = min(0.9, b * 1.2)
            
            return Color(hue: Double(h), saturation: Double(enhancedSaturation), brightness: Double(adjustedBrightness))
        }
    }
    
    private func selectMostVibrant(from colors: [UIColor], count: Int) -> [UIColor] {
        // Sort by saturation and take the most vibrant
        let sorted = colors.sorted { color1, color2 in
            var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
            color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
            return s1 > s2
        }
        
        // Take diverse colors (not too similar)
        var selected: [UIColor] = []
        for color in sorted {
            if selected.isEmpty {
                selected.append(color)
            } else {
                // Check if color is different enough from already selected
                let isDifferent = selected.allSatisfy { existingColor in
                    !colorsAreSimilar(color, existingColor)
                }
                if isDifferent && selected.count < count {
                    selected.append(color)
                }
            }
        }
        
        return Array(selected.prefix(count))
    }
    
    private func colorsAreSimilar(_ color1: UIColor, _ color2: UIColor) -> Bool {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        
        let hueDiff = abs(h1 - h2)
        let adjustedHueDiff = min(hueDiff, 1.0 - hueDiff) // Handle hue wrapping
        
        return adjustedHueDiff < 0.1 // Colors are similar if hues are within 10%
    }
    
    private func defaultColors() -> [Color] {
        return [
            Color(red: 0.9, green: 0.2, blue: 0.3),   // Vibrant red
            Color(red: 0.2, green: 0.3, blue: 0.9),   // Vibrant blue
            Color(red: 0.9, green: 0.6, blue: 0.2),   // Vibrant orange
            Color(red: 0.3, green: 0.8, blue: 0.4)    // Vibrant green
        ]
    }
    
    private func defaultUIColors() -> [UIColor] {
        return [
            UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0),
            UIColor(red: 0.2, green: 0.3, blue: 0.9, alpha: 1.0),
            UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0),
            UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        ]
    }
}