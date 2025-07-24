import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Fluid Gradient System
struct FluidGradientSystem: View {
    let bookCoverImage: UIImage
    @State private var extractedColors: [Color] = []
    @State private var timeOffset: Double = 0
    @StateObject private var noiseGenerator = PerlinNoiseGenerator()
    
    var body: some View {
        ZStack {
            // Base layer - deep dark foundation
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()
            
            // Fluid gradient layers - fewer layers with more blur
            if !extractedColors.isEmpty {
                ForEach(0..<3, id: \.self) { layer in
                    FluidGradientLayer(
                        colors: extractedColors,
                        layerIndex: layer,
                        timeOffset: timeOffset,
                        noiseGenerator: noiseGenerator
                    )
                    .blendMode(layer == 0 ? .normal : .screen)
                    .opacity(layer == 0 ? 0.8 : 0.4)
                    .blur(radius: 80 + Double(layer) * 20) // Very high blur for ink effect
                }
                
                // Subtle color overlay for richness
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                extractedColors.first?.opacity(0.2) ?? .clear,
                                extractedColors.last?.opacity(0.1) ?? .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                
                // Metallic sheen overlay
                MetallicSheenOverlay(timeOffset: timeOffset)
                    .blendMode(.colorDodge)
                    .opacity(0.15)
                
                // Film grain texture
                FilmGrainOverlay()
                    .blendMode(.overlay)
                    .opacity(0.05)
            }
        }
        .onAppear {
            extractBookColors()
            startAnimation()
        }
    }
    
    private func extractBookColors() {
        let analyzer = BookCoverColorAnalyzer()
        extractedColors = analyzer.extractDominantColors(from: bookCoverImage, count: 5)
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            timeOffset = 1.0
        }
    }
}

// MARK: - Fluid Gradient Layer
struct FluidGradientLayer: View {
    let colors: [Color]
    let layerIndex: Int
    let timeOffset: Double
    @ObservedObject var noiseGenerator: PerlinNoiseGenerator
    
    var body: some View {
        Canvas { context, size in
            let time = timeOffset * Double.pi * 2
            let layerSpeed = 0.7 / Double(layerIndex + 1)
            
            // Fewer, larger blobs for ink-like effect
            let blobCount = 2 + layerIndex
            
            for blob in 0..<blobCount {
                let colorIndex = (blob + layerIndex * 2) % colors.count
                let color = colors[colorIndex]
                
                // Slower, more fluid movement
                let angle = time * layerSpeed + Double(blob) * 2.0
                let radiusX = size.width * 0.3
                let radiusY = size.height * 0.4
                
                // Elliptical motion for more natural flow
                let baseX = size.width * 0.5 + radiusX * sin(angle)
                let baseY = size.height * 0.5 + radiusY * cos(angle * 0.7)
                
                // Gentle noise displacement
                let noiseScale = 0.1
                let noiseX = noiseGenerator.noise(
                    x: time * noiseScale + Double(blob),
                    y: Double(layerIndex) * 0.3
                ) * size.width * 0.2
                
                let noiseY = noiseGenerator.noise(
                    x: time * noiseScale + Double(blob) + 10,
                    y: Double(layerIndex) * 0.3
                ) * size.height * 0.2
                
                let center = CGPoint(x: baseX + noiseX, y: baseY + noiseY)
                
                drawInkBlob(
                    context: context,
                    size: size,
                    center: center,
                    color: color,
                    time: time,
                    blobIndex: blob
                )
            }
        }
    }
    
    private func drawInkBlob(
        context: GraphicsContext,
        size: CGSize,
        center: CGPoint,
        color: Color,
        time: Double,
        blobIndex: Int
    ) {
        // Create large, smooth blob shape
        let baseRadius = size.width * 0.5 // Much larger radius
        
        // Simple gradient with smooth falloff
        let gradient = Gradient(stops: [
            .init(color: color, location: 0),
            .init(color: color.opacity(0.7), location: 0.2),
            .init(color: color.opacity(0.4), location: 0.5),
            .init(color: color.opacity(0.1), location: 0.8),
            .init(color: .clear, location: 1)
        ])
        
        // Draw simple ellipse for smoother blending
        let ellipseWidth = baseRadius * 2 * (1 + 0.2 * sin(time + Double(blobIndex)))
        let ellipseHeight = baseRadius * 1.8 * (1 + 0.2 * cos(time * 0.8 + Double(blobIndex)))
        
        // Apply rotation through context transform
        context.withCGContext { cgContext in
            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.rotate(by: (time * 10 + Double(blobIndex) * 60) * .pi / 180)
            cgContext.translateBy(x: -center.x, y: -center.y)
            
            context.fill(
                Ellipse()
                    .path(in: CGRect(
                        x: center.x - ellipseWidth / 2,
                        y: center.y - ellipseHeight / 2,
                        width: ellipseWidth,
                        height: ellipseHeight
                    )),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: baseRadius
                )
            )
            
            cgContext.restoreGState()
        }
    }
}

// MARK: - Metallic Sheen Overlay
struct MetallicSheenOverlay: View {
    let timeOffset: Double
    
    var body: some View {
        Canvas { context, size in
            let time = timeOffset * Double.pi * 2
            
            // Single large sheen that moves slowly
            let x = size.width * (0.3 + 0.4 * sin(time * 0.2))
            let y = size.height * (0.4 + 0.3 * cos(time * 0.15))
            
            let gradient = Gradient(stops: [
                .init(color: .white.opacity(0.3), location: 0),
                .init(color: .white.opacity(0.1), location: 0.3),
                .init(color: .clear, location: 1)
            ])
            
            context.fill(
                Ellipse()
                    .path(in: CGRect(
                        x: x - size.width * 0.5,
                        y: y - size.height * 0.3,
                        width: size.width,
                        height: size.height * 0.6
                    )),
                with: .radialGradient(
                    gradient, 
                    center: CGPoint(x: x, y: y), 
                    startRadius: 0, 
                    endRadius: size.width * 0.6
                )
            )
        }
        .blur(radius: 100)
    }
}

// MARK: - Film Grain Overlay
struct FilmGrainOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                for _ in 0..<100 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let brightness = CGFloat.random(in: 0.5...0.8)
                    
                    context.fill(
                        Circle()
                            .path(in: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(Double(brightness)))
                    )
                }
            }
        }
    }
}

// MARK: - Perlin Noise Generator
class PerlinNoiseGenerator: ObservableObject {
    private let permutation: [Int]
    
    init() {
        var p = Array(0..<256)
        p.shuffle()
        self.permutation = p + p
    }
    
    func noise(x: Double, y: Double) -> Double {
        let X = Int(floor(x)) & 255
        let Y = Int(floor(y)) & 255
        
        let xf = x - floor(x)
        let yf = y - floor(y)
        
        let u = fade(xf)
        let v = fade(yf)
        
        let aa = permutation[permutation[X] + Y]
        let ab = permutation[permutation[X] + Y + 1]
        let ba = permutation[permutation[X + 1] + Y]
        let bb = permutation[permutation[X + 1] + Y + 1]
        
        let x1 = lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u)
        let x2 = lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u)
        
        return lerp(x1, x2, v)
    }
    
    private func fade(_ t: Double) -> Double {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + t * (b - a)
    }
    
    private func grad(_ hash: Int, _ x: Double, _ y: Double) -> Double {
        let h = hash & 3
        let u = h < 2 ? x : y
        let v = h < 2 ? y : x
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

// MARK: - Book Cover Color Analyzer
struct BookCoverColorAnalyzer {
    func extractDominantColors(from image: UIImage, count: Int) -> [Color] {
        guard let cgImage = image.cgImage else { return [] }
        
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
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return [] }
        
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var colorMap: [UIColor: Int] = [:]
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * 4
                let r = CGFloat(pixels[index]) / 255.0
                let g = CGFloat(pixels[index + 1]) / 255.0
                let b = CGFloat(pixels[index + 2]) / 255.0
                
                let brightness = (r + g + b) / 3.0
                if brightness > 0.15 && brightness < 0.85 {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    colorMap[color, default: 0] += 1
                }
            }
        }
        
        let sortedColors = colorMap.sorted { $0.value > $1.value }
        let topColors = sortedColors.prefix(count).map { $0.key }
        
        return topColors.map { uiColor in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            let enhancedSaturation = min(1.0, s * 1.8)
            let adjustedBrightness = min(0.9, b * 1.1)
            
            return Color(hue: Double(h), saturation: Double(enhancedSaturation), brightness: Double(adjustedBrightness))
        }
    }
}