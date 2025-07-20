import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Cinematic Book Gradient (Netflix-inspired)
struct CinematicBookGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var lightSourcePositions: [CGPoint] = []
    @State private var breathingPhase: Double = 0
    @State private var kenBurnsScale: CGFloat = 1.0
    
    // Callback to pass accent color to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Full-bleed blurred book cover
                fullBleedCoverLayer(in: geometry.size)
                
                // Layer 2: Dynamic color light sources
                colorLightSourcesLayer(in: geometry.size)
                
                // Layer 3: Cinematic vignette
                cinematicVignetteLayer
                
                // Layer 4: Film grain texture
                filmGrainLayer
            }
            .ignoresSafeArea()
            .onAppear {
                extractColorsAndPositions()
                startAnimations()
            }
        }
    }
    
    // MARK: - Layer 1: Full-bleed Book Cover
    @ViewBuilder
    private func fullBleedCoverLayer(in size: CGSize) -> some View {
        Image(uiImage: bookCoverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width * 1.2, height: size.height * 1.2) // Oversized for Ken Burns
            .scaleEffect(kenBurnsScale)
            .offset(y: scrollOffset * 0.3) // Parallax effect
            .blur(radius: 150) // Heavy blur for atmosphere
            .opacity(0.35)
            .animation(.easeInOut(duration: 20).repeatForever(autoreverses: true), value: kenBurnsScale)
    }
    
    // MARK: - Layer 2: Color Light Sources
    @ViewBuilder
    private func colorLightSourcesLayer(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard !extractedColors.isEmpty else { return }
            
            for (index, position) in lightSourcePositions.enumerated() {
                let color = extractedColors[index % extractedColors.count]
                
                // Breathing effect for organic feel
                let breathScale = 1.0 + 0.1 * sin(breathingPhase + Double(index) * 1.2)
                let radius = min(canvasSize.width, canvasSize.height) * 0.6 * breathScale
                
                // Natural light falloff gradient
                let gradient = Gradient(stops: [
                    .init(color: color.opacity(0.8), location: 0),
                    .init(color: color.opacity(0.6), location: 0.2),
                    .init(color: color.opacity(0.3), location: 0.5),
                    .init(color: color.opacity(0.1), location: 0.8),
                    .init(color: Color.clear, location: 1)
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
        .blendMode(.screen)
        .opacity(0.7)
    }
    
    // MARK: - Layer 3: Cinematic Vignette
    @ViewBuilder
    private var cinematicVignetteLayer: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.black.opacity(0.1), location: 0.5),
                        .init(color: Color.black.opacity(0.3), location: 0.8),
                        .init(color: Color.black.opacity(0.5), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.8
                )
            )
            .allowsHitTesting(false)
    }
    
    // MARK: - Layer 4: Film Grain
    @ViewBuilder
    private var filmGrainLayer: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                // Create random grain pattern
                for _ in 0..<200 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0.3...0.7)
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
            .blendMode(.overlay)
            .opacity(0.03)
        }
    }
    
    // MARK: - Color Extraction and Positioning
    private func extractColorsAndPositions() {
        guard let ciImage = CIImage(image: bookCoverImage) else { return }
        
        let context = CIContext()
        
        // Scale down for performance
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = 0.1 // Smaller for faster processing
        
        guard let outputImage = scaleFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        // Extract dominant colors and their positions
        let width = cgImage.width
        let height = cgImage.height
        
        // Divide image into regions
        let regions = [
            CGRect(x: 0, y: 0, width: width/2, height: height/2),           // Top left
            CGRect(x: width/2, y: 0, width: width/2, height: height/2),     // Top right
            CGRect(x: width/4, y: height/2, width: width/2, height: height/2) // Bottom center
        ]
        
        var colors: [Color] = []
        var positions: [CGPoint] = []
        
        for region in regions {
            if let color = extractDominantColor(from: cgImage, in: region) {
                colors.append(color)
                
                // Map region center to screen coordinates
                let centerX = (region.midX / CGFloat(width)) * UIScreen.main.bounds.width
                let centerY = (region.midY / CGFloat(height)) * UIScreen.main.bounds.height
                positions.append(CGPoint(x: centerX, y: centerY))
            }
        }
        
        // Ensure we have at least 3 colors
        while colors.count < 3 {
            colors.append(colors.last ?? Color.gray)
            positions.append(CGPoint(
                x: UIScreen.main.bounds.width * CGFloat.random(in: 0.2...0.8),
                y: UIScreen.main.bounds.height * CGFloat.random(in: 0.2...0.8)
            ))
        }
        
        extractedColors = colors
        lightSourcePositions = positions
        
        // Pass the most vibrant color as accent
        if let accentColor = findMostVibrantColor(from: colors) {
            onAccentColorExtracted?(accentColor)
        }
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
        
        // Simple averaging for dominant color
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var pixelCount = 0
        
        for y in stride(from: 0, to: Int(region.height), by: 5) {
            for x in stride(from: 0, to: Int(region.width), by: 5) {
                let index = (y * Int(region.width) + x) * 4
                let r = CGFloat(pixels[index]) / 255.0
                let g = CGFloat(pixels[index + 1]) / 255.0
                let b = CGFloat(pixels[index + 2]) / 255.0
                
                // Skip very dark or very light pixels
                let brightness = (r + g + b) / 3.0
                if brightness > 0.1 && brightness < 0.9 {
                    totalR += r
                    totalG += g
                    totalB += b
                    pixelCount += 1
                }
            }
        }
        
        guard pixelCount > 0 else { return nil }
        
        // Enhance saturation for more vibrant colors
        let avgR = totalR / CGFloat(pixelCount)
        let avgG = totalG / CGFloat(pixelCount)
        let avgB = totalB / CGFloat(pixelCount)
        
        let color = UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Boost saturation and brightness
        return Color(
            hue: Double(h),
            saturation: Double(min(s * 1.5, 1.0)),
            brightness: Double(min(b * 1.2, 0.9))
        )
    }
    
    private func findMostVibrantColor(from colors: [Color]) -> Color? {
        var mostVibrant: Color?
        var maxSaturation: CGFloat = 0
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            if s > maxSaturation && b > 0.3 {
                maxSaturation = s
                mostVibrant = color
            }
        }
        
        return mostVibrant
    }
    
    private func startAnimations() {
        // Breathing animation for light sources
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathingPhase = .pi * 2
        }
        
        // Slow Ken Burns effect
        withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
            kenBurnsScale = 1.05
        }
    }
}

// MARK: - Preview
struct CinematicBookGradient_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            CinematicBookGradient(
                bookCoverImage: image,
                bookTitle: "The Odyssey",
                bookAuthor: "Homer",
                scrollOffset: 0
            )
        }
    }
}