import SwiftUI

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: View {
    let colorPalette: BookCoverAnalyzer.ColorPalette
    let strategy: BackgroundStrategy
    let scrollOffset: CGFloat
    
    @State private var animationPhase: CGFloat = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient mesh layer
            GradientMeshView(
                palette: colorPalette,
                strategy: strategy,
                animationPhase: animationPhase
            )
            .ignoresSafeArea()
            
            // Floating glass orbs
            FloatingOrbsView(
                colors: colorPalette.glass.isEmpty ? colorPalette.secondary : colorPalette.glass,
                phase: animationPhase
            )
            .scaleEffect(breathingScale)
            .glassEffect() // Apply glass effect properly
            
            // Flow pattern overlay
            FlowPatternView(
                strategy: strategy,
                palette: colorPalette,
                phase: shimmerPhase
            )
            .opacity(0.3)
            .blendMode(.overlay)
            .glassEffect() // Glass effect on flow patterns
            
            // Ambient light layer
            AmbientLightLayer(
                palette: colorPalette,
                phase: animationPhase
            )
            .blendMode(.softLight)
            .opacity(0.5)
            
            // Glass shimmer effect
            GlassShimmerLayer(phase: shimmerPhase)
                .blendMode(.screen)
                .opacity(0.15)
                .glassEffect()
        }
        .onAppear {
            startAnimations()
        }
        .offset(y: scrollOffset * 0.1) // Subtle parallax
    }
    
    private func startAnimations() {
        // Main animation cycle (60 seconds)
        withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
        
        // Breathing effect (8 seconds)
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            breathingScale = 1.02
        }
        
        // Shimmer effect (30 seconds)
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            shimmerPhase = .pi * 2
        }
    }
}

// MARK: - Gradient Mesh View
struct GradientMeshView: View {
    let palette: BookCoverAnalyzer.ColorPalette
    let strategy: BackgroundStrategy
    let animationPhase: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // Create mesh based on strategy
            switch strategy {
            case .oceanicFlow:
                drawOceanicMesh(context: &context, size: size)
            case .minimalAccent:
                drawMinimalMesh(context: &context, size: size)
            case .monochromaticDepth:
                drawMonochromaticMesh(context: &context, size: size)
            case .richTapestry:
                drawRichMesh(context: &context, size: size)
            case .liquidGlass:
                drawLiquidMesh(context: &context, size: size)
            }
        }
        .drawingGroup() // Optimize rendering
    }
    
    private func drawOceanicMesh(context: inout GraphicsContext, size: CGSize) {
        let colors = palette.primary + palette.secondary
        guard !colors.isEmpty else { return }
        
        // Create wave-like bezier paths
        for (index, color) in colors.enumerated() {
            let phase = animationPhase + Double(index) * .pi / 3
            
            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                
                for x in stride(from: 0, through: size.width, by: 20) {
                    let y = size.height * 0.5 + sin(Double(x) / 100 + phase) * 100
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
            
            let gradient = Gradient(colors: [
                color.opacity(0.8),
                color.opacity(0.4),
                color.opacity(0.1)
            ])
            
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
        }
    }
    
    private func drawMinimalMesh(context: inout GraphicsContext, size: CGSize) {
        // Use subtle gradients with accent colors
        let mainColor = palette.primary.first ?? Color.gray
        let accentColors = palette.detail.isEmpty ? palette.secondary : palette.detail
        
        // Base gradient
        let baseGradient = Gradient(colors: [
            Color.white.opacity(0.9),
            mainColor.opacity(0.1),
            Color.white.opacity(0.95)
        ])
        
        context.fill(
            Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                baseGradient,
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
        
        // Accent spots
        for (index, accent) in accentColors.enumerated() {
            let center = CGPoint(
                x: size.width * (0.2 + Double(index) * 0.3),
                y: size.height * (0.3 + sin(animationPhase + Double(index)) * 0.1)
            )
            
            let gradient = Gradient(colors: [
                accent.opacity(0.3),
                accent.opacity(0.1),
                Color.clear
            ])
            
            context.fill(
                Circle().path(in: CGRect(
                    x: center.x - 100,
                    y: center.y - 100,
                    width: 200,
                    height: 200
                )),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
        }
    }
    
    private func drawMonochromaticMesh(context: inout GraphicsContext, size: CGSize) {
        let baseColor = palette.primary.first ?? Color.gray
        
        // Create depth layers
        for i in 0..<5 {
            let offset = Double(i) * 20
            let opacity = 1.0 - Double(i) * 0.15
            
            let gradient = Gradient(stops: [
                .init(color: baseColor.opacity(opacity), location: 0),
                .init(color: baseColor.opacity(opacity * 0.7), location: 0.5),
                .init(color: baseColor.opacity(opacity * 0.3), location: 1)
            ])
            
            let path = Path { path in
                path.move(to: CGPoint(x: -offset, y: -offset))
                path.addLine(to: CGPoint(x: size.width + offset, y: -offset))
                path.addLine(to: CGPoint(x: size.width + offset, y: size.height + offset))
                path.addLine(to: CGPoint(x: -offset, y: size.height + offset))
                path.closeSubpath()
            }
            
            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: offset, y: offset),
                    endPoint: CGPoint(x: size.width - offset, y: size.height - offset)
                )
            )
        }
    }
    
    private func drawRichMesh(context: inout GraphicsContext, size: CGSize) {
        let allColors = palette.primary + palette.secondary + palette.detail
        guard !allColors.isEmpty else { return }
        
        // Create complex mesh with multiple blend points
        let gridSize = 4
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = size.height / CGFloat(gridSize)
        
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let colorIndex = (y * gridSize + x) % allColors.count
                let color = allColors[colorIndex]
                
                let center = CGPoint(
                    x: CGFloat(x) * cellWidth + cellWidth / 2,
                    y: CGFloat(y) * cellHeight + cellHeight / 2
                )
                
                // Animated offset
                let offsetX = sin(animationPhase + Double(x)) * 20
                let offsetY = cos(animationPhase + Double(y)) * 20
                
                let gradient = Gradient(colors: [
                    color,
                    color.opacity(0.6),
                    color.opacity(0.2),
                    Color.clear
                ])
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: center.x + offsetX - cellWidth,
                        y: center.y + offsetY - cellHeight,
                        width: cellWidth * 2,
                        height: cellHeight * 2
                    )),
                    with: .radialGradient(
                        gradient,
                        center: CGPoint(x: center.x + offsetX, y: center.y + offsetY),
                        startRadius: 0,
                        endRadius: cellWidth * 1.5
                    )
                )
            }
        }
    }
    
    private func drawLiquidMesh(context: inout GraphicsContext, size: CGSize) {
        let colors = palette.glass.isEmpty ? palette.primary : palette.glass
        guard !colors.isEmpty else { return }
        
        // Create organic liquid shapes
        for (index, color) in colors.enumerated() {
            let phase = animationPhase + Double(index) * .pi / 2
            
            let path = Path { path in
                let points = createOrganicPoints(
                    count: 8,
                    radius: size.width * 0.3,
                    center: CGPoint(
                        x: size.width * (0.3 + Double(index) * 0.2),
                        y: size.height * (0.4 + sin(phase) * 0.1)
                    ),
                    phase: phase
                )
                
                if let first = points.first {
                    path.move(to: first)
                    
                    // Create smooth curves between points
                    for i in 0..<points.count {
                        let current = points[i]
                        let next = points[(i + 1) % points.count]
                        let control1 = CGPoint(
                            x: current.x + (next.x - current.x) * 0.25,
                            y: current.y
                        )
                        let control2 = CGPoint(
                            x: next.x - (next.x - current.x) * 0.25,
                            y: next.y
                        )
                        
                        path.addCurve(to: next, control1: control1, control2: control2)
                    }
                    
                    path.closeSubpath()
                }
            }
            
            let gradient = Gradient(colors: [
                color.opacity(0.6),
                color.opacity(0.3),
                color.opacity(0.1)
            ])
            
            context.fill(
                path,
                with: .radialGradient(
                    gradient,
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endRadius: size.width * 0.5
                )
            )
        }
    }
    
    private func createOrganicPoints(count: Int, radius: CGFloat, center: CGPoint, phase: Double) -> [CGPoint] {
        var points = [CGPoint]()
        let angleStep = (.pi * 2) / Double(count)
        
        for i in 0..<count {
            let angle = Double(i) * angleStep
            let radiusVariation = radius * (1 + sin(phase + angle * 2) * 0.2)
            
            let x = center.x + cos(angle) * radiusVariation
            let y = center.y + sin(angle) * radiusVariation
            
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
}

// MARK: - Floating Orbs View
struct FloatingOrbsView: View {
    let colors: [Color]
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<min(colors.count, 5), id: \.self) { index in
                FloatingOrb(
                    color: colors[index],
                    index: index,
                    phase: phase,
                    containerSize: geometry.size
                )
            }
        }
    }
}

struct FloatingOrb: View {
    let color: Color
    let index: Int
    let phase: CGFloat
    let containerSize: CGSize
    
    private var position: CGPoint {
        let baseX = containerSize.width * (0.2 + Double(index) * 0.15)
        let baseY = containerSize.height * (0.3 + Double(index % 2) * 0.4)
        
        let offsetX = sin(phase + Double(index) * .pi / 3) * 30
        let offsetY = cos(phase * 0.7 + Double(index) * .pi / 4) * 40
        
        return CGPoint(x: baseX + offsetX, y: baseY + offsetY)
    }
    
    private var size: CGFloat {
        let baseSize = containerSize.width * 0.15
        let variation = sin(phase * 2 + Double(index)) * 10
        return baseSize + variation
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.8),
                        color.opacity(0.4),
                        color.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.8
                )
            )
            .frame(width: size * 2, height: size * 2)
            .position(position)
            .blur(radius: 2)
    }
}

// MARK: - Flow Pattern View
struct FlowPatternView: View {
    let strategy: BackgroundStrategy
    let palette: BookCoverAnalyzer.ColorPalette
    let phase: CGFloat
    
    var body: some View {
        Canvas { context, size in
            switch strategy {
            case .oceanicFlow:
                drawWavePattern(context: &context, size: size)
            case .minimalAccent:
                drawSubtlePattern(context: &context, size: size)
            case .monochromaticDepth:
                drawLayeredPattern(context: &context, size: size)
            case .richTapestry:
                drawComplexPattern(context: &context, size: size)
            case .liquidGlass:
                drawLiquidPattern(context: &context, size: size)
            }
        }
    }
    
    private func drawWavePattern(context: inout GraphicsContext, size: CGSize) {
        let waveColor = palette.secondary.first ?? Color.blue
        
        for i in 0..<3 {
            let offset = Double(i) * 50
            let opacity = 0.3 - Double(i) * 0.1
            
            let startY = size.height / 2 + CGFloat(offset)
            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: startY))
                
                for x in stride(from: 0, through: size.width, by: 10) {
                    let angle = Double(x) / 50 + phase + Double(i)
                    let waveY = startY + CGFloat(sin(angle) * 30)
                    path.addLine(to: CGPoint(x: CGFloat(x), y: waveY))
                }
                
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
            
            context.fill(
                path,
                with: .color(waveColor.opacity(opacity))
            )
        }
    }
    
    private func drawSubtlePattern(context: inout GraphicsContext, size: CGSize) {
        // Minimal geometric pattern
        let accentColor = palette.detail.first ?? Color.gray
        
        for i in 0..<5 {
            let x = size.width * (0.1 + Double(i) * 0.2)
            let y = size.height * 0.5 + sin(phase + Double(i)) * 20
            
            context.fill(
                Circle().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(accentColor.opacity(0.3))
            )
        }
    }
    
    private func drawLayeredPattern(context: inout GraphicsContext, size: CGSize) {
        let baseColor = palette.primary.first ?? Color.gray
        
        // Concentric shapes
        for i in 0..<4 {
            let scale = 1.0 - Double(i) * 0.2
            let opacity = 0.2 - Double(i) * 0.05
            
            let rect = CGRect(
                x: size.width * CGFloat(1 - scale) / 2,
                y: size.height * CGFloat(1 - scale) / 2,
                width: size.width * CGFloat(scale),
                height: size.height * CGFloat(scale)
            )
            
            context.fill(
                RoundedRectangle(cornerRadius: 20).path(in: rect),
                with: .color(baseColor.opacity(opacity))
            )
        }
    }
    
    private func drawComplexPattern(context: inout GraphicsContext, size: CGSize) {
        // Intricate overlapping shapes
        let colors = palette.secondary + palette.detail
        
        for (index, color) in colors.enumerated() {
            let angle = Double(index) * .pi / Double(colors.count) + phase
            let radius = size.width * 0.3
            
            let center = CGPoint(
                x: size.width / 2 + CGFloat(Foundation.cos(angle) * radius * 0.5),
                y: size.height / 2 + CGFloat(Foundation.sin(angle) * radius * 0.5)
            )
            
            let path = Path { path in
                path.addEllipse(in: CGRect(
                    x: center.x - radius / 2,
                    y: center.y - radius / 3,
                    width: radius,
                    height: radius * 0.67
                ))
            }
            
            context.fill(
                path,
                with: .color(color.opacity(0.15))
            )
        }
    }
    
    private func drawLiquidPattern(context: inout GraphicsContext, size: CGSize) {
        // Organic liquid shapes
        let liquidColor = palette.glass.first ?? palette.primary.first ?? Color.blue
        
        let path = Path { path in
            let controlPoints = [
                CGPoint(x: 0, y: size.height * 0.3),
                CGPoint(x: size.width * 0.3, y: size.height * 0.5 + sin(phase) * 50),
                CGPoint(x: size.width * 0.7, y: size.height * 0.4 + cos(phase) * 30),
                CGPoint(x: size.width, y: size.height * 0.6)
            ]
            
            path.move(to: controlPoints[0])
            
            for i in 0..<(controlPoints.count - 1) {
                let current = controlPoints[i]
                let next = controlPoints[i + 1]
                let control = CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2 + sin(phase + Double(i)) * 20
                )
                
                path.addQuadCurve(to: next, control: control)
            }
            
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        
        context.fill(
            path,
            with: .color(liquidColor.opacity(0.2))
        )
    }
}

// MARK: - Ambient Light Layer
struct AmbientLightLayer: View {
    let palette: BookCoverAnalyzer.ColorPalette
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            // Top light
            RadialGradient(
                colors: [
                    (palette.primary.first ?? Color.white).opacity(0.3),
                    Color.clear
                ],
                center: UnitPoint(
                    x: 0.5 + sin(phase) * 0.1,
                    y: 0.1
                ),
                startRadius: 0,
                endRadius: geometry.size.height * 0.5
            )
            
            // Bottom accent light
            if let accentColor = palette.detail.first {
                RadialGradient(
                    colors: [
                        accentColor.opacity(0.2),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: 0.5 + cos(phase) * 0.1,
                        y: 0.9
                    ),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.4
                )
            }
        }
    }
}

// MARK: - Glass Shimmer Layer
struct GlassShimmerLayer: View {
    let phase: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: Color.white.opacity(0.3), location: 0.45),
                    .init(color: Color.white.opacity(0.5), location: 0.5),
                    .init(color: Color.white.opacity(0.3), location: 0.55),
                    .init(color: Color.clear, location: 1)
                ],
                startPoint: UnitPoint(x: -0.5 + phase / .pi, y: 0),
                endPoint: UnitPoint(x: 0.5 + phase / .pi, y: 1)
            )
            .mask(
                LinearGradient(
                    colors: [Color.clear, Color.black, Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}