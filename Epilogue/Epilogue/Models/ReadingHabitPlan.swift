import Foundation
import SwiftData
import SwiftUI

// MARK: - Reading Habit Plan
/// A living, trackable reading habit or challenge that adapts to user behavior
/// Designed to integrate deeply with Ambient Mode sessions and provide gentle accountability

@Model
final class ReadingHabitPlan {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Plan identity
    var planType: String = PlanType.habit.rawValue // "habit" or "challenge"
    var title: String = "" // "Your 7-Day Reading Kickstart"
    var goal: String = "" // "Build a sustainable morning reading habit..."

    // User preferences (from question flow)
    var preferredTime: String? // "Morning", "Evening", etc.
    var commitmentLevel: String? // "15 min/day", "30 min/day", etc.
    var userBlocker: String? // "Too busy", "Hard to focus", etc.

    // Plan duration
    var planDuration: String? // "7 days", "14 days", "21 days", "30 days"

    // Challenge-specific
    var challengeType: String? // "Read more books", "Explore new genres", etc.
    var ambitionLevel: String? // "Gentle start", "Ambitious goal", etc.
    var timeframe: String? // "This month", "This year", etc.
    var targetBooks: Int? // Number of books to read

    // Ritual details
    var ritualWhen: String? // "Right after you wake up"
    var ritualWhere: String? // "At your kitchen table"
    var ritualDuration: String? // "10 minutes"
    var ritualTrigger: String? // "After I pour my morning coffee..."

    // Pro tip from AI
    var proTip: String?

    // First book recommendation
    var recommendedBookTitle: String?
    var recommendedBookAuthor: String?
    var recommendedBookReason: String?

    // Status
    var isActive: Bool = true
    var isPaused: Bool = false
    var pausedAt: Date?
    var completedAt: Date?

    // Progress tracking
    @Relationship(deleteRule: .cascade, inverse: \HabitDay.plan)
    var days: [HabitDay]?

    // Associated book (optional)
    var bookId: String? // The book.id associated with this plan
    var bookTitle: String? // Cached for display without loading book
    var bookAuthor: String? // Cached for display without loading book
    var bookCoverURL: String? // Cached for display without loading book

    // Streak tracking
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: Date?

    // Notifications
    var notificationsEnabled: Bool = false
    var notificationTime: Date? // Time of day for reminder
    var notificationDays: [Int]? // Days of week (1 = Sunday, 7 = Saturday)

    init(type: PlanType, title: String, goal: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.planType = type.rawValue
        self.title = title
        self.goal = goal
        self.isActive = true

        // Initialize 7 days for habit plans
        if type == .habit {
            initializeWeek()
        }
    }

    // MARK: - Computed Properties

    var type: PlanType {
        PlanType(rawValue: planType) ?? .habit
    }

    var orderedDays: [HabitDay] {
        (days ?? []).sorted { $0.dayNumber < $1.dayNumber }
    }

    var completedDays: Int {
        orderedDays.filter { $0.isCompleted }.count
    }

    var totalDays: Int {
        days?.count ?? 7
    }

    var weekProgress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedDays) / Double(totalDays)
    }

    var todayDay: HabitDay? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return orderedDays.first { calendar.startOfDay(for: $0.date) == today }
    }

    var currentDayNumber: Int {
        let calendar = Calendar.current
        let startOfPlan = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: startOfPlan, to: today)
        return (components.day ?? 0) + 1
    }

    var isOnTrack: Bool {
        // User is on track if they've completed today or it's still early in their preferred time
        if let today = todayDay, today.isCompleted {
            return true
        }
        return currentStreak > 0
    }

    var statusMessage: String {
        if let today = todayDay, today.isCompleted {
            return "Great reading today!"
        } else if currentStreak > 0 {
            return "\(currentStreak) day streak"
        } else if completedDays > 0 {
            return "Ready to get back on track?"
        } else {
            return "Let's start your journey"
        }
    }

    // MARK: - Plan Management

    func initializeWeek() {
        initializeDays(count: 7)
    }

    func initializeDays(count: Int) {
        guard days == nil || days?.isEmpty == true else { return }

        days = []
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())

        for dayOffset in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let day = HabitDay(dayNumber: dayOffset + 1, date: date)
            day.plan = self
            days?.append(day)
        }
        updatedAt = Date()
    }

    func recordReading(minutes: Int, fromAmbientSession: Bool = false) {
        guard let today = todayDay else { return }

        today.minutesRead += minutes
        today.sessionsCount += 1
        today.lastSessionAt = Date()

        if fromAmbientSession {
            today.fromAmbientMode = true
        }

        // Check if daily goal is met
        let targetMinutes = parseTargetMinutes()
        if today.minutesRead >= targetMinutes && !today.isCompleted {
            today.isCompleted = true
            today.completedAt = Date()
            updateStreak()
        }

        lastActivityDate = Date()
        updatedAt = Date()
    }

    func markDayComplete(_ dayNumber: Int) {
        guard let day = orderedDays.first(where: { $0.dayNumber == dayNumber }) else { return }

        if !day.isCompleted {
            day.isCompleted = true
            day.completedAt = Date()
            updateStreak()
        }

        lastActivityDate = Date()
        updatedAt = Date()
    }

    private func updateStreak() {
        let calendar = Calendar.current
        var streak = 0
        let today = calendar.startOfDay(for: Date())

        // Count backwards from today
        for day in orderedDays.reversed() {
            let dayDate = calendar.startOfDay(for: day.date)

            // Only count up to today
            if dayDate > today { continue }

            if day.isCompleted {
                streak += 1
            } else if dayDate < today {
                // If we hit an incomplete day in the past, streak is broken
                break
            }
        }

        currentStreak = streak
        longestStreak = max(longestStreak, currentStreak)
    }

    func pause() {
        isPaused = true
        pausedAt = Date()
        updatedAt = Date()
    }

    func resume() {
        isPaused = false
        pausedAt = nil
        updatedAt = Date()
    }

    func complete() {
        isActive = false
        completedAt = Date()
        updatedAt = Date()
    }

    private func parseTargetMinutes() -> Int {
        guard let commitment = commitmentLevel else { return 15 }

        if commitment.contains("15") { return 15 }
        if commitment.contains("30") { return 30 }
        if commitment.contains("1 hour") || commitment.contains("60") { return 60 }
        if commitment.contains("hours/week") { return 30 } // Flexible weekly goal

        return 15 // Default
    }
}

// MARK: - Habit Day
/// Tracks a single day within a reading habit plan

@Model
final class HabitDay {
    var id: UUID = UUID()
    var dayNumber: Int = 1 // Day 1, Day 2, etc.
    var date: Date = Date()

    var plan: ReadingHabitPlan?

    // Progress
    var minutesRead: Int = 0
    var sessionsCount: Int = 0
    var lastSessionAt: Date?

    // Completion
    var isCompleted: Bool = false
    var completedAt: Date?

    // Source tracking
    var fromAmbientMode: Bool = false // Was this tracked via ambient session?
    var manualEntry: Bool = false // Did user manually mark complete?

    // Optional reflection
    var reflection: String?

    init(dayNumber: Int, date: Date) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.date = date
    }

    // MARK: - Computed Properties

    var dayLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDate = calendar.startOfDay(for: date)

        if dayDate == today {
            return "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  dayDate == tomorrow {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }

    var shortDayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isPast: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    var isFuture: Bool {
        date > Date()
    }

    var status: DayStatus {
        if isCompleted {
            return .completed
        } else if isToday {
            return .today
        } else if isPast {
            return .missed
        } else {
            return .upcoming
        }
    }
}

// MARK: - Supporting Types

enum PlanType: String, Codable, CaseIterable {
    case habit = "habit"
    case challenge = "challenge"

    var displayName: String {
        switch self {
        case .habit: return "Reading Habit"
        case .challenge: return "Reading Challenge"
        }
    }

    var icon: String {
        switch self {
        case .habit: return "sunrise.fill"
        case .challenge: return "flag.fill"
        }
    }
}

enum DayStatus: String, Codable {
    case upcoming
    case today
    case completed
    case missed

    var color: Color {
        switch self {
        case .upcoming: return .white.opacity(0.3)
        case .today: return DesignSystem.Colors.primaryAccent
        case .completed: return DesignSystem.Colors.success
        case .missed: return .white.opacity(0.15)
        }
    }
}
