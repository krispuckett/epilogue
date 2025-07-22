import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Professional Cinematic Book Gradient System
struct ProfessionalBookGradient: View {
    let bookCoverImage: UIImage
    let scrollOffset: CGFloat
    
    @State private var extractedPalette: VibrantPalette = VibrantPalette()
    @State private var meshNodes: [MeshNode] = []
    @State private var plasmaLayers: [PlasmaLayer] = []
    @State private var particleField: [LightParticle] = []
    
    // Animation states
    @State private var globalPhase: Double = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var rotationPhase: Double = 0
    @State private var plasmaPhase: Double = 0
    
    var onAccentColorExtracted: ((Color) -> Void)?
    
    // MARK: - Data Structures
    struct VibrantPalette {
        var hero: Color = Color(hue: 0.6, saturation: 0.9, brightness: 0.9)      // Primary vibrant color
        var accent: Color = Color(hue: 0.1, saturation: 0.85, brightness: 0.95)  // Complementary pop
        var glow: Color = Color(hue: 0.8, saturation: 0.8, brightness: 1.0)      // Bright highlight
        var deep: Color = Color(hue: 0.5, saturation: 0.9, brightness: 0.6)      // Rich deep tone
        var spark: Color = Color(hue: 0.15, saturation: 0.7, brightness: 1.0)    // Light accent
        var neon: Color = Color(hue: 0.3, saturation: 1.0, brightness: 0.9)      // Electric color
        var aura: Color = Color(hue: 0.7, saturation: 0.6, brightness: 0.8)      // Atmospheric
        
        var temperature: Temperature = .balanced
        var energy: EnergyLevel = .high
        
        enum Temperature {
            case cool, warm, balanced, electric
        }
        
        enum EnergyLevel {
            case calm, moderate, high, intense
        }
    }
    
    struct MeshNode {
        let id = UUID()
        var basePosition: CGPoint
        var color: Color
        var radius: CGFloat
        var frequency: Double
        var amplitude: Double
        var phaseOffset: Double
        var blendMode: BlendMode
    }
    
    struct PlasmaLayer {
        var colors: [Color]
        var scale: CGFloat
        var speed: Double
        var complexity: Int
        var opacity: Double
    }
    
    struct LightParticle {
        var position: CGPoint
        var velocity: CGVector
        var color: Color
        var size: CGFloat
        var lifespan: Double
        var intensity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 0: Deep space black for contrast
                Color.black
                    .ignoresSafeArea()
                
                // Layer 1: Ultra-blurred cover with enhanced saturation
                enhancedCoverLayer(size: geometry.size)
                
                // Layer 2: Plasma gradient system
                plasmaGradientSystem(size: geometry.size)
                
                // Layer 3: Dynamic mesh network
                meshNetworkLayer(size: geometry.size)
                
                // Layer 4: Particle field
                particleFieldLayer(size: geometry.size)
                
                // Layer 5: Light bloom effects
                lightBloomLayer(size: geometry.size)
                
                // Layer 6: Cinematic polish
                cinematicPolishLayer(size: geometry.size)
            }
            .ignoresSafeArea()
            .onAppear {
                Task {
                    await extractVibrantColors()
                    setupDynamicElements(size: geometry.size)
                    startCinematicAnimations()
                }
            }
        }
    }
    
    // MARK: - Layer 1: Enhanced Cover
    @ViewBuilder
    private func enhancedCoverLayer(size: CGSize) -> some View {
        // First pass: Heavy blur with saturation boost
        Image(uiImage: bookCoverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width * 1.5, height: size.height * 1.5)
            .scaleEffect(breathingScale)
            .rotationEffect(.degrees(rotationPhase))
            .offset(y: scrollOffset * 0.15)
            .blur(radius: 120)
            .saturation(2.5) // Massive saturation boost
            .contrast(1.3)
            .opacity(0.4)
            .blendMode(.screen)
        
        // Second pass: Medium blur for texture
        Image(uiImage: bookCoverImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width * 1.3, height: size.height * 1.3)
            .scaleEffect(breathingScale * 0.95)
            .offset(y: scrollOffset * 0.1)
            .blur(radius: 80)
            .saturation(3.0)
            .opacity(0.2)
            .blendMode(.colorDodge)
    }
    
    // MARK: - Layer 2: Plasma Gradients
    @ViewBuilder
    private func plasmaGradientSystem(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for (index, layer) in plasmaLayers.enumerated() {
                    let layerTime = time * layer.speed + Double(index) * 0.5
                    
                    // Create plasma effect with multiple sine waves
                    for i in 0..<layer.complexity {
                        let phase = layerTime + Double(i) * .pi / Double(layer.complexity)
                        
                        for j in 0..<layer.complexity {
                            let x = canvasSize.width * (0.5 + 0.4 * sin(phase * 1.3 + Double(j)))
                            let y = canvasSize.height * (0.5 + 0.4 * cos(phase * 0.7 + Double(j) * 0.8))
                            
                            let colorIndex = (i + j) % layer.colors.count
                            let color = layer.colors[colorIndex]
                            
                            let radius = canvasSize.width * layer.scale * (0.8 + 0.2 * sin(phase * 2))
                            
                            let gradient = Gradient(stops: [
                                .init(color: color, location: 0),
                                .init(color: color.opacity(0.6), location: 0.3),
                                .init(color: color.opacity(0.2), location: 0.7),
                                .init(color: .clear, location: 1)
                            ])
                            
                            context.fill(
                                Circle()
                                    .path(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                with: .radialGradient(gradient, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius)
                            )
                        }
                    }
                }
            }
            .blendMode(.plusLighter)
            .opacity(0.7)
        }
    }
    
    // MARK: - Layer 3: Mesh Network
    @ViewBuilder
    private func meshNetworkLayer(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for node in meshNodes {
                    // Calculate dynamic position
                    let t = time * node.frequency + node.phaseOffset
                    let dx = sin(t) * node.amplitude
                    let dy = cos(t * 0.7) * node.amplitude * 0.8
                    
                    let currentPos = CGPoint(
                        x: node.basePosition.x + dx,
                        y: node.basePosition.y + dy
                    )
                    
                    // Pulsing radius
                    let pulseRadius = node.radius * (1 + 0.3 * sin(t * 2))
                    
                    // Rich gradient with multiple stops
                    let gradient = Gradient(stops: [
                        .init(color: node.color, location: 0),
                        .init(color: node.color.opacity(0.8), location: 0.2),
                        .init(color: node.color.opacity(0.5), location: 0.5),
                        .init(color: node.color.opacity(0.2), location: 0.8),
                        .init(color: .clear, location: 1)
                    ])
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(
                                x: currentPos.x - pulseRadius,
                                y: currentPos.y - pulseRadius,
                                width: pulseRadius * 2,
                                height: pulseRadius * 2
                            )),
                        with: .radialGradient(gradient, center: currentPos, startRadius: 0, endRadius: pulseRadius)
                    )
                }
                
                // Draw connections between nearby nodes
                context.stroke(
                    Path { path in
                        for i in 0..<meshNodes.count {
                            for j in (i + 1)..<meshNodes.count {
                                let node1 = meshNodes[i]
                                let node2 = meshNodes[j]
                                
                                let t1 = time * node1.frequency + node1.phaseOffset
                                let pos1 = CGPoint(
                                    x: node1.basePosition.x + sin(t1) * node1.amplitude,
                                    y: node1.basePosition.y + cos(t1 * 0.7) * node1.amplitude * 0.8
                                )
                                
                                let t2 = time * node2.frequency + node2.phaseOffset
                                let pos2 = CGPoint(
                                    x: node2.basePosition.x + sin(t2) * node2.amplitude,
                                    y: node2.basePosition.y + cos(t2 * 0.7) * node2.amplitude * 0.8
                                )
                                
                                let distance = hypot(pos2.x - pos1.x, pos2.y - pos1.y)
                                
                                if distance < canvasSize.width * 0.3 {
                                    path.move(to: pos1)
                                    path.addLine(to: pos2)
                                }
                            }
                        }
                    },
                    with: .linearGradient(
                        Gradient(colors: [extractedPalette.glow.opacity(0.3), extractedPalette.spark.opacity(0.1)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                    ),
                    lineWidth: 1
                )
            }
            .blendMode(meshNodes.first?.blendMode ?? .screen)
            .opacity(0.8)
        }
    }
    
    // MARK: - Layer 4: Particle Field
    @ViewBuilder
    private func particleFieldLayer(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1/60)) { _ in
            Canvas { context, canvasSize in
                for particle in particleField {
                    let glowGradient = Gradient(stops: [
                        .init(color: particle.color, location: 0),
                        .init(color: particle.color.opacity(0.5), location: 0.5),
                        .init(color: .clear, location: 1)
                    ])
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(
                                x: particle.position.x - particle.size,
                                y: particle.position.y - particle.size,
                                width: particle.size * 2,
                                height: particle.size * 2
                            )),
                        with: .radialGradient(
                            glowGradient,
                            center: particle.position,
                            startRadius: 0,
                            endRadius: particle.size * 2
                        )
                    )
                }
            }
            .blendMode(.plusLighter)
            .opacity(0.6)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
                updateParticles(size: size)
            }
        }
    }
    
    // MARK: - Layer 5: Light Blooms
    @ViewBuilder
    private func lightBloomLayer(size: CGSize) -> some View {
        // Hero light bloom
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        extractedPalette.hero.opacity(0.6),
                        extractedPalette.hero.opacity(0.3),
                        extractedPalette.hero.opacity(0.1),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size.width * 0.5
                )
            )
            .frame(width: size.width * 1.2, height: size.width * 1.2)
            .offset(x: sin(globalPhase) * 50, y: cos(globalPhase * 0.7) * 30)
            .blur(radius: 30)
            .blendMode(.screen)
        
        // Accent light bloom
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        extractedPalette.accent.opacity(0.5),
                        extractedPalette.accent.opacity(0.2),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size.width * 0.4
                )
            )
            .frame(width: size.width * 0.8, height: size.width * 0.8)
            .offset(x: -sin(globalPhase * 1.3) * 70, y: sin(globalPhase * 0.9) * 50)
            .blur(radius: 25)
            .blendMode(.colorDodge)
    }
    
    // MARK: - Layer 6: Cinematic Polish
    @ViewBuilder
    private func cinematicPolishLayer(size: CGSize) -> some View {
        // Vignette with color tint
        Rectangle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.1), location: 0.5),
                        .init(color: extractedPalette.deep.opacity(0.3), location: 0.8),
                        .init(color: .black.opacity(0.6), location: 1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size.height * 0.8
                )
            )
            .allowsHitTesting(false)
        
        // Film grain
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                for _ in 0..<150 {
                    let x = CGFloat.random(in: 0 ... size.width)
                    let y = CGFloat.random(in: 0 ... size.height)
                    let brightness = CGFloat.random(in: 0.5 ... 0.8)
                    
                    context.fill(
                        Circle().path(in: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
            .blendMode(.overlay)
            .opacity(0.03)
        }
    }
    
    // MARK: - Color Extraction Engine
    private func extractVibrantColors() async {
        guard let ciImage = CIImage(image: bookCoverImage) else { return }
        
        let context = CIContext()
        let size = CGSize(width: 150, height: 150)
        
        // Scale image for analysis
        let scaleFilter = CIFilter.lanczosScaleTransform()
        scaleFilter.inputImage = ciImage
        scaleFilter.scale = Float(size.width / ciImage.extent.width)
        
        guard let outputImage = scaleFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        // Extract and process colors
        let analysis = performAdvancedColorAnalysis(cgImage)
        extractedPalette = generateVibrantPalette(from: analysis)
        
        // Notify parent
        onAccentColorExtracted?(extractedPalette.accent)
    }
    
    private struct ColorAnalysis {
        var dominantColors: [(color: UIColor, weight: Double)] = []
        var colorClusters: [ColorCluster] = []
        var overallBrightness: Double = 0
        var overallSaturation: Double = 0
        var hasWhiteDominance: Bool = false
        var hasDarkDominance: Bool = false
        var colorVariety: Double = 0
    }
    
    private struct ColorCluster {
        var centroid: UIColor
        var colors: [UIColor]
        var weight: Double
    }
    
    private func performAdvancedColorAnalysis(_ cgImage: CGImage) -> ColorAnalysis {
        var analysis = ColorAnalysis()
        
        let width = cgImage.width
        let height = cgImage.height
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
        ) else { return analysis }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Collect all colors with K-means clustering
        var allColors: [UIColor] = []
        var totalBrightness: Double = 0
        var totalSaturation: Double = 0
        var whiteCount = 0
        var darkCount = 0
        
        // Sample pixels
        for y in stride(from: 0, to: height, by: 3) {
            for x in stride(from: 0, to: width, by: 3) {
                let index = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                allColors.append(color)
                totalBrightness += Double(br)
                totalSaturation += Double(s)
                
                if br > 0.9 && s < 0.1 { whiteCount += 1 }
                if br < 0.2 { darkCount += 1 }
            }
        }
        
        let sampleCount = allColors.count
        analysis.overallBrightness = totalBrightness / Double(sampleCount)
        analysis.overallSaturation = totalSaturation / Double(sampleCount)
        analysis.hasWhiteDominance = Double(whiteCount) / Double(sampleCount) > 0.3
        analysis.hasDarkDominance = Double(darkCount) / Double(sampleCount) > 0.3
        
        // Perform K-means clustering
        let clusters = performKMeansClustering(colors: allColors, k: 7)
        analysis.colorClusters = clusters
        
        // Extract dominant colors
        analysis.dominantColors = clusters
            .sorted { $0.weight > $1.weight }
            .map { ($0.centroid, $0.weight) }
        
        return analysis
    }
    
    private func performKMeansClustering(colors: [UIColor], k: Int) -> [ColorCluster] {
        // Simplified K-means implementation
        var centroids = colors.shuffled().prefix(k).map { $0 }
        var clusters: [ColorCluster] = []
        
        for _ in 0..<10 { // iterations
            clusters = centroids.map { ColorCluster(centroid: $0, colors: [], weight: 0) }
            
            // Assign colors to nearest centroid
            for color in colors {
                let nearestIndex = findNearestCentroid(color: color, centroids: centroids)
                clusters[nearestIndex].colors.append(color)
            }
            
            // Update centroids
            for i in 0..<k {
                if !clusters[i].colors.isEmpty {
                    centroids[i] = averageColor(colors: clusters[i].colors)
                    clusters[i].centroid = centroids[i]
                    clusters[i].weight = Double(clusters[i].colors.count) / Double(colors.count)
                }
            }
        }
        
        return clusters.filter { !$0.colors.isEmpty }
    }
    
    private func findNearestCentroid(color: UIColor, centroids: [UIColor]) -> Int {
        var minDistance = Double.infinity
        var nearestIndex = 0
        
        for (index, centroid) in centroids.enumerated() {
            let distance = colorDistance(color, centroid)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    private func colorDistance(_ c1: UIColor, _ c2: UIColor) -> Double {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        
        let dr = Double(r1 - r2)
        let dg = Double(g1 - g2)
        let db = Double(b1 - b2)
        
        return sqrt(dr * dr + dg * dg + db * db)
    }
    
    private func averageColor(colors: [UIColor]) -> UIColor {
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            totalR += r
            totalG += g
            totalB += b
        }
        
        let count = CGFloat(colors.count)
        return UIColor(red: totalR / count, green: totalG / count, blue: totalB / count, alpha: 1.0)
    }
    
    private func generateVibrantPalette(from analysis: ColorAnalysis) -> VibrantPalette {
        var palette = VibrantPalette()
        
        // Special handling for different cover types
        if analysis.hasWhiteDominance {
            // White/light covers: Generate bold complementary palette
            palette = generateComplementaryVibrantPalette()
        } else if analysis.hasDarkDominance {
            // Dark covers: Add neon accents
            palette = generateNeonAccentedPalette(from: analysis)
        } else if analysis.overallSaturation < 0.3 {
            // Monochrome/desaturated: Create harmonic variations
            palette = generateHarmonicVibrantPalette(from: analysis)
        } else {
            // Colorful covers: Enhance and amplify
            palette = amplifyExistingColors(from: analysis)
        }
        
        // Ensure maximum vibrancy
        palette = maximizeVibrancy(palette)
        
        // Determine characteristics
        palette.temperature = determineTemperature(from: palette)
        palette.energy = determineEnergy(from: analysis)
        
        return palette
    }
    
    private func generateComplementaryVibrantPalette() -> VibrantPalette {
        var palette = VibrantPalette()
        
        // Golden ratio color wheel positions for maximum harmony
        let baseHue = Double.random(in: 0 ... 1)
        
        palette.hero = Color(hue: baseHue, saturation: 0.9, brightness: 0.85)
        palette.accent = Color(hue: (baseHue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.95, brightness: 0.9)
        palette.glow = Color(hue: (baseHue + 0.618).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 1.0)
        palette.deep = Color(hue: (baseHue + 0.382).truncatingRemainder(dividingBy: 1), saturation: 1.0, brightness: 0.6)
        palette.spark = Color(hue: (baseHue + 0.15).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.95)
        palette.neon = Color(hue: (baseHue + 0.85).truncatingRemainder(dividingBy: 1), saturation: 1.0, brightness: 0.9)
        palette.aura = Color(hue: baseHue, saturation: 0.5, brightness: 0.8)
        
        return palette
    }
    
    private func generateNeonAccentedPalette(from analysis: ColorAnalysis) -> VibrantPalette {
        var palette = VibrantPalette()
        
        // Extract base color from dominant dark tones
        if let firstColor = analysis.dominantColors.first {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            firstColor.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Create electric variations
            palette.hero = Color(hue: Double(h), saturation: 0.9, brightness: 0.8)
            palette.accent = Color(hue: Double(h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 1.0, brightness: 0.9)
            palette.glow = Color(hue: 0.55, saturation: 1.0, brightness: 1.0) // Cyan glow
            palette.deep = Color(hue: Double(h), saturation: 0.8, brightness: 0.5)
            palette.spark = Color(hue: 0.9, saturation: 1.0, brightness: 1.0) // Magenta spark
            palette.neon = Color(hue: 0.15, saturation: 1.0, brightness: 0.95) // Electric yellow
            palette.aura = Color(hue: 0.75, saturation: 0.8, brightness: 0.7) // Purple aura
        }
        
        return palette
    }
    
    private func generateHarmonicVibrantPalette(from analysis: ColorAnalysis) -> VibrantPalette {
        var palette = VibrantPalette()
        
        // Find any hint of color
        var baseHue: Double = 0.6 // Default to cyan if truly monochrome
        
        for (color, _) in analysis.dominantColors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            if s > 0.1 {
                baseHue = Double(h)
                break
            }
        }
        
        // Create rich harmonic variations
        palette.hero = Color(hue: baseHue, saturation: 0.85, brightness: 0.8)
        palette.accent = Color(hue: (baseHue + 0.083).truncatingRemainder(dividingBy: 1), saturation: 0.9, brightness: 0.85)
        palette.glow = Color(hue: (baseHue - 0.083).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.95)
        palette.deep = Color(hue: baseHue, saturation: 0.95, brightness: 0.6)
        palette.spark = Color(hue: (baseHue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.9)
        palette.neon = Color(hue: (baseHue + 0.167).truncatingRemainder(dividingBy: 1), saturation: 1.0, brightness: 0.85)
        palette.aura = Color(hue: baseHue, saturation: 0.6, brightness: 0.75)
        
        return palette
    }
    
    private func amplifyExistingColors(from analysis: ColorAnalysis) -> VibrantPalette {
        var palette = VibrantPalette()
        let colors = analysis.dominantColors.prefix(7)
        
        // Amplify and assign colors
        if colors.count >= 1 {
            palette.hero = superchargeColor(colors[0].color, targetSaturation: 0.9)
        }
        if colors.count >= 2 {
            palette.accent = superchargeColor(colors[1].color, targetSaturation: 0.95)
        }
        if colors.count >= 3 {
            palette.glow = superchargeColor(colors[2].color, targetSaturation: 0.7, targetBrightness: 0.95)
        }
        if colors.count >= 4 {
            palette.deep = superchargeColor(colors[3].color, targetSaturation: 0.9, targetBrightness: 0.6)
        }
        if colors.count >= 5 {
            palette.spark = superchargeColor(colors[4].color, targetSaturation: 0.8, targetBrightness: 0.9)
        }
        if colors.count >= 6 {
            palette.neon = superchargeColor(colors[5].color, targetSaturation: 1.0)
        }
        if colors.count >= 7 {
            palette.aura = superchargeColor(colors[6].color, targetSaturation: 0.7)
        }
        
        // Fill any missing colors
        if colors.count < 7 {
            let baseColor = colors.first?.color ?? UIColor.cyan
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            if colors.count < 6 {
                palette.neon = Color(hue: Double(h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 1.0, brightness: 0.9)
            }
            if colors.count < 5 {
                palette.spark = Color(hue: Double(h + 0.25).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.95)
            }
        }
        
        return palette
    }
    
    private func superchargeColor(_ color: UIColor, targetSaturation: Double = 0.9, targetBrightness: Double? = nil) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Ensure minimum saturation
        let finalSaturation = max(Double(s) * 1.5, targetSaturation)
        
        // Adjust brightness if specified, otherwise enhance slightly
        let finalBrightness = targetBrightness ?? min(Double(b) * 1.3, 0.9)
        
        return Color(hue: Double(h), saturation: min(finalSaturation, 1.0), brightness: finalBrightness)
    }
    
    private func maximizeVibrancy(_ palette: VibrantPalette) -> VibrantPalette {
        var maxed = palette
        
        // Ensure all colors meet minimum vibrancy requirements
        maxed.hero = ensureVibrancy(palette.hero, minSaturation: 0.8)
        maxed.accent = ensureVibrancy(palette.accent, minSaturation: 0.85)
        maxed.glow = ensureVibrancy(palette.glow, minSaturation: 0.6, minBrightness: 0.9)
        maxed.deep = ensureVibrancy(palette.deep, minSaturation: 0.8, maxBrightness: 0.7)
        maxed.spark = ensureVibrancy(palette.spark, minSaturation: 0.7, minBrightness: 0.85)
        maxed.neon = ensureVibrancy(palette.neon, minSaturation: 0.9)
        maxed.aura = ensureVibrancy(palette.aura, minSaturation: 0.5)
        
        return maxed
    }
    
    private func ensureVibrancy(_ color: Color, minSaturation: Double = 0.8, minBrightness: Double = 0.6, maxBrightness: Double = 1.0) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        let finalSaturation = max(Double(s), minSaturation)
        let finalBrightness = min(max(Double(b), minBrightness), maxBrightness)
        
        return Color(hue: Double(h), saturation: finalSaturation, brightness: finalBrightness)
    }
    
    private func determineTemperature(from palette: VibrantPalette) -> VibrantPalette.Temperature {
        let uiColor = UIColor(palette.hero)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Cool: blues, greens (0.4 - 0.7)
        // Warm: reds, oranges (0 - 0.15, 0.85 - 1)
        // Electric: purples, magentas (0.7 - 0.85)
        
        if h >= 0.4 && h <= 0.7 {
            return .cool
        } else if h >= 0.7 && h <= 0.85 {
            return .electric
        } else if h <= 0.15 || h >= 0.85 {
            return .warm
        } else {
            return .balanced
        }
    }
    
    private func determineEnergy(from analysis: ColorAnalysis) -> VibrantPalette.EnergyLevel {
        let avgSaturation = analysis.overallSaturation
        let colorVariety = Double(analysis.colorClusters.count) / 7.0
        
        let energyScore = avgSaturation * 0.6 + colorVariety * 0.4
        
        if energyScore > 0.7 {
            return .intense
        } else if energyScore > 0.5 {
            return .high
        } else if energyScore > 0.3 {
            return .moderate
        } else {
            return .calm
        }
    }
    
    // MARK: - Dynamic Element Setup
    private func setupDynamicElements(size: CGSize) {
        // Create mesh nodes based on palette
        let positions: [(x: CGFloat, y: CGFloat)] = [
            (0.2, 0.3), (0.8, 0.2), (0.5, 0.5),
            (0.3, 0.7), (0.7, 0.8), (0.9, 0.5),
            (0.1, 0.6), (0.4, 0.9), (0.6, 0.1)
        ]
        
        let colors = [
            extractedPalette.hero,
            extractedPalette.accent,
            extractedPalette.glow,
            extractedPalette.deep,
            extractedPalette.spark,
            extractedPalette.neon,
            extractedPalette.aura,
            extractedPalette.hero.opacity(0.8),
            extractedPalette.accent.opacity(0.7)
        ]
        
        meshNodes = positions.enumerated().map { index, pos in
            MeshNode(
                basePosition: CGPoint(x: size.width * pos.x, y: size.height * pos.y),
                color: colors[index % colors.count],
                radius: size.width * CGFloat.random(in: 0.2 ... 0.4),
                frequency: Double.random(in: 0.1 ... 0.3),
                amplitude: Double.random(in: 30 ... 80),
                phaseOffset: Double.random(in: 0 ... (2 * .pi)),
                blendMode: index % 2 == 0 ? .screen : .plusLighter
            )
        }
        
        // Create plasma layers
        plasmaLayers = [
            PlasmaLayer(
                colors: [extractedPalette.hero, extractedPalette.accent, extractedPalette.glow],
                scale: 0.3,
                speed: 0.05,
                complexity: 3,
                opacity: 0.6
            ),
            PlasmaLayer(
                colors: [extractedPalette.deep, extractedPalette.spark, extractedPalette.neon],
                scale: 0.25,
                speed: -0.03,
                complexity: 4,
                opacity: 0.5
            ),
            PlasmaLayer(
                colors: [extractedPalette.aura, extractedPalette.hero, extractedPalette.accent],
                scale: 0.35,
                speed: 0.02,
                complexity: 2,
                opacity: 0.4
            )
        ]
        
        // Initialize particle field
        particleField = (0..<50).map { _ in
            LightParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0 ... size.width),
                    y: CGFloat.random(in: 0 ... size.height)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -30 ... 30),
                    dy: CGFloat.random(in: -50 ... 50)
                ),
                color: [extractedPalette.spark, extractedPalette.glow, extractedPalette.neon].randomElement()!,
                size: CGFloat.random(in: 2 ... 6),
                lifespan: Double.random(in: 3 ... 8),
                intensity: Double.random(in: 0.6 ... 1.0)
            )
        }
    }
    
    // MARK: - Animation Engine
    private func startCinematicAnimations() {
        // Global phase (60 second cycle)
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            globalPhase = .pi * 2
        }
        
        // Breathing effect (8 seconds)
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            breathingScale = 1.15
        }
        
        // Rotation (120 seconds for full rotation)
        withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
            rotationPhase = 360
        }
        
        // Plasma phase
        withAnimation(.linear(duration: 45).repeatForever(autoreverses: false)) {
            plasmaPhase = .pi * 2
        }
    }
    
    private func updateParticles(size: CGSize) {
        particleField = particleField.compactMap { particle in
            var updated = particle
            
            // Update position
            updated.position.x += updated.velocity.dx / 60
            updated.position.y += updated.velocity.dy / 60
            
            // Update lifespan
            updated.lifespan -= 1/60
            
            // Respawn if needed
            if updated.lifespan <= 0 || updated.position.x < -50 || updated.position.x > size.width + 50 ||
               updated.position.y < -50 || updated.position.y > size.height + 50 {
                
                // Respawn at edge
                let edge = Int.random(in: 0 ... 3)
                switch edge {
                case 0: // Top
                    updated.position = CGPoint(x: CGFloat.random(in: 0 ... size.width), y: -20)
                    updated.velocity.dy = CGFloat.random(in: 20 ... 60)
                case 1: // Right
                    updated.position = CGPoint(x: size.width + 20, y: CGFloat.random(in: 0 ... size.height))
                    updated.velocity.dx = CGFloat.random(in: -60 ... -20)
                case 2: // Bottom
                    updated.position = CGPoint(x: CGFloat.random(in: 0 ... size.width), y: size.height + 20)
                    updated.velocity.dy = CGFloat.random(in: -60 ... -20)
                default: // Left
                    updated.position = CGPoint(x: -20, y: CGFloat.random(in: 0 ... size.height))
                    updated.velocity.dx = CGFloat.random(in: 20 ... 60)
                }
                
                updated.lifespan = Double.random(in: 3 ... 8)
                updated.color = [extractedPalette.spark, extractedPalette.glow, extractedPalette.neon].randomElement()!
                updated.intensity = 1.0
            }
            
            return updated
        }
    }
}

// MARK: - Preview
struct ProfessionalBookGradient_Previews: PreviewProvider {
    static var previews: some View {
        if let image = UIImage(systemName: "book.fill") {
            ProfessionalBookGradient(
                bookCoverImage: image,
                scrollOffset: 0
            )
        }
    }
}