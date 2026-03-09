import Foundation

// MARK: - Reading Nudge Engine
/// Proactive, contextual nudge system for reading sessions.
/// Surfaces gentle prompts in the Dynamic Island / Lock Screen banner
/// to encourage capture, celebrate milestones, and maintain engagement.
///
/// Guardrails:
/// - 5-minute quiet period at session start
/// - Minimum 10 minutes between nudges
/// - Maximum 3 nudges per session

@MainActor
final class ReadingNudgeEngine {
    static let shared = ReadingNudgeEngine()

    // MARK: - Nudge Types

    enum NudgeType: String, Codable {
        case captureReminder    // "Anything worth capturing?"
        case milestone          // "25 pages today!"
        case paceChange         // "You're reading faster now"
        case sessionLength      // "1 hour of reading — nice"
        case bookCompletion     // "Almost done with this one"
    }

    struct Nudge: Codable, Hashable {
        let type: NudgeType
        let message: String
        let icon: String // SF Symbol name
        let timestamp: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 60 // Nudges expire after 60s
        }
    }

    // MARK: - Guardrails

    private let quietPeriod: TimeInterval = 5 * 60        // 5 min at start
    private let minNudgeInterval: TimeInterval = 10 * 60  // 10 min between
    private let maxNudgesPerSession = 3

    // MARK: - Session State

    private var sessionStartTime: Date?
    private var nudgeHistory: [Nudge] = []
    private var lastNudgeTime: Date?
    private var lastPageCount: Int = 0
    private var lastPaceCheckTime: Date?
    private var lastPacePageCount: Int = 0
    private var currentNudge: Nudge?

    // MARK: - Public API

    /// Start tracking for a new session
    func startSession() {
        sessionStartTime = Date()
        nudgeHistory = []
        lastNudgeTime = nil
        lastPageCount = 0
        lastPaceCheckTime = nil
        lastPacePageCount = 0
        currentNudge = nil
    }

    /// End session tracking
    func endSession() {
        sessionStartTime = nil
        currentNudge = nil
    }

    /// Check if a nudge should fire given current session state.
    /// Returns a Nudge if conditions are met, nil otherwise.
    func checkForNudge(
        elapsedSeconds: TimeInterval,
        pagesRead: Int,
        captureCount: Int,
        totalPages: Int?
    ) -> Nudge? {
        guard canNudge() else { return nil }

        // Priority order: completion > milestone > session length > pace > capture
        if let nudge = checkBookCompletion(pagesRead: pagesRead, totalPages: totalPages) {
            return fire(nudge)
        }
        if let nudge = checkMilestone(pagesRead: pagesRead) {
            return fire(nudge)
        }
        if let nudge = checkSessionLength(elapsed: elapsedSeconds) {
            return fire(nudge)
        }
        if let nudge = checkPaceChange(pagesRead: pagesRead, elapsed: elapsedSeconds) {
            return fire(nudge)
        }
        if let nudge = checkCaptureReminder(elapsed: elapsedSeconds, captureCount: captureCount) {
            return fire(nudge)
        }

        return nil
    }

    /// Get the current active nudge (nil if expired or dismissed)
    func getPendingNudge() -> Nudge? {
        guard let nudge = currentNudge, !nudge.isExpired else {
            currentNudge = nil
            return nil
        }
        return nudge
    }

    /// Dismiss the current nudge
    func dismissNudge() {
        currentNudge = nil
    }

    // MARK: - Guardrail Checks

    private func canNudge() -> Bool {
        guard let start = sessionStartTime else { return false }

        // Quiet period at start
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < quietPeriod { return false }

        // Max nudges per session
        if nudgeHistory.count >= maxNudgesPerSession { return false }

        // Min interval between nudges
        if let last = lastNudgeTime {
            if Date().timeIntervalSince(last) < minNudgeInterval { return false }
        }

        return true
    }

    private func fire(_ nudge: Nudge) -> Nudge {
        currentNudge = nudge
        nudgeHistory.append(nudge)
        lastNudgeTime = nudge.timestamp
        return nudge
    }

    // MARK: - Nudge Checks

    private func checkBookCompletion(pagesRead: Int, totalPages: Int?) -> Nudge? {
        guard let total = totalPages, total > 0 else { return nil }
        let remaining = total - pagesRead
        let pct = Double(pagesRead) / Double(total)

        // Nudge at 90% if not already nudged for completion
        if pct >= 0.9 && remaining > 0 && remaining <= 30 {
            if !nudgeHistory.contains(where: { $0.type == .bookCompletion }) {
                return Nudge(
                    type: .bookCompletion,
                    message: "\(remaining) pages to go — you're so close",
                    icon: "flag.checkered",
                    timestamp: Date()
                )
            }
        }
        return nil
    }

    private func checkMilestone(pagesRead: Int) -> Nudge? {
        // Milestones at 25, 50, 100 pages
        let milestones = [100, 50, 25]
        for milestone in milestones {
            if pagesRead >= milestone && lastPageCount < milestone {
                lastPageCount = pagesRead
                return Nudge(
                    type: .milestone,
                    message: "\(milestone) pages today",
                    icon: "star.fill",
                    timestamp: Date()
                )
            }
        }
        lastPageCount = pagesRead
        return nil
    }

    private func checkSessionLength(elapsed: TimeInterval) -> Nudge? {
        let hours = Int(elapsed / 3600)
        let minutes = Int(elapsed / 60)

        // Nudge at 1 hour
        if hours >= 1 && !nudgeHistory.contains(where: { $0.type == .sessionLength }) {
            return Nudge(
                type: .sessionLength,
                message: minutes >= 120 ? "\(hours) hours of reading" : "1 hour of reading — nice",
                icon: "clock.fill",
                timestamp: Date()
            )
        }
        return nil
    }

    private func checkPaceChange(pagesRead: Int, elapsed: TimeInterval) -> Nudge? {
        guard elapsed > 15 * 60 else { return nil } // Need 15+ min of data

        let now = Date()

        // Initialize pace tracking
        if lastPaceCheckTime == nil {
            lastPaceCheckTime = now
            lastPacePageCount = pagesRead
            return nil
        }

        guard let lastCheck = lastPaceCheckTime else { return nil }
        let interval = now.timeIntervalSince(lastCheck)

        // Check every 10 minutes
        guard interval >= 10 * 60 else { return nil }

        let recentPages = pagesRead - lastPacePageCount
        let recentRate = Double(recentPages) / (interval / 60.0) // pages/min

        let overallRate = Double(pagesRead) / (elapsed / 60.0)

        lastPaceCheckTime = now
        lastPacePageCount = pagesRead

        // 50% faster than average
        if recentRate > overallRate * 1.5 && recentPages > 5 {
            if !nudgeHistory.contains(where: { $0.type == .paceChange }) {
                return Nudge(
                    type: .paceChange,
                    message: "You're in the zone right now",
                    icon: "hare.fill",
                    timestamp: Date()
                )
            }
        }

        return nil
    }

    private func checkCaptureReminder(elapsed: TimeInterval, captureCount: Int) -> Nudge? {
        // After 20+ minutes with no captures
        if elapsed > 20 * 60 && captureCount == 0 {
            if !nudgeHistory.contains(where: { $0.type == .captureReminder }) {
                return Nudge(
                    type: .captureReminder,
                    message: "Anything worth capturing?",
                    icon: "text.quote",
                    timestamp: Date()
                )
            }
        }
        return nil
    }
}
