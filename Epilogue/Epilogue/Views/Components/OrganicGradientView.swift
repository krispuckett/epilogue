import SwiftUI

// MARK: - Organic Gradient View (Canvas-based alternative)
struct OrganicGradientView: View {
    @State private var phase: Double = 0
    @State private var timer: Timer?
    
    // Animation parameters
    let animationDuration: Double = 20.0
    let layerCount = 4
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Draw multiple gradient layers
                for i in 0..<layerCount {
                    let layerTime = time + Double(i) * 2.5
                    let opacity = 0.25 + (0.15 * Double(i % 2))
                    
                    drawGradientLayer(
                        context: context,
                        size: size,
                        time: layerTime,
                        index: i,
                        opacity: opacity
                    )
                }
                
                // Add vignette overlay
                drawVignette(context: context, size: size)
            }
        }
        .ignoresSafeArea()
    }
    
    private func drawGradientLayer(context: GraphicsContext, size: CGSize, time: Double, index: Int, opacity: Double) {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        
        // Create animated gradient stops
        let stops = createAnimatedStops(time: time, index: index)
        
        // Calculate rotation and offset
        let angle = Angle(degrees: time * 5.0 + Double(index) * 45)
        let offsetX = sin(time * 0.3 + Double(index)) * 50
        let offsetY = cos(time * 0.2 + Double(index) * 1.5) * 30
        
        // Create gradient with animated parameters
        let gradient = Gradient(stops: stops)
        let startPoint = CGPoint(
            x: size.width * 0.5 + offsetX,
            y: -size.height * 0.2 + offsetY
        )
        let endPoint = CGPoint(
            x: size.width * 0.5 - offsetX,
            y: size.height * 1.2 - offsetY
        )
        
        // Apply transformations and draw
        var drawingContext = context
        drawingContext.opacity = opacity
        drawingContext.rotate(by: angle)
        drawingContext.fill(
            path,
            with: .linearGradient(
                gradient,
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
    
    private func createAnimatedStops(time: Double, index: Int) -> [Gradient.Stop] {
        let phase = time * 0.1
        let colors = gradientColors(for: index)
        
        return [
            .init(color: colors.0, location: 0.0 + sin(phase) * 0.1),
            .init(color: colors.1, location: 0.3 + cos(phase * 1.2) * 0.1),
            .init(color: colors.2, location: 0.6 + sin(phase * 0.8) * 0.1),
            .init(color: colors.3, location: 1.0 + cos(phase * 0.9) * 0.1)
        ]
    }
    
    private func gradientColors(for index: Int) -> (Color, Color, Color, Color) {
        switch index % 4 {
        case 0:
            return (
                Color(red: 1.0, green: 0.35, blue: 0.1),
                Color(red: 1.0, green: 0.55, blue: 0.26),
                Color(red: 1.0, green: 0.7, blue: 0.4),
                Color(red: 0.9, green: 0.3, blue: 0.15)
            )
        case 1:
            return (
                Color(red: 0.9, green: 0.3, blue: 0.15),
                Color(red: 1.0, green: 0.45, blue: 0.2),
                Color(red: 1.0, green: 0.6, blue: 0.35),
                Color(red: 1.0, green: 0.35, blue: 0.1)
            )
        case 2:
            return (
                Color(red: 1.0, green: 0.6, blue: 0.35),
                Color(red: 0.95, green: 0.4, blue: 0.15),
                Color(red: 1.0, green: 0.5, blue: 0.25),
                Color(red: 0.85, green: 0.25, blue: 0.1)
            )
        default:
            return (
                Color(red: 0.95, green: 0.4, blue: 0.2),
                Color(red: 1.0, green: 0.65, blue: 0.4),
                Color(red: 0.9, green: 0.35, blue: 0.15),
                Color(red: 1.0, green: 0.55, blue: 0.3)
            )
        }
    }
    
    private func drawVignette(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.8
        
        let gradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black.opacity(0.1), location: 0.6),
            .init(color: .black.opacity(0.3), location: 1.0)
        ])
        
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: size))
        
        context.fill(
            path,
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}

// MARK: - Perlin Noise Effect View
struct PerlinNoiseEffectView: View {
    @State private var noiseOffset: CGSize = .zero
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<3) { layer in
                    NoiseLayer(
                        size: geometry.size,
                        layerIndex: layer,
                        offset: noiseOffset
                    )
                    .blendMode(layer == 0 ? .normal : .screen)
                    .opacity(0.3 - Double(layer) * 0.1)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            withAnimation(.linear(duration: 1.0 / 60.0)) {
                noiseOffset.width += 0.5
                noiseOffset.height += 0.3
            }
        }
    }
}

// MARK: - Noise Layer
struct NoiseLayer: View {
    let size: CGSize
    let layerIndex: Int
    let offset: CGSize
    
    var body: some View {
        Canvas { context, _ in
            let scale = 2.0 + Double(layerIndex)
            let speed = 1.0 - Double(layerIndex) * 0.3
            
            // Create noise pattern with dots
            for x in stride(from: 0, to: size.width, by: 20) {
                for y in stride(from: 0, to: size.height, by: 20) {
                    let noise = perlinNoise(
                        x: (x + offset.width * speed) / 100.0 * scale,
                        y: (y + offset.height * speed) / 100.0 * scale
                    )
                    
                    if noise > 0.3 {
                        let opacity = (noise - 0.3) * 0.5
                        let radius = 2.0 + noise * 3.0
                        
                        context.opacity = opacity
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )),
                            with: .color(Color(red: 1.0, green: 0.55, blue: 0.26))
                        )
                    }
                }
            }
        }
    }
    
    // Simple Perlin noise approximation
    private func perlinNoise(x: Double, y: Double) -> Double {
        let n = sin(x * 2.0) * cos(y * 2.0) +
                sin(x * 4.0) * cos(y * 4.0) * 0.5 +
                sin(x * 8.0) * cos(y * 8.0) * 0.25
        return (n + 1.75) / 3.5
    }
}

