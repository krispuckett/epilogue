import SwiftUI

// MARK: - Enhanced Liquid Thinking with Dynamic Blur
// Ethereal thinking indicator with pulsing blur and mist rings

struct SubtleLiquidThinking: View {
    let bookColor: Color
    @Binding var shouldCollapse: Bool
    @State private var morphPhase: CGFloat = 0
    @State private var blurPulse: Double = 2
    @State private var mistRing1Scale: CGFloat = 0.8
    @State private var mistRing1Blur: Double = 0
    @State private var mistRing1Opacity: Double = 0.3
    @State private var mistRing2Scale: CGFloat = 0.8
    @State private var mistRing2Blur: Double = 0
    @State private var mistRing2Opacity: Double = 0.3
    @State private var mistRing3Scale: CGFloat = 0.8
    @State private var mistRing3Blur: Double = 0
    @State private var mistRing3Opacity: Double = 0.3
    @State private var isCollapsing = false
    
    var body: some View {
        ZStack {
            // Questioning mist rings - expanding blur circles
            Circle()
                .stroke(bookColor.opacity(mistRing1Opacity), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(mistRing1Scale)
                .blur(radius: mistRing1Blur)
            
            Circle()
                .stroke(bookColor.opacity(mistRing2Opacity), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(mistRing2Scale)
                .blur(radius: mistRing2Blur)
            
            Circle()
                .stroke(bookColor.opacity(mistRing3Opacity), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(mistRing3Scale)
                .blur(radius: mistRing3Blur)
            
            // Main thinking bubble with pulsing blur
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20 + morphPhase * 3))
                .blur(radius: blurPulse)
                .overlay {
                    // Vibrant animated dots with coordinated blur
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0 + morphPhase * 0.2)
                                .opacity(0.6 + morphPhase * 0.4)
                                .blur(radius: blurPulse * 0.3)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: morphPhase
                                )
                        }
                    }
                }
                .frame(width: 80, height: 40)
        }
        .onAppear {
            startThinkingAnimations()
        }
        .onChange(of: shouldCollapse) { _, newValue in
            if newValue {
                triggerCollapseAnimation()
            }
        }
    }
    
    private func startThinkingAnimations() {
        // Main morph animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            morphPhase = 1.0
        }
        
        // Pulsing blur effect (2px to 5px)
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            blurPulse = 5
        }
        
        // Mist ring 1 animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false)) {
            mistRing1Scale = 1.5
            mistRing1Blur = 8
            mistRing1Opacity = 0
        }
        
        // Mist ring 2 animation (delayed)
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false).delay(0.3)) {
            mistRing2Scale = 1.5
            mistRing2Blur = 8
            mistRing2Opacity = 0
        }
        
        // Mist ring 3 animation (more delayed)
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false).delay(0.6)) {
            mistRing3Scale = 1.5
            mistRing3Blur = 8
            mistRing3Opacity = 0
        }
    }
    
    private func triggerCollapseAnimation() {
        isCollapsing = true
        
        // Collapse all rings inward
        withAnimation(.easeIn(duration: 0.3)) {
            mistRing1Scale = 0.5
            mistRing1Blur = 0
            mistRing1Opacity = 0
            
            mistRing2Scale = 0.5
            mistRing2Blur = 0
            mistRing2Opacity = 0
            
            mistRing3Scale = 0.5
            mistRing3Blur = 0
            mistRing3Opacity = 0
            
            blurPulse = 0
        }
    }
}

// MARK: - Message with Thinking State
struct MessageWithThinking: View {
    let message: String?
    let isThinking: Bool
    let bookColor: Color
    @State private var shouldCollapse = false
    
    var body: some View {
        Group {
            if isThinking && message == nil {
                // Show subtle thinking indicator
                SubtleLiquidThinking(bookColor: bookColor, shouldCollapse: $shouldCollapse)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
            } else if let message = message {
                // Show the actual message
                Text(message)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isThinking)
    }
}