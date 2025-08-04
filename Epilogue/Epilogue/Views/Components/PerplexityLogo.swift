import SwiftUI

struct PerplexityLogo: View {
    let size: CGFloat
    
    init(size: CGFloat = 20) {
        self.size = size
    }
    
    var body: some View {
        // Perplexity logo is a stylized infinity symbol
        Image(systemName: "infinity")
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.8, blue: 0.9), // Cyan
                        Color(red: 0.4, green: 0.6, blue: 1.0)  // Blue
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// Alternative: If you want to use a more accurate representation
struct PerplexityLogoDetailed: View {
    let size: CGFloat
    
    init(size: CGFloat = 20) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Create a custom shape that resembles Perplexity's actual logo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.8, blue: 0.9),
                            Color(red: 0.4, green: 0.6, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // White P in the center
            Text("P")
                .font(.system(size: size * 0.6, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PerplexityLogo(size: 30)
        PerplexityLogoDetailed(size: 30)
        
        // Show in context
        HStack {
            PerplexityLogo()
            Text("Perplexity")
        }
    }
    .padding()
}