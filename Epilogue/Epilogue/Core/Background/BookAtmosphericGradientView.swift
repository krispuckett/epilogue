import SwiftUI

/// Apple Music-style atmospheric gradient background for book views
/// Enhanced with voice-responsive parameters for ambient mode
struct BookAtmosphericGradientView: View {
    // Core parameters
    let book: Book?
    let colorPalette: ColorPalette?
    var intensity: Double = 0.85
    
    // NEW: Voice-responsive parameters
    var frequency: Double = 0.0      // 0-1 normalized from voice frequency
    var rhythm: Double = 0.0         // Speaking rhythm/cadence
    var speakingSpeed: Double = 0.0  // Words per minute
    
    @State private var displayedPalette: ColorPalette?
    @State private var gradientRotation: Double = 0
    @State private var colorShift: Double = 0
    @State private var breathingScale: Double = 1.0
    @State private var pulseOpacity: Double = 0.8
    
    // Computed animation based on speaking speed
    private var gradientAnimation: Animation {
        // Faster animation for faster speech, slower for slower speech
        let baseDuration = 30.0
        let speedFactor = max(0.5, min(2.0, speakingSpeed / 150.0))
        return Animation.easeInOut(duration: baseDuration / speedFactor)
            .repeatForever(autoreverses: true)
    }
    
    // Color shift based on voice frequency
    private var frequencyColorModifier: Color {
        // Higher frequency = warmer tones (more red/orange)
        // Lower frequency = cooler tones (more blue/purple)
        if frequency > 0.6 {
            // High frequency - warm shift
            return Color(red: 0.2, green: 0.1, blue: 0.0).opacity(0.3)
        } else if frequency < 0.4 {
            // Low frequency - cool shift
            return Color(red: 0.0, green: 0.1, blue: 0.2).opacity(0.3)
        } else {
            // Mid frequency - neutral
            return Color.clear
        }
    }
    
    init(book: Book? = nil, 
         colorPalette: ColorPalette? = nil, 
         intensity: Double = 0.85,
         frequency: Double = 0.0,
         rhythm: Double = 0.0,
         speakingSpeed: Double = 0.0) {
        self.book = book
        self.colorPalette = colorPalette
        self.intensity = intensity
        self.frequency = frequency
        self.rhythm = rhythm
        self.speakingSpeed = speakingSpeed
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black base layer
                Color.black
                    .ignoresSafeArea()
                
                // Primary gradient - voice-responsive
                if let palette = displayedPalette ?? colorPalette {
                    // Main gradient with voice-responsive modifications
                    LinearGradient(
                        stops: [
                            .init(color: palette.primary.opacity(intensity), location: 0.0),
                            .init(color: palette.secondary.opacity(intensity * 0.8), location: 0.2),
                            .init(color: palette.accent.opacity(intensity * 0.5), location: 0.35),
                            .init(color: palette.background.opacity(intensity * 0.3), location: 0.5),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 40 + rhythm * 10) // Blur responds to speaking rhythm
                    .rotationEffect(.degrees(gradientRotation))
                    .scaleEffect(breathingScale)
                    .opacity(pulseOpacity)
                    .ignoresSafeArea()
                    .overlay {
                        // Frequency-based color overlay
                        frequencyColorModifier
                            .blendMode(.overlay)
                            .ignoresSafeArea()
                            .animation(.easeInOut(duration: 0.5), value: frequency)
                    }
                    
                    // Secondary animated gradient for voice dynamics
                    if rhythm > 0.3 {
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(rhythm * 0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200 + rhythm * 100
                        )
                        .scaleEffect(1.0 + rhythm * 0.2)
                        .ignoresSafeArea()
                        .blendMode(.plusLighter)
                        .animation(.easeOut(duration: 0.3), value: rhythm)
                    }
                }
                
                // Subtle noise texture overlay (keeping at 3% as requested)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.03) // 3% opacity for subtle texture depth
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            displayedPalette = processColors(colorPalette ?? getDefaultPalette())
            
            // Start breathing animation for ambient feel
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathingScale = 1.05
                pulseOpacity = 0.9
            }
            
            // Start gradient rotation animation
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
            
            // Start gradient animation if speaking
            if speakingSpeed > 0 {
                withAnimation(gradientAnimation) {
                    gradientRotation = 5
                }
            }
        }
        .onChange(of: colorPalette) { _, newPalette in
            displayedPalette = processColors(newPalette ?? getDefaultPalette())
        }
        .onChange(of: speakingSpeed) { _, newSpeed in
            // Adjust animation based on speaking speed
            if newSpeed > 0 {
                withAnimation(gradientAnimation) {
                    gradientRotation = 5 * (newSpeed / 150.0)
                }
            } else {
                withAnimation(.easeOut(duration: 2.0)) {
                    gradientRotation = 0
                }
            }
        }
        .onChange(of: frequency) { _, newFrequency in
            // Subtle color shift based on frequency
            withAnimation(.easeInOut(duration: 0.3)) {
                colorShift = newFrequency
            }
        }
    }
    
    private func getDefaultPalette() -> ColorPalette {
        ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26),
            secondary: Color(red: 0.8, green: 0.3, blue: 0.4),
            accent: Color(red: 0.6, green: 0.2, blue: 0.5),
            background: Color.black,
            textColor: Color.white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    }
    
    /// Create gradient stops with non-linear distribution
    private func createGradientStops(from palette: ColorPalette) -> [Gradient.Stop] {
        let colors = getProcessedColors(from: palette)
        
        // Extremely light and simple gradient
        return [
            .init(color: colors.primary.opacity(0.3), location: 0.0),
            .init(color: colors.primary.opacity(0.15), location: 0.2),
            .init(color: Color.clear, location: 0.5)
        ]
    }
    
    /// Get processed colors with proper contrast
    private func getProcessedColors(from palette: ColorPalette) -> (primary: Color, secondary: Color, accent: Color, background: Color) {
        // For monochromatic palettes, ensure we have variation
        if palette.isMonochromatic {
            return createMonochromaticVariations(from: palette.primary)
        }
        
        // Ensure minimum brightness differences
        var colors = [palette.primary, palette.secondary, palette.accent, palette.background]
        colors = ensureContrast(colors)
        
        return (colors[0], colors[1], colors[2], colors[3])
    }
    
    /// Create subtle variations for monochromatic covers
    private func createMonochromaticVariations(from baseColor: Color) -> (primary: Color, secondary: Color, accent: Color, background: Color) {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Create variations with subtle hue shifts
        let primary = baseColor
        let secondary = Color(hue: Double(hue + 0.02), saturation: Double(saturation * 0.8), brightness: Double(brightness * 0.9))
        let accent = Color(hue: Double(hue - 0.02), saturation: Double(saturation * 0.9), brightness: Double(brightness * 0.8))
        let background = Color(hue: Double(hue), saturation: Double(saturation * 0.6), brightness: Double(brightness * 0.6))
        
        return (primary, secondary, accent, background)
    }
    
    /// Ensure minimum 30% brightness difference between colors
    private func ensureContrast(_ colors: [Color]) -> [Color] {
        var processedColors = colors
        let minDifference: CGFloat = 0.3
        
        for i in 1..<processedColors.count {
            let prevBrightness = getBrightness(processedColors[i-1])
            var currBrightness = getBrightness(processedColors[i])
            
            // If too similar, adjust brightness
            if abs(prevBrightness - currBrightness) < minDifference {
                if prevBrightness > 0.5 {
                    // Make current darker
                    currBrightness = max(0, prevBrightness - minDifference)
                } else {
                    // Make current lighter
                    currBrightness = min(1, prevBrightness + minDifference)
                }
                
                processedColors[i] = adjustBrightness(processedColors[i], to: currBrightness)
            }
        }
        
        return processedColors
    }
    
    /// Get brightness value from color
    private func getBrightness(_ color: Color) -> CGFloat {
        let uiColor = UIColor(color)
        var brightness: CGFloat = 0
        uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }
    
    /// Adjust color brightness to target value
    private func adjustBrightness(_ color: Color, to targetBrightness: CGFloat) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(targetBrightness), opacity: Double(alpha))
    }
    
    /// Process colors - enhance them like ambient chat
    private func processColors(_ palette: ColorPalette) -> ColorPalette {
        return ColorPalette(
            primary: enhanceColor(palette.primary),
            secondary: enhanceColor(palette.secondary),
            accent: enhanceColor(palette.accent),
            background: enhanceColor(palette.background),
            textColor: palette.textColor,
            luminance: palette.luminance,
            isMonochromatic: palette.isMonochromatic,
            extractionQuality: palette.extractionQuality
        )
    }
    
    /// Enhance color - EXACT same as ambient chat
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // EXACT same enhancement as ambient chat
        saturation = min(saturation * 1.4, 1.0)  // Boost vibrancy
        brightness = max(brightness, 0.4)         // Minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
    
}

// MARK: - Convenience Transition

/// Temporary typealias for easier migration
typealias BookGradientView = BookAtmosphericGradientView

// MARK: - Preview

#Preview {
    BookAtmosphericGradientView(
        colorPalette: ColorPalette(
            primary: .blue,
            secondary: .purple,
            accent: .pink,
            background: .indigo,
            textColor: .white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    )
}