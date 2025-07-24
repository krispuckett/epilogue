import SwiftUI

// MARK: - Universal Bright Gradient System
struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette?
    let displayScheme: DisplayColorScheme?
    @State private var animationPhase: CGFloat = 0
    @State private var breathingScale: CGFloat = 1.0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    // Convenience initializers
    init(colorPalette: ColorPalette) {
        self.colorPalette = colorPalette
        self.displayScheme = nil
    }
    
    init(displayScheme: DisplayColorScheme) {
        self.colorPalette = nil
        self.displayScheme = displayScheme
    }
    
    var body: some View {
        ZStack {
            // ALWAYS start with white/light base to prevent darkness
            Color.white.opacity(colorScheme == .dark ? 0.5 : 0.7)
                .ignoresSafeArea()
            
            // Dynamic mesh gradient with guaranteed brightness
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints(),
                    colors: generateBrightColors()
                )
                .ignoresSafeArea()
                .opacity(0.7) // Reduced opacity to show more white base
            } else {
                // Fallback for older iOS versions
                universalFallbackGradient()
            }
            
            // Brightness amplifier layer
            RadialGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            
            // Floating light orbs for additional brightness
            if !reduceMotion {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(
                            x: sin(animationPhase + Double(index) * .pi) * 100,
                            y: cos(animationPhase + Double(index) * .pi) * 150
                        )
                        .blur(radius: 30)
                }
            }
            
            // Edge vignette (very subtle, not dark)
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.02)
                        ],
                        center: .center,
                        startRadius: 300,
                        endRadius: 500
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .brightness(0.2) // Increased brightness boost
        .onAppear {
            if !reduceMotion {
                startAnimations()
            }
        }
    }
    
    // MARK: - Mesh Gradient Points
    private func meshPoints() -> [SIMD2<Float>] {
        // Slightly animated mesh points for subtle movement
        let offset = reduceMotion ? 0 : Float(sin(animationPhase) * 0.05)
        
        return [
            // Top row
            [0.0, 0.0], [0.5 + offset, 0.0], [1.0, 0.0],
            // Middle row
            [0.0, 0.5], [0.5, 0.5 + offset], [1.0, 0.5],
            // Bottom row
            [0.0, 1.0], [0.5 - offset, 1.0], [1.0, 1.0]
        ]
    }
    
    // MARK: - Bright Color Generation
    private func generateBrightColors() -> [Color] {
        // Use display scheme if available (single source of truth)
        if let scheme = displayScheme {
            return scheme.meshGradientColors()
        }
        
        // Fallback to color palette
        guard let palette = colorPalette else {
            return [Color.gray, Color.white, Color.gray,
                    Color.white, Color.gray, Color.white,
                    Color.gray, Color.white, Color.gray]
        }
        
        // Legacy bright color generation
        let brightPrimary = palette.primary.mixed(with: .white, by: 0.7)
        let brightSecondary = palette.secondary.mixed(with: .white, by: 0.75)
        let brightAccent = palette.accent.mixed(with: .white, by: 0.6)
        let brightBackground = palette.background.mixed(with: .white, by: 0.8)
        
        return [
            brightPrimary.mixed(with: .white, by: 0.3),
            Color.white,
            brightSecondary.mixed(with: .white, by: 0.3),
            brightSecondary,
            brightAccent,
            brightPrimary,
            brightBackground,
            brightAccent.mixed(with: .white, by: 0.2),
            Color.white.opacity(0.9)
        ]
    }
    
    // MARK: - Fallback Gradient
    @ViewBuilder
    private func universalFallbackGradient() -> some View {
        // Beautiful layered gradient for older iOS
        if let scheme = displayScheme, scheme.gradientColors.count >= 3 {
            // Use display scheme colors
            ZStack {
                LinearGradient(
                    colors: [scheme.gradientColors[0], scheme.gradientColors[1]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    colors: [scheme.gradientColors[2], Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 300
                )
                .opacity(0.5)
                
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.clear,
                        scheme.gradientColors.last ?? Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        } else if let palette = colorPalette {
            // Fallback to palette
            ZStack {
                LinearGradient(
                    colors: [
                        palette.primary.mixed(with: .white, by: 0.7),
                        palette.secondary.mixed(with: .white, by: 0.75)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    colors: [
                        palette.accent.mixed(with: .white, by: 0.6),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 300
                )
                .opacity(0.5)
                
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.clear,
                        palette.background.mixed(with: .white, by: 0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        } else {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Animations
    private func startAnimations() {
        // Gentle breathing
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathingScale = 1.02
        }
        
        // Slow phase animation for subtle movement
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            animationPhase = .pi * 2
        }
    }
}

// MARK: - Color Theory Extensions
extension Color {
    /// Lighten color by mixing with white
    func lightened(by amount: Double) -> Color {
        let clampedAmount = min(max(amount, 0), 1)
        return self.mixed(with: .white, by: clampedAmount)
    }
    
    /// Mix two colors together
    func mixed(with color: Color, by amount: Double) -> Color {
        let clampedAmount = min(max(amount, 0), 1)
        
        let c1 = UIColor(self).cgColor
        let c2 = UIColor(color).cgColor
        
        guard let components1 = c1.components,
              let components2 = c2.components,
              components1.count >= 3,
              components2.count >= 3 else {
            return self
        }
        
        let r = components1[0] * (1 - clampedAmount) + components2[0] * clampedAmount
        let g = components1[1] * (1 - clampedAmount) + components2[1] * clampedAmount
        let b = components1[2] * (1 - clampedAmount) + components2[2] * clampedAmount
        let a = (components1.count > 3 ? components1[3] : 1) * (1 - clampedAmount) +
                (components2.count > 3 ? components2[3] : 1) * clampedAmount
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Get complementary color
    func complementary() -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let newHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
        return Color(UIColor(hue: newHue, saturation: s, brightness: b, alpha: a))
    }
    
    /// Get analogous colors (±30° on color wheel)
    func analogous() -> [Color] {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let angle: CGFloat = 30.0 / 360.0 // 30 degrees in normalized form
        
        let color1 = Color(UIColor(
            hue: (h + angle).truncatingRemainder(dividingBy: 1.0),
            saturation: s,
            brightness: b,
            alpha: a
        ))
        
        let color2 = Color(UIColor(
            hue: (h - angle + 1.0).truncatingRemainder(dividingBy: 1.0),
            saturation: s,
            brightness: b,
            alpha: a
        ))
        
        return [color1, color2]
    }
    
    /// Get triadic colors (120° intervals)
    func triadic() -> [Color] {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let angle: CGFloat = 120.0 / 360.0 // 120 degrees
        
        let color1 = Color(UIColor(
            hue: (h + angle).truncatingRemainder(dividingBy: 1.0),
            saturation: s,
            brightness: b,
            alpha: a
        ))
        
        let color2 = Color(UIColor(
            hue: (h + angle * 2).truncatingRemainder(dividingBy: 1.0),
            saturation: s,
            brightness: b,
            alpha: a
        ))
        
        return [color1, color2]
    }
}

// MARK: - Preview
struct BookCoverBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Any book example 1
            ZStack {
                BookCoverBackgroundView(
                    colorPalette: ColorPalette(
                        primary: Color.blue,
                        secondary: Color.purple,
                        accent: Color.orange,
                        background: Color.gray,
                        textColor: .white,
                        luminance: 0.5,
                        isMonochromatic: false,
                        extractionQuality: 1.0
                    )
                )
                
                VStack {
                    Text("Universal Gradient")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("Works with ANY book!")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Any book example 2
            ZStack {
                BookCoverBackgroundView(
                    colorPalette: ColorPalette(
                        primary: Color.green,
                        secondary: Color.yellow,
                        accent: Color.red,
                        background: Color.brown,
                        textColor: .white,
                        luminance: 0.6,
                        isMonochromatic: false,
                        extractionQuality: 1.0
                    )
                )
                
                VStack {
                    Text("Automatic Brightness")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("Always beautiful!")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}