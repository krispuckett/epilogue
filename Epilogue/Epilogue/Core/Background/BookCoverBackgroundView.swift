import SwiftUI

// MARK: - Claude Voice Mode Style Gradient - EXACTLY
struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette?
    let displayScheme: DisplayColorScheme?
    
    // Convenience initializers
    init(colorPalette: ColorPalette) {
        self.colorPalette = colorPalette
        self.displayScheme = nil
    }
    
    init(displayScheme: DisplayColorScheme) {
        self.colorPalette = nil
        self.displayScheme = displayScheme
    }
    
    private var primaryColor: Color {
        if let scheme = displayScheme {
            return scheme.gradientColors.first ?? .black
        }
        // Use the extracted color directly - trust the extraction
        return colorPalette?.primary ?? .black
    }
    
    private var accentColor: Color {
        if let scheme = displayScheme {
            return scheme.gradientColors.last ?? .black
        }
        // Use accent for bottom glow
        return colorPalette?.accent ?? .black
    }
    
    var body: some View {
        ZStack {
            // Pure black base
            Color.black
                .ignoresSafeArea()
            
            // TOP GLOW - Make it BIG and SMOOTH like Claude
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            // Start with full color at top
                            .init(color: primaryColor, location: 0.0),
                            .init(color: primaryColor.opacity(0.9), location: 0.05),
                            .init(color: primaryColor.opacity(0.7), location: 0.1),
                            .init(color: primaryColor.opacity(0.5), location: 0.15),
                            .init(color: primaryColor.opacity(0.3), location: 0.25),
                            .init(color: primaryColor.opacity(0.15), location: 0.35),
                            .init(color: primaryColor.opacity(0.05), location: 0.45),
                            .init(color: Color.clear, location: 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .blur(radius: 20) // KEY: Blur for glow effect
            
            // BOTTOM GLOW - Same treatment
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: accentColor, location: 0.0),
                            .init(color: accentColor.opacity(0.8), location: 0.05),
                            .init(color: accentColor.opacity(0.6), location: 0.1),
                            .init(color: accentColor.opacity(0.4), location: 0.15),
                            .init(color: accentColor.opacity(0.2), location: 0.25),
                            .init(color: accentColor.opacity(0.1), location: 0.35),
                            .init(color: Color.clear, location: 0.45)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea()
                .blur(radius: 20)
            
            // EXTRA GLOW LAYER for richness (like Claude's orange glow)
            Circle()
                .fill(primaryColor.opacity(0.3))
                .blur(radius: 100)
                .scaleEffect(1.5)
                .offset(y: -UIScreen.main.bounds.height * 0.3)
                .ignoresSafeArea()
            
            Circle()
                .fill(accentColor.opacity(0.3))
                .blur(radius: 80)
                .scaleEffect(1.2)
                .offset(y: UIScreen.main.bounds.height * 0.3)
                .ignoresSafeArea()
        }
    }
}

// Note: Array safe subscript is defined elsewhere in the project

// MARK: - Preview
struct BookCoverBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Lord of the Rings example - gold top, red bottom
            ZStack {
                BookCoverBackgroundView(
                    colorPalette: ColorPalette(
                        primary: Color(red: 1.0, green: 0.84, blue: 0), // Gold
                        secondary: Color.orange,
                        accent: Color.red, // Red for bottom
                        background: Color.black,
                        textColor: .white,
                        luminance: 0.5,
                        isMonochromatic: false,
                        extractionQuality: 1.0
                    )
                )
                
                VStack {
                    Text("Lord of the Rings")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Text("J.R.R. Tolkien")
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
            
            // Claude voice mode example - orange/red
            ZStack {
                BookCoverBackgroundView(
                    colorPalette: ColorPalette(
                        primary: Color.orange,
                        secondary: Color(red: 1.0, green: 0.5, blue: 0.2),
                        accent: Color.red,
                        background: Color.black,
                        textColor: .white,
                        luminance: 0.3,
                        isMonochromatic: false,
                        extractionQuality: 1.0
                    )
                )
                
                VStack {
                    Text("Claude Voice Mode")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Text("Smooth Gradients")
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}