import SwiftUI
import CoreImage

// MARK: - Gradient Test View
struct GradientTestView: View {
    @State private var selectedGradient = 0
    
    // Sample book colors (from The Hobbit)
    let hobbitColors = [
        Color(red: 0.85, green: 0.2, blue: 0.2),    // Red sun
        Color(red: 0.9, green: 0.75, blue: 0.3),    // Yellow mountains
        Color(red: 0.2, green: 0.2, blue: 0.3),     // Dark sky
        Color(red: 0.8, green: 0.6, blue: 0.2),     // Golden
        Color(red: 0.15, green: 0.15, blue: 0.2)    // Deep blue
    ]
    
    private func createPlaceholderImage() -> Data? {
        // Create a simple colored image with the hobbit colors
        let size = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Fill with gradient-like colors
            let rect1 = CGRect(x: 0, y: 0, width: size.width, height: size.height / 3)
            UIColor(hobbitColors[0]).setFill()
            context.fill(rect1)
            
            let rect2 = CGRect(x: 0, y: size.height / 3, width: size.width, height: size.height / 3)
            UIColor(hobbitColors[1]).setFill()
            context.fill(rect2)
            
            let rect3 = CGRect(x: 0, y: 2 * size.height / 3, width: size.width, height: size.height / 3)
            UIColor(hobbitColors[2]).setFill()
            context.fill(rect3)
        }
        
        return image.pngData()
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            Group {
                switch selectedGradient {
                case 0:
                    VoronoiMeshGradient(bookColors: hobbitColors)
                case 1:
                    ChromaticDispersionGradient(bookColors: hobbitColors)
                case 2:
                    ReactiveLuminanceGradient(bookColors: hobbitColors)
                case 3:
                    ColorEchoGradient(bookColors: hobbitColors)
                case 4:
                    // Bold Luminance - using a placeholder image
                    if let placeholderData = createPlaceholderImage(),
                       let placeholderImage = UIImage(data: placeholderData) {
                        BoldLuminanceGradient(bookCoverImage: placeholderImage)
                    } else {
                        Color.black
                    }
                default:
                    Color.black
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Book cover preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.3))
                    .frame(width: 150, height: 225)
                    .overlay {
                        Text("Book Cover")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                
                Text("The Hobbit")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("J.R.R. Tolkien")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
                
                // Gradient selector
                VStack(spacing: 12) {
                    Text("Select Gradient Style")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
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
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Gradient Showcase")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
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

// MARK: - Preview
#Preview {
    GradientTestView()
}