import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "ReadingAnalytics")

/// Service for computing and caching reading analytics
@MainActor
final class ReadingAnalyticsService: ObservableObject {
    static let shared = ReadingAnalyticsService()

    @Published private(set) var isUpdating = false
    @Published private(set) var lastUpdateTime: Date?

    private var modelContext: ModelContext?

    private init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Main Analytics Computation

    /// Recomputes all analytics from raw data
    func refreshAnalytics() async {
        guard let context = modelContext else {
            logger.error("ModelContext not configured for ReadingAnalyticsService")
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        logger.info("Starting analytics refresh...")

        do {
            // Get or create the analytics record
            let analytics = try await getOrCreateAnalytics(context: context)

            // Compute time-based metrics
            try await computeTimeMetrics(analytics: analytics, context: context)

            // Compute engagement metrics
            try await computeEngagementMetrics(analytics: analytics, context: context)

            // Compute patterns
            try await computePatterns(analytics: analytics, context: context)

            // Update streak
            updateStreak(analytics: analytics)

            // Check for new milestones
            try await checkMilestones(analytics: analytics, context: context)

            // Update daily summaries
            try await updateDailySummaries(context: context)

            // Update book stats
            try await updateBookStats(context: context)

            analytics.lastUpdated = Date()
            try context.save()

            lastUpdateTime = Date()
            logger.info("Analytics refresh completed successfully")
        } catch {
            logger.error("Failed to refresh analytics: \(error.localizedDescription)")
        }
    }

    // MARK: - Quick Metrics (No Full Refresh)

    /// Get current streak without full refresh
    func getCurrentStreak(context: ModelContext) -> Int {
        do {
            let descriptor = FetchDescriptor<ReadingAnalytics>()
            if let analytics = try context.fetch(descriptor).first {
                return analytics.currentStreak
            }
        } catch {
            logger.error("Failed to fetch streak: \(error.localizedDescription)")
        }
        return 0
    }

    /// Get reading time for a date range
    func getReadingTime(from startDate: Date, to endDate: Date, context: ModelContext) -> TimeInterval {
        do {
            let predicate = #Predicate<ReadingSession> { session in
                session.startDate >= startDate && session.startDate <= endDate
            }
            let descriptor = FetchDescriptor(predicate: predicate)
            let sessions = try context.fetch(descriptor)
            return sessions.reduce(0) { $0 + $1.duration }
        } catch {
            logger.error("Failed to fetch reading time: \(error.localizedDescription)")
        }
        return 0
    }

    /// Get daily summaries for a date range
    func getDailySummaries(from startDate: Date, to endDate: Date, context: ModelContext) -> [DailyReadingSummary] {
        do {
            let startOfRange = Calendar.current.startOfDay(for: startDate)
            let endOfRange = Calendar.current.startOfDay(for: endDate)
            let predicate = #Predicate<DailyReadingSummary> { summary in
                summary.date >= startOfRange && summary.date <= endOfRange
            }
            let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch daily summaries: \(error.localizedDescription)")
        }
        return []
    }

    /// Get sessions for today
    func getTodaysSessions(context: ModelContext) -> [ReadingSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        do {
            let predicate = #Predicate<ReadingSession> { session in
                session.startDate >= startOfDay && session.startDate < endOfDay
            }
            let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch today's sessions: \(error.localizedDescription)")
        }
        return []
    }

    /// Get this week's reading data for charts
    func getWeeklyReadingData(context: ModelContext) -> [DayReadingData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        var result: [DayReadingData] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: date) ?? date

            do {
                let predicate = #Predicate<ReadingSession> { session in
                    session.startDate >= date && session.startDate < dayEnd
                }
                let descriptor = FetchDescriptor(predicate: predicate)
                let sessions = try context.fetch(descriptor)

                let totalTime = sessions.reduce(0) { $0 + $1.duration }
                let dayOfWeek = calendar.component(.weekday, from: date)

                result.append(DayReadingData(
                    date: date,
                    dayOfWeek: dayOfWeek,
                    totalMinutes: totalTime / 60,
                    sessionCount: sessions.count
                ))
            } catch {
                logger.error("Failed to fetch weekly data: \(error.localizedDescription)")
            }
        }

        return result
    }

    // MARK: - Private Helpers

    private func getOrCreateAnalytics(context: ModelContext) async throws -> ReadingAnalytics {
        let descriptor = FetchDescriptor<ReadingAnalytics>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let analytics = ReadingAnalytics()
        context.insert(analytics)
        return analytics
    }

    private func computeTimeMetrics(analytics: ReadingAnalytics, context: ModelContext) async throws {
        let calendar = Calendar.current
        let now = Date()

        // This week
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        analytics.totalReadingTimeThisWeek = getReadingTime(from: weekStart, to: now, context: context)
        analytics.sessionsThisWeek = try getSessionCount(from: weekStart, to: now, context: context)

        // This month
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        analytics.totalReadingTimeThisMonth = getReadingTime(from: monthStart, to: now, context: context)
        analytics.sessionsThisMonth = try getSessionCount(from: monthStart, to: now, context: context)

        // This year
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        analytics.totalReadingTimeThisYear = getReadingTime(from: yearStart, to: now, context: context)
        analytics.sessionsThisYear = try getSessionCount(from: yearStart, to: now, context: context)

        // All time
        analytics.totalReadingTimeAllTime = getReadingTime(from: .distantPast, to: now, context: context)
        analytics.totalSessions = try getSessionCount(from: .distantPast, to: now, context: context)
    }

    private func getSessionCount(from startDate: Date, to endDate: Date, context: ModelContext) throws -> Int {
        let predicate = #Predicate<ReadingSession> { session in
            session.startDate >= startDate && session.startDate <= endDate
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    private func computeEngagementMetrics(analytics: ReadingAnalytics, context: ModelContext) async throws {
        let calendar = Calendar.current
        let now = Date()

        // This week
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        analytics.quotesThisWeek = try getQuoteCount(from: weekStart, to: now, context: context)
        analytics.notesThisWeek = try getNoteCount(from: weekStart, to: now, context: context)

        // This month
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        analytics.quotesThisMonth = try getQuoteCount(from: monthStart, to: now, context: context)
        analytics.notesThisMonth = try getNoteCount(from: monthStart, to: now, context: context)

        // This year
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        analytics.quotesThisYear = try getQuoteCount(from: yearStart, to: now, context: context)
        analytics.notesThisYear = try getNoteCount(from: yearStart, to: now, context: context)

        // All time
        analytics.totalQuotes = try getQuoteCount(from: .distantPast, to: now, context: context)
        analytics.totalNotes = try getNoteCount(from: .distantPast, to: now, context: context)

        // Book stats
        analytics.booksFinishedThisYear = try getCompletedBookCount(from: yearStart, to: now, context: context)
        analytics.booksFinishedAllTime = try getCompletedBookCount(from: .distantPast, to: now, context: context)
    }

    private func getQuoteCount(from startDate: Date, to endDate: Date, context: ModelContext) throws -> Int {
        let predicate = #Predicate<CapturedQuote> { quote in
            (quote.timestamp ?? Date.distantPast) >= startDate && (quote.timestamp ?? Date.distantPast) <= endDate
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    private func getNoteCount(from startDate: Date, to endDate: Date, context: ModelContext) throws -> Int {
        let predicate = #Predicate<CapturedNote> { note in
            (note.timestamp ?? Date.distantPast) >= startDate && (note.timestamp ?? Date.distantPast) <= endDate
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    private func getCompletedBookCount(from startDate: Date, to endDate: Date, context: ModelContext) throws -> Int {
        let completedStatus = ReadingStatus.read.rawValue
        let predicate = #Predicate<BookModel> { book in
            book.readingStatus == completedStatus
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    private func computePatterns(analytics: ReadingAnalytics, context: ModelContext) async throws {
        let descriptor = FetchDescriptor<ReadingSession>()
        let sessions = try context.fetch(descriptor)

        // Hourly distribution
        var hourlyDist: [Int: TimeInterval] = [:]
        for session in sessions {
            let hour = session.startHour
            hourlyDist[hour, default: 0] += session.duration
        }
        analytics.setHourlyDistribution(hourlyDist)

        // Find preferred hour
        if let (hour, _) = hourlyDist.max(by: { $0.value < $1.value }) {
            analytics.preferredReadingHour = hour
        }

        // Day of week distribution
        var dayDist: [Int: TimeInterval] = [:]
        for session in sessions {
            let day = session.dayOfWeek
            dayDist[day, default: 0] += session.duration
        }
        analytics.setDayOfWeekDistribution(dayDist)

        // Find preferred day
        if let (day, _) = dayDist.max(by: { $0.value < $1.value }) {
            analytics.preferredDayOfWeek = day
        }

        // Monthly trend (this year)
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        var monthlyTrend: [Int: TimeInterval] = [:]
        for session in sessions {
            if session.year == currentYear {
                let month = session.month
                monthlyTrend[month, default: 0] += session.duration
            }
        }
        analytics.setMonthlyTrend(monthlyTrend)
    }

    private func updateStreak(analytics: ReadingAnalytics) {
        // Check if streak is broken
        if analytics.checkStreakBroken() {
            analytics.currentStreak = 0
        }
    }

    private func checkMilestones(analytics: ReadingAnalytics, context: ModelContext) async throws {
        let existingMilestones = try fetchExistingMilestoneTypes(context: context)

        // Check streak milestones
        if analytics.currentStreak >= 7 && !existingMilestones.contains(.streak7Days) {
            createMilestone(.streak7Days, value: 7, context: context)
        }
        if analytics.currentStreak >= 30 && !existingMilestones.contains(.streak30Days) {
            createMilestone(.streak30Days, value: 30, context: context)
        }
        if analytics.currentStreak >= 100 && !existingMilestones.contains(.streak100Days) {
            createMilestone(.streak100Days, value: 100, context: context)
        }
        if analytics.currentStreak >= 365 && !existingMilestones.contains(.streak365Days) {
            createMilestone(.streak365Days, value: 365, context: context)
        }

        // Check hours milestones
        let totalHours = analytics.totalReadingTimeAllTime / 3600
        if totalHours >= 10 && !existingMilestones.contains(.hours10) {
            createMilestone(.hours10, value: 10, context: context)
        }
        if totalHours >= 50 && !existingMilestones.contains(.hours50) {
            createMilestone(.hours50, value: 50, context: context)
        }
        if totalHours >= 100 && !existingMilestones.contains(.hours100) {
            createMilestone(.hours100, value: 100, context: context)
        }
        if totalHours >= 500 && !existingMilestones.contains(.hours500) {
            createMilestone(.hours500, value: 500, context: context)
        }

        // Check books milestones
        if analytics.booksFinishedAllTime >= 5 && !existingMilestones.contains(.books5) {
            createMilestone(.books5, value: 5, context: context)
        }
        if analytics.booksFinishedAllTime >= 10 && !existingMilestones.contains(.books10) {
            createMilestone(.books10, value: 10, context: context)
        }
        if analytics.booksFinishedAllTime >= 25 && !existingMilestones.contains(.books25) {
            createMilestone(.books25, value: 25, context: context)
        }
        if analytics.booksFinishedAllTime >= 50 && !existingMilestones.contains(.books50) {
            createMilestone(.books50, value: 50, context: context)
        }
        if analytics.booksFinishedAllTime >= 100 && !existingMilestones.contains(.books100) {
            createMilestone(.books100, value: 100, context: context)
        }

        // Check quotes milestones
        if analytics.totalQuotes >= 50 && !existingMilestones.contains(.quotes50) {
            createMilestone(.quotes50, value: 50, context: context)
        }
        if analytics.totalQuotes >= 100 && !existingMilestones.contains(.quotes100) {
            createMilestone(.quotes100, value: 100, context: context)
        }
        if analytics.totalQuotes >= 500 && !existingMilestones.contains(.quotes500) {
            createMilestone(.quotes500, value: 500, context: context)
        }

        // Check notes milestones
        if analytics.totalNotes >= 50 && !existingMilestones.contains(.notes50) {
            createMilestone(.notes50, value: 50, context: context)
        }
        if analytics.totalNotes >= 100 && !existingMilestones.contains(.notes100) {
            createMilestone(.notes100, value: 100, context: context)
        }

        // First session milestone
        if analytics.totalSessions == 1 && !existingMilestones.contains(.firstSession) {
            createMilestone(.firstSession, context: context)
        }

        // First quote milestone
        if analytics.totalQuotes == 1 && !existingMilestones.contains(.firstQuote) {
            createMilestone(.firstQuote, context: context)
        }

        // First note milestone
        if analytics.totalNotes == 1 && !existingMilestones.contains(.firstNote) {
            createMilestone(.firstNote, context: context)
        }

        // First book milestone
        if analytics.booksFinishedAllTime == 1 && !existingMilestones.contains(.firstBook) {
            createMilestone(.firstBook, context: context)
        }
    }

    private func fetchExistingMilestoneTypes(context: ModelContext) throws -> Set<MilestoneType> {
        let descriptor = FetchDescriptor<ReadingMilestone>()
        let milestones = try context.fetch(descriptor)
        return Set(milestones.compactMap { MilestoneType(rawValue: $0.type) })
    }

    private func createMilestone(_ type: MilestoneType, value: Int = 0, bookLocalId: String? = nil, context: ModelContext) {
        let milestone = ReadingMilestone(type: type, value: value, bookLocalId: bookLocalId)
        context.insert(milestone)
        logger.info("New milestone achieved: \(type.displayName)")
    }

    private func updateDailySummaries(context: ModelContext) async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get or create today's summary
        let predicate = #Predicate<DailyReadingSummary> { summary in
            summary.date == today
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        let todaySummary: DailyReadingSummary
        if let existing = try context.fetch(descriptor).first {
            todaySummary = existing
        } else {
            todaySummary = DailyReadingSummary(date: today)
            context.insert(todaySummary)
        }

        // Compute today's metrics
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let sessionPredicate = #Predicate<ReadingSession> { session in
            session.startDate >= today && session.startDate < tomorrow
        }
        let sessionDescriptor = FetchDescriptor(predicate: sessionPredicate)
        let sessions = try context.fetch(sessionDescriptor)

        todaySummary.totalReadingTime = sessions.reduce(0) { $0 + $1.duration }
        todaySummary.sessionCount = sessions.count
        todaySummary.pagesRead = sessions.reduce(0) { $0 + $1.pagesRead }

        // Get unique book IDs
        todaySummary.bookIdsRead = Array(Set(sessions.compactMap { $0.bookLocalId }))

        // Count quotes and notes for today
        let quotePredicate = #Predicate<CapturedQuote> { quote in
            (quote.timestamp ?? Date.distantPast) >= today && (quote.timestamp ?? Date.distantPast) < tomorrow
        }
        let quoteDescriptor = FetchDescriptor(predicate: quotePredicate)
        todaySummary.quotesCount = try context.fetchCount(quoteDescriptor)

        let notePredicate = #Predicate<CapturedNote> { note in
            (note.timestamp ?? Date.distantPast) >= today && (note.timestamp ?? Date.distantPast) < tomorrow
        }
        let noteDescriptor = FetchDescriptor(predicate: notePredicate)
        todaySummary.notesCount = try context.fetchCount(noteDescriptor)
    }

    private func updateBookStats(context: ModelContext) async throws {
        let sessionDescriptor = FetchDescriptor<ReadingSession>()
        let allSessions = try context.fetch(sessionDescriptor)

        // Group sessions by book
        var bookSessionsMap: [String: [ReadingSession]] = [:]
        for session in allSessions {
            guard let bookId = session.bookLocalId else { continue }
            bookSessionsMap[bookId, default: []].append(session)
        }

        for (bookId, sessions) in bookSessionsMap {
            // Get or create book stats
            let predicate = #Predicate<BookReadingStats> { stats in
                stats.bookLocalId == bookId
            }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            let stats: BookReadingStats
            if let existing = try context.fetch(descriptor).first {
                stats = existing
            } else {
                // Get book info
                let bookPredicate = #Predicate<BookModel> { book in
                    book.localId == bookId
                }
                var bookDescriptor = FetchDescriptor(predicate: bookPredicate)
                bookDescriptor.fetchLimit = 1

                guard let book = try context.fetch(bookDescriptor).first else { continue }
                stats = BookReadingStats(bookLocalId: bookId, title: book.title, author: book.author)
                context.insert(stats)
            }

            // Compute stats
            stats.totalReadingTime = sessions.reduce(0) { $0 + $1.duration }
            stats.sessionCount = sessions.count
            stats.firstStartedDate = sessions.min(by: { $0.startDate < $1.startDate })?.startDate
            stats.lastReadDate = sessions.max(by: { $0.startDate < $1.startDate })?.startDate

            // Count quotes and notes for this book
            let quotePredicate = #Predicate<CapturedQuote> { quote in
                quote.bookLocalId == bookId
            }
            let quoteDescriptor = FetchDescriptor(predicate: quotePredicate)
            stats.quotesCount = try context.fetchCount(quoteDescriptor)

            let notePredicate = #Predicate<CapturedNote> { note in
                note.bookLocalId == bookId
            }
            let noteDescriptor = FetchDescriptor(predicate: notePredicate)
            stats.notesCount = try context.fetchCount(noteDescriptor)
        }
    }

    /// Record that a reading session occurred (for streak tracking)
    func recordReadingActivity(context: ModelContext) {
        Task { @MainActor in
            do {
                let analytics = try await getOrCreateAnalytics(context: context)
                analytics.updateStreak(for: Date())
                try context.save()
            } catch {
                logger.error("Failed to record reading activity: \(error.localizedDescription)")
            }
        }
    }

    /// Get uncelebrated milestones
    func getUncelebratedMilestones(context: ModelContext) -> [ReadingMilestone] {
        do {
            let predicate = #Predicate<ReadingMilestone> { milestone in
                milestone.celebrated == false
            }
            let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.achievedDate, order: .reverse)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch uncelebrated milestones: \(error.localizedDescription)")
        }
        return []
    }

    /// Mark milestone as celebrated
    func celebrateMilestone(_ milestone: ReadingMilestone, context: ModelContext) {
        milestone.celebrated = true
        do {
            try context.save()
        } catch {
            logger.error("Failed to save milestone celebration: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct DayReadingData: Identifiable {
    let id = UUID()
    let date: Date
    let dayOfWeek: Int  // 1 = Sunday
    let totalMinutes: TimeInterval
    let sessionCount: Int

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var formattedTime: String {
        let hours = Int(totalMinutes) / 60
        let minutes = Int(totalMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
