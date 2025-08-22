import SwiftUI

// MARK: - Liquid Glass Thinking Indicator
struct LiquidGlassThinkingIndicator: View {
    @State private var phase = 0
    @State private var scale: [CGFloat] = [1.0, 0.8, 0.6]
    @State private var opacity: [Double] = [1.0, 0.6, 0.3]
    
    let primaryColor: Color
    
    init(color: Color = Color(red: 1.0, green: 0.55, blue: 0.26)) {
        self.primaryColor = color
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryColor.opacity(opacity[index]),
                                primaryColor.opacity(opacity[index] * 0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 10)
                    .scaleEffect(scale[index])
                    .glassEffect(in: Circle())
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        withAnimation {
            phase += 1
            
            // Cycle through different states
            scale = scale.map { s in
                s == 1.0 ? 0.6 : (s == 0.6 ? 0.8 : 1.0)
            }
            opacity = opacity.map { o in
                o == 1.0 ? 0.3 : (o == 0.3 ? 0.6 : 1.0)
            }
        }
        
        // Continue animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animateDots()
        }
    }
}

// MARK: - Thinking Message View
struct ThinkingMessageView: View {
    let bookContext: Book?
    let colorPalette: ColorPalette?
    @State private var glowOpacity = 0.3
    @State private var rotationAngle = 0.0
    
    var primaryColor: Color {
        colorPalette?.adaptiveUIColor ?? Color(red: 1.0, green: 0.55, blue: 0.26)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 12) {
                // Thinking indicator
                LiquidGlassThinkingIndicator(color: primaryColor)
                
                // Optional context text
                Text("Thinking...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .italic()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: geometry.size.width * 0.7, alignment: .leading)
            .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                // Animated glow border
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                primaryColor.opacity(glowOpacity),
                                primaryColor.opacity(glowOpacity * 0.3),
                                primaryColor.opacity(glowOpacity * 0.1),
                                primaryColor.opacity(glowOpacity * 0.3),
                                primaryColor.opacity(glowOpacity)
                            ]),
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 2)
            }
            .onAppear {
                // Pulse glow
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.6
                }
                
                // Rotate gradient
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        LiquidGlassThinkingIndicator()
            .padding()
            .background(Color.black)
        
        ThinkingMessageView(bookContext: nil, colorPalette: nil)
            .padding()
            .background(Color.black)
    }
}