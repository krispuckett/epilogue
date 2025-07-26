import SwiftUI
import Combine

// MARK: - Ambient Background
struct AmbientBackground: View {
    @Binding var animationPhase: Double
    @Binding var orbPositions: [CGPoint]
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.031, green: 0.027, blue: 0.027), // #080707
                    Color(red: 0.11, green: 0.105, blue: 0.102)   // #1C1B1A
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating orbs
            ForEach(0..<3) { index in
                Circle()
                    .fill(orbGradient(for: index))
                    .frame(width: 200, height: 200)
                    .blur(radius: 60)
                    .opacity(0.4)
                    .position(orbPosition(for: index))
                    .animation(.easeInOut(duration: 20).repeatForever(autoreverses: true), value: animationPhase)
            }
        }
    }
    
    private func orbGradient(for index: Int) -> LinearGradient {
        let gradients = [
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.8, green: 0.4, blue: 0.2).opacity(0.6),
                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing),
            
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.4, green: 0.3, blue: 0.6).opacity(0.5),
                Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing),
            
            LinearGradient(gradient: Gradient(colors: [
                Color(red: 0.2, green: 0.4, blue: 0.5).opacity(0.5),
                Color(red: 0.3, green: 0.5, blue: 0.6).opacity(0.3)
            ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        ]
        
        return gradients[index % gradients.count]
    }
    
    private func orbPosition(for index: Int) -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Figure-8 pattern with different phases
        let phase = animationPhase + (Double(index) * 2 * .pi / 3)
        let x = screenWidth * (0.5 + 0.3 * sin(phase))
        let y = screenHeight * (0.5 + 0.3 * sin(2 * phase))
        
        return CGPoint(x: x, y: y)
    }
}