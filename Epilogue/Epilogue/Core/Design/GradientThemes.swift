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
    case daybreak = "daybreak"

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
        case .daybreak:
            return "Daybreak"
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
        case .daybreak:
            return "Soft morning light"
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
        case .daybreak:
            return "sun.max.fill"
        }
    }

    // MARK: - Themed Tab Bar Icons
    var libraryIconActive: String {
        switch self {
        case .amber:
            return "book-active"
        case .ocean:
            return "book-active-ocean"
        case .forest:
            return "book-active-forest"
        default:
            return "book-active"
        }
    }

    var notesIconActive: String {
        switch self {
        case .amber:
            return "feather-active"
        case .ocean:
            return "feather-active-ocean"
        case .forest:
            return "feather-active-forest"
        default:
            return "feather-active"
        }
    }

    var sessionsIconActive: String {
        switch self {
        case .amber:
            return "msgs-active"
        case .ocean:
            return "msgs-active-ocean"
        case .forest:
            return "msgs-active-forest"
        default:
            return "msgs-active"
        }
    }

    var libraryIconInactive: String {
        return "book-inactive"
    }

    var notesIconInactive: String {
        return "feather-inactive"
    }

    var sessionsIconInactive: String {
        return "msgs-inactive"
    }

    // MARK: - Color Palette
    var primaryAccent: Color {
        switch self {
        case .amber:
            return Color(red: 1.0, green: 0.65, blue: 0.35)  // Warmer, less red amber
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
        case .daybreak:
            return Color(red: 0.25, green: 0.60, blue: 0.85) // Rich sky blue
        }
    }

    // MARK: - Gradient Colors
    /// Returns a sophisticated gradient color palette for each theme
    var gradientColors: [Color] {
        switch self {
        case .amber:
            return [
                Color(red: 1.0, green: 0.65, blue: 0.35),   // Warm golden amber
                Color(red: 0.98, green: 0.58, blue: 0.30),  // Honey gold
                Color(red: 0.95, green: 0.52, blue: 0.25),  // Deep amber
                Color(red: 0.90, green: 0.45, blue: 0.20)   // Burnished gold
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
                Color(red: 0.20, green: 0.35, blue: 0.28),  // Sage green
                Color(red: 0.25, green: 0.42, blue: 0.32),  // Forest canopy
                Color(red: 0.18, green: 0.38, blue: 0.35),  // Deep teal forest
                Color(red: 0.22, green: 0.45, blue: 0.38)   // Misty pine
            ]
        case .sunset:
            return [
                Color(red: 0.85, green: 0.45, blue: 0.38),  // Dusty coral
                Color(red: 0.78, green: 0.38, blue: 0.45),  // Soft rose
                Color(red: 0.72, green: 0.42, blue: 0.52),  // Lavender pink
                Color(red: 0.65, green: 0.35, blue: 0.48)   // Plum dusk
            ]
        case .midnight:
            return [
                Color(red: 0.10, green: 0.12, blue: 0.25),  // Deep navy
                Color(red: 0.08, green: 0.15, blue: 0.32),  // Midnight blue
                Color(red: 0.12, green: 0.18, blue: 0.38),  // Royal indigo
                Color(red: 0.06, green: 0.10, blue: 0.28)   // Dark sapphire
            ]
        case .volcanic:
            return [
                Color(red: 0.65, green: 0.25, blue: 0.15),  // Burnt sienna
                Color(red: 0.58, green: 0.20, blue: 0.18),  // Deep terracotta
                Color(red: 0.52, green: 0.18, blue: 0.12),  // Rust
                Color(red: 0.45, green: 0.15, blue: 0.10)   // Dark amber
            ]
        case .aurora:
            return [
                Color(red: 0.15, green: 0.35, blue: 0.42),  // Deep teal
                Color(red: 0.20, green: 0.45, blue: 0.52),  // Arctic blue
                Color(red: 0.25, green: 0.52, blue: 0.58),  // Glacial cyan
                Color(red: 0.18, green: 0.42, blue: 0.48)   // Northern waters
            ]
        case .nebula:
            return [
                Color(red: 0.35, green: 0.25, blue: 0.45),  // Mystic purple
                Color(red: 0.42, green: 0.28, blue: 0.52),  // Cosmic violet
                Color(red: 0.38, green: 0.22, blue: 0.48),  // Deep lavender
                Color(red: 0.32, green: 0.20, blue: 0.42)   // Royal purple
            ]
        case .daybreak:
            return [
                Color(red: 0.85, green: 0.78, blue: 0.88),  // Soft lavender pink
                Color(red: 0.72, green: 0.75, blue: 0.88),  // Periwinkle blue
                Color(red: 0.58, green: 0.70, blue: 0.90),  // Sky blue
                Color(red: 0.88, green: 0.92, blue: 0.95)   // Pale morning blue
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
        case .daybreak:
            return 6.0  // Gentle morning rhythm
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
        case .daybreak:
            return 0.6  // Very subtle movement
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

        // Haptic feedback for theme change
        HapticManager.shared.mediumTap()
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