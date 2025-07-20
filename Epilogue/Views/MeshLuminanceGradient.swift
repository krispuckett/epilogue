import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Gradient Pattern Types
enum GradientPattern: CaseIterable {
    case cornerBlobs      // Default corner placement
    case horizontalWaves  // Ocean-like horizontal flow
    case radialBurst     // Center explosion
    case verticalFlow    // Top to bottom cascade
    case diagonalDrift   // Diagonal movement
    case organicScatter  // Random organic placement
    case circularRipple  // Concentric circles
    case spiralTwist     // Spiral pattern
    
    var description: String {
        switch self {
        case .cornerBlobs: return "Corner Blobs"
        case .horizontalWaves: return "Horizontal Waves"
        case .radialBurst: return "Radial Burst"
        case .verticalFlow: return "Vertical Flow"
        case .diagonalDrift: return "Diagonal Drift"
        case .organicScatter: return "Organic Scatter"
        case .circularRipple: return "Circular Ripple"
        case .spiralTwist: return "Spiral Twist"
        }
    }
}

// MARK: - Mesh Luminance Gradient
struct MeshLuminanceGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    @State private var extractedColors: [Color] = []
    @State private var accentColor: Color = .gray
    @State private var breathingPhase: Double = 0
    @State private var isWhiteCover: Bool = false
    @State private var isMonochromatic: Bool = false
    @State private var detectedGenre: BookGenre = .unknown
    @State private var coverBrightness: Double = 0.5
    @State private var gradientPattern: GradientPattern = .cornerBlobs
    @State private var colorPointCount: Int = 4
    
    // Accessibility
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.colorScheme) var colorScheme
    
    // Callback to pass accent color to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    
    // Dynamic blur based on cover brightness
    private var blurRadius: CGFloat {
        if coverBrightness < 0.4 {
            // Dark covers: Less blur for more vibrant colors
            return 70
        } else if isWhiteCover {
            // White covers: Medium blur
            return 80
        } else {
            // Standard covers
            return 90
        }
    }
    
    var body: some View {
        ZStack {
            // Base layer with accessibility considerations
            baseLayer
            
            // Contrast zones for better readability
            contrastZoneGradient
            
            // Mesh gradient with overlapping orbs
            if !extractedColors.isEmpty && !reduceTransparency {
                meshGradientLayer
                
                // Add subtle texture overlay
                GrainTexture()
                    .opacity(0.03)
            }
            
            // Subtle text protection only when really needed
            if coverBrightness > 0.8 && !reduceTransparency {
                textProtectionLayer
            }
        }
        .ignoresSafeArea()
        .onAppear {
            extractBookColors()
            startBreathing()
        }
    }
    
    @ViewBuilder
    private var baseLayer: some View {
        if reduceTransparency {
            // Solid color for accessibility
            LinearGradient(
                colors: [
                    accentColor.opacity(0.15),
                    Color(white: colorScheme == .dark ? 0.1 : 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isWhiteCover {
            // Smart white cover base
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.96), // Warm cream top
                    Color(red: 0.94, green: 0.93, blue: 0.91)  // Slightly darker bottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private var contrastZoneGradient: some View {
        // Balanced contrast zones - less aggressive darkening
        let isDarkCover = coverBrightness < 0.4
        
        LinearGradient(
            stops: [
                // TOP 30%: Ensure nav contrast without overdarkening
                .init(color: Color.black.opacity(isDarkCover ? 0 : 0.02), location: 0.0),
                .init(color: Color.black.opacity(0), location: 0.3),
                // MIDDLE 40%: Full color expression
                .init(color: Color.clear, location: 0.7),
                // BOTTOM 30%: Subtle darkening for tab bar
                .init(color: Color.black.opacity(isDarkCover ? 0.05 : 0.1), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    @ViewBuilder
    private var meshGradientLayer: some View {
        ZStack {
            // Layer 1: Primary book colors (60% opacity)
            primaryColorLayer
                .opacity(0.6)
            
            // Layer 2: Complementary accents (40% opacity) - only for monochromatic
            if isMonochromatic && !extractedColors.isEmpty {
                complementaryLayer
                    .opacity(0.4)
                    .blendMode(.screen)
            }
            
            // Layer 3: Dark anchors for depth (20% opacity)
            depthAnchorLayer
                .opacity(0.2)
                .blendMode(.multiply)
        }
        .blur(radius: blurRadius)
        .opacity(calculateGradientOpacity())
    }
    
    @ViewBuilder
    private var primaryColorLayer: some View {
        Canvas { context, size in
            let positions = calculateDynamicPositions(for: size, pattern: gradientPattern, count: colorPointCount)
            
            for (index, position) in positions.enumerated() {
                let colorIndex = index % extractedColors.count
                var color = extractedColors[colorIndex]
                
                // Adjust color based on cover properties
                color = adjustColorForCover(color)
                
                // Dynamic breathing with slight offset per orb
                let breathScale = 1.0 + 0.02 * sin(breathingPhase + Double(index) * 0.6)
                let radius = calculateDynamicRadius(for: size, pattern: gradientPattern, index: index) * breathScale
                
                drawGradientOrb(
                    context: context,
                    color: color,
                    position: position,
                    radius: radius,
                    pattern: gradientPattern
                )
            }
        }
    }
    
    @ViewBuilder
    private var complementaryLayer: some View {
        Canvas { context, size in
            // Use offset positions for complementary colors
            let positions = calculateDynamicPositions(
                for: size,
                pattern: gradientPattern,
                count: min(3, colorPointCount),
                offset: true
            )
            
            let complementaryColors = generateComplementaryColors(from: extractedColors)
            
            for (index, position) in positions.enumerated() {
                let color = complementaryColors[index % complementaryColors.count]
                let breathScale = 1.0 + 0.025 * sin(breathingPhase + Double(index) * 0.8 + 1.5)
                let radius = calculateDynamicRadius(for: size, pattern: gradientPattern, index: index) * breathScale * 0.8
                
                drawGradientOrb(
                    context: context,
                    color: color,
                    position: position,
                    radius: radius,
                    pattern: gradientPattern
                )
            }
        }
    }
    
    @ViewBuilder
    private var depthAnchorLayer: some View {
        Canvas { context, size in
            // Fewer, larger dark anchors
            let positions = calculateDynamicPositions(
                for: size,
                pattern: .organicScatter,
                count: 2
            )
            
            for (index, position) in positions.enumerated() {
                let darkColor = Color(white: 0.1)
                let radius = calculateDynamicRadius(for: size, pattern: gradientPattern, index: index) * 1.2
                
                drawGradientOrb(
                    context: context,
                    color: darkColor,
                    position: position,
                    radius: radius,
                    pattern: gradientPattern
                )
            }
        }
    }
    
    @ViewBuilder
    private var textProtectionLayer: some View {
        // Very subtle scrim only for very light covers
        VStack(spacing: 0) {
            // Top protection for navigation
            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            
            Spacer()
            
            // Bottom protection for tab bar
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
    }
    
    private func calculateDynamicPositions(for size: CGSize, pattern: GradientPattern, count: Int, offset: Bool = false) -> [CGPoint] {
        var positions: [CGPoint] = []
        let offsetAmount: CGFloat = offset ? 0.15 : 0
        
        switch pattern {
        case .horizontalWaves:
            // Ocean-like horizontal flow
            for i in 0..<count {
                let x = CGFloat(i) / CGFloat(count - 1) * size.width
                let y = size.height * (0.5 + 0.3 * sin(CGFloat(i) * 0.8) + offsetAmount)
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .radialBurst:
            // Center explosion pattern
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            if count == 1 {
                positions.append(center)
            } else {
                for i in 0..<count {
                    let angle = (CGFloat(i) / CGFloat(count)) * 2 * .pi
                    let radius = size.width * (0.3 + offsetAmount)
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius
                    positions.append(CGPoint(x: x, y: y))
                }
            }
            
        case .verticalFlow:
            // Top to bottom cascade
            for i in 0..<count {
                let y = CGFloat(i) / CGFloat(count - 1) * size.height
                let x = size.width * (0.5 + 0.2 * sin(CGFloat(i) * 1.2) + offsetAmount)
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .diagonalDrift:
            // Diagonal movement pattern
            for i in 0..<count {
                let progress = CGFloat(i) / CGFloat(count - 1)
                let x = progress * size.width + offsetAmount * size.width
                let y = progress * size.height + 0.2 * size.height * sin(progress * 2 * .pi)
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .organicScatter:
            // Random organic placement with golden ratio
            for i in 0..<count {
                let angle = CGFloat(i) * 2.399963 // Golden angle
                let radius = sqrt(CGFloat(i)) / sqrt(CGFloat(count)) * min(size.width, size.height) * 0.4
                let x = size.width * 0.5 + cos(angle) * radius + offsetAmount * size.width
                let y = size.height * 0.5 + sin(angle) * radius
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .circularRipple:
            // Concentric circles
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            for i in 0..<count {
                let ringProgress = CGFloat(i) / CGFloat(count)
                let angle = CGFloat(i) * 2.5 // Slight spiral
                let radius = ringProgress * min(size.width, size.height) * 0.4
                let x = center.x + cos(angle) * radius + offsetAmount * size.width * 0.5
                let y = center.y + sin(angle) * radius
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .spiralTwist:
            // Spiral pattern
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(count - 1) * 4 * .pi
                let radius = t / (4 * .pi) * min(size.width, size.height) * 0.4
                let x = center.x + cos(t) * radius + offsetAmount * size.width * 0.3
                let y = center.y + sin(t) * radius
                positions.append(CGPoint(x: x, y: y))
            }
            
        case .cornerBlobs:
            // Default corner placement (legacy)
            if count >= 4 {
                positions = [
                    CGPoint(x: size.width * (0.25 + offsetAmount), y: size.height * 0.3),
                    CGPoint(x: size.width * (0.75 - offsetAmount), y: size.height * 0.4),
                    CGPoint(x: size.width * 0.5, y: size.height * (0.7 + offsetAmount)),
                    CGPoint(x: size.width * (0.3 + offsetAmount), y: size.height * 0.85)
                ]
            } else {
                // Fewer points
                for i in 0..<count {
                    let angle = CGFloat(i) / CGFloat(count) * 2 * .pi - .pi / 2
                    let x = size.width * (0.5 + 0.3 * cos(angle) + offsetAmount)
                    let y = size.height * (0.5 + 0.3 * sin(angle))
                    positions.append(CGPoint(x: x, y: y))
                }
            }
        }
        
        return positions
    }
    
    private func calculateDynamicRadius(for size: CGSize, pattern: GradientPattern, index: Int) -> CGFloat {
        let baseRadius = min(size.width, size.height)
        
        switch pattern {
        case .horizontalWaves:
            return baseRadius * 0.5 // Medium waves
        case .radialBurst:
            return baseRadius * 0.6 // Large burst
        case .verticalFlow:
            return baseRadius * 0.45 // Tall columns
        case .diagonalDrift:
            return baseRadius * 0.5
        case .organicScatter:
            // Vary sizes for organic feel
            return baseRadius * (0.3 + 0.3 * sin(CGFloat(index)))
        case .circularRipple:
            return baseRadius * 0.4
        case .spiralTwist:
            return baseRadius * 0.35
        case .cornerBlobs:
            return baseRadius * 0.6 // Original size
        }
    }
    
    private func drawGradientOrb(context: GraphicsContext, color: Color, position: CGPoint, radius: CGFloat, pattern: GradientPattern) {
        let gradient: Gradient
        
        // Pattern-specific gradient styles
        switch pattern {
        case .horizontalWaves, .verticalFlow:
            // Elliptical gradients for flow patterns
            gradient = Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0.7), location: 0.3),
                .init(color: color.opacity(0.4), location: 0.6),
                .init(color: color.opacity(0.1), location: 0.9),
                .init(color: Color.clear, location: 1)
            ])
        case .radialBurst:
            // Sharp center, quick falloff
            gradient = Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0.9), location: 0.1),
                .init(color: color.opacity(0.5), location: 0.4),
                .init(color: color.opacity(0.2), location: 0.7),
                .init(color: Color.clear, location: 1)
            ])
        default:
            // Standard gradient
            gradient = Gradient(stops: [
                .init(color: color, location: 0),
                .init(color: color.opacity(0.8), location: 0.3),
                .init(color: color.opacity(0.5), location: 0.6),
                .init(color: color.opacity(0.2), location: 0.85),
                .init(color: Color.clear, location: 1)
            ])
        }
        
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
    
    private func adjustColorForCover(_ color: Color) -> Color {
        if coverBrightness < 0.4 {
            return brightenColorForDarkCover(color)
        } else if colorScheme == .dark {
            return darkenColorForDarkMode(color)
        }
        return color
    }
    
    private func generateComplementaryColors(from colors: [Color]) -> [Color] {
        var complementaryColors: [Color] = []
        
        for color in colors.prefix(2) {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Generate complementary hue (opposite on color wheel)
            let complementaryHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
            
            // Create variations
            complementaryColors.append(Color(
                hue: Double(complementaryHue),
                saturation: Double(s * 0.8),
                brightness: Double(b * 1.1)
            ))
            
            // Add analogous complement
            let analogousHue = (h + 0.33).truncatingRemainder(dividingBy: 1.0)
            complementaryColors.append(Color(
                hue: Double(analogousHue),
                saturation: Double(s * 0.7),
                brightness: Double(b * 0.9)
            ))
        }
        
        return complementaryColors
    }
    
    private func selectGradientPattern(for genre: BookGenre, title: String?) -> GradientPattern {
        // Book-specific patterns
        if let bookTitle = title?.lowercased() {
            if bookTitle.contains("odyssey") || bookTitle.contains("sea") || bookTitle.contains("ocean") {
                return .horizontalWaves
            } else if bookTitle.contains("hail mary") || bookTitle.contains("space") || bookTitle.contains("star") {
                return .radialBurst
            } else if bookTitle.contains("hobbit") || bookTitle.contains("journey") {
                return .diagonalDrift
            } else if bookTitle.contains("dune") {
                return .horizontalWaves // Desert waves
            }
        }
        
        // Genre-based patterns
        switch genre {
        case .fantasy, .sciFi:
            return [.radialBurst, .spiralTwist, .organicScatter].randomElement() ?? .radialBurst
        case .philosophy, .literary:
            return [.verticalFlow, .circularRipple].randomElement() ?? .verticalFlow
        case .thriller, .mystery:
            return [.diagonalDrift, .organicScatter].randomElement() ?? .diagonalDrift
        case .romance:
            return [.circularRipple, .spiralTwist].randomElement() ?? .circularRipple
        case .science, .medical:
            return [.radialBurst, .verticalFlow].randomElement() ?? .radialBurst
        default:
            // Random selection for variety
            return GradientPattern.allCases.randomElement() ?? .cornerBlobs
        }
    }
    
    private func determineColorPointCount(for pattern: GradientPattern, isMonochromatic: Bool) -> Int {
        switch pattern {
        case .horizontalWaves, .verticalFlow:
            return isMonochromatic ? 5 : 4
        case .radialBurst:
            return 6
        case .organicScatter:
            return Int.random(in: 3...5)
        case .circularRipple, .spiralTwist:
            return 4
        default:
            return isMonochromatic ? 3 : 4
        }
    }
    
    private func createAccessibleGradient(for color: Color, at position: CGPoint, in size: CGSize, isWhiteCover: Bool) -> Gradient {
        var adjustedColor = color
        
        // Smart intensity scaling based on brightness
        let uiColor = UIColor(color)
        var brightness: CGFloat = 0
        uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        
        if brightness > 0.8 {
            // Reduce saturation for bright colors
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            adjustedColor = Color(hue: Double(h), saturation: Double(s * 0.7), brightness: Double(b * 0.9))
        }
        
        // Less aggressive opacity reduction
        let verticalPosition = position.y / size.height
        let opacityMultiplier = verticalPosition < 0.3 ? 0.8 : 1.0
        
        // More vibrant gradients for dark covers
        let baseOpacity = coverBrightness < 0.4 ? 1.0 : 0.9
        
        return Gradient(stops: [
            .init(color: adjustedColor.opacity(baseOpacity * opacityMultiplier), location: 0),
            .init(color: adjustedColor.opacity(0.8 * opacityMultiplier), location: 0.3),
            .init(color: adjustedColor.opacity(0.5 * opacityMultiplier), location: 0.6),
            .init(color: adjustedColor.opacity(0.2 * opacityMultiplier), location: 0.85),
            .init(color: Color.clear, location: 1)
        ])
    }
    
    private func darkenColorForDarkMode(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Less aggressive darkening for dark mode
        return Color(
            hue: Double(h),
            saturation: Double(min(s * 1.1, 1.0)),
            brightness: Double(b * 0.8)
        )
    }
    
    private func brightenColorForDarkCover(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Brighten by 30-40% and boost saturation for glow effect
        return Color(
            hue: Double(h),
            saturation: Double(min(s * 1.5, 1.0)),  // Boost saturation
            brightness: Double(min(b * 1.4, 0.95))  // Brighten significantly
        )
    }
    
    private func calculateGradientOpacity() -> Double {
        if reduceTransparency {
            return 0.3
        }
        
        // Smart opacity system based on cover brightness
        if coverBrightness < 0.4 {
            // Dark books: Lower opacity to let black through, creating glow effect
            return colorScheme == .dark ? 0.5 : 0.6
        } else if coverBrightness > 0.7 {
            // Light books: Higher opacity for more color presence
            return colorScheme == .dark ? 0.6 : 0.8
        } else {
            // Medium books: Balanced opacity
            return colorScheme == .dark ? 0.6 : 0.7
        }
    }
    
    private func extractBookColors() {
        let analyzer = ImprovedColorAnalyzer()
        let result = analyzer.extractColors(
            from: bookCoverImage,
            bookTitle: bookTitle,
            bookAuthor: bookAuthor
        )
        extractedColors = result.colors
        isWhiteCover = result.isWhiteCover
        isMonochromatic = result.isMonochromatic
        accentColor = result.accentColor
        detectedGenre = result.genre
        coverBrightness = result.averageBrightness
        
        // Select appropriate gradient pattern
        gradientPattern = selectGradientPattern(for: detectedGenre, title: bookTitle)
        colorPointCount = determineColorPointCount(for: gradientPattern, isMonochromatic: isMonochromatic)
        
        // Add complementary colors if monochromatic
        if isMonochromatic && !isWhiteCover {
            let complementaryColors = generateComplementaryColors(from: extractedColors)
            // Insert complementary colors between existing ones
            var enrichedColors: [Color] = []
            for (index, color) in extractedColors.enumerated() {
                enrichedColors.append(color)
                if index < complementaryColors.count {
                    enrichedColors.append(complementaryColors[index])
                }
            }
            extractedColors = enrichedColors
        }
        
        // Pass accent color to parent for UI tinting
        // For monochromatic, prefer complementary as accent
        if isMonochromatic && extractedColors.count > 2 {
            accentColor = extractedColors[1] // Use first complementary
        }
        onAccentColorExtracted?(accentColor)
        
        // Debug print
        print("📚 Extracted colors for book: \(bookTitle ?? "Unknown")")
        print("  Genre: \(detectedGenre)")
        print("  Pattern: \(gradientPattern.description)")
        print("  Is white cover: \(isWhiteCover)")
        print("  Is monochromatic: \(isMonochromatic)")
        print("  Cover brightness: \(coverBrightness)")
        print("  Color points: \(colorPointCount)")
        print("  Accent color: \(accentColor.description)")
        for (index, color) in extractedColors.enumerated() {
            print("  Color \(index): \(color.description)")
        }
    }
    
    private func startBreathing() {
        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
            breathingPhase = .pi * 2
        }
    }
}

// MARK: - Book Genre
enum BookGenre {
    case fantasy
    case philosophy
    case romance
    case thriller
    case literary
    case sciFi
    case mystery
    case selfHelp
    case science
    case medical
    case business
    case history
    case unknown
    
    var colorPalette: [Color] {
        switch self {
        case .fantasy:
            return [
                Color(red: 0.95, green: 0.9, blue: 0.85),    // Warm cream
                Color(red: 0.85, green: 0.65, blue: 0.2),    // Rich gold
                Color(red: 0.2, green: 0.25, blue: 0.5),     // Deep twilight blue
                Color(red: 0.4, green: 0.3, blue: 0.6)       // Mystic purple
            ]
        case .philosophy:
            return [
                Color(white: 0.95),                           // Cool white
                Color(red: 0.7, green: 0.75, blue: 0.8),    // Cool gray
                Color(red: 0.3, green: 0.4, blue: 0.55),    // Subtle blue
                Color(red: 0.5, green: 0.55, blue: 0.6)     // Medium gray
            ]
        case .romance:
            return [
                Color(red: 1.0, green: 0.98, blue: 0.95),   // Soft cream
                Color(red: 1.0, green: 0.85, blue: 0.85),   // Soft pink
                Color(red: 0.9, green: 0.7, blue: 0.7),     // Warm rose
                Color(red: 0.95, green: 0.9, blue: 0.85)    // Warm cream
            ]
        case .thriller:
            return [
                Color(white: 0.15),                          // Dark gray
                Color(white: 0.3),                           // Medium dark gray
                Color(red: 0.8, green: 0.1, blue: 0.1),     // Blood red accent
                Color(white: 0.5)                            // Gray
            ]
        case .literary:
            return [
                Color(red: 0.9, green: 0.85, blue: 0.75),   // Warm beige
                Color(red: 0.7, green: 0.6, blue: 0.5),     // Earth brown
                Color(red: 0.6, green: 0.55, blue: 0.45),   // Muted earth
                Color(red: 0.8, green: 0.75, blue: 0.65)    // Light earth
            ]
        case .sciFi:
            return [
                Color(red: 0.1, green: 0.15, blue: 0.25),   // Deep space blue
                Color(red: 0.2, green: 0.3, blue: 0.5),     // Electric blue
                Color(red: 0.5, green: 0.3, blue: 0.7),     // Purple
                Color(red: 0.3, green: 0.8, blue: 0.9)      // Cyan
            ]
        case .selfHelp:
            return [
                Color(red: 1.0, green: 0.95, blue: 0.85),   // Warm white
                Color(red: 1.0, green: 0.7, blue: 0.3),     // Motivational orange
                Color(red: 0.9, green: 0.5, blue: 0.2),     // Deep orange
                Color(red: 1.0, green: 0.85, blue: 0.6)     // Light yellow
            ]
        case .science:
            return [
                Color(red: 0.9, green: 0.95, blue: 0.95),   // Cool white
                Color(red: 0.3, green: 0.7, blue: 0.8),     // Cool teal
                Color(red: 0.7, green: 0.8, blue: 0.85),    // Silver blue
                Color(red: 0.5, green: 0.6, blue: 0.7)      // Steel gray
            ]
        case .medical:
            return [
                Color(white: 0.98),                          // Clinical white
                Color(red: 0.2, green: 0.6, blue: 0.7),     // Medical teal
                Color(red: 0.8, green: 0.2, blue: 0.2),     // Red cross
                Color(red: 0.85, green: 0.9, blue: 0.92)    // Pale mint
            ]
        case .business:
            return [
                Color(red: 0.95, green: 0.95, blue: 0.95),  // Professional white
                Color(red: 0.2, green: 0.3, blue: 0.5),     // Corporate blue
                Color(red: 0.5, green: 0.5, blue: 0.5),     // Neutral gray
                Color(red: 0.1, green: 0.2, blue: 0.3)      // Dark navy
            ]
        case .history:
            return [
                Color(red: 0.92, green: 0.88, blue: 0.82),  // Parchment
                Color(red: 0.6, green: 0.5, blue: 0.4),     // Sepia brown
                Color(red: 0.7, green: 0.65, blue: 0.55),   // Aged paper
                Color(red: 0.4, green: 0.35, blue: 0.3)     // Dark brown
            ]
        default:
            return [
                Color(white: 0.9),
                Color(white: 0.7),
                Color(white: 0.5),
                Color(white: 0.3)
            ]
        }
    }
    
    // Mood color for gradient formula
    var moodColor: Color {
        switch self {
        case .fantasy: return Color(red: 0.3, green: 0.2, blue: 0.5)      // Deep purple
        case .philosophy: return Color(red: 0.4, green: 0.5, blue: 0.65)  // Thoughtful blue
        case .selfHelp: return Color(red: 0.95, green: 0.6, blue: 0.2)    // Energetic orange
        case .science: return Color(red: 0.4, green: 0.75, blue: 0.85)    // Lab teal
        case .medical: return Color(red: 0.3, green: 0.65, blue: 0.75)    // Clinical teal
        case .business: return Color(red: 0.25, green: 0.35, blue: 0.55)  // Professional blue
        case .romance: return Color(red: 0.95, green: 0.7, blue: 0.75)    // Soft pink
        case .thriller: return Color(red: 0.2, green: 0.1, blue: 0.15)    // Dark shadow
        case .literary: return Color(red: 0.65, green: 0.55, blue: 0.45)  // Warm earth
        case .sciFi: return Color(red: 0.3, green: 0.4, blue: 0.7)        // Space blue
        case .history: return Color(red: 0.55, green: 0.45, blue: 0.35)   // Antique brown
        case .mystery: return Color(red: 0.25, green: 0.2, blue: 0.3)     // Mysterious gray
        default: return Color(red: 0.5, green: 0.5, blue: 0.6)            // Neutral gray
        }
    }
}

// MARK: - Improved Color Analyzer
struct ImprovedColorAnalyzer {
    struct ColorResult {
        let colors: [Color]
        let isWhiteCover: Bool
        let isMonochromatic: Bool
        let accentColor: Color
        let genre: BookGenre
        let averageBrightness: Double
    }
    
    func extractColors(from image: UIImage, bookTitle: String?, bookAuthor: String?) -> ColorResult {
        // Detect genre from title and author
        let genre = detectGenre(title: bookTitle, author: bookAuthor)
        guard let cgImage = image.cgImage else {
            return ColorResult(
                colors: genre.colorPalette,
                isWhiteCover: false,
                isMonochromatic: false,
                accentColor: genre.colorPalette[1],
                genre: genre,
                averageBrightness: 0.5
            )
        }
        
        // Resize for analysis
        let maxDimension: CGFloat = 100
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
            return ColorResult(
                colors: fallbackColors(), 
                isWhiteCover: false,
                isMonochromatic: false,
                accentColor: Color(red: 1.0, green: 0.55, blue: 0.26),
                genre: genre,
                averageBrightness: 0.5
            )
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else {
            return ColorResult(
                colors: fallbackColors(), 
                isWhiteCover: false,
                isMonochromatic: false,
                accentColor: Color(red: 1.0, green: 0.55, blue: 0.26),
                genre: genre,
                averageBrightness: 0.5
            )
        }
        
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Analyze colors
        var whitePixelCount = 0
        var colorBuckets: [String: (color: UIColor, count: Int)] = [:]
        var totalBrightness: CGFloat = 0
        var pixelCount = 0
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * 4
                let r = CGFloat(pixels[index]) / 255.0
                let g = CGFloat(pixels[index + 1]) / 255.0
                let b = CGFloat(pixels[index + 2]) / 255.0
                
                // Check if pixel is white/light gray
                let brightness = (r + g + b) / 3.0
                let saturation = max(r, g, b) - min(r, g, b)
                
                // Track average brightness
                totalBrightness += brightness
                pixelCount += 1
                
                // Smart white cover detection: brightness > 0.85
                if brightness > 0.85 && saturation < 0.2 {
                    whitePixelCount += 1
                } else if brightness > 0.2 && saturation > 0.1 {
                    // This is a colored pixel - potential accent color
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    
                    // Quantize color to reduce variations
                    let key = quantizeColor(r: r, g: g, b: b)
                    if let existing = colorBuckets[key] {
                        colorBuckets[key] = (existing.color, existing.count + 1)
                    } else {
                        colorBuckets[key] = (color, 1)
                    }
                }
            }
        }
        
        // Calculate average brightness first
        let averageBrightness = pixelCount > 0 ? Double(totalBrightness / CGFloat(pixelCount)) : 0.5
        
        // Determine if this is a white cover
        let totalPixels = (width / 2) * (height / 2)
        let isWhiteCover = Float(whitePixelCount) / Float(totalPixels) > 0.6
        
        // Sort colors by frequency and vibrancy
        let sortedColors = colorBuckets.values
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0.color }
        
        // Extract the most vibrant colors
        var extractedColors: [Color] = []
        
        // Track accent color for UI elements
        var primaryAccentColor: Color? = nil
        
        if isWhiteCover {
            // Smart color logic for white covers using gradient formula
            print("📚 White cover detected, applying gradient formula...")
            
            // Find the most saturated accent color
            var primaryAccent: Color? = nil
            var mostSaturated: CGFloat = 0
            
            for uiColor in sortedColors {
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                if s > mostSaturated && b > 0.3 {
                    mostSaturated = s
                    primaryAccent = Color(
                        hue: Double(h),
                        saturation: Double(min(1.0, s * 1.5)),
                        brightness: Double(b)
                    )
                }
            }
            
            // GRADIENT FORMULA for white covers:
            // 40% Soft base (cream/off-white)
            // 30% Primary accent (from cover)
            // 20% Mood color (from genre)
            // 10% Dark anchor (for depth)
            
            let baseColor = Color(red: 0.98, green: 0.97, blue: 0.96)  // Warm cream
            let accentFromCover = primaryAccent ?? genre.colorPalette[1]
            let moodFromGenre = genre.moodColor
            let darkAnchor = Color(red: 0.2, green: 0.2, blue: 0.25)   // Deep anchor
            
            // Special cases for specific genres
            if genre == .selfHelp && bookTitle?.lowercased().contains("atomic") ?? false {
                // Atomic Habits specific
                extractedColors = [
                    baseColor,                                   // Cream base
                    accentFromCover,                            // Red accent
                    Color(red: 1.0, green: 0.6, blue: 0.2),    // Motivational orange
                    darkAnchor
                ]
            } else if genre == .selfHelp && bookTitle?.lowercased().contains("subtle art") ?? false {
                // The Subtle Art specific
                extractedColors = [
                    Color(white: 0.97),                         // Off-white
                    accentFromCover,                            // Orange accent
                    Color(red: 0.6, green: 0.65, blue: 0.7),   // Cool gray
                    darkAnchor
                ]
            } else if genre == .medical {
                // Medical text with red cross
                extractedColors = [
                    Color(white: 0.98),                         // Clinical white
                    accentFromCover,                            // Red cross if present
                    Color(red: 0.3, green: 0.65, blue: 0.75),  // Clinical teal
                    darkAnchor
                ]
            } else {
                // Default gradient formula application
                extractedColors = [
                    baseColor.opacity(0.9),                     // 40% influence
                    accentFromCover.opacity(0.8),               // 30% influence
                    moodFromGenre.opacity(0.7),                 // 20% influence
                    darkAnchor.opacity(0.6)                     // 10% influence
                ]
            }
            
            // Set primary accent color for UI elements
            primaryAccentColor = accentFromCover
            
        } else {
            // For colored covers, extract dominant colors with smart enhancement
            let isDarkCover = averageBrightness < 0.4
            
            for uiColor in sortedColors {
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                // Dynamic enhancement based on cover brightness
                let saturationBoost = isDarkCover ? 2.0 : 1.8
                let brightnessBoost = isDarkCover ? 1.4 : 1.1
                
                let enhancedColor = Color(
                    hue: Double(h),
                    saturation: Double(min(1.0, s * saturationBoost)),
                    brightness: Double(min(0.95, b * brightnessBoost))
                )
                extractedColors.append(enhancedColor)
                if extractedColors.count >= 4 {
                    break
                }
            }
            
            // Set primary accent color as the most vibrant
            if !extractedColors.isEmpty {
                primaryAccentColor = extractedColors.first
            }
        }
        
        // Ensure we have at least 4 colors
        while extractedColors.count < 4 {
            extractedColors.append(extractedColors.last ?? Color.gray.opacity(0.5))
        }
        
        // Check if colors are monochromatic
        let isMonochromatic = checkIfMonochromatic(extractedColors)
        
        // Determine accent color for UI elements
        // For monochromatic covers, pick second color or generate complementary
        let accentColor: Color
        if isMonochromatic && extractedColors.count >= 2 {
            accentColor = extractedColors[1]
        } else {
            accentColor = primaryAccentColor ?? findDarkestColor(from: extractedColors)
        }
        
        return ColorResult(
            colors: extractedColors,
            isWhiteCover: isWhiteCover,
            isMonochromatic: isMonochromatic,
            accentColor: accentColor,
            genre: genre,
            averageBrightness: averageBrightness
        )
    }
    
    private func quantizeColor(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        // Quantize to reduce color variations
        let qR = Int(r * 10)
        let qG = Int(g * 10)
        let qB = Int(b * 10)
        return "\(qR)-\(qG)-\(qB)"
    }
    
    private func detectGenre(title: String?, author: String?) -> BookGenre {
        let combinedText = "\(title ?? "") \(author ?? "")".lowercased()
        
        // Self-Help keywords
        if combinedText.contains("habits") || combinedText.contains("self") ||
           combinedText.contains("improve") || combinedText.contains("better") ||
           combinedText.contains("success") || combinedText.contains("mind") ||
           combinedText.contains("atomic") || combinedText.contains("subtle art") {
            return .selfHelp
        }
        
        // Medical keywords
        if combinedText.contains("medical") || combinedText.contains("medicine") ||
           combinedText.contains("anatomy") || combinedText.contains("health") ||
           combinedText.contains("clinical") || combinedText.contains("patient") {
            return .medical
        }
        
        // Science keywords
        if combinedText.contains("science") || combinedText.contains("physics") ||
           combinedText.contains("chemistry") || combinedText.contains("biology") ||
           combinedText.contains("research") || combinedText.contains("theory") {
            return .science
        }
        
        // Business keywords
        if combinedText.contains("business") || combinedText.contains("management") ||
           combinedText.contains("leader") || combinedText.contains("strategy") ||
           combinedText.contains("market") || combinedText.contains("economy") {
            return .business
        }
        
        // History keywords
        if combinedText.contains("history") || combinedText.contains("war") ||
           combinedText.contains("ancient") || combinedText.contains("civil") ||
           combinedText.contains("revolution") || combinedText.contains("empire") {
            return .history
        }
        
        // Fantasy keywords
        if combinedText.contains("tolkien") || combinedText.contains("ring") ||
           combinedText.contains("hobbit") || combinedText.contains("dragon") ||
           combinedText.contains("magic") || combinedText.contains("wizard") {
            return .fantasy
        }
        
        // Philosophy
        if combinedText.contains("philosophy") || combinedText.contains("plato") ||
           combinedText.contains("nietzsche") || combinedText.contains("kant") ||
           combinedText.contains("wisdom") || combinedText.contains("think") {
            return .philosophy
        }
        
        // Romance
        if combinedText.contains("love") || combinedText.contains("romance") ||
           combinedText.contains("heart") || combinedText.contains("kiss") {
            return .romance
        }
        
        // Thriller/Mystery
        if combinedText.contains("murder") || combinedText.contains("thriller") ||
           combinedText.contains("mystery") || combinedText.contains("detective") ||
           combinedText.contains("crime") || combinedText.contains("suspense") {
            return combinedText.contains("mystery") ? .mystery : .thriller
        }
        
        // Sci-Fi
        if combinedText.contains("space") || combinedText.contains("robot") ||
           combinedText.contains("future") || combinedText.contains("sci-fi") {
            return .sciFi
        }
        
        // Literary fiction (default for unknown)
        return .literary
    }
    
    private func generateComplementaryColor(for color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        // Rotate hue by 180 degrees for complementary
        let complementaryHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
        
        return Color(
            hue: Double(complementaryHue),
            saturation: Double(s * 0.7), // Slightly less saturated
            brightness: Double(b * 0.8)  // Slightly darker
        )
    }
    
    private func checkIfMonochromatic(_ colors: [Color]) -> Bool {
        guard colors.count >= 2 else { return false }
        
        var hues: [CGFloat] = []
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Only consider colors with enough saturation
            if s > 0.1 {
                hues.append(h)
            }
        }
        
        guard hues.count >= 2 else { return false }
        
        // Check if all hues are within 30 degrees (0.083 in 0-1 scale)
        let sortedHues = hues.sorted()
        let maxDifference = sortedHues.last! - sortedHues.first!
        
        // Also check wrap-around (red hues near 0 and 1)
        let wrapDifference = (1.0 - sortedHues.last!) + sortedHues.first!
        
        return min(maxDifference, wrapDifference) < 0.083
    }
    
    private func findDarkestColor(from colors: [Color]) -> Color {
        var darkestColor = colors.first ?? .black
        var lowestBrightness: CGFloat = 1.0
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            if b < lowestBrightness && b > 0.1 { // Avoid pure black
                lowestBrightness = b
                darkestColor = color
            }
        }
        
        return darkestColor
    }
    
    private func fallbackColors() -> [Color] {
        return [
            Color(red: 0.95, green: 0.95, blue: 0.95),  // Light gray
            Color(red: 0.9, green: 0.75, blue: 0.3),    // Gold
            Color(red: 0.8, green: 0.8, blue: 0.8),     // Medium gray
            Color(red: 1.0, green: 0.95, blue: 0.85)    // Warm white
        ]
    }
}

// MARK: - Grain Texture
struct GrainTexture: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                for _ in 0..<100 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0.4...0.6)
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
        }
        .blendMode(.overlay)
    }
}