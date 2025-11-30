import Foundation
import UserNotifications
import SwiftData

// MARK: - Reading Plan Notification Service
/// Schedules and manages reading reminder notifications for habit plans

final class ReadingPlanNotificationService {
    static let shared = ReadingPlanNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification identifiers
    private let readingReminderPrefix = "readingPlanReminder_"

    private init() {}

    // MARK: - Permission

    /// Request notification permission if not already granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            #if DEBUG
            print("🔔 Notification permission: \(granted ? "granted" : "denied")")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("❌ Notification permission error: \(error)")
            #endif
            return false
        }
    }

    /// Check current notification authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Notifications

    /// Schedule daily reading reminders for a habit plan
    func scheduleReminders(for plan: ReadingHabitPlan) async {
        // First, remove any existing reminders for this plan
        await cancelReminders(for: plan)

        // Check if notifications are enabled for this plan
        guard plan.notificationsEnabled else {
            #if DEBUG
            print("🔔 Notifications disabled for plan: \(plan.title)")
            #endif
            return
        }

        // Determine reminder time
        let reminderTime = plan.notificationTime ?? defaultReminderTime(for: plan)

        // Schedule for each active day (or all days if not specified)
        let daysToSchedule = plan.notificationDays ?? [1, 2, 3, 4, 5, 6, 7] // All days

        for dayOfWeek in daysToSchedule {
            await scheduleWeeklyReminder(
                for: plan,
                dayOfWeek: dayOfWeek,
                time: reminderTime
            )
        }

        #if DEBUG
        print("🔔 Scheduled \(daysToSchedule.count) reminders for plan: \(plan.title)")
        #endif
    }

    /// Schedule a single weekly recurring reminder
    private func scheduleWeeklyReminder(
        for plan: ReadingHabitPlan,
        dayOfWeek: Int,
        time: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: plan)
        content.body = reminderBody(for: plan)
        content.sound = .default
        content.categoryIdentifier = "READING_REMINDER"
        content.userInfo = [
            "type": "readingPlanReminder",
            "planId": plan.id.uuidString
        ]

        // Create date components for the trigger
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        dateComponents.weekday = dayOfWeek

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let identifier = "\(readingReminderPrefix)\(plan.id.uuidString)_day\(dayOfWeek)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("🔔 Scheduled reminder for day \(dayOfWeek) at \(time)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule reminder: \(error)")
            #endif
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel all reminders for a specific plan
    func cancelReminders(for plan: ReadingHabitPlan) async {
        let identifiersToRemove = (1...7).map { day in
            "\(readingReminderPrefix)\(plan.id.uuidString)_day\(day)"
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)

        #if DEBUG
        print("🔔 Cancelled reminders for plan: \(plan.title)")
        #endif
    }

    /// Cancel all reading plan reminders
    func cancelAllReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let readingReminders = pending.filter { $0.identifier.hasPrefix(readingReminderPrefix) }
        let identifiers = readingReminders.map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        #if DEBUG
        print("🔔 Cancelled all \(identifiers.count) reading plan reminders")
        #endif
    }

    // MARK: - Helpers

    /// Generate default reminder time based on plan preferences
    private func defaultReminderTime(for plan: ReadingHabitPlan) -> Date {
        var components = DateComponents()

        switch plan.preferredTime?.lowercased() {
        case "morning", "first thing":
            components.hour = 7
            components.minute = 30
        case "lunch", "midday":
            components.hour = 12
            components.minute = 0
        case "afternoon":
            components.hour = 15
            components.minute = 0
        case "evening":
            components.hour = 19
            components.minute = 0
        case "before bed", "night":
            components.hour = 21
            components.minute = 0
        default:
            // Default to 8 AM
            components.hour = 8
            components.minute = 0
        }

        return Calendar.current.date(from: components) ?? Date()
    }

    /// Generate notification title based on plan state
    private func reminderTitle(for plan: ReadingHabitPlan) -> String {
        if plan.currentStreak > 0 {
            return "Keep your \(plan.currentStreak)-day streak going"
        } else if plan.completedDays > 0 {
            return "Time to read"
        } else {
            return "Start your reading journey"
        }
    }

    /// Generate notification body based on plan state
    private func reminderBody(for plan: ReadingHabitPlan) -> String {
        let messages: [String]

        if plan.currentStreak > 2 {
            messages = [
                "You're building something amazing. \(plan.commitmentLevel ?? "A few minutes") today keeps the momentum going.",
                "Day \(plan.currentStreak + 1) awaits. Your reading ritual is becoming a habit.",
                "\(plan.currentStreak) days strong. Don't break the chain."
            ]
        } else if plan.completedDays > 0 {
            messages = [
                "Ready to pick up where you left off?",
                "\(plan.ritualWhere ?? "Your reading spot") is waiting for you.",
                "Even a few pages count toward your goal."
            ]
        } else {
            messages = [
                "Day 1 starts now. Just \(plan.commitmentLevel ?? "a few minutes") to begin.",
                "Your reading journey begins with a single page.",
                "Find a cozy spot and open that book."
            ]
        }

        return messages.randomElement() ?? "Time to read"
    }
}

// MARK: - NotificationDelegate Extension

extension NotificationDelegate {
    /// Handle reading plan notification tap
    func handleReadingPlanNotification(planId: String) {
        // Post notification to navigate to ambient mode with the plan
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToReadingPlan"),
                object: planId
            )
        }
    }
}
