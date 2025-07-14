import SwiftUI
import UIKit

// MARK: - Particle Emitter View
struct ParticleEmitterView: UIViewRepresentable {
    let colors: [UIColor] = [
        UIColor(red: 1.0, green: 0.75, blue: 0.4, alpha: 0.6),    // Warm amber
        UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 0.6),     // Soft blue
        UIColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 0.6),     // Muted gold
        UIColor(red: 0.7, green: 0.5, blue: 0.8, alpha: 0.6)      // Soft purple
    ]
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // Create emitter layer
        let emitterLayer = CAEmitterLayer()
        emitterLayer.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height)
        emitterLayer.emitterShape = .line
        emitterLayer.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        emitterLayer.renderMode = .additive
        
        // Create cells for different colored particles
        var cells: [CAEmitterCell] = []
        
        for (index, color) in colors.enumerated() {
            let cell = CAEmitterCell()
            cell.birthRate = 0.5
            cell.lifetime = 15.0
            cell.lifetimeRange = 5.0
            cell.velocity = 30
            cell.velocityRange = 20
            cell.emissionRange = .pi / 6
            cell.emissionLongitude = -.pi / 2
            cell.scale = 0.3
            cell.scaleRange = 0.2
            cell.scaleSpeed = -0.02
            cell.alphaSpeed = -0.05
            cell.contents = createParticleImage(color: color).cgImage
            cell.name = "particle\(index)"
            
            // Add subtle movement
            cell.spin = 0.5
            cell.spinRange = 1
            
            cells.append(cell)
        }
        
        emitterLayer.emitterCells = cells
        view.layer.addSublayer(emitterLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update particle positions based on device motion if needed
    }
    
    private func createParticleImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 40, height: 40)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        
        // Create soft glowing orb
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = size.width / 2
        
        // Add glow effect with gradient
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                color.withAlphaComponent(0.8).cgColor,
                color.withAlphaComponent(0.4).cgColor,
                color.withAlphaComponent(0.0).cgColor
            ] as CFArray,
            locations: [0, 0.5, 1]
        )!
        
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - Empty Library View
struct EmptyLibraryView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Particle system background
            ParticleEmitterView()
                .ignoresSafeArea()
                .opacity(0.6)
            
            VStack(spacing: 16) {
                // Animated book icon
                Image(systemName: "books.vertical")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.3))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .padding(.bottom, 8)
                
                Text("Your library awaits")
                    .font(.system(.title, design: .serif))
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Text("Tap + to add your first book")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .onAppear {
                isAnimating = true
            }
        }
    }
}