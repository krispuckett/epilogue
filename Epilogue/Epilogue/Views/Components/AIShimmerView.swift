import SwiftUI

// MARK: - AI Shimmer View (iOS 26 Style)
struct AIShimmerView: View {
    let isActive: Bool
    let colors: [Color]
    @State private var animationPhase: CGFloat = 0
    
    init(isActive: Bool, colors: [Color] = [
        DesignSystem.Colors.primaryAccent,
        Color(red: 1.0, green: 0.7, blue: 0.4),
        Color(red: 1.0, green: 0.8, blue: 0.6)
    ]) {
        self.isActive = isActive
        self.colors = colors
    }
    
    var body: some View {
        ZStack {
            if isActive {
                // Shimmer gradient layer
                LinearGradient(
                    colors: shimmerColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    // Moving shimmer effect
                    LinearGradient(
                        colors: [
                            .clear,
                            DesignSystem.Colors.textQuaternary,
                            .white.opacity(0.8),
                            DesignSystem.Colors.textQuaternary,
                            .clear
                        ],
                        startPoint: UnitPoint(x: animationPhase - 0.3, y: 0.5),
                        endPoint: UnitPoint(x: animationPhase + 0.3, y: 0.5)
                    )
                )
                .animation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false),
                    value: animationPhase
                )
                .onAppear {
                    animationPhase = 1.3
                }
                
                // Pulsing glow overlay
                LinearGradient(
                    colors: colors.map { $0.opacity(0.2) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isActive
                )
            }
        }
    }
    
    private var shimmerColors: [Color] {
        var gradientColors: [Color] = []
        
        // Create smooth color transitions
        for i in 0..<colors.count {
            gradientColors.append(colors[i].opacity(0.1))
            gradientColors.append(colors[i].opacity(0.4))
            if i < colors.count - 1 {
                gradientColors.append(colors[i].opacity(0.1))
            }
        }
        
        return gradientColors
    }
}

// MARK: - Thinking Animation View
struct ThinkingAnimationView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Thinking")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DesignSystem.Colors.textSecondary)
                        .frame(width: 3, height: 3)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
        }
        .onAppear {
            withAnimation {
                animationPhase = 3
            }
        }
    }
}

// MARK: - AI Enhanced Input Field
struct AIEnhancedInputField: View {
    let placeholder: String
    let isProcessing: Bool
    let shimmerColors: [Color]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isProcessing {
                    ThinkingAnimationView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
        }
        .overlay {
            // AI shimmer effect when processing
            if isProcessing {
                AIShimmerView(isActive: true, colors: shimmerColors)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Regular shimmer
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
            .fill(.clear)
            .frame(height: 50)
            .overlay {
                AIShimmerView(isActive: true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
        
        // Thinking animation
        ThinkingAnimationView()
        
        // AI Enhanced input field
        AIEnhancedInputField(
            placeholder: "Ask your books anything...",
            isProcessing: true,
            shimmerColors: [
                DesignSystem.Colors.primaryAccent,
                Color(red: 1.0, green: 0.7, blue: 0.4)
            ]
        ) {
            // Action
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(.black)
}