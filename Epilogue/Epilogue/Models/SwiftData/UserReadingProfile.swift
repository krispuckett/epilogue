import Foundation
import SwiftData

// MARK: - User Reading Profile
/// Singleton model tracking user preferences and patterns over time.
/// Enables personalized AI responses.

@Model
final class UserReadingProfile {
    // MARK: - Core Identity
    var id: String = "user_profile"  // Singleton - only one profile

    // MARK: - Response Preferences
    /// Preferred response length: "brief", "moderate", "detailed"
    var preferredResponseLength: String = "moderate"

    /// Reading pace: "slow", "moderate", "fast"
    var readingPace: String = "moderate"

    // MARK: - Reading Patterns (comma-separated)
    /// Themes user gravitates toward
    var favoriteThemesRaw: String = ""

    var favoriteThemes: [String] {
        get { favoriteThemesRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { favoriteThemesRaw = newValue.joined(separator: ", ") }
    }

    /// Topics user has struggled with historically
    var confusingTopicsRaw: String = ""

    var confusingTopics: [String] {
        get { confusingTopicsRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { confusingTopicsRaw = newValue.joined(separator: ", ") }
    }

    // MARK: - Timing Patterns
    /// Peak reading hours (stored as comma-separated integers 0-23)
    var peakReadingHoursRaw: String = ""

    var peakReadingHours: [Int] {
        get {
            peakReadingHoursRaw.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set {
            peakReadingHoursRaw = newValue.map { String($0) }.joined(separator: ", ")
        }
    }

    /// Average session duration in minutes
    var averageSessionDuration: Double = 0

    // MARK: - Statistics
    var totalBooksDiscussed: Int = 0
    var totalQuestionsAsked: Int = 0
    var sessionCount: Int = 0

    // MARK: - Last Updated
    var lastUpdated: Date = Date()

    // MARK: - Initialization

    init() {
        self.id = "user_profile"
        self.lastUpdated = Date()
    }

    // MARK: - Pattern Updates

    /// Record a reading session for pattern tracking
    func recordSession(duration: TimeInterval, hour: Int) {
        sessionCount += 1

        // Update average duration
        let totalDuration = averageSessionDuration * Double(sessionCount - 1) + (duration / 60)
        averageSessionDuration = totalDuration / Double(sessionCount)

        // Update peak hours
        var hours = peakReadingHours
        hours.append(hour)
        // Keep last 100 readings
        if hours.count > 100 {
            hours = Array(hours.suffix(100))
        }
        peakReadingHours = hours

        lastUpdated = Date()
    }

    /// Add a theme the user enjoys
    func addFavoriteTheme(_ theme: String) {
        var themes = favoriteThemes
        if !themes.contains(theme) {
            themes.append(theme)
            // Keep top 20
            if themes.count > 20 {
                themes = Array(themes.suffix(20))
            }
            favoriteThemes = themes
            lastUpdated = Date()
        }
    }

    /// Record a topic the user found confusing
    func recordConfusingTopic(_ topic: String) {
        var topics = confusingTopics
        if !topics.contains(topic) {
            topics.append(topic)
            // Keep last 10
            if topics.count > 10 {
                topics = Array(topics.suffix(10))
            }
            confusingTopics = topics
            lastUpdated = Date()
        }
    }

    // MARK: - AI Context

    /// Build user preference context for AI prompts
    func buildPreferenceContext() -> String {
        var context: [String] = []

        // Response style
        switch preferredResponseLength {
        case "brief":
            context.append("User prefers brief, to-the-point responses.")
        case "detailed":
            context.append("User appreciates detailed, thorough explanations.")
        default:
            break
        }

        // Favorite themes
        if !favoriteThemes.isEmpty {
            context.append("User gravitates toward themes like: \(favoriteThemes.prefix(5).joined(separator: ", ")).")
        }

        // Confusing topics (be helpful with these)
        if !confusingTopics.isEmpty {
            context.append("User has previously found these topics challenging: \(confusingTopics.prefix(3).joined(separator: ", ")). Explain these carefully if they come up.")
        }

        return context.joined(separator: " ")
    }
}
