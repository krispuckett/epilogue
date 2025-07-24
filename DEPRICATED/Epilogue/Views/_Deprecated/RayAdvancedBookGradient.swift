import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - True Color Extraction
extension UIImage {
    /// Extracts only true colors that exist in the image using k-means clustering
    func extractTrueColors() -> [Color] {
        guard let ciImage = CIImage(image: self) else { return [] }
        
        // Sample from center 80% to avoid edge artifacts
        let centerRegion = CGRect(
            x: ciImage.extent.width * 0.1,
            y: ciImage.extent.height * 0.1,
            width: ciImage.extent.width * 0.8,
            height: ciImage.extent.height * 0.8
        )
        
        let croppedImage = ciImage.cropped(to: centerRegion)
        
        // Extract colors using k-means clustering
        let dominantColors = performKMeansClustering(on: croppedImage, clusterCount: 6)
        
        // Filter and validate colors
        let validatedColors = validateColors(dominantColors, sourceImage: croppedImage)
        
        // Group similar colors and take top 3-4
        let groupedColors = groupSimilarColors(validatedColors)
        
        // Sort by coverage and return top colors
        return Array(groupedColors.prefix(4))
    }
    
    private func performKMeansClustering(on image: CIImage, clusterCount: Int) -> [(color: UIColor, coverage: Float)] {
        let context = CIContext()
        
        // Scale down for performance
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        
        // Sample pixels for k-means
        var pixels: [[Float]] = []
        let width = Int(scaledImage.extent.width)
        let height = Int(scaledImage.extent.height)
        
        // Create bitmap
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmap = [UInt8](repeating: 0, count: width * height * 4)
        
        context.render(
            scaledImage,
            toBitmap: &bitmap,
            rowBytes: width * 4,
            bounds: scaledImage.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
        
        // Sample every 4th pixel for k-means
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let index = (y * width + x) * 4
                let r = Float(bitmap[index]) / 255.0
                let g = Float(bitmap[index + 1]) / 255.0
                let b = Float(bitmap[index + 2]) / 255.0
                
                // Skip very dark and very light pixels
                let brightness = (r + g + b) / 3.0
                if brightness > 0.05 && brightness < 0.95 {
                    pixels.append([r, g, b])
                }
            }
        }
        
        // Perform k-means clustering
        let clusters = kMeans(data: pixels, k: clusterCount, maxIterations: 20)
        
        // Convert clusters to colors with coverage
        var colorCoverage: [(color: UIColor, coverage: Float)] = []
        
        for cluster in clusters {
            let color = UIColor(
                red: CGFloat(cluster.center[0]),
                green: CGFloat(cluster.center[1]),
                blue: CGFloat(cluster.center[2]),
                alpha: 1.0
            )
            let coverage = Float(cluster.points.count) / Float(pixels.count)
            
            if coverage > 0.05 { // Only include colors with >5% coverage
                colorCoverage.append((color: color, coverage: coverage))
            }
        }
        
        return colorCoverage.sorted { $0.coverage > $1.coverage }
    }
    
    private func kMeans(data: [[Float]], k: Int, maxIterations: Int) -> [Cluster] {
        guard !data.isEmpty else { return [] }
        
        // Initialize clusters with random centers
        var clusters: [Cluster] = []
        let shuffled = data.shuffled()
        
        for i in 0..<min(k, data.count) {
            clusters.append(Cluster(center: shuffled[i], points: []))
        }
        
        // K-means iterations
        for _ in 0..<maxIterations {
            // Clear points from clusters
            for i in 0..<clusters.count {
                clusters[i].points.removeAll()
            }
            
            // Assign points to nearest cluster
            for point in data {
                var minDistance: Float = Float.greatestFiniteMagnitude
                var nearestCluster = 0
                
                for (index, cluster) in clusters.enumerated() {
                    let distance = euclideanDistance(point, cluster.center)
                    if distance < minDistance {
                        minDistance = distance
                        nearestCluster = index
                    }
                }
                
                clusters[nearestCluster].points.append(point)
            }
            
            // Update cluster centers
            for i in 0..<clusters.count {
                if !clusters[i].points.isEmpty {
                    let newCenter = calculateMean(clusters[i].points)
                    clusters[i].center = newCenter
                }
            }
        }
        
        return clusters
    }
    
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(a.count, b.count) {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sqrt(sum)
    }
    
    private func calculateMean(_ points: [[Float]]) -> [Float] {
        guard !points.isEmpty else { return [] }
        
        let dimensions = points[0].count
        var mean = [Float](repeating: 0, count: dimensions)
        
        for point in points {
            for i in 0..<dimensions {
                mean[i] += point[i]
            }
        }
        
        for i in 0..<dimensions {
            mean[i] /= Float(points.count)
        }
        
        return mean
    }
    
    private func validateColors(_ colors: [(color: UIColor, coverage: Float)], sourceImage: CIImage) -> [Color] {
        var validColors: [Color] = []
        
        for (color, coverage) in colors {
            // Skip colors with low coverage
            if coverage < 0.05 { continue }
            
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Filter out artifacts (whites becoming yellows, etc)
            let isArtifact = (b > 0.9 && s > 0.1 && s < 0.3) || // White artifacts
                             (b < 0.1 && s > 0.1) // Black artifacts
            
            if !isArtifact {
                // Boost brightness by 20% for more vibrant colors
                let brightenedB = min(b * 1.2, 1.0)
                let brightenedColor = UIColor(hue: h, saturation: s, brightness: brightenedB, alpha: 1.0)
                validColors.append(Color(uiColor: brightenedColor))
            }
        }
        
        return validColors
    }
    
    private func groupSimilarColors(_ colors: [Color]) -> [Color] {
        var groups: [[Color]] = []
        var used = Set<Int>()
        
        for (index, color) in colors.enumerated() {
            if used.contains(index) { continue }
            
            var group = [color]
            used.insert(index)
            
            let uiColor = UIColor(color)
            var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
            uiColor.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
            
            // Find similar colors (within 10% HSB variance)
            for (otherIndex, otherColor) in colors.enumerated() {
                if used.contains(otherIndex) { continue }
                
                let otherUIColor = UIColor(otherColor)
                var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
                otherUIColor.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
                
                let hDiff = min(abs(h1 - h2), 1.0 - abs(h1 - h2))
                let sDiff = abs(s1 - s2)
                let bDiff = abs(b1 - b2)
                
                if hDiff < 0.1 && sDiff < 0.1 && bDiff < 0.1 {
                    group.append(otherColor)
                    used.insert(otherIndex)
                }
            }
            
            groups.append(group)
        }
        
        // Return the most prominent color from each group
        return groups.compactMap { $0.first }
    }
}

// MARK: - Data Structures
private struct Cluster {
    var center: [Float]
    var points: [[Float]]
}

// MARK: - Parallax Layer
struct ParallaxLayer<Content: View>: View {
    let content: Content
    let scrollOffset: CGFloat
    let parallaxFactor: CGFloat
    
    init(
        parallaxFactor: CGFloat,
        scrollOffset: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.parallaxFactor = parallaxFactor
        self.scrollOffset = scrollOffset
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(y: scrollOffset * parallaxFactor)
    }
}

// MARK: - Color Orb
struct ColorOrb: View {
    let color: Color
    let size: CGFloat
    let position: CGPoint
    let scrollOffset: CGFloat
    
    private var opacity: Double {
        // Subtle opacity change on scroll
        let scrollFactor = min(abs(scrollOffset) / 500, 0.3)
        return 0.8 - scrollFactor
    }
    
    private var scale: CGFloat {
        // Subtle scale change on scroll
        let scrollFactor = min(abs(scrollOffset) / 1000, 0.2)
        return 1.0 + scrollFactor
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(1.0),
                        color.opacity(0.6),
                        color.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size * scale, height: size * scale)
            .position(position)
            .opacity(opacity)
            .blur(radius: 25)
            .blendMode(.plusLighter)
    }
}

// MARK: - Layered Book Background
struct LayeredBookBackground: View {
    let bookImage: UIImage
    let scrollOffset: CGFloat
    
    @State private var extractedColors: [Color] = []
    @State private var isProcessing = true
    
    var body: some View {
        ZStack {
            if !isProcessing && !extractedColors.isEmpty {
                // Layer 1: Blurred book cover base
                ParallaxLayer(parallaxFactor: 0.2, scrollOffset: scrollOffset) {
                    Image(uiImage: bookImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width * 1.5, 
                               height: UIScreen.main.bounds.height * 1.5)
                        .blur(radius: 30)
                        .opacity(0.7)
                }
                
                // Layer 2: Floating color orbs
                ParallaxLayer(parallaxFactor: 0.5, scrollOffset: scrollOffset) {
                    GeometryReader { geometry in
                        ZStack {
                            // Position orbs based on extracted colors
                            ForEach(0..<min(extractedColors.count, 3), id: \.self) { index in
                                let positions = [
                                    CGPoint(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3),
                                    CGPoint(x: geometry.size.width * 0.7, y: geometry.size.height * 0.5),
                                    CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.7)
                                ]
                                
                                ColorOrb(
                                    color: extractedColors[index],
                                    size: geometry.size.width * 0.6,
                                    position: positions[index % positions.count],
                                    scrollOffset: scrollOffset
                                )
                            }
                        }
                    }
                }
                
                // Layer 3: Glass overlay
                ParallaxLayer(parallaxFactor: 0.8, scrollOffset: scrollOffset) {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(in: .rect)
                        .opacity(0.1)
                }
                
                // Dark gradient for readability
                // Light gradient overlay for readability
                LinearGradient(
                    colors: [
                        Color.clear,
                        extractedColors.first?.opacity(0.2) ?? Color.black.opacity(0.2),
                        extractedColors.first?.opacity(0.4) ?? Color.black.opacity(0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Loading state
                Color.black
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await processColors()
        }
    }
    
    @MainActor
    private func processColors() async {
        // Extract true colors asynchronously
        let colors = await Task.detached(priority: .userInitiated) {
            bookImage.extractTrueColors()
        }.value
        
        extractedColors = colors
        
        // Debug logging
        print("🎨 Ray Advanced - Extracted \(colors.count) true colors")
        for (index, color) in colors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            print("  Color \(index): R:\(Int(r*255)) G:\(Int(g*255)) B:\(Int(b*255))")
        }
        
        isProcessing = false
    }
}

// MARK: - Ray Advanced Book Gradient
struct RayAdvancedBookGradient: View {
    let bookCoverImage: UIImage
    let bookTitle: String?
    let bookAuthor: String?
    let scrollOffset: CGFloat
    
    // Callback to pass accent color to parent
    var onAccentColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        LayeredBookBackground(
            bookImage: bookCoverImage,
            scrollOffset: scrollOffset
        )
        .zIndex(-1) // Ensure gradient stays behind UI elements
        .allowsHitTesting(false) // Prevent gradient from intercepting touches
        .onAppear {
            // Extract accent color for UI elements
            Task {
                let colors = bookCoverImage.extractTrueColors()
                if let accentColor = colors.first {
                    await MainActor.run {
                        onAccentColorExtracted?(accentColor)
                    }
                }
            }
        }
    }
}

// MARK: - Scroll Offset Tracking
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var scrollOffset: CGFloat = 0
        
        var body: some View {
            ZStack {
                if let image = UIImage(systemName: "book.fill") {
                    RayAdvancedBookGradient(
                        bookCoverImage: image,
                        bookTitle: "The Odyssey",
                        bookAuthor: "Homer",
                        scrollOffset: scrollOffset
                    )
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: geometry.frame(in: .global).minY
                                )
                        }
                        .frame(height: 0)
                        
                        ForEach(0..<20) { index in
                            Text("Content \(index)")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
            }
        }
    }
    
    return PreviewWrapper()
}