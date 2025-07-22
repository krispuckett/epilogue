import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Intelligent Book Gradient System
struct IntelligentBookGradient: View {
    let bookCoverImage: UIImage
    let scrollOffset: CGFloat
    
    // Enhanced color palette generation
    @State private var colorPalette: ColorPalette = ColorPalette()
    @State private var meshPoints: [MeshPoint] = []
    @State private var orbitingLights: [OrbitingLight] = []
    @State private var animationPhase: Double = 0
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var meshPhase: Double = 0
    
    var onAccentColorExtracted: ((Color) -> Void)?
    
    struct ColorPalette {
        var primary: Color = .clear
        var secondary: Color = .clear
        var tertiary: Color = .clear
        var accent: Color = .clear
        var highlight: Color = .clear
        var isMonochrome: Bool = false
        var dominantHue: Double = 0
        var temperature: ColorTemperature = .neutral
        
        enum ColorTemperature {
            case cool, warm, neutral
        }
    }
    
    struct MeshPoint {
        var position: CGPoint
        var color: Color
        var radius: CGFloat
        var velocity: CGVector
        var phase: Double
    }
    
    struct OrbitingLight {
        var color: Color
        var orbitRadius: CGFloat
        var orbitSpeed: Double
        var phase: Double
        var intensity: Double
        var pulseSpeed: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Ultra-blurred book cover base
                blurredCoverBase(in: geometry.size)
                
                // Layer 2: Dynamic mesh gradient
                dynamicMeshGradient(in: geometry.size)
                
                // Layer 3: Orbiting color lights
                orbitingLightSystem(in: geometry.size)
                
                // Layer 4: Atmospheric effects
                atmosphericEffects(in: geometry.size)
                
                // Layer 5: Subtle film grain
                filmGrain()
            }
            .ignoresSafeArea()
            .onAppear {
                Task {
                    await extractIntelligentColors()
                    setupAnimatedElements()
                    startAnimations()
                }
            }
        }
    }
    
    // MARK: - Layer 1: Blurred Cover Base
    @ViewBuilder
    private func blurredCoverBase(in size: CGSize) -> some View {
        Image(uiImage: bookCoverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width * 1.3, height: size.height * 1.3)
            .scaleEffect(kenBurnsScale)
            .offset(y: scrollOffset * 0.2)
            .blur(radius: 150)
            .opacity(0.35)
            .blendMode(.multiply)
    }
    
    // MARK: - Layer 2: Dynamic Mesh Gradient
    @ViewBuilder
    private func dynamicMeshGradient(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/30)) { _ in
            Canvas { context, canvasSize in
                // Create mesh gradient effect
                for (index, point) in meshPoints.enumerated() {
                    let t = animationPhase + point.phase
                    
                    // Organic movement based on color temperature
                    let movePattern: (x: Double, y: Double) = {
                        switch colorPalette.temperature {
                        case .cool:
                            // Wave-like motion for cool colors
                            return (
                                sin(t * point.velocity.dx) * 50,
                                cos(t * point.velocity.dy) * 30
                            )
                        case .warm:
                            // Radial pulsing for warm colors
                            let radius = sin(t * 0.5) * 20
                            return (
                                cos(t * point.velocity.dx) * radius,
                                sin(t * point.velocity.dy) * radius
                            )
                        case .neutral:
                            // Gentle floating
                            return (
                                sin(t * point.velocity.dx) * 30,
                                sin(t * point.velocity.dy * 0.7) * 20
                            )
                        }
                    }()
                    
                    let currentPos = CGPoint(
                        x: point.position.x + movePattern.x,
                        y: point.position.y + movePattern.y
                    )
                    
                    // Dynamic radius based on breathing effect
                    let breathingRadius = point.radius * (1 + 0.2 * sin(t * 2 + point.phase))
                    
                    // Multi-stop gradient for richness
                    let gradient = Gradient(stops: [
                        .init(color: point.color, location: 0),
                        .init(color: point.color.opacity(0.8), location: 0.3),
                        .init(color: point.color.opacity(0.4), location: 0.6),
                        .init(color: point.color.opacity(0.1), location: 0.85),
                        .init(color: .clear, location: 1)
                    ])
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(
                                x: currentPos.x - breathingRadius,
                                y: currentPos.y - breathingRadius,
                                width: breathingRadius * 2,
                                height: breathingRadius * 2
                            )),
                        with: .radialGradient(
                            gradient,
                            center: currentPos,
                            startRadius: 0,
                            endRadius: breathingRadius
                        )
                    )
                }
            }
            .blendMode(.screen)
            .opacity(0.8)
        }
    }
    
    // MARK: - Layer 3: Orbiting Lights
    @ViewBuilder
    private func orbitingLightSystem(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/60)) { _ in
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                
                for light in orbitingLights {
                    let t = animationPhase * light.orbitSpeed + light.phase
                    
                    // Calculate orbit position
                    let x = center.x + cos(t) * light.orbitRadius
                    let y = center.y + sin(t * 0.7) * light.orbitRadius * 0.6 // Elliptical orbit
                    
                    // Pulsing intensity
                    let intensity = light.intensity * (0.8 + 0.2 * sin(t * light.pulseSpeed))
                    
                    // Light gradient
                    let gradient = Gradient(stops: [
                        .init(color: light.color.opacity(intensity), location: 0),
                        .init(color: light.color.opacity(intensity * 0.5), location: 0.2),
                        .init(color: light.color.opacity(intensity * 0.2), location: 0.5),
                        .init(color: .clear, location: 1)
                    ])
                    
                    let radius = min(canvasSize.width, canvasSize.height) * 0.4
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )),
                        with: .radialGradient(
                            gradient,
                            center: CGPoint(x: x, y: y),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
            .blendMode(.plusLighter)
            .opacity(0.6)
        }
    }
    
    // MARK: - Layer 4: Atmospheric Effects
    @ViewBuilder
    private func atmosphericEffects(in size: CGSize) -> some View {
        // Vignette
        Rectangle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.1), location: 0.5),
                        .init(color: .black.opacity(0.3), location: 0.85),
                        .init(color: .black.opacity(0.5), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size.height * 0.8
                )
            )
            .blendMode(.multiply)
            .allowsHitTesting(false)
    }
    
    // MARK: - Layer 5: Film Grain
    @ViewBuilder
    private func filmGrain() -> some View {
        TimelineView(.animation(minimumInterval: 0.05)) { _ in
            Canvas { context, size in
                for _ in 0..<100 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0.4...0.6)
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
            .blendMode(.overlay)
            .opacity(0.02)
        }
    }
    
    // MARK: - Intelligent Color Extraction
    private func extractIntelligentColors() async {
        guard let ciImage = CIImage(image: bookCoverImage) else { return }
        
        let context = CIContext()
        let size = CGSize(width: 100, height: 100) // Small for performance
        
        // Scale down image
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = Float(size.width / ciImage.extent.width)
        
        guard let outputImage = scaleFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        // Analyze the image
        let analysis = analyzeImage(cgImage)
        
        // Generate intelligent color palette
        colorPalette = generateColorPalette(from: analysis)
        
        // Notify parent of accent color
        onAccentColorExtracted?(colorPalette.accent)
    }
    
    private struct ImageAnalysis {
        var dominantColors: [UIColor] = []
        var colorHistogram: [UIColor: Int] = [:]
        var brightness: Double = 0.5
        var saturation: Double = 0.5
        var isMonochrome: Bool = false
        var hasWhiteBackground: Bool = false
    }
    
    private func analyzeImage(_ cgImage: CGImage) -> ImageAnalysis {
        var analysis = ImageAnalysis()
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return analysis }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Analyze pixels
        var colorCounts: [String: (color: UIColor, count: Int)] = [:]
        var totalBrightness: Double = 0
        var totalSaturation: Double = 0
        var whitePixelCount = 0
        let totalPixels = width * height
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                totalBrightness += Double(br)
                totalSaturation += Double(s)
                
                // Check for white/near-white pixels
                if br > 0.95 && s < 0.05 {
                    whitePixelCount += 1
                }
                
                // Quantize color for grouping
                let quantizedColor = quantizeColor(h: h, s: s, b: br)
                let key = "\(quantizedColor.h)-\(quantizedColor.s)-\(quantizedColor.b)"
                
                if let existing = colorCounts[key] {
                    colorCounts[key] = (existing.color, existing.count + 1)
                } else {
                    colorCounts[key] = (
                        UIColor(hue: quantizedColor.h, saturation: quantizedColor.s, brightness: quantizedColor.b, alpha: 1.0),
                        1
                    )
                }
            }
        }
        
        // Sort colors by frequency
        let sortedColors = colorCounts.values
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0.color }
        
        analysis.dominantColors = Array(sortedColors)
        analysis.brightness = totalBrightness / Double(totalPixels / 4)
        analysis.saturation = totalSaturation / Double(totalPixels / 4)
        analysis.hasWhiteBackground = Double(whitePixelCount) / Double(totalPixels / 4) > 0.3
        
        // Check if monochrome
        let uniqueHues = Set(sortedColors.compactMap { color -> Int? in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            return s > 0.1 ? Int(h * 360) : nil
        })
        analysis.isMonochrome = uniqueHues.count < 3
        
        return analysis
    }
    
    private func quantizeColor(h: CGFloat, s: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let hueSteps: CGFloat = 24 // 15-degree steps
        let satSteps: CGFloat = 5
        let briSteps: CGFloat = 5
        
        return (
            round(h * hueSteps) / hueSteps,
            round(s * satSteps) / satSteps,
            round(b * briSteps) / briSteps
        )
    }
    
    private func generateColorPalette(from analysis: ImageAnalysis) -> ColorPalette {
        var palette = ColorPalette()
        
        // Handle different cover types
        if analysis.hasWhiteBackground || analysis.brightness > 0.85 {
            // Light/white cover - generate complementary colors
            palette = generateComplementaryPalette(from: analysis)
        } else if analysis.isMonochrome {
            // Monochrome cover - generate harmonic variations
            palette = generateHarmonicPalette(from: analysis)
        } else {
            // Colorful cover - enhance existing colors
            palette = enhanceExistingColors(from: analysis)
        }
        
        // Ensure high saturation
        palette = boostSaturation(palette)
        
        // Determine color temperature
        palette.temperature = determineTemperature(palette.dominantHue)
        
        return palette
    }
    
    private func generateComplementaryPalette(from analysis: ImageAnalysis) -> ColorPalette {
        var palette = ColorPalette()
        
        // Find any accent color in the image
        var seedHue: CGFloat = 0.5 // Default to cyan if no color found
        
        for color in analysis.dominantColors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            if s > 0.2 {
                seedHue = h
                break
            }
        }
        
        // Generate complementary color scheme
        palette.primary = Color(hue: Double(seedHue), saturation: 0.8, brightness: 0.7)
        palette.secondary = Color(hue: Double(seedHue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.6)
        palette.tertiary = Color(hue: Double(seedHue + 0.33).truncatingRemainder(dividingBy: 1), saturation: 0.6, brightness: 0.8)
        palette.accent = Color(hue: Double(seedHue + 0.17).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.8)
        palette.highlight = Color(hue: Double(seedHue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 0.9)
        palette.dominantHue = Double(seedHue)
        
        return palette
    }
    
    private func generateHarmonicPalette(from analysis: ImageAnalysis) -> ColorPalette {
        var palette = ColorPalette()
        
        // Find the base hue
        var baseHue: CGFloat = 0
        var baseSat: CGFloat = 0.5
        var baseBri: CGFloat = 0.5
        
        if let firstColor = analysis.dominantColors.first {
            firstColor.getHue(&baseHue, saturation: &baseSat, brightness: &baseBri, alpha: nil)
        }
        
        // Generate analogous harmony
        palette.primary = Color(hue: Double(baseHue), saturation: 0.8, brightness: 0.7)
        palette.secondary = Color(hue: Double(baseHue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.6)
        palette.tertiary = Color(hue: Double(baseHue - 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.65)
        palette.accent = Color(hue: Double(baseHue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.8)
        palette.highlight = Color(hue: Double(baseHue), saturation: 0.3, brightness: 0.9)
        palette.dominantHue = Double(baseHue)
        palette.isMonochrome = true
        
        return palette
    }
    
    private func enhanceExistingColors(from analysis: ImageAnalysis) -> ColorPalette {
        var palette = ColorPalette()
        let colors = analysis.dominantColors.prefix(5)
        
        if colors.count >= 1 {
            palette.primary = enhanceColor(colors[0])
        }
        if colors.count >= 2 {
            palette.secondary = enhanceColor(colors[1])
        }
        if colors.count >= 3 {
            palette.tertiary = enhanceColor(colors[2])
        }
        if colors.count >= 4 {
            palette.accent = enhanceColor(colors[3])
        } else {
            // Generate accent if not enough colors
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            UIColor(palette.primary).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            palette.accent = Color(hue: Double(h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.8)
        }
        
        // Always generate a bright highlight
        palette.highlight = Color(hue: 0.15, saturation: 0.3, brightness: 0.95)
        
        // Set dominant hue
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        UIColor(palette.primary).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        palette.dominantHue = Double(h)
        
        return palette
    }
    
    private func enhanceColor(_ color: UIColor) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Enhance saturation and brightness
        let enhancedS = min(s * 1.8, 1.0)
        let enhancedB = min(b * 1.3, 0.9)
        
        return Color(hue: Double(h), saturation: Double(enhancedS), brightness: Double(enhancedB))
    }
    
    private func boostSaturation(_ palette: ColorPalette) -> ColorPalette {
        var boosted = palette
        
        // Ensure all colors have high saturation
        boosted.primary = boostColorSaturation(palette.primary, minSaturation: 0.7)
        boosted.secondary = boostColorSaturation(palette.secondary, minSaturation: 0.7)
        boosted.tertiary = boostColorSaturation(palette.tertiary, minSaturation: 0.7)
        boosted.accent = boostColorSaturation(palette.accent, minSaturation: 0.8)
        boosted.highlight = boostColorSaturation(palette.highlight, minSaturation: 0.4)
        
        return boosted
    }
    
    private func boostColorSaturation(_ color: Color, minSaturation: Double) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        if Double(s) < minSaturation {
            return Color(hue: Double(h), saturation: minSaturation, brightness: Double(b))
        }
        return color
    }
    
    private func determineTemperature(_ hue: Double) -> ColorPalette.ColorTemperature {
        // Cool: blues, greens (0.4 - 0.7)
        // Warm: reds, oranges, yellows (0 - 0.15, 0.85 - 1.0)
        if hue >= 0.4 && hue <= 0.7 {
            return .cool
        } else if hue <= 0.15 || hue >= 0.85 {
            return .warm
        } else {
            return .neutral
        }
    }
    
    // MARK: - Animation Setup
    private func setupAnimatedElements() {
        let screenSize = UIScreen.main.bounds.size
        
        // Create mesh points
        meshPoints = [
            MeshPoint(
                position: CGPoint(x: screenSize.width * 0.2, y: screenSize.height * 0.3),
                color: colorPalette.primary,
                radius: screenSize.width * 0.4,
                velocity: CGVector(dx: 0.3, dy: 0.4),
                phase: 0
            ),
            MeshPoint(
                position: CGPoint(x: screenSize.width * 0.8, y: screenSize.height * 0.2),
                color: colorPalette.secondary,
                radius: screenSize.width * 0.35,
                velocity: CGVector(dx: 0.4, dy: 0.3),
                phase: .pi / 3
            ),
            MeshPoint(
                position: CGPoint(x: screenSize.width * 0.5, y: screenSize.height * 0.7),
                color: colorPalette.tertiary,
                radius: screenSize.width * 0.45,
                velocity: CGVector(dx: 0.35, dy: 0.45),
                phase: .pi * 2 / 3
            ),
            MeshPoint(
                position: CGPoint(x: screenSize.width * 0.3, y: screenSize.height * 0.8),
                color: colorPalette.accent,
                radius: screenSize.width * 0.3,
                velocity: CGVector(dx: 0.5, dy: 0.35),
                phase: .pi
            )
        ]
        
        // Create orbiting lights
        orbitingLights = [
            OrbitingLight(
                color: colorPalette.accent,
                orbitRadius: screenSize.width * 0.35,
                orbitSpeed: 0.2,
                phase: 0,
                intensity: 0.8,
                pulseSpeed: 1.5
            ),
            OrbitingLight(
                color: colorPalette.highlight,
                orbitRadius: screenSize.width * 0.25,
                orbitSpeed: -0.3,
                phase: .pi / 2,
                intensity: 0.6,
                pulseSpeed: 2.0
            ),
            OrbitingLight(
                color: colorPalette.primary,
                orbitRadius: screenSize.width * 0.4,
                orbitSpeed: 0.15,
                phase: .pi,
                intensity: 0.7,
                pulseSpeed: 1.2
            )
        ]
    }
    
    private func startAnimations() {
        // Main animation timer (60 seconds cycle)
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
        
        // Ken Burns effect (30 seconds)
        withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
            kenBurnsScale = 1.08
        }
        
        // Mesh phase animation
        withAnimation(.easeInOut(duration: 45).repeatForever(autoreverses: true)) {
            meshPhase = .pi * 2
        }
    }
}

// MARK: - Preview Helper
struct IntelligentBookGradient_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            IntelligentBookGradient(
                bookCoverImage: image,
                scrollOffset: 0
            )
        }
    }
}