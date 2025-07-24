import SwiftUI

// MARK: - Glass Readability Overlay
struct GlassReadabilityOverlay: View {
    let luminanceMap: BookCoverAnalyzer.LuminanceMap
    let textAreas: [CGRect]
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<textAreas.count, id: \.self) { index in
                let area = textAreas[index]
                let needsContrast = checkContrastNeeded(for: area)
                
                if needsContrast {
                    ReadableGlassArea(
                        frame: area,
                        intensity: calculateIntensity(for: area),
                        isDarkMode: colorScheme == .dark
                    )
                }
            }
        }
    }
    
    private func checkContrastNeeded(for area: CGRect) -> Bool {
        // Check if the area overlaps with bright regions
        for brightRegion in luminanceMap.brightRegions {
            if area.intersects(brightRegion) {
                return true
            }
        }
        
        // Check average luminance in the area
        let avgLuminance = calculateAreaLuminance(area)
        
        // Need contrast if too bright or too dark
        return avgLuminance > 0.7 || avgLuminance < 0.3
    }
    
    private func calculateIntensity(for area: CGRect) -> Double {
        let avgLuminance = calculateAreaLuminance(area)
        
        // Higher intensity for brighter areas
        if avgLuminance > 0.7 {
            return 0.8
        } else if avgLuminance < 0.3 {
            return 0.4
        } else {
            return 0.6
        }
    }
    
    private func calculateAreaLuminance(_ area: CGRect) -> Double {
        // Calculate average luminance for the area
        var totalLuminance = 0.0
        var count = 0
        
        let gridSize = luminanceMap.brightness.count
        guard gridSize > 0 else { return 0.5 }
        
        let cellWidth = 1.0 / Double(gridSize)
        let cellHeight = 1.0 / Double(gridSize)
        
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let cellRect = CGRect(
                    x: Double(x) * cellWidth,
                    y: Double(y) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                
                if area.intersects(cellRect) {
                    totalLuminance += luminanceMap.brightness[y][x]
                    count += 1
                }
            }
        }
        
        return count > 0 ? totalLuminance / Double(count) : 0.5
    }
}

// MARK: - Readable Glass Area
struct ReadableGlassArea: View {
    let frame: CGRect
    let intensity: Double
    let isDarkMode: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(glassBackground)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .glassEffect() // Apply glass effect last
    }
    
    private var glassBackground: some ShapeStyle {
        if isDarkMode {
            return Material.ultraThinMaterial.opacity(intensity)
        } else {
            return Material.thinMaterial.opacity(intensity * 0.8)
        }
    }
}

// MARK: - Dynamic Text Container
struct DynamicTextContainer<Content: View>: View {
    let content: () -> Content
    @State private var textFrame: CGRect = .zero
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Glass background layer
            if textFrame != .zero {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Material.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.7 : 0.8)
                    .frame(width: textFrame.width + 32, height: textFrame.height + 24)
                    .position(x: textFrame.midX, y: textFrame.midY)
                    .glassEffect()
            }
            
            // Content layer
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                textFrame = geometry.frame(in: .global)
                            }
                            .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                textFrame = newFrame
                            }
                    }
                )
        }
    }
}

// MARK: - Adaptive Glass Text Style
struct AdaptiveGlassTextStyle: ViewModifier {
    let luminance: Double
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(textColor)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 1)
    }
    
    private var textColor: Color {
        if colorScheme == .dark {
            // Dark mode
            return luminance > 0.6 ? .black : .white
        } else {
            // Light mode
            return luminance > 0.7 ? .black : .white
        }
    }
    
    private var shadowColor: Color {
        if colorScheme == .dark {
            return luminance > 0.6 ? .white.opacity(0.3) : .black.opacity(0.5)
        } else {
            return luminance > 0.7 ? .white.opacity(0.5) : .black.opacity(0.3)
        }
    }
    
    private var shadowRadius: CGFloat {
        return luminance > 0.5 ? 2 : 1
    }
}

extension View {
    func adaptiveGlassText(luminance: Double) -> some View {
        self.modifier(AdaptiveGlassTextStyle(luminance: luminance))
    }
}

// MARK: - Glass Section Container
struct GlassSectionContainer<Content: View>: View {
    let title: String?
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
            }
            
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .fill(Material.regularMaterial)
                .opacity(colorScheme == .dark ? 0.3 : 0.5)
        )
        .glassEffect()
    }
}

// MARK: - Contrast Analyzer
struct ContrastAnalyzer {
    static func calculateContrast(foreground: Color, background: Color) -> Double {
        let fgLuminance = luminance(of: foreground)
        let bgLuminance = luminance(of: background)
        
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    static func meetsWCAGAA(foreground: Color, background: Color) -> Bool {
        let contrast = calculateContrast(foreground: foreground, background: background)
        return contrast >= 4.5 // WCAG AA standard
    }
    
    static func meetsWCAGAAA(foreground: Color, background: Color) -> Bool {
        let contrast = calculateContrast(foreground: foreground, background: background)
        return contrast >= 7.0 // WCAG AAA standard
    }
    
    private static func luminance(of color: Color) -> Double {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        // Convert to linear RGB
        let linearR = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let linearG = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let linearB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        // Calculate relative luminance
        return 0.2126 * Double(linearR) + 0.7152 * Double(linearG) + 0.0722 * Double(linearB)
    }
}

// MARK: - Glass Effect Extension
extension View {
    func adaptiveGlassLayer(intensity: Double = 0.5) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Material.thinMaterial)
                    .opacity(intensity)
            )
            .glassEffect()
    }
    
    func glassSection(cornerRadius: CGFloat = 20) -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .glassEffect()
    }
}