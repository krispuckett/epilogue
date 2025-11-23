import Foundation
import UserNotifications
import OSLog
import Combine

/// Manages gentle check-in notifications for reading journeys
/// Uses companion voice - no metrics, no pressure, just friendly support
@MainActor
class JourneyCheckInManager: ObservableObject {
    static let shared = JourneyCheckInManager()

    private let logger = Logger(subsystem: "com.epilogue", category: "JourneyCheckIn")
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Settings

    @Published var checkInsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(checkInsEnabled, forKey: "journeyCheckInsEnabled")
            if !checkInsEnabled {
                cancelAllCheckIns()
            }
        }
    }

    @Published var checkInFrequency: CheckInFrequency {
        didSet {
            UserDefaults.standard.set(checkInFrequency.rawValue, forKey: "journeyCheckInFrequency")
        }
    }

    @Published var preferredCheckInTime: Date {
        didSet {
            // Store just the hour and minute components
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: preferredCheckInTime)
            UserDefaults.standard.set(components.hour, forKey: "journeyCheckInHour")
            UserDefaults.standard.set(components.minute, forKey: "journeyCheckInMinute")
        }
    }

    enum CheckInFrequency: String, CaseIterable, Codable {
        case weekly = "Weekly"
        case biweekly = "Every 2 Weeks"
        case monthly = "Monthly"

        var days: Int {
            switch self {
            case .weekly: return 7
            case .biweekly: return 14
            case .monthly: return 30
            }
        }

        var displayName: String { rawValue }
    }

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults
        self.checkInsEnabled = UserDefaults.standard.object(forKey: "journeyCheckInsEnabled") as? Bool ?? true

        if let frequencyString = UserDefaults.standard.string(forKey: "journeyCheckInFrequency"),
           let frequency = CheckInFrequency(rawValue: frequencyString) {
            self.checkInFrequency = frequency
        } else {
            self.checkInFrequency = .weekly
        }

        // Load preferred time (default to 7:00 PM)
        let hour = UserDefaults.standard.object(forKey: "journeyCheckInHour") as? Int ?? 19
        let minute = UserDefaults.standard.object(forKey: "journeyCheckInMinute") as? Int ?? 0
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        self.preferredCheckInTime = Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Permission Management

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                logger.info("📬 Notification permission granted for journey check-ins")
            } else {
                logger.info("❌ Notification permission denied")
            }
            return granted
        } catch {
            logger.error("❌ Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }

    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Check-In Scheduling

    /// Schedule the next check-in for a journey
    func scheduleNextCheckIn(for journey: ReadingJourney) async {
        guard checkInsEnabled else {
            logger.info("⏭️ Check-ins disabled, skipping schedule")
            return
        }

        guard await checkNotificationPermission() else {
            logger.warning("⚠️ No notification permission, cannot schedule check-in")
            return
        }

        // Calculate next check-in date
        let nextCheckInDate = calculateNextCheckInDate(for: journey)

        // Cancel any existing notifications for this journey
        await cancelCheckIn(for: journey)

        // Create notification content
        let content = createCheckInContent(for: journey)

        // Create trigger
        let calendar = Calendar.current
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextCheckInDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        // Create request
        let identifier = "journey-checkin-\(journey.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            logger.info("📅 Scheduled check-in for journey at \(nextCheckInDate)")

            // Update journey's next check-in date
            journey.nextCheckInSuggested = nextCheckInDate
        } catch {
            logger.error("❌ Failed to schedule check-in: \(error.localizedDescription)")
        }
    }

    /// Calculate next check-in date based on journey state and frequency
    private func calculateNextCheckInDate(for journey: ReadingJourney) -> Date {
        let calendar = Calendar.current
        let now = Date()

        // Start from last check-in or journey creation date
        let baseDate = journey.lastCheckIn ?? journey.createdAt

        // Add frequency interval
        var nextDate = calendar.date(byAdding: .day, value: checkInFrequency.days, to: baseDate) ?? now

        // If calculated date is in the past, use today + frequency
        if nextDate < now {
            nextDate = calendar.date(byAdding: .day, value: checkInFrequency.days, to: now) ?? now
        }

        // Apply preferred time of day
        let timeComponents = calendar.dateComponents([.hour, .minute], from: preferredCheckInTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        return calendar.date(from: dateComponents) ?? nextDate
    }

    /// Create notification content with companion voice
    private func createCheckInContent(for journey: ReadingJourney) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        // Get current book if available
        if let currentBook = journey.currentBook,
           let bookTitle = currentBook.bookModel?.title {
            content.title = "How's \(bookTitle) going?"
            content.body = "No pressure—just checking in. Tap to share how you're feeling about it."
        } else if let completedCount = journey.books?.filter({ $0.isCompleted }).count,
                  completedCount > 0 {
            content.title = "Nice work on your journey"
            content.body = "You've finished \(completedCount) book\(completedCount == 1 ? "" : "s"). Want to check in on what's next?"
        } else {
            content.title = "Thinking about your reading?"
            content.body = "No rush—just wanted to see how your journey is feeling."
        }

        content.sound = .default
        content.categoryIdentifier = "JOURNEY_CHECKIN"
        content.userInfo = [
            "type": "journeyCheckIn",
            "journeyId": journey.id.uuidString
        ]

        return content
    }

    // MARK: - Cancellation

    /// Cancel check-in notification for a specific journey
    func cancelCheckIn(for journey: ReadingJourney) async {
        let identifier = "journey-checkin-\(journey.id.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.info("🗑️ Cancelled check-in for journey")
    }

    /// Cancel all check-in notifications
    func cancelAllCheckIns() {
        Task {
            let pendingRequests = await notificationCenter.pendingNotificationRequests()
            let journeyCheckInIdentifiers = pendingRequests
                .filter { $0.identifier.starts(with: "journey-checkin-") }
                .map { $0.identifier }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: journeyCheckInIdentifiers)
            logger.info("🗑️ Cancelled all journey check-ins (\(journeyCheckInIdentifiers.count) notifications)")
        }
    }

    // MARK: - Check-In Recording

    /// Record that user checked in (called from notification tap or manual check-in)
    func recordCheckIn(for journey: ReadingJourney) async {
        journey.lastCheckIn = Date()
        logger.info("✅ Recorded check-in for journey")

        // Schedule next check-in
        await scheduleNextCheckIn(for: journey)
    }

    // MARK: - Debug Helpers

    func getPendingCheckIns() async -> [(identifier: String, date: Date?)] {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests
            .filter { $0.identifier.starts(with: "journey-checkin-") }
            .map { request in
                let date: Date?
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let triggerDate = trigger.nextTriggerDate() {
                    date = triggerDate
                } else {
                    date = nil
                }
                return (request.identifier, date)
            }
    }
}
