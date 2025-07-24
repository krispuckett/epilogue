import SwiftUI

struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette
    @State private var phase: Double = 0
    @State private var secondaryPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Base: Pure black for clean contrast
            Color.black
                .ignoresSafeArea()
            
            // Layer 1: Primary color gradient (keep pure)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: colorPalette.primary.opacity(0.6), location: 0),
                    .init(color: colorPalette.primary.opacity(0.2), location: 0.5),
                    .init(color: Color.clear, location: 1)
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            // Layer 2: Secondary color (separate, don't mix)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: colorPalette.secondary.opacity(0.4), location: 0),
                    .init(color: colorPalette.secondary.opacity(0.1), location: 0.5),
                    .init(color: Color.clear, location: 1)
                ]),
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Layer 3: Accent highlight (pure color pop)
            Circle()
                .fill(colorPalette.accent.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 150, y: -200)
                .scaleEffect(1 + sin(phase) * 0.1)
            
            // Layer 4: Background color zone (if different from others)
            if colorPalette.background != colorPalette.primary && colorPalette.background != colorPalette.secondary {
                Circle()
                    .fill(colorPalette.background.opacity(0.25))
                    .frame(width: 400, height: 400)
                    .blur(radius: 120)
                    .offset(x: -180, y: 100)
                    .scaleEffect(1 + cos(secondaryPhase) * 0.08)
            }
            
            // Layer 5: Vignette for depth
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.clear, location: 0.5),
                            .init(color: Color.black.opacity(0.3), location: 0.8),
                            .init(color: Color.black.opacity(0.5), location: 1)
                        ]),
                        center: .center,
                        startRadius: 300,
                        endRadius: 600
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            // Layer 6: Subtle texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            Color.clear,
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .blendMode(.plusLighter)
        }
        .onAppear {
            // Primary animation
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
            
            // Secondary animation (different speed for variety)
            withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
                secondaryPhase = .pi * 2
            }
        }
    }
}

// MARK: - Preview

struct BookCoverBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            BookCoverBackgroundView(
                colorPalette: ColorPalette(
                    primary: .orange,
                    secondary: .red,
                    accent: .yellow,
                    background: .brown,
                    textColor: .white,
                    luminance: 0.5,
                    isMonochromatic: false,
                    extractionQuality: 1.0
                )
            )
            
            VStack {
                Text("The Hobbit")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("Clean color separation example")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}