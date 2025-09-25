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
        // SVG-like representation of Perplexity's logo
        // The logo consists of two interlocking curved shapes forming an abstract "P"
        ZStack {
            // Background gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.75, blue: 0.85), // Perplexity teal
                            Color(red: 0.25, green: 0.55, blue: 0.95)  // Perplexity blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Custom path for the Perplexity "P" shape
            // This creates two interlocking curved elements
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let scale = min(width, height) / 24.0 // Scale to standard 24x24 viewbox
                
                context.translateBy(x: width / 2, y: height / 2)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -12, y: -12) // Center the 24x24 viewbox
                
                // First curved element
                var path1 = Path()
                path1.move(to: CGPoint(x: 8, y: 6))
                path1.addCurve(
                    to: CGPoint(x: 16, y: 12),
                    control1: CGPoint(x: 14, y: 6),
                    control2: CGPoint(x: 16, y: 8)
                )
                path1.addCurve(
                    to: CGPoint(x: 8, y: 18),
                    control1: CGPoint(x: 16, y: 16),
                    control2: CGPoint(x: 14, y: 18)
                )
                
                // Second curved element (interlocking)
                var path2 = Path()
                path2.move(to: CGPoint(x: 16, y: 6))
                path2.addCurve(
                    to: CGPoint(x: 8, y: 12),
                    control1: CGPoint(x: 10, y: 6),
                    control2: CGPoint(x: 8, y: 8)
                )
                path2.addCurve(
                    to: CGPoint(x: 16, y: 18),
                    control1: CGPoint(x: 8, y: 16),
                    control2: CGPoint(x: 10, y: 18)
                )
                
                context.stroke(
                    path1,
                    with: .color(.white),
                    lineWidth: 2.5
                )
                
                context.stroke(
                    path2,
                    with: .color(.white.opacity(0.8)),
                    lineWidth: 2.5
                )
            }
            .frame(width: size, height: size)
        }
    }
}

// Simplified SVG-accurate version using shapes
struct PerplexityLogoSVG: View {
    let size: CGFloat
    
    init(size: CGFloat = 20) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "20D5EC"), // Perplexity's actual teal
                            Color(hex: "2D6FE4")  // Perplexity's actual blue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // The stylized "P" using two overlapping shapes
            GeometryReader { geometry in
                let scale = geometry.size.width / 100
                
                ZStack {
                    // First curve
                    Path { path in
                        path.move(to: CGPoint(x: 30 * scale, y: 25 * scale))
                        path.addQuadCurve(
                            to: CGPoint(x: 30 * scale, y: 75 * scale),
                            control: CGPoint(x: 70 * scale, y: 50 * scale)
                        )
                    }
                    .stroke(.white, lineWidth: 10 * scale)
                    
                    // Second curve
                    Path { path in
                        path.move(to: CGPoint(x: 70 * scale, y: 25 * scale))
                        path.addQuadCurve(
                            to: CGPoint(x: 70 * scale, y: 75 * scale),
                            control: CGPoint(x: 30 * scale, y: 50 * scale)
                        )
                    }
                    .stroke(.white.opacity(0.9), lineWidth: 10 * scale)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// Color hex initializer is already defined in ColorExtensions.swift

#Preview {
    VStack(spacing: 20) {
        Text("Logo Variations")
            .font(.headline)
        
        HStack(spacing: 30) {
            VStack {
                PerplexityLogo(size: 40)
                Text("Simple")
                    .font(.caption)
            }
            
            VStack {
                PerplexityLogoDetailed(size: 40)
                Text("Detailed")
                    .font(.caption)
            }
            
            VStack {
                PerplexityLogoSVG(size: 40)
                Text("SVG-like")
                    .font(.caption)
            }
        }
        
        Divider()
        
        // Show in context at different sizes
        VStack(alignment: .leading, spacing: 15) {
            Text("In Context")
                .font(.headline)
            
            HStack {
                PerplexityLogoSVG(size: 20)
                Text("Perplexity (20pt)")
            }
            
            HStack {
                PerplexityLogoSVG(size: 30)
                Text("Perplexity (30pt)")
            }
            
            HStack {
                PerplexityLogoSVG(size: 50)
                Text("Perplexity (50pt)")
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}