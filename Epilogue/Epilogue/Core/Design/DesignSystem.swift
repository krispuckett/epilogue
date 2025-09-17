import SwiftUI

// MARK: - Epilogue Design System
/// Centralized design tokens for consistent UI across the app
/// Following iOS 26 design guidelines with Liquid Glass effects

public enum DesignSystem {
    
    // MARK: - Colors
    public enum Colors {
        /// Primary brand color - Theme-aware
        public static var primaryAccent: Color {
            ThemeManager.shared.currentTheme.primaryAccent
        }
        
        /// Text colors with semantic naming
        public static let textPrimary = Color.white
        public static let textSecondary = Color.white.opacity(0.70)
        public static let textTertiary = Color.white.opacity(0.50)
        public static let textQuaternary = Color.white.opacity(0.30)
        
        /// Surface colors for cards and backgrounds
        public static let surfaceBackground = Color(red: 0.11, green: 0.105, blue: 0.102)
        public static let surfaceCard = Color.white.opacity(0.05)
        public static let surfaceHover = Color.white.opacity(0.10)
        public static let surfacePressed = Color.white.opacity(0.15)
        
        /// Semantic colors
        public static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
        public static let warning = Color(red: 1.0, green: 0.7, blue: 0.2)
        public static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
        public static let info = Color(red: 0.2, green: 0.6, blue: 1.0)
        
        /// Glass effect tints
        public static let glassLight = Color.white.opacity(0.05)
        public static let glassMedium = Color.white.opacity(0.10)
        public static let glassStrong = Color.white.opacity(0.15)
        
        /// Border colors
        public static let borderSubtle = Color.white.opacity(0.05)
        public static let borderDefault = Color.white.opacity(0.10)
        public static let borderStrong = Color.white.opacity(0.15)
    }
    
    // MARK: - Spacing (8pt grid system)
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let xxxl: CGFloat = 64
        
        /// Consistent padding values
        public static let cardPadding: CGFloat = 24
        public static let inlinePadding: CGFloat = 16
        public static let listItemPadding: CGFloat = 20
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let card: CGFloat = 16
        public static let large: CGFloat = 20
        public static let extraLarge: CGFloat = 24
        public static let pill: CGFloat = 100
    }
    
    // MARK: - Typography
    public enum Typography {
        // Font sizes following iOS type scale
        public static let caption2: CGFloat = 10
        public static let caption: CGFloat = 11
        public static let footnote: CGFloat = 13
        public static let body: CGFloat = 15
        public static let callout: CGFloat = 16
        public static let headline: CGFloat = 17
        public static let title3: CGFloat = 20
        public static let title2: CGFloat = 24
        public static let title1: CGFloat = 28
        public static let largeTitle: CGFloat = 34
        
        // Line spacing
        public static let tightLineSpacing: CGFloat = 4
        public static let defaultLineSpacing: CGFloat = 6
        public static let relaxedLineSpacing: CGFloat = 8
        public static let looseLineSpacing: CGFloat = 11
        
        // Letter spacing (kerning)
        public static let tightKerning: CGFloat = 0.6
        public static let normalKerning: CGFloat = 0.8
        public static let wideKerning: CGFloat = 1.2
        public static let extraWideKerning: CGFloat = 1.5
    }
    
    // MARK: - Animation
    public enum Animation {
        /// Standard spring animation for most interactions
        public static let springStandard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        
        /// Bouncy spring for playful interactions
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6)
        
        /// Smooth spring for subtle animations
        public static let springSmooth = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.85)
        
        /// Quick spring for responsive feedback
        public static let springQuick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)
        
        /// Ease animations
        public static let easeQuick = SwiftUI.Animation.easeInOut(duration: 0.2)
        public static let easeStandard = SwiftUI.Animation.easeInOut(duration: 0.3)
        public static let easeSlow = SwiftUI.Animation.easeInOut(duration: 0.5)
    }
    
    // MARK: - Shadows
    public enum Shadow {
        public struct Style {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        public static let subtle = Style(
            color: .black.opacity(0.10),
            radius: 4,
            x: 0,
            y: 2
        )
        
        public static let card = Style(
            color: .black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
        
        public static let elevated = Style(
            color: .black.opacity(0.20),
            radius: 12,
            x: 0,
            y: 6
        )
        
        public static let floating = Style(
            color: .black.opacity(0.25),
            radius: 20,
            x: 0,
            y: 10
        )
    }
    
    // MARK: - Haptic Feedback Standards
    public enum HapticFeedback {
        /// Light tap for navigation and toggles
        public static func light() {
            HapticManager.shared.lightTap()
        }
        
        /// Medium tap for confirmations and selections
        public static func medium() {
            HapticManager.shared.mediumTap()
        }
        
        /// Success for completions and saves
        public static func success() {
            HapticManager.shared.success()
        }
        
        /// Warning for errors and deletions
        public static func warning() {
            HapticManager.shared.warning()
        }
        
        /// Selection changed for tab/segment changes
        public static func selection() {
            HapticManager.shared.selectionChanged()
        }
    }
    
    // MARK: - Component Heights
    public enum Heights {
        public static let tabBar: CGFloat = 49
        public static let toolbar: CGFloat = 44
        public static let button: CGFloat = 44
        public static let buttonSmall: CGFloat = 32
        public static let listItem: CGFloat = 104
        public static let bookCard: CGFloat = 270
        public static let bookCoverSmall: CGFloat = 80
        public static let bookCoverMedium: CGFloat = 180
    }
}

// MARK: - View Extensions for Easy Access
extension View {
    /// Apply primary accent color
    func primaryAccent() -> some View {
        self.foregroundStyle(DesignSystem.Colors.primaryAccent)
    }
    
    /// Apply standard card styling
    func cardStyle(padding: CGFloat = DesignSystem.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(DesignSystem.Colors.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
            )
    }
    
    /// Apply standard animation
    func standardAnimation() -> some View {
        self.animation(DesignSystem.Animation.springStandard, value: UUID())
    }
    
    /// Apply standard shadow
    func cardShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
}

// MARK: - Text Style Modifiers
extension Text {
    func epilogueTextStyle(_ style: EpilogueTextStyle) -> some View {
        switch style {
        case .largeTitle:
            return self
                .font(.system(size: DesignSystem.Typography.largeTitle, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .title1:
            return self
                .font(.system(size: DesignSystem.Typography.title1, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .title2:
            return self
                .font(.system(size: DesignSystem.Typography.title2, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .title3:
            return self
                .font(.system(size: DesignSystem.Typography.title3, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .headline:
            return self
                .font(.system(size: DesignSystem.Typography.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .body:
            return self
                .font(.system(size: DesignSystem.Typography.body, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        case .bodySecondary:
            return self
                .font(.system(size: DesignSystem.Typography.body, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        case .caption:
            return self
                .font(.system(size: DesignSystem.Typography.caption, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        case .footnote:
            return self
                .font(.system(size: DesignSystem.Typography.footnote, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

enum EpilogueTextStyle {
    case largeTitle
    case title1
    case title2
    case title3
    case headline
    case body
    case bodySecondary
    case caption
    case footnote
}

// MARK: - Opacity Standards
extension Double {
    /// Standard opacity values in 0.05 increments
    static let opacity5 = 0.05
    static let opacity10 = 0.10
    static let opacity15 = 0.15
    static let opacity20 = 0.20
    static let opacity25 = 0.25
    static let opacity30 = 0.30
    static let opacity35 = 0.35
    static let opacity40 = 0.40
    static let opacity45 = 0.45
    static let opacity50 = 0.50
    static let opacity55 = 0.55
    static let opacity60 = 0.60
    static let opacity65 = 0.65
    static let opacity70 = 0.70
    static let opacity75 = 0.75
    static let opacity80 = 0.80
    static let opacity85 = 0.85
    static let opacity90 = 0.90
    static let opacity95 = 0.95
}