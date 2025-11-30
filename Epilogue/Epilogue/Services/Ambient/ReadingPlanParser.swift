import Foundation

// MARK: - Reading Plan Parser
/// Parses AI responses into structured ReadingHabitPlan objects
/// Uses regex and structured extraction to convert markdown responses into data models

struct ReadingPlanParser {

    // MARK: - Parse Habit Plan

    /// Attempts to parse a habit plan from AI response text
    static func parseHabitPlan(
        from response: String,
        context: ReadingPlanContext
    ) -> ReadingHabitPlan? {
        // Extract title
        let title = extractTitle(from: response) ?? "Your 7-Day Reading Kickstart"

        // Extract goal
        let goal = extractGoal(from: response) ?? "Build a sustainable reading habit that fits your schedule."

        // Create the plan
        let plan = ReadingHabitPlan(type: .habit, title: title, goal: goal)

        // Set user preferences from context
        plan.preferredTime = context.timePreference
        plan.commitmentLevel = context.commitmentLevel
        plan.userBlocker = context.challengeOrBlocker

        // Extract ritual details
        if let ritual = extractRitualDetails(from: response) {
            plan.ritualWhen = ritual.when
            plan.ritualWhere = ritual.where_
            plan.ritualDuration = ritual.duration
            plan.ritualTrigger = ritual.trigger
        }

        // Extract recommended book
        if let book = extractFirstBook(from: response) {
            plan.recommendedBookTitle = book.title
            plan.recommendedBookAuthor = book.author
            plan.recommendedBookReason = book.reason
        }

        // Extract pro tip
        plan.proTip = extractProTip(from: response)

        // Initialize the week
        plan.initializeWeek()

        return plan
    }

    // MARK: - Parse Challenge Plan

    /// Attempts to parse a challenge plan from AI response text
    static func parseChallengePlan(
        from response: String,
        context: ReadingPlanContext
    ) -> ReadingHabitPlan? {
        // Extract title
        let title = extractTitle(from: response) ?? "Your Reading Challenge"

        // Extract goal/challenge statement
        let goal = extractChallenge(from: response) ?? "Push your reading boundaries and discover new favorites."

        // Create the plan
        let plan = ReadingHabitPlan(type: .challenge, title: title, goal: goal)

        // Set challenge-specific fields from context
        plan.challengeType = context.timePreference  // First question for challenge is type
        plan.ambitionLevel = context.commitmentLevel
        plan.timeframe = context.challengeOrBlocker

        // Extract target books
        plan.targetBooks = extractTargetBooks(from: response, ambition: context.commitmentLevel)

        // Extract recommended book
        if let book = extractFirstBook(from: response) {
            plan.recommendedBookTitle = book.title
            plan.recommendedBookAuthor = book.author
            plan.recommendedBookReason = book.reason
        }

        // Extract pro tip / accountability tip
        plan.proTip = extractProTip(from: response) ?? extractAccountabilityTip(from: response)

        return plan
    }

    // MARK: - Extraction Helpers

    private static func extractTitle(from text: String) -> String? {
        // Look for **Title** or ## Title patterns
        let patterns = [
            #"\*\*([^*]+(?:Reading|Challenge|Kickstart|Plan)[^*]*)\*\*"#,
            #"##\s*(.+(?:Reading|Challenge|Kickstart|Plan).+)"#,
            #"\*\*Your ([^*]+)\*\*"#
        ]

        for pattern in patterns {
            if let match = text.firstMatch(pattern: pattern) {
                let title = match.trimmingCharacters(in: .whitespacesAndNewlines)
                // Clean up any leftover markdown
                return title.replacingOccurrences(of: "**", with: "")
            }
        }

        return nil
    }

    private static func extractGoal(from text: String) -> String? {
        // Look for "The Goal: " section
        let patterns = [
            #"\*\*The Goal\*\*:?\s*(.+?)(?=\n\n|\*\*)"#,
            #"The Goal:?\s*(.+?)(?=\n\n)"#
        ]

        for pattern in patterns {
            if let match = text.firstMatch(pattern: pattern) {
                return cleanMarkdown(match)
            }
        }

        return nil
    }

    private static func extractChallenge(from text: String) -> String? {
        // Look for "The Challenge: " section
        let patterns = [
            #"\*\*The Challenge\*\*:?\s*(.+?)(?=\n\n|\*\*)"#,
            #"The Challenge:?\s*(.+?)(?=\n\n)"#
        ]

        for pattern in patterns {
            if let match = text.firstMatch(pattern: pattern) {
                return cleanMarkdown(match)
            }
        }

        return nil
    }

    private struct RitualDetails {
        var when: String?
        var where_: String?
        var duration: String?
        var trigger: String?
    }

    private static func extractRitualDetails(from text: String) -> RitualDetails? {
        var ritual = RitualDetails()

        // When
        if let when = text.firstMatch(pattern: #"\*\*When\*\*:?\s*(.+?)(?=\n|\*\*)"#) {
            ritual.when = cleanMarkdown(when)
        }

        // Where
        if let where_ = text.firstMatch(pattern: #"\*\*Where\*\*:?\s*(.+?)(?=\n|\*\*)"#) {
            ritual.where_ = cleanMarkdown(where_)
        }

        // How long / Duration
        if let duration = text.firstMatch(pattern: #"\*\*How long\*\*:?\s*(.+?)(?=\n|\*\*)"#) {
            ritual.duration = cleanMarkdown(duration)
        }

        // Trigger
        if let trigger = text.firstMatch(pattern: #"\*\*(?:The )?[Tt]rigger\*\*:?\s*(.+?)(?=\n\n|\*\*)"#) {
            ritual.trigger = cleanMarkdown(trigger)
        }

        // Only return if we found at least one field
        if ritual.when != nil || ritual.where_ != nil || ritual.duration != nil || ritual.trigger != nil {
            return ritual
        }

        return nil
    }

    private struct BookRecommendation {
        let title: String
        let author: String?
        let reason: String?
    }

    private static func extractFirstBook(from text: String) -> BookRecommendation? {
        // Look for patterns like:
        // **Book Title** by Author - Reason
        // 1. **Book Title** by Author - Reason
        // **Your First Book**: **Title** by Author

        let patterns = [
            #"\*\*Your First Book\*\*:?\s*\*?\*?([^*\n]+)\*?\*?\s*(?:by\s+)?([^-\n]+)?(?:\s*-\s*(.+))?"#,
            #"1\.\s*\*\*([^*]+)\*\*\s*by\s+([^-\n]+)(?:\s*-\s*(.+))?"#,
            #"\*\*([^*]+)\*\*\s*by\s+([^-\n]+)(?:\s*-\s*(.+))?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    let titleRange = Range(match.range(at: 1), in: text)
                    let authorRange = match.numberOfRanges > 2 ? Range(match.range(at: 2), in: text) : nil
                    let reasonRange = match.numberOfRanges > 3 ? Range(match.range(at: 3), in: text) : nil

                    if let titleRange = titleRange {
                        let title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let author = authorRange.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
                        let reason = reasonRange.map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }

                        if !title.isEmpty {
                            return BookRecommendation(title: title, author: author, reason: reason)
                        }
                    }
                }
            }
        }

        return nil
    }

    private static func extractProTip(from text: String) -> String? {
        let patterns = [
            #"\*\*One Pro Tip\*\*:?\s*(.+?)(?=\n\n|$)"#,
            #"\*\*Pro Tip\*\*:?\s*(.+?)(?=\n\n|$)"#
        ]

        for pattern in patterns {
            if let match = text.firstMatch(pattern: pattern) {
                return cleanMarkdown(match)
            }
        }

        return nil
    }

    private static func extractAccountabilityTip(from text: String) -> String? {
        let patterns = [
            #"\*\*Accountability Tip\*\*:?\s*(.+?)(?=\n\n|$)"#
        ]

        for pattern in patterns {
            if let match = text.firstMatch(pattern: pattern) {
                return cleanMarkdown(match)
            }
        }

        return nil
    }

    private static func extractTargetBooks(from text: String, ambition: String?) -> Int {
        // Try to extract a number from "Your Target" section
        if let target = text.firstMatch(pattern: #"\*\*Your Target\*\*:?\s*(\d+)"#),
           let number = Int(target) {
            return number
        }

        // Fallback based on ambition level
        switch ambition {
        case "Gentle start": return 3
        case "Moderate push": return 5
        case "Ambitious goal": return 10
        case "All in": return 15
        default: return 5
        }
    }

    private static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        // Remove ** bold markers
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        // Remove * italic markers (but not bullet points)
        cleaned = cleaned.replacingOccurrences(of: #"(?<!\n)\*(?!\*)"#, with: "", options: .regularExpression)
        // Remove leading/trailing whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}

// MARK: - String Extension for Regex

private extension String {
    func firstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(self.startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: self) else {
            return nil
        }

        return String(self[captureRange])
    }
}
