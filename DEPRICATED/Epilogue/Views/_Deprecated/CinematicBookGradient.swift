import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Cinematic Book Gradient (Apple Music-inspired)
struct CinematicBookGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var meshPhase: Double = 0
    @State private var coverBrightness: CGFloat = 0.5 // Track overall cover brightness
    @State private var isDarkCover: Bool = false
    
    // Scroll dynamics
    @State private var scrollVelocity: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var velocityResetTimer: Timer?
    
    // Callbacks to pass color info to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    var onBackgroundAnalyzed: ((Double, Bool) -> Void)? // (luminance, needsHighContrast)
    var onColorsExtracted: (([Color]) -> Void)?
    
    // Computed properties for scroll dynamics
    private var scrollProgress: CGFloat {
        // Normalize scroll to -1...1 range
        let divisor: CGFloat = 300.0
        return scrollOffset / divisor
    }
    
    private var scrollDistortion: CGFloat {
        // Create a distortion value for effects
        let divisor: CGFloat = 200.0
        return scrollOffset / divisor
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Heavily blurred book cover foundation
                blurredCoverFoundation(in: geometry.size)
                
                // Layer 2: Subtle mesh gradient overlay
                subtleMeshGradient(in: geometry.size)
                
                // Layer 3: Soft lighting depth
                softLightingLayer(in: geometry.size)
                
                // Layer 4: Polish - vignette
                subtleVignette
                
                // Layer 5: Polish - minimal noise
                minimalNoiseTexture
                
                // Layer 6: Darkening scrim for light covers only
                if coverBrightness > 0.6 {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                    .allowsHitTesting(false)
                }
                
                // Layer 7: Velocity streak effects (only for fast scrolling)
                if abs(scrollVelocity) > 5 {
                    velocityStreakLayer(in: geometry.size)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                extractDominantColors()
                startSubtleAnimation()
            }
            .onChange(of: scrollOffset) { newValue in
                updateScrollVelocity(newValue)
            }
        }
    }
    
    // MARK: - Layer 1: Blurred Cover Foundation
    @ViewBuilder
    private func blurredCoverFoundation(in size: CGSize) -> some View {
        let baseBlur: CGFloat = isDarkCover ? 60 : 80
        let blurMultiplier: CGFloat = 20.0
        let dynamicBlur = baseBlur + abs(scrollProgress) * blurMultiplier
        let scaleMultiplier: CGFloat = 0.05
        let dynamicScale = CGFloat(1.0) + abs(scrollProgress) * scaleMultiplier
        
        let widthMultiplier: CGFloat = 1.1
        let heightMultiplier: CGFloat = 1.1
        let parallaxMultiplier: CGFloat = 0.2
        
        Image(uiImage: bookCoverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width * widthMultiplier, height: size.height * heightMultiplier)
            .scaleEffect(dynamicScale)
            .offset(y: scrollOffset * parallaxMultiplier) // Subtle parallax
            .blur(radius: dynamicBlur)
            .opacity(isDarkCover ? 0.75 : 0.5) // Higher opacity for dark covers to show more color
            .animation(.easeOut(duration: 0.2), value: scrollProgress)
    }
    
    // MARK: - Layer 2: Subtle Mesh Gradient
    @ViewBuilder
    private func subtleMeshGradient(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard extractedColors.count >= 3 else { return }
            
            // Use more colors for richer gradients on dark covers
            let colors = extractedColors
            let colorCount = min(colors.count, isDarkCover ? 6 : 4)
            
            // Dynamic opacity based on cover brightness
            let baseOpacity = isDarkCover ? 1.0 : 0.6 // Maximum opacity for dark covers
            
            // Create multiple gradient layers for richer effect
            for (index, color) in colors.prefix(colorCount).enumerated() {
                // Distribute colors more naturally around the center
                let angle = (Double(index) / Double(colorCount)) * .pi * 2
                let distance = 0.3 + (Double(index % 2) * 0.2) // Alternate between inner and outer positions
                
                // Create radial gradients positioned around center with scroll-based movement
                let scrollShift = sin(scrollDistortion * .pi) * 0.1
                let velocityDivisor: CGFloat = 20.0
                let velocityPulse = min(abs(scrollVelocity) / velocityDivisor, CGFloat(0.3)) // Subtle pulse based on velocity
                
                // Vary opacity - stronger in center, fading outward, with velocity adjustment
                let boostMultiplier: Double = 0.5
                let velocityOpacityBoost = 1.0 + Double(velocityPulse) * boostMultiplier
                let distanceFade = 1.0 - distance * 0.5
                let opacity = Double(baseOpacity) * distanceFade * velocityOpacityBoost
                
                // Break down complex calculations
                let xBase = 0.5 + cos(angle) * distance
                let xWave = sin(meshPhase + Double(index)) * 0.05
                let xTotal = xBase + xWave + scrollShift
                
                let yBase = 0.5 + sin(angle) * distance * 0.8
                let yWave = cos(meshPhase + Double(index)) * 0.05
                let yTotal = yBase + yWave + scrollShift * 0.5
                
                let center = CGPoint(
                    x: canvasSize.width * CGFloat(xTotal),
                    y: canvasSize.height * CGFloat(yTotal)
                )
                
                let gradient = Gradient(stops: [
                    .init(color: color.opacity(opacity), location: 0),
                    .init(color: color.opacity(opacity * 0.6), location: 0.4),
                    .init(color: color.opacity(opacity * 0.3), location: 0.7),
                    .init(color: Color.clear, location: 1.0)
                ])
                
                let radius = canvasSize.width * 0.35 // Consistent smaller radius for more defined colors
                
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
            
            // Add extra vibrant accents for dark covers
            if isDarkCover && colors.count >= 3 {
                // Top accent light
                let accentGradient = Gradient(stops: [
                    .init(color: colors[0].opacity(0.6), location: 0),
                    .init(color: colors[0].opacity(0.3), location: 0.3),
                    .init(color: Color.clear, location: 0.7)
                ])
                
                context.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: canvasSize)),
                    with: .linearGradient(
                        accentGradient,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height * 0.4)
                    )
                )
            }
        }
        .blur(radius: 55) // Add blur to mesh the gradient orbs together
        .blendMode(isDarkCover ? .screen : .plusLighter) // Use screen for dark covers to avoid blue artifacts
        .opacity(isDarkCover ? 0.85 : 0.5) // Higher opacity for dark covers
    }
    
    // MARK: - Layer 3: Soft Lighting
    @ViewBuilder
    private func softLightingLayer(in size: CGSize) -> some View {
        ZStack {
            // Dynamic top light based on cover brightness
            // Use warm white to avoid blue tints
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.98, blue: 0.95).opacity(isDarkCover ? 0.4 : 0.25),
                    Color(red: 1.0, green: 0.98, blue: 0.95).opacity(isDarkCover ? 0.2 : 0.1),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: size.height * (isDarkCover ? 0.8 : 0.6)
            )
            .scaleEffect(x: 1.5, y: 1.0)
            .offset(y: meshPhase * 10 - 5) // Very subtle movement
            
            // Soft bottom glow
            RadialGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.9),
                startRadius: 0,
                endRadius: size.height * 0.3
            )
        }
        .blendMode(.overlay)
    }
    
    // MARK: - Layer 4: Subtle Vignette
    @ViewBuilder
    private var subtleVignette: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.clear, location: 0.6),
                        .init(color: Color.black.opacity(0.05), location: 0.85),
                        .init(color: Color.black.opacity(0.1), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: UIScreen.main.bounds.height * 0.9
                )
            )
            .allowsHitTesting(false)
    }
    
    // MARK: - Layer 5: Minimal Noise Texture
    @ViewBuilder
    private var minimalNoiseTexture: some View {
        // Static noise pattern - no animation for subtlety
        Canvas { context, size in
            // Create subtle noise pattern
            for y in stride(from: 0, through: size.height, by: 3) {
                for x in stride(from: 0, through: size.width, by: 3) {
                    let noise = Double.random(in: 0.4...0.6)
                    context.fill(
                        Rectangle()
                            .path(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1)),
                        with: .color(.white.opacity(noise))
                    )
                }
            }
        }
        .blendMode(.overlay)
        .opacity(0.02) // Very subtle
    }
    
    // MARK: - Color Extraction with Smart Brightness Detection
    private func extractDominantColors() {
        #if DEBUG
        print("🎨 CinematicBookGradient - Starting color extraction for: \(bookTitle ?? "Unknown")")
        #endif
        guard let ciImage = CIImage(image: bookCoverImage) else { 
            #if DEBUG
            print("❌ Failed to create CIImage")
            #endif
            return 
        }
        
        // Use original image for better color extraction
        guard let cgImage = bookCoverImage.cgImage else {
            #if DEBUG
            print("❌ Failed to get CGImage")
            #endif
            return
        }
        
        // Analyze brightness first
        let overallBrightness = analyzeCoverBrightness(cgImage: cgImage)
        coverBrightness = overallBrightness
        isDarkCover = overallBrightness < 0.4
        #if DEBUG
        print("📊 Cover brightness: \(overallBrightness), isDark: \(isDarkCover)")
        #endif
        
        // Determine if we need high contrast UI
        // Check if colors are predominantly blue/monochromatic
        var isMonochromatic = false
        var isLightBlueGray = false
        if let firstColor = extractedColors.first {
            let uiColor = UIColor(firstColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            // Blue hues are around 0.55-0.7
            isMonochromatic = (h > 0.5 && h < 0.75) || (s < 0.3)
            // Light blue-gray detection
            isLightBlueGray = overallBrightness > 0.6 && h > 0.5 && h < 0.75 && s < 0.25
        }
        
        // Need high contrast for:
        // 1. Light blue-gray covers (always need high contrast)
        // 2. Medium brightness monochromatic covers
        // 3. Very light covers (> 0.7 brightness)
        let needsHighContrast = isLightBlueGray || 
                               (overallBrightness > 0.7) ||
                               (overallBrightness > 0.4 && overallBrightness < 0.7 && isMonochromatic)
        onBackgroundAnalyzed?(Double(overallBrightness), needsHighContrast)
        #if DEBUG
        print("📊 Needs high contrast: \(needsHighContrast), monochromatic: \(isMonochromatic), lightBlueGray: \(isLightBlueGray)")
        #endif
        
        // Extract ALL unique colors from the image
        var colors = extractAllUniqueColors(from: cgImage)
        #if DEBUG
        print("🎨 Extracted \(colors.count) unique colors")
        #endif
        
        // Remove duplicate colors
        colors = removeDuplicateColors(colors)
        
        // Take up to 6 colors without modification
        extractedColors = Array(colors.prefix(6))
        
        // If we have too few colors, generate analogous colors from what we have
        if extractedColors.count < 3 && !extractedColors.isEmpty {
            // Get the first color and create variations
            let baseColor = extractedColors[0]
            let uiColor = UIColor(baseColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Add darker/lighter variations of the same hue
            if b > 0.5 {
                extractedColors.append(Color(hue: Double(h), saturation: Double(s), brightness: Double(b * 0.7)))
            } else {
                extractedColors.append(Color(hue: Double(h), saturation: Double(s * 0.8), brightness: Double(min(b * 1.3, 0.9))))
            }
            
            // Add a slightly shifted hue (analogous color)
            let hueShift = 0.05 // Small shift to stay in the same color family
            extractedColors.append(Color(hue: Double((h + hueShift).truncatingRemainder(dividingBy: 1.0)), 
                                       saturation: Double(s * 0.9), 
                                       brightness: Double(b)))
        } else if extractedColors.isEmpty {
            // Absolute fallback - use dark neutrals
            extractedColors = [Color(white: 0.2), Color(white: 0.3), Color(white: 0.15)]
        }
        
        #if DEBUG
        print("🎨 Final gradient colors: \(extractedColors.count)")
        #endif
        
        // Call the new callback with extracted colors
        onColorsExtracted?(extractedColors)
        
        // Use SmartAccentColorExtractor for better accent color detection
        let smartAccent = SmartAccentColorExtractor.extractAccentColor(
            from: bookCoverImage,
            bookTitle: bookTitle
        )
        onAccentColorExtracted?(smartAccent)
    }
    
    private func analyzeCoverBrightness(cgImage: CGImage) -> CGFloat {
        // Create a small version for quick brightness analysis
        let maxDimension: CGFloat = 100
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
        ) else { return 0.5 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        var totalBrightness: CGFloat = 0
        var pixelCount = 0
        
        // Sample all pixels in the smaller image
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Calculate perceived brightness using luminance formula
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                totalBrightness += brightness
                pixelCount += 1
            }
        }
        
        return pixelCount > 0 ? totalBrightness / CGFloat(pixelCount) : 0.5
    }
    
    private func removeDuplicateColors(_ colors: [Color]) -> [Color] {
        var uniqueColors: [Color] = []
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            var isDuplicate = false
            for existing in uniqueColors {
                let existingUI = UIColor(existing)
                var eh: CGFloat = 0, es: CGFloat = 0, eb: CGFloat = 0
                existingUI.getHue(&eh, saturation: &es, brightness: &eb, alpha: nil)
                
                // Check if colors are too similar
                if abs(h - eh) < 0.05 && abs(s - es) < 0.1 && abs(b - eb) < 0.1 {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                uniqueColors.append(color)
            }
        }
        
        return uniqueColors
    }
    
    
    private func extractDominantColor(from cgImage: CGImage, in region: CGRect, coverBrightness: CGFloat) -> Color? {
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
        
        // Calculate average color
        let avgR = totalR / CGFloat(pixelCount)
        let avgG = totalG / CGFloat(pixelCount)
        let avgB = totalB / CGFloat(pixelCount)
        
        let color = UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Smart brightness adjustment based on cover analysis
        let saturationBoost: CGFloat
        let brightnessBoost: CGFloat
        let minBrightness: CGFloat
        
        if coverBrightness < 0.4 {
            // Dark cover - aggressive brightening
            saturationBoost = 1.5
            brightnessBoost = 1.6
            minBrightness = 0.7
        } else if coverBrightness < 0.6 {
            // Medium cover - moderate brightening
            saturationBoost = 1.4
            brightnessBoost = 1.3
            minBrightness = 0.65
        } else {
            // Light cover - gentle enhancement
            saturationBoost = 1.2
            brightnessBoost = 1.1
            minBrightness = 0.6
        }
        
        // Return color with minimal adjustment to preserve original
        return Color(
            hue: Double(h),
            saturation: Double(max(s, 0.3)), // Ensure minimum saturation
            brightness: Double(b) // Keep original brightness
        )
    }
    
    
    private func extractAllUniqueColors(from cgImage: CGImage) -> [Color] {
        // Resize for performance
        let maxDimension: CGFloat = 300
        let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height))
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * newWidth
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: newWidth * newHeight * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(newWidth), height: CGFloat(newHeight)))
        
        // Collect all unique vibrant colors
        var colorMap: [String: (color: Color, count: Int)] = [:]
        
        // Sample every pixel to find all colors
        for y in stride(from: 0, to: newHeight, by: 2) {
            for x in stride(from: 0, to: newWidth, by: 2) {
                let index = ((newWidth * y) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Convert to HSB to check vibrancy
                let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Keep only colors with meaningful saturation or very dark colors
                // This prevents artifacts and compression noise from being picked up
                let brightness = (r + g + b) / 3.0
                
                // For dark covers like Project Hail Mary, we need to be more selective
                // Skip near-grays unless they're very dark (black)
                // Also skip potential blue artifacts from compression
                let isBlueArtifact = (h > 0.55 && h < 0.7) && s < 0.3 && brightness < 0.3
                
                if (s > 0.15 || brightness < 0.1) && !(r > 0.95 && g > 0.95 && b > 0.95) && !isBlueArtifact {
                    // Create a key that groups very similar colors
                    let roundedR = round(r * 20) / 20
                    let roundedG = round(g * 20) / 20
                    let roundedB = round(b * 20) / 20
                    
                    let key = "\(roundedR)-\(roundedG)-\(roundedB)"
                    
                    if let existing = colorMap[key] {
                        colorMap[key] = (existing.color, existing.count + 1)
                    } else {
                        // Store the actual color, not rounded
                        let color = Color(red: r, green: g, blue: b)
                        colorMap[key] = (color, 1)
                    }
                }
            }
        }
        
        // Sort by saturation and frequency to get the most vibrant colors
        let sortedColors = colorMap.values
            .filter { $0.count > 10 } // Higher threshold to avoid noise
            .sorted { entry1, entry2 in
                let ui1 = UIColor(entry1.color)
                let ui2 = UIColor(entry2.color)
                var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
                var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
                ui1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
                ui2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
                
                // Prioritize:
                // 1. High saturation colors (reds, yellows)
                // 2. Very dark colors (blacks)
                // 3. Medium brightness with good saturation
                
                if b1 < 0.1 && b2 >= 0.1 { return true }  // Black comes first
                if b2 < 0.1 && b1 >= 0.1 { return false }
                
                // For non-black colors, prioritize saturation
                if s1 > 0.7 && s2 <= 0.7 { return true }
                if s2 > 0.7 && s1 <= 0.7 { return false }
                
                // Then by overall vibrancy
                let score1 = s1 * (1.0 + CGFloat(entry1.count) / 100.0)
                let score2 = s2 * (1.0 + CGFloat(entry2.count) / 100.0)
                
                return score1 > score2
            }
            .prefix(10)
            .map { $0.color }
        
        // Debug: Print the colors we found
        #if DEBUG
        print("🎨 Top extracted colors for \(bookTitle ?? "Unknown"):")
        #endif
        var blueCount = 0
        for (index, color) in sortedColors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
            
            let hex = String(format: "#%02X%02X%02X", 
                           Int(r * 255), 
                           Int(g * 255), 
                           Int(b * 255))
            
            let isBlue = h > 0.55 && h < 0.7
            if isBlue { blueCount += 1 }
            
            #if DEBUG
            print("  Color \(index): \(hex) - H:\(String(format: "%.2f", h)) S:\(String(format: "%.2f", s)) B:\(String(format: "%.2f", br))\(isBlue ? " [BLUE]" : "")")
            #endif
        }
        
        if blueCount > 0 {
            #if DEBUG
            print("  ⚠️ Found \(blueCount) blue colors in extracted palette")
            #endif
        }
        
        return Array(sortedColors)
    }
    
    private func startSubtleAnimation() {
        // Very slow, barely perceptible animation
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: true)) {
            meshPhase = 1.0
        }
    }
    
    // MARK: - Scroll Velocity Tracking
    private func updateScrollVelocity(_ newOffset: CGFloat) {
        // Calculate velocity
        let delta = newOffset - previousScrollOffset
        scrollVelocity = delta
        previousScrollOffset = newOffset
        
        // Cancel existing timer
        velocityResetTimer?.invalidate()
        
        // Reset velocity after scrolling stops
        velocityResetTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                scrollVelocity = 0
            }
        }
    }
    
    // MARK: - Layer 7: Velocity Streak Layer (Fast Scrolling)
    @ViewBuilder
    private func velocityStreakLayer(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard !extractedColors.isEmpty else { return }
            
            let streakColor = extractedColors.first ?? Color.white
            let direction: CGFloat = scrollVelocity > 0 ? 1.0 : -1.0
            let streakMultiplier: CGFloat = 10.0
            let maxStreakRatio: CGFloat = 0.3
            let streakLength = min(abs(scrollVelocity) * streakMultiplier, canvasSize.height * maxStreakRatio)
            
            // Create motion streaks
            for i in 0..<3 {
                let xOffsetBase: CGFloat = 0.3
                let xOffsetIncrement: CGFloat = 0.2
                let xOffset = canvasSize.width * (xOffsetBase + CGFloat(i) * xOffsetIncrement)
                
                let yCenter: CGFloat = 0.5
                let yOffsetMultiplier: CGFloat = 0.5
                let yStart = canvasSize.height * yCenter - streakLength * direction * yOffsetMultiplier
                let yEnd = canvasSize.height * yCenter + streakLength * direction * yOffsetMultiplier
                
                let gradient = Gradient(stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: streakColor.opacity(0.3), location: 0.5),
                    .init(color: Color.clear, location: 1.0)
                ])
                
                let path = Path { path in
                    path.move(to: CGPoint(x: xOffset, y: yStart))
                    path.addLine(to: CGPoint(x: xOffset, y: yEnd))
                }
                
                context.stroke(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: xOffset, y: yStart),
                        endPoint: CGPoint(x: xOffset, y: yEnd)
                    ),
                    lineWidth: 20
                )
            }
        }
        .blur(radius: 20)
        .opacity(min(abs(scrollVelocity) / CGFloat(20.0), CGFloat(0.5)))
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.3), value: scrollVelocity)
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