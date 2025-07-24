import SwiftUI
import CoreImage

// MARK: - Gradient Test View
struct GradientTestView: View {
    @State private var selectedGradient = 0
    @State private var showingBookPicker = false
    @State private var selectedBook: Book?
    @State private var bookCoverImage: UIImage?
    @State private var extractedColors: [Color] = []
    @State private var isLoadingColors = false
    @State private var colorExtractionId = UUID() // Force refresh when colors change
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Default colors for when no book is selected
    let defaultColors = [
        Color(red: 0.85, green: 0.2, blue: 0.2),
        Color(red: 0.9, green: 0.75, blue: 0.3),
        Color(red: 0.2, green: 0.2, blue: 0.3),
        Color(red: 0.8, green: 0.6, blue: 0.2),
        Color(red: 0.15, green: 0.15, blue: 0.2)
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            Group {
                let colors = extractedColors.isEmpty ? defaultColors : extractedColors
                
                switch selectedGradient {
                case 0:
                    VoronoiMeshGradient(bookColors: colors)
                        .id(colorExtractionId) // Force complete refresh
                case 1:
                    ChromaticDispersionGradient(bookColors: colors)
                        .id(colorExtractionId)
                case 2:
                    ReactiveLuminanceGradient(bookColors: colors)
                        .id(colorExtractionId)
                case 3:
                    ColorEchoGradient(bookColors: colors)
                        .id(colorExtractionId)
                case 4:
                    // Bold Luminance - requires actual image
                    if let image = bookCoverImage {
                        BoldLuminanceGradient(bookCoverImage: image)
                    } else {
                        Color.black
                            .overlay {
                                Text("Select a book to see this gradient")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                case 5:
                    // Nuevo Tokyo style gradient
                    if let image = bookCoverImage {
                        NuevoTokyoBookGradient(
                            bookCoverImage: image,
                            bookTitle: selectedBook?.title,
                            bookAuthor: selectedBook?.author,
                            scrollOffset: 0
                        )
                    } else {
                        NuevoTokyoGradient(bookColors: colors)
                    }
                case 6:
                    // Cinematic gradient (Apple Music style)
                    if let image = bookCoverImage {
                        CinematicBookGradient(
                            bookCoverImage: image,
                            bookTitle: selectedBook?.title,
                            bookAuthor: selectedBook?.author,
                            scrollOffset: 0
                        )
                    } else {
                        Color.black
                            .overlay {
                                Text("Select a book to see this gradient")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                case 7:
                    // Simple gradient
                    if let image = bookCoverImage {
                        SimpleBookGradient(
                            bookCoverImage: image,
                            bookTitle: selectedBook?.title,
                            bookAuthor: selectedBook?.author,
                            scrollOffset: 0
                        )
                    } else {
                        Color.black
                            .overlay {
                                Text("Select a book to see this gradient")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                case 8:
                    // Ray Advanced gradient
                    if let image = bookCoverImage {
                        GeometryReader { geometry in
                            RayAdvancedBookGradient(
                                bookCoverImage: image,
                                bookTitle: selectedBook?.title,
                                bookAuthor: selectedBook?.author,
                                scrollOffset: 0
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        }
                    } else {
                        Color.black
                            .overlay {
                                Text("Select a book to see this gradient")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                    }
                default:
                    Color.black
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Book cover preview with tap to select
                Button(action: { showingBookPicker = true }) {
                    ZStack {
                        if let coverURL = selectedBook?.coverImageURL {
                            SharedBookCoverView(coverURL: coverURL, width: 150, height: 225)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.3))
                                .frame(width: 150, height: 225)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text("Tap to select book")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Loading overlay
                        if isLoadingColors {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.6))
                                .frame(width: 150, height: 225)
                                .overlay {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(selectedBook?.title ?? "Select a Book")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text(selectedBook?.author ?? "From your library")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
                
                // Gradient selector
                VStack(spacing: 12) {
                    Text("Select Gradient Style")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 12) {
                            GradientButton(title: "Voronoi Mesh", isSelected: selectedGradient == 0) {
                                selectedGradient = 0
                            }
                            
                            GradientButton(title: "Chromatic", isSelected: selectedGradient == 1) {
                                selectedGradient = 1
                            }
                            
                            GradientButton(title: "Luminance", isSelected: selectedGradient == 2) {
                                selectedGradient = 2
                            }
                            
                            GradientButton(title: "Color Echo", isSelected: selectedGradient == 3) {
                                selectedGradient = 3
                            }
                            
                            GradientButton(title: "Bold Luminance", isSelected: selectedGradient == 4) {
                                selectedGradient = 4
                            }
                            
                            GradientButton(title: "Nuevo Tokyo", isSelected: selectedGradient == 5) {
                                selectedGradient = 5
                            }
                            
                            GradientButton(title: "Cinematic", isSelected: selectedGradient == 6) {
                                selectedGradient = 6
                            }
                            
                            GradientButton(title: "Simple", isSelected: selectedGradient == 7) {
                                selectedGradient = 7
                            }
                            
                            GradientButton(title: "Ray Advanced", isSelected: selectedGradient == 8) {
                                selectedGradient = 8
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 50) // Fixed height for scroll view
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.3))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Gradient Showcase")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(onBookSelected: { book in
                selectedBook = book
                showingBookPicker = false
                loadBookCover(book)
            })
            .environmentObject(libraryViewModel)
        }
    }
    
    // MARK: - Load Book Cover
    private func loadBookCover(_ book: Book) {
        guard var urlString = book.coverImageURL else { return }
        
        // Convert HTTP to HTTPS for ATS compliance
        urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        
        // Add higher quality zoom parameter if not present
        if !urlString.contains("zoom=") {
            urlString += urlString.contains("?") ? "&zoom=2" : "?zoom=2"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        print("📚 Loading book cover from: \(urlString)")
        
        // Reset colors and show loading state
        isLoadingColors = true
        extractedColors = []
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Error loading book cover: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingColors = false
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("✅ Book cover loaded successfully, size: \(image.size)")
                DispatchQueue.main.async {
                    self.bookCoverImage = image
                    self.extractColorsFromImage(image)
                    self.isLoadingColors = false
                }
            } else {
                print("❌ Failed to create UIImage from data")
                DispatchQueue.main.async {
                    self.isLoadingColors = false
                }
            }
        }.resume()
    }
    
    // MARK: - Extract Colors
    private func extractColorsFromImage(_ image: UIImage) {
        print("🎨 Starting color extraction for book: \(selectedBook?.title ?? "Unknown")")
        
        var colors: [Color] = []
        
        // For gradients that need actual image (Bold Luminance, Nuevo Tokyo, Cinematic, Simple, Ray Advanced)
        // we'll extract colors using a proper method
        if [4, 5, 6, 7, 8].contains(selectedGradient) {
            // These gradients use the image directly, but we still need some colors for fallback
            colors = extractProperColors(from: image)
        } else {
            // For other gradients (Voronoi, Chromatic, Luminance, Color Echo), extract vibrant colors
            colors = extractProperColors(from: image)
        }
        
        print("🎨 Extracted \(colors.count) colors")
        
        // If we didn't find enough colors, add some defaults
        if colors.isEmpty {
            print("⚠️ No colors found, using defaults")
            colors = defaultColors
        }
        
        // Ensure we have at least 5 colors by creating variations
        while colors.count < 5 && !colors.isEmpty {
            let baseColor = colors[colors.count % colors.count]
            colors.append(generateComplementaryColor(from: baseColor))
        }
        
        print("🎨 Final color count: \(colors.count)")
        
        // Force UI update with new ID
        DispatchQueue.main.async {
            self.extractedColors = colors
            self.colorExtractionId = UUID() // Force gradient views to recreate
            print("✅ Colors updated in UI with new ID: \(self.colorExtractionId)")
            
            // Debug: Print extracted colors
            for (index, color) in colors.enumerated() {
                let uiColor = UIColor(color)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                print("Color \(index): H=\(h * 360)°, S=\(s * 100)%, B=\(b * 100)%")
            }
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
        
        context.draw(cgImage, in: CGRect(x: -region.minX, y: -region.minY, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        guard let pixelData = context.data else { return nil }
        
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: Int(region.width * region.height) * 4)
        
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
        
        let avgR = totalR / CGFloat(pixelCount)
        let avgG = totalG / CGFloat(pixelCount)
        let avgB = totalB / CGFloat(pixelCount)
        
        return Color(red: avgR, green: avgG, blue: avgB)
    }
    
    private func extractVibrantColor(from cgImage: CGImage, in region: CGRect) -> Color? {
        // Create a bitmap context for the region
        let width = Int(region.width)
        let height = Int(region.height)
        
        guard width > 0 && height > 0 else { return nil }
        
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
        ) else { return nil }
        
        // Draw the cropped region
        context.draw(cgImage, in: CGRect(x: -region.minX, y: -region.minY, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        
        // Use K-means clustering to find dominant colors
        var colorClusters: [(r: CGFloat, g: CGFloat, b: CGFloat, count: Int)] = []
        
        // Sample pixels
        let sampleRate = 5 // Sample every 5th pixel
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let index = ((width * y) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                // Skip very dark or very light pixels
                let brightness = (r + g + b) / 3.0
                if brightness < 0.1 || brightness > 0.95 {
                    continue
                }
                
                // Find or create cluster
                var foundCluster = false
                for i in 0..<colorClusters.count {
                    let dr = colorClusters[i].r - r
                    let dg = colorClusters[i].g - g
                    let db = colorClusters[i].b - b
                    let distance = sqrt(dr*dr + dg*dg + db*db)
                    
                    if distance < 0.15 { // Threshold for color similarity
                        // Update cluster average
                        let count = CGFloat(colorClusters[i].count)
                        colorClusters[i].r = (colorClusters[i].r * count + r) / (count + 1)
                        colorClusters[i].g = (colorClusters[i].g * count + g) / (count + 1)
                        colorClusters[i].b = (colorClusters[i].b * count + b) / (count + 1)
                        colorClusters[i].count += 1
                        foundCluster = true
                        break
                    }
                }
                
                if !foundCluster && colorClusters.count < 10 {
                    colorClusters.append((r: r, g: g, b: b, count: 1))
                }
            }
        }
        
        // Find the most vibrant cluster
        var bestColor: Color?
        var maxScore: CGFloat = 0
        
        for cluster in colorClusters {
            let uiColor = UIColor(red: cluster.r, green: cluster.g, blue: cluster.b, alpha: 1.0)
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
            
            // Score based on saturation, brightness, and cluster size
            let score = s * br * CGFloat(cluster.count) / 100.0
            
            if score > maxScore && s > 0.2 {
                maxScore = score
                // Boost saturation for more vibrant colors
                bestColor = Color(
                    hue: Double(h),
                    saturation: Double(min(s * 1.3, 1.0)),
                    brightness: Double(min(br * 1.1, 0.9))
                )
            }
        }
        
        // Fallback to dominant color if no vibrant color found
        if bestColor == nil && !colorClusters.isEmpty {
            let dominant = colorClusters.max(by: { $0.count < $1.count })!
            bestColor = Color(red: dominant.r, green: dominant.g, blue: dominant.b)
        }
        
        return bestColor
    }
    
    private func extractProperColors(from image: UIImage) -> [Color] {
        // Use CIAreaAverage filter for accurate color extraction
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to create CIImage")
            return []
        }
        
        var extractedColors: [Color] = []
        
        // Define regions to sample (similar to how gradients extract colors)
        let regions = [
            CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5),   // Top left
            CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5),   // Top right
            CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5),   // Bottom left
            CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),   // Bottom right
            CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), // Center
        ]
        
        let imageRect = ciImage.extent
        
        for region in regions {
            let sampleRect = CGRect(
                x: imageRect.origin.x + imageRect.width * region.origin.x,
                y: imageRect.origin.y + imageRect.height * region.origin.y,
                width: imageRect.width * region.size.width,
                height: imageRect.height * region.size.height
            )
            
            // Use CIAreaAverage filter
            let filter = CIFilter(name: "CIAreaAverage")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: sampleRect), forKey: "inputExtent")
            
            if let outputImage = filter.outputImage {
                let context = CIContext()
                var bitmap = [UInt8](repeating: 0, count: 4)
                context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                
                let r = CGFloat(bitmap[0]) / 255.0
                let g = CGFloat(bitmap[1]) / 255.0
                let b = CGFloat(bitmap[2]) / 255.0
                
                // Convert to HSB to check if it's a good color
                let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Filter out pure black, pure white, and very desaturated colors
                if !((r < 0.1 && g < 0.1 && b < 0.1) || (r > 0.95 && g > 0.95 && b > 0.95) || s < 0.1) {
                    let color = Color(red: Double(r), green: Double(g), blue: Double(b))
                    extractedColors.append(color)
                    print("🎨 Region color: R:\(Int(r*255)) G:\(Int(g*255)) B:\(Int(b*255))")
                }
            }
        }
        
        // If we didn't get enough colors, sample more regions
        if extractedColors.count < 5 {
            // Sample additional regions
            let additionalRegions = [
                CGRect(x: 0.33, y: 0.1, width: 0.34, height: 0.3),  // Top middle
                CGRect(x: 0.1, y: 0.33, width: 0.3, height: 0.34),  // Left middle
                CGRect(x: 0.6, y: 0.33, width: 0.3, height: 0.34),  // Right middle
                CGRect(x: 0.33, y: 0.6, width: 0.34, height: 0.3),  // Bottom middle
            ]
            
            for region in additionalRegions {
                let sampleRect = CGRect(
                    x: imageRect.origin.x + imageRect.width * region.origin.x,
                    y: imageRect.origin.y + imageRect.height * region.origin.y,
                    width: imageRect.width * region.size.width,
                    height: imageRect.height * region.size.height
                )
                
                let filter = CIFilter(name: "CIAreaAverage")!
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(cgRect: sampleRect), forKey: "inputExtent")
                
                if let outputImage = filter.outputImage {
                    let context = CIContext()
                    var bitmap = [UInt8](repeating: 0, count: 4)
                    context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                    
                    let r = CGFloat(bitmap[0]) / 255.0
                    let g = CGFloat(bitmap[1]) / 255.0
                    let b = CGFloat(bitmap[2]) / 255.0
                    
                    // Check if this color is different from existing ones
                    var isUnique = true
                    for existingColor in extractedColors {
                        let existingUI = UIColor(existingColor)
                        var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0
                        existingUI.getRed(&er, green: &eg, blue: &eb, alpha: nil)
                        
                        let diff = abs(r - er) + abs(g - eg) + abs(b - eb)
                        if diff < 0.3 {
                            isUnique = false
                            break
                        }
                    }
                    
                    if isUnique && !((r < 0.1 && g < 0.1 && b < 0.1) || (r > 0.95 && g > 0.95 && b > 0.95)) {
                        let color = Color(red: Double(r), green: Double(g), blue: Double(b))
                        extractedColors.append(color)
                    }
                }
            }
        }
        
        // Remove duplicates
        extractedColors = removeSimilarColors(extractedColors)
        
        return extractedColors
    }
    
    private func removeSimilarColors(_ colors: [Color]) -> [Color] {
        var uniqueColors: [Color] = []
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            var isUnique = true
            for existing in uniqueColors {
                let existingUI = UIColor(existing)
                var eh: CGFloat = 0, es: CGFloat = 0, eb: CGFloat = 0
                existingUI.getHue(&eh, saturation: &es, brightness: &eb, alpha: nil)
                
                // Check if colors are too similar
                let hueDiff = min(abs(h - eh), 1.0 - abs(h - eh))
                if hueDiff < 0.08 && abs(s - es) < 0.2 && abs(b - eb) < 0.2 {
                    isUnique = false
                    break
                }
            }
            
            if isUnique {
                uniqueColors.append(color)
            }
        }
        
        return uniqueColors
    }
    
    private func generateComplementaryColor(from color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Generate a color with shifted hue
        let shift = CGFloat.random(in: 0.15...0.35)
        let newHue = (h + shift).truncatingRemainder(dividingBy: 1.0)
        
        return Color(
            hue: Double(newHue),
            saturation: Double(max(s * 0.8, 0.5)),
            brightness: Double(min(b * 1.1, 0.85))
        )
    }
}

// MARK: - Gradient Button
struct GradientButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                    } else {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(in: Capsule())
                    }
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - 1. Voronoi Mesh Gradient
struct VoronoiMeshGradient: View {
    let bookColors: [Color]
    @State private var breathingPhase: Double = 0
    
    var body: some View {
        Canvas { context, size in
            // Generate cell centers for full screen coverage
            let cellCenters = generateVoronoiPoints(in: size, count: bookColors.count)
            
            // Draw each Voronoi cell
            for (index, center) in cellCenters.enumerated() {
                let color = bookColors[index % bookColors.count]
                
                // Gentle breathing effect only
                let breathScale = 1.0 + 0.03 * sin(breathingPhase + Double(index) * 0.5)
                let radius = max(size.width, size.height) * 0.6 * breathScale
                
                // Create gradient from center
                let gradient = Gradient(colors: [
                    color,
                    color.opacity(0.8),
                    color.opacity(0.4),
                    color.opacity(0.1),
                    Color.clear
                ])
                
                context.fill(
                    Circle().path(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
                )
            }
        }
        .blur(radius: 80)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
        }
    }
    
    private func generateVoronoiPoints(in size: CGSize, count: Int) -> [CGPoint] {
        // Distribute points evenly across the screen for full coverage
        var points: [CGPoint] = []
        
        // Create a grid-like distribution for better coverage
        let positions = [
            CGPoint(x: size.width * 0.2, y: size.height * 0.2),
            CGPoint(x: size.width * 0.8, y: size.height * 0.2),
            CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            CGPoint(x: size.width * 0.2, y: size.height * 0.8),
            CGPoint(x: size.width * 0.8, y: size.height * 0.8)
        ]
        
        for i in 0..<count {
            points.append(positions[i % positions.count])
        }
        
        return points
    }
}

// MARK: - 2. Chromatic Dispersion Gradient
struct ChromaticDispersionGradient: View {
    let bookColors: [Color]
    @State private var breathingPhase: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { channel in
                Canvas { context, size in
                    // Minimal chromatic offset
                    let channelOffset = Double(channel) * 8
                    
                    // Full screen coverage positions
                    let positions = [
                        CGPoint(x: size.width * 0.3, y: size.height * 0.3),
                        CGPoint(x: size.width * 0.7, y: size.height * 0.3),
                        CGPoint(x: size.width * 0.5, y: size.height * 0.7)
                    ]
                    
                    for (index, color) in bookColors.prefix(3).enumerated() {
                        let position = positions[index % positions.count]
                        let offsetPosition = CGPoint(
                            x: position.x + channelOffset,
                            y: position.y
                        )
                        
                        let channelColor = extractChannel(from: color, channel: channel)
                        
                        // Breathing effect
                        let breathScale = 1.0 + 0.05 * sin(breathingPhase + Double(index))
                        let radius = size.width * 0.6 * breathScale
                        
                        let gradient = Gradient(colors: [
                            channelColor,
                            channelColor.opacity(0.6),
                            channelColor.opacity(0.2),
                            Color.clear
                        ])
                        
                        context.fill(
                            Circle().path(in: CGRect(x: offsetPosition.x - radius, y: offsetPosition.y - radius, width: radius * 2, height: radius * 2)),
                            with: .radialGradient(gradient, center: offsetPosition, startRadius: 0, endRadius: radius)
                        )
                    }
                }
                .blur(radius: 60)
                .blendMode(channel == 0 ? .normal : .screen)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
        }
    }
    
    func extractChannel(from color: Color, channel: Int) -> Color {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        switch channel {
        case 0: return Color(red: Double(r), green: 0, blue: 0)
        case 1: return Color(red: 0, green: Double(g), blue: 0)
        case 2: return Color(red: 0, green: 0, blue: Double(b))
        default: return color
        }
    }
}

// MARK: - 3. Reactive Luminance Gradient
struct ReactiveLuminanceGradient: View {
    let bookColors: [Color]
    @State private var touchLocation: CGPoint = .zero
    @State private var luminanceBoost: Double = 0
    @State private var breathingPhase: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let breathingEffect = sin(breathingPhase * 0.5) * 0.1 + 0.9
                
            // Full screen coverage with minimal movement
            let positions = [
                CGPoint(x: size.width * 0.2, y: size.height * 0.3),
                CGPoint(x: size.width * 0.8, y: size.height * 0.3),
                CGPoint(x: size.width * 0.5, y: size.height * 0.7)
            ]
            
            for (index, position) in positions.enumerated() {
                if index < bookColors.count {
                    let color = bookColors[index]
                    
                    let dx = position.x - touchLocation.x
                    let dy = position.y - touchLocation.y
                    let distance = sqrt(dx * dx + dy * dy)
                    let proximityBoost = max(0, 1.0 - distance / 300.0) * luminanceBoost
                    
                    let adjustedColor = adjustLuminance(
                        color,
                        by: breathingEffect + proximityBoost
                    )
                    
                    let breathScale = 1.0 + 0.05 * sin(breathingPhase + Double(index))
                    let radius = size.width * 0.7 * breathScale
                    
                    let gradient = Gradient(colors: [
                        adjustedColor,
                        adjustedColor.opacity(0.7),
                        adjustedColor.opacity(0.3),
                        Color.clear
                    ])
                    
                    context.fill(
                        Circle().path(in: CGRect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(gradient, center: position, startRadius: 0, endRadius: radius)
                    )
                }
            }
        }
        .blur(radius: 80)
        .ignoresSafeArea()
        .onTapGesture { location in
            touchLocation = location
            withAnimation(.spring(response: 0.5)) {
                luminanceBoost = 1.0
            }
            
            withAnimation(.easeOut(duration: 2).delay(0.1)) {
                luminanceBoost = 0
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
        }
    }
    
    func adjustLuminance(_ color: Color, by factor: Double) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let newBrightness = min(1.0, Double(b) * factor)
        return Color(hue: Double(h), saturation: Double(s), brightness: newBrightness)
    }
}

// MARK: - 4. Color Echo Gradient
struct ColorEchoGradient: View {
    let bookColors: [Color]
    @State private var breathingPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Primary gradient layer
            Canvas { context, size in
                // Full screen positions
                let positions = [
                    CGPoint(x: size.width * 0.2, y: size.height * 0.2),
                    CGPoint(x: size.width * 0.8, y: size.height * 0.3),
                    CGPoint(x: size.width * 0.5, y: size.height * 0.6),
                    CGPoint(x: size.width * 0.3, y: size.height * 0.85)
                ]
                
                for (index, position) in positions.enumerated() {
                    if index < bookColors.count {
                        let color = bookColors[index]
                        let breathScale = 1.0 + 0.03 * sin(breathingPhase + Double(index) * 0.7)
                        let radius = size.width * 0.6 * breathScale
                        
                        let gradient = Gradient(colors: [
                            color,
                            color.opacity(0.7),
                            color.opacity(0.3),
                            Color.clear
                        ])
                        
                        context.fill(
                            Circle().path(in: CGRect(
                                x: position.x - radius,
                                y: position.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )),
                            with: .radialGradient(gradient, center: position, startRadius: 0, endRadius: radius)
                        )
                    }
                }
            }
            .blur(radius: 90)
            
            // Subtle echo layer
            Canvas { context, size in
                let echoPositions = [
                    CGPoint(x: size.width * 0.7, y: size.height * 0.4),
                    CGPoint(x: size.width * 0.3, y: size.height * 0.7)
                ]
                
                for (index, position) in echoPositions.enumerated() {
                    if index < bookColors.count {
                        let color = bookColors[bookColors.count - 1 - index]
                        let echoRadius = size.width * 0.5
                        
                        let gradient = Gradient(colors: [
                            color.opacity(0.2),
                            color.opacity(0.1),
                            Color.clear
                        ])
                        
                        context.fill(
                            Circle().path(in: CGRect(
                                x: position.x - echoRadius,
                                y: position.y - echoRadius,
                                width: echoRadius * 2,
                                height: echoRadius * 2
                            )),
                            with: .radialGradient(gradient, center: position, startRadius: 0, endRadius: echoRadius)
                        )
                    }
                }
            }
            .blur(radius: 100)
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                breathingPhase = .pi * 2
            }
        }
    }
}

// MARK: - 5. Nuevo Tokyo Style Gradient
struct NuevoTokyoGradient: View {
    let bookColors: [Color]
    @State private var animationPhase: Double = 0
    @State private var extractedColors: [Color] = []
    
    var body: some View {
        ZStack {
            // Base layer: Linear gradient from extracted colors
            if !extractedColors.isEmpty {
                LinearGradient(
                    colors: extractedColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Secondary layer: Subtle animated mesh overlay
                Canvas { context, size in
                    let meshColors = generateJapaneseColorPalette(from: extractedColors)
                    
                    // Draw subtle organic shapes
                    for (index, color) in meshColors.prefix(4).enumerated() {
                        let position = CGPoint(
                            x: size.width * (0.2 + Double(index) * 0.2 + sin(animationPhase + Double(index)) * 0.05),
                            y: size.height * (0.3 + Double(index) * 0.15 + cos(animationPhase + Double(index)) * 0.05)
                        )
                        
                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(0.3), location: 0.0),
                            .init(color: color.opacity(0.15), location: 0.5),
                            .init(color: Color.clear, location: 1.0)
                        ])
                        
                        let radius = size.width * 0.4
                        
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
                .blur(radius: 50)
                .blendMode(.plusLighter)
                .opacity(0.5)
            }
            
            // Dark vignette overlay
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.clear, location: 0.4),
                            .init(color: Color.black.opacity(0.3), location: 0.7),
                            .init(color: Color.black.opacity(0.6), location: 0.9),
                            .init(color: Color.black.opacity(0.8), location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: UIScreen.main.bounds.height * 0.8
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            // Use provided colors immediately, then enhance with Japanese aesthetic
            extractedColors = enhanceColorsForNuevoTokyo(bookColors)
            
            // Very slow, meditative animation
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
    
    private func generateJapaneseColorPalette(from colors: [Color]) -> [Color] {
        var palette: [Color] = []
        
        // Expand palette with harmonious colors
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Add original color with adjusted saturation (more muted)
            palette.append(Color(
                hue: Double(h),
                saturation: Double(s * 0.7), // Mute saturation
                brightness: Double(b * 0.9)
            ))
            
            // Add analogous color (30 degrees)
            let analogousHue = (h + 0.083).truncatingRemainder(dividingBy: 1.0)
            palette.append(Color(
                hue: Double(analogousHue),
                saturation: Double(s * 0.6),
                brightness: Double(b * 0.85)
            ))
            
            // Add complementary accent (subtle)
            let complementaryHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
            palette.append(Color(
                hue: Double(complementaryHue),
                saturation: Double(s * 0.4),
                brightness: Double(b * 0.95)
            ))
        }
        
        return palette
    }
    
    private func calculateOrganicPosition(index: Int, layer: Int, size: CGSize, phase: Double) -> CGPoint {
        // Create flowing, organic positions inspired by Japanese gardens
        let baseAngle = (Double(index) / 8.0) * .pi * 2
        let layerOffset = Double(layer) * 0.3
        
        // Gentle, flowing movement
        let radiusVariation = sin(phase + Double(index) * 0.5) * 0.1 + 0.9
        let radius = size.width * (0.3 + layerOffset) * radiusVariation
        
        let x = size.width * 0.5 + cos(baseAngle + phase * 0.2) * radius
        let y = size.height * 0.5 + sin(baseAngle + phase * 0.2) * radius * 0.8
        
        return CGPoint(x: x, y: y)
    }
    
    private func createOrganicPath(center: CGPoint, radius: CGFloat, index: Int, phase: Double) -> Path {
        var path = Path()
        
        // Create organic blob shape using bezier curves
        let points = 8
        let angleStep = (.pi * 2) / Double(points)
        
        var controlPoints: [(point: CGPoint, control1: CGPoint, control2: CGPoint)] = []
        
        for i in 0..<points {
            let angle = Double(i) * angleStep
            let radiusVariation = 0.8 + 0.2 * sin(phase * 2 + angle * 3 + Double(index))
            let r = radius * radiusVariation
            
            let point = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            
            // Calculate smooth control points
            let controlRadius = r * 0.55 // Magic number for smooth circles
            let control1 = CGPoint(
                x: center.x + cos(angle - angleStep/3) * controlRadius,
                y: center.y + sin(angle - angleStep/3) * controlRadius
            )
            let control2 = CGPoint(
                x: center.x + cos(angle + angleStep/3) * controlRadius,
                y: center.y + sin(angle + angleStep/3) * controlRadius
            )
            
            controlPoints.append((point, control1, control2))
        }
        
        // Build the path
        if let firstPoint = controlPoints.first {
            path.move(to: firstPoint.point)
            
            for i in 0..<controlPoints.count {
                let current = controlPoints[i]
                let next = controlPoints[(i + 1) % controlPoints.count]
                
                path.addCurve(
                    to: next.point,
                    control1: current.control2,
                    control2: next.control1
                )
            }
            
            path.closeSubpath()
        }
        
        return path
    }
    
    private func addTextureOverlay(context: inout GraphicsContext, size: CGSize) {
        // Add subtle rice paper texture effect
        let dotSize: CGFloat = 2
        let spacing: CGFloat = 8
        
        for y in stride(from: 0, to: size.height, by: spacing) {
            for x in stride(from: 0, to: size.width, by: spacing) {
                // Create organic distribution
                let offset = sin(Double(x) * 0.01) * 3
                let opacity = Double.random(in: 0.02...0.05)
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: x + offset,
                        y: y,
                        width: dotSize,
                        height: dotSize
                    )),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }
    
    private func enhanceColorsForNuevoTokyo(_ colors: [Color]) -> [Color] {
        var enhancedColors: [Color] = []
        
        // Process each color to create Japanese-inspired palette
        for color in colors.prefix(5) {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Create muted, sophisticated version
            let mutedColor = Color(
                hue: Double(h),
                saturation: Double(s * 0.65), // Reduce saturation for muted look
                brightness: Double(min(b * 1.1, 0.85)) // Slightly boost brightness but cap it
            )
            enhancedColors.append(mutedColor)
            
            // Add subtle variations
            if enhancedColors.count < 6 {
                // Add slightly shifted hue
                let shiftedHue = (h + 0.05).truncatingRemainder(dividingBy: 1.0)
                enhancedColors.append(Color(
                    hue: Double(shiftedHue),
                    saturation: Double(s * 0.5),
                    brightness: Double(b * 0.9)
                ))
            }
        }
        
        // Ensure we have at least 4 colors for smooth gradient
        while enhancedColors.count < 4 {
            if let lastColor = enhancedColors.last {
                let uiColor = UIColor(lastColor)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                let newHue = (h + 0.15).truncatingRemainder(dividingBy: 1.0)
                enhancedColors.append(Color(
                    hue: Double(newHue),
                    saturation: Double(s * 0.7),
                    brightness: Double(b)
                ))
            } else {
                enhancedColors.append(Color(hue: 0.6, saturation: 0.3, brightness: 0.7))
            }
        }
        
        return enhancedColors
    }
}

// MARK: - Preview
#Preview {
    GradientTestView()
}