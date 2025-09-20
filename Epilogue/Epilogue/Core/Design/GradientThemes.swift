import SwiftUI
import Combine

// MARK: - Gradient Theme System
/// Ultra-premium gradient themes for Epilogue
/// Each theme is meticulously crafted for sophistication and depth

public enum GradientTheme: String, CaseIterable, Codable {
    case amber = "amber"
    case ocean = "ocean"
    case forest = "forest"
    case sunset = "sunset"
    case midnight = "midnight"
    case volcanic = "volcanic"
    case aurora = "aurora"
    case nebula = "nebula"

    // MARK: - Display Properties
    var displayName: String {
        switch self {
        case .amber:
            return "Amber Glow"
        case .ocean:
            return "Ocean Depths"
        case .forest:
            return "Forest Mist"
        case .sunset:
            return "Sunset Bloom"
        case .midnight:
            return "Midnight Hour"
        case .volcanic:
            return "Volcanic Core"
        case .aurora:
            return "Aurora Borealis"
        case .nebula:
            return "Nebula Dreams"
        }
    }

    var description: String {
        switch self {
        case .amber:
            return "Warm, contemplative amber tones"
        case .ocean:
            return "Deep oceanic blues and teals"
        case .forest:
            return "Serene forest greens and mist"
        case .sunset:
            return "Romantic sunset hues"
        case .midnight:
            return "Mysterious midnight blues"
        case .volcanic:
            return "Intense volcanic warmth"
        case .aurora:
            return "Ethereal northern lights"
        case .nebula:
            return "Cosmic purple nebula"
        }
    }

    var icon: String {
        switch self {
        case .amber:
            return "flame.fill"
        case .ocean:
            return "water.waves"
        case .forest:
            return "leaf.fill"
        case .sunset:
            return "sunset.fill"
        case .midnight:
            return "moon.stars.fill"
        case .volcanic:
            return "flame.circle.fill"
        case .aurora:
            return "sparkles"
        case .nebula:
            return "sparkle"
        }
    }

    // MARK: - Color Palette
    var primaryAccent: Color {
        switch self {
        case .amber:
            return Color(red: 1.0, green: 0.55, blue: 0.26)  // Original amber
        case .ocean:
            return Color(red: 0.05, green: 0.65, blue: 0.82)  // Bright ocean teal
        case .forest:
            return Color(red: 0.34, green: 0.62, blue: 0.42) // Vibrant forest green
        case .sunset:
            return Color(red: 0.98, green: 0.45, blue: 0.52) // Bright sunset coral
        case .midnight:
            return Color(red: 0.22, green: 0.32, blue: 0.72) // Electric midnight blue
        case .volcanic:
            return Color(red: 0.95, green: 0.35, blue: 0.18) // Bright volcanic orange
        case .aurora:
            return Color(red: 0.45, green: 0.95, blue: 0.75) // Bright aurora mint
        case .nebula:
            return Color(red: 0.65, green: 0.35, blue: 0.95) // Bright nebula purple
        }
    }

    // MARK: - Gradient Colors
    /// Returns a sophisticated gradient color palette for each theme
    var gradientColors: [Color] {
        switch self {
        case .amber:
            return [
                Color(red: 1.0, green: 0.55, blue: 0.26),
                Color(red: 1.0, green: 0.45, blue: 0.20),
                Color(red: 0.9, green: 0.35, blue: 0.15),
                Color(red: 0.8, green: 0.25, blue: 0.10)
            ]
        case .ocean:
            return [
                Color(red: 0.05, green: 0.65, blue: 0.82),  // Brighter teal
                Color(red: 0.02, green: 0.52, blue: 0.75),  // Deep ocean blue
                Color(red: 0.0, green: 0.42, blue: 0.68),   // Rich marine
                Color(red: 0.0, green: 0.32, blue: 0.55)    // Dark depth
            ]
        case .forest:
            return [
                Color(red: 0.34, green: 0.62, blue: 0.42),  // Fresh spring green
                Color(red: 0.28, green: 0.54, blue: 0.38),  // Vibrant forest
                Color(red: 0.20, green: 0.45, blue: 0.32),  // Deep emerald
                Color(red: 0.14, green: 0.35, blue: 0.25)   // Dark forest floor
            ]
        case .sunset:
            return [
                Color(red: 0.98, green: 0.45, blue: 0.52),  // Bright coral pink
                Color(red: 0.96, green: 0.58, blue: 0.42),  // Golden peach
                Color(red: 0.94, green: 0.68, blue: 0.48),  // Warm apricot
                Color(red: 0.92, green: 0.38, blue: 0.58)   // Magenta blush
            ]
        case .midnight:
            return [
                Color(red: 0.22, green: 0.32, blue: 0.72),  // Electric indigo
                Color(red: 0.15, green: 0.25, blue: 0.62),  // Royal blue
                Color(red: 0.08, green: 0.18, blue: 0.52),  // Deep sapphire
                Color(red: 0.03, green: 0.08, blue: 0.38)   // Midnight abyss
            ]
        case .volcanic:
            return [
                Color(red: 0.95, green: 0.35, blue: 0.18),  // Bright lava orange
                Color(red: 0.88, green: 0.25, blue: 0.12),  // Molten core
                Color(red: 0.78, green: 0.18, blue: 0.08),  // Deep magma
                Color(red: 0.68, green: 0.12, blue: 0.05)   // Volcanic ash
            ]
        case .aurora:
            return [
                Color(red: 0.45, green: 0.95, blue: 0.75),  // Bright mint
                Color(red: 0.35, green: 0.88, blue: 0.88),  // Arctic cyan
                Color(red: 0.55, green: 0.75, blue: 0.98),  // Sky blue
                Color(red: 0.65, green: 0.60, blue: 0.95)   // Lavender glow
            ]
        case .nebula:
            return [
                Color(red: 0.65, green: 0.35, blue: 0.95),  // Bright cosmic purple
                Color(red: 0.55, green: 0.28, blue: 0.88),  // Electric violet
                Color(red: 0.42, green: 0.22, blue: 0.78),  // Deep purple
                Color(red: 0.32, green: 0.18, blue: 0.68)   // Dark nebula
            ]
        }
    }

    // MARK: - Animation Properties
    /// Each theme has unique animation characteristics
    var animationDuration: Double {
        switch self {
        case .amber, .sunset:
            return 5.0  // Warm themes breathe slowly
        case .ocean, .forest:
            return 6.0  // Natural themes have gentle rhythm
        case .midnight, .nebula:
            return 7.0  // Dark themes move mysteriously
        case .volcanic:
            return 4.0  // Intense theme pulses faster
        case .aurora:
            return 8.0  // Aurora flows gracefully
        }
    }

    var animationIntensity: Double {
        switch self {
        case .amber, .forest:
            return 0.8  // Subtle movement
        case .ocean, .sunset:
            return 0.9  // Moderate movement
        case .midnight, .nebula:
            return 0.7  // Gentle movement
        case .volcanic:
            return 1.0  // Strong movement
        case .aurora:
            return 0.85 // Flowing movement
        }
    }
}

// MARK: - Theme Manager
@MainActor
public class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: GradientTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedGradientTheme")
        }
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedGradientTheme"),
           let theme = GradientTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .amber // Default to original amber
        }
    }

    func setTheme(_ theme: GradientTheme) {
        currentTheme = theme

        // Force immediate UI update
        objectWillChange.send()

        // Haptic feedback for theme change
        HapticManager.shared.mediumTap()

        // Post notification for views to refresh
        NotificationCenter.default.post(name: Notification.Name("ThemeChanged"), object: theme)
    }
}

// MARK: - Environment Key
private struct GradientThemeKey: EnvironmentKey {
    static let defaultValue: GradientTheme = .amber
}

extension EnvironmentValues {
    var gradientTheme: GradientTheme {
        get { self[GradientThemeKey.self] }
        set { self[GradientThemeKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func gradientTheme(_ theme: GradientTheme) -> some View {
        environment(\.gradientTheme, theme)
    }
}