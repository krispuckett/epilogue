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
            return Color(red: 0.0, green: 0.58, blue: 0.71)  // Deep ocean teal
        case .forest:
            return Color(red: 0.27, green: 0.53, blue: 0.36) // Forest green
        case .sunset:
            return Color(red: 0.94, green: 0.42, blue: 0.48) // Sunset coral
        case .midnight:
            return Color(red: 0.17, green: 0.24, blue: 0.61) // Midnight blue
        case .volcanic:
            return Color(red: 0.89, green: 0.29, blue: 0.15) // Volcanic orange
        case .aurora:
            return Color(red: 0.40, green: 0.93, blue: 0.71) // Aurora green
        case .nebula:
            return Color(red: 0.58, green: 0.29, blue: 0.92) // Nebula purple
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
                Color(red: 0.0, green: 0.58, blue: 0.71),
                Color(red: 0.0, green: 0.48, blue: 0.65),
                Color(red: 0.0, green: 0.38, blue: 0.58),
                Color(red: 0.0, green: 0.28, blue: 0.45)
            ]
        case .forest:
            return [
                Color(red: 0.27, green: 0.53, blue: 0.36),
                Color(red: 0.22, green: 0.45, blue: 0.31),
                Color(red: 0.17, green: 0.37, blue: 0.26),
                Color(red: 0.12, green: 0.29, blue: 0.21)
            ]
        case .sunset:
            return [
                Color(red: 0.94, green: 0.42, blue: 0.48),
                Color(red: 0.95, green: 0.51, blue: 0.38),
                Color(red: 0.96, green: 0.60, blue: 0.42),
                Color(red: 0.89, green: 0.35, blue: 0.51)
            ]
        case .midnight:
            return [
                Color(red: 0.17, green: 0.24, blue: 0.61),
                Color(red: 0.12, green: 0.18, blue: 0.51),
                Color(red: 0.07, green: 0.12, blue: 0.41),
                Color(red: 0.02, green: 0.06, blue: 0.31)
            ]
        case .volcanic:
            return [
                Color(red: 0.89, green: 0.29, blue: 0.15),
                Color(red: 0.85, green: 0.20, blue: 0.10),
                Color(red: 0.75, green: 0.15, blue: 0.08),
                Color(red: 0.65, green: 0.10, blue: 0.05)
            ]
        case .aurora:
            return [
                Color(red: 0.40, green: 0.93, blue: 0.71),
                Color(red: 0.30, green: 0.85, blue: 0.85),
                Color(red: 0.50, green: 0.70, blue: 0.95),
                Color(red: 0.60, green: 0.55, blue: 0.90)
            ]
        case .nebula:
            return [
                Color(red: 0.58, green: 0.29, blue: 0.92),
                Color(red: 0.48, green: 0.25, blue: 0.85),
                Color(red: 0.38, green: 0.20, blue: 0.75),
                Color(red: 0.28, green: 0.15, blue: 0.65)
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