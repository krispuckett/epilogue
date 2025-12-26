import SwiftUI
import Charts
import SwiftData

struct YearInReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var analytics: ReadingAnalytics?
    @State private var monthlyData: [MonthReadingData] = []
    @State private var timeOfDayData: [TimeOfDayData] = []
    @State private var dayOfWeekData: [DayOfWeekData] = []
    @State private var milestones: [ReadingMilestone] = []

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Stats
                HeroStatsSection(analytics: analytics)

                // Monthly Trend Chart
                MonthlyTrendChart(data: monthlyData)

                // Reading Patterns
                ReadingPatternsSection(
                    timeOfDayData: timeOfDayData,
                    dayOfWeekData: dayOfWeekData,
                    preferredHour: analytics?.preferredReadingHour,
                    preferredDay: analytics?.preferredDayOfWeek
                )

                // Milestones Achieved
                if !milestones.isEmpty {
                    MilestonesSection(milestones: milestones)
                }

                // Engagement Stats
                EngagementSection(analytics: analytics)
            }
            .padding(.vertical)
        }
        .task {
            loadData()
        }
    }

    private func loadData() {
        // Load analytics
        do {
            let descriptor = FetchDescriptor<ReadingAnalytics>()
            analytics = try modelContext.fetch(descriptor).first
        } catch {
            analytics = nil
        }

        // Load monthly data
        loadMonthlyData()

        // Load time pattern data
        loadTimePatterns()

        // Load milestones
        loadMilestones()
    }

    private func loadMonthlyData() {
        let calendar = Calendar.current

        monthlyData = (1...12).compactMap { month -> MonthReadingData? in
            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = 1

            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return nil
            }

            // Only include months up to current
            if monthStart > Date() {
                return MonthReadingData(month: month, totalMinutes: 0, sessionCount: 0)
            }

            let readingTime = ReadingAnalyticsService.shared.getReadingTime(
                from: monthStart,
                to: monthEnd,
                context: modelContext
            )

            return MonthReadingData(
                month: month,
                totalMinutes: readingTime / 60,
                sessionCount: 0  // Could add session count if needed
            )
        }
    }

    private func loadTimePatterns() {
        guard let analytics = analytics else { return }

        // Time of day distribution
        let hourlyDist = analytics.getHourlyDistribution()
        var todData: [TimeOfDay: TimeInterval] = [:]

        for (hour, time) in hourlyDist {
            let tod: TimeOfDay
            switch hour {
            case 5..<12: tod = .morning
            case 12..<17: tod = .afternoon
            case 17..<21: tod = .evening
            default: tod = .night
            }
            todData[tod, default: 0] += time
        }

        timeOfDayData = TimeOfDay.allCases.map { tod in
            TimeOfDayData(timeOfDay: tod, totalMinutes: (todData[tod] ?? 0) / 60)
        }

        // Day of week distribution
        let dayDist = analytics.getDayOfWeekDistribution()
        dayOfWeekData = (1...7).map { day in
            DayOfWeekData(dayOfWeek: day, totalMinutes: (dayDist[day] ?? 0) / 60)
        }
    }

    private func loadMilestones() {
        do {
            let yearStart = Calendar.current.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
            let predicate = #Predicate<ReadingMilestone> { milestone in
                milestone.achievedDate >= yearStart
            }
            let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.achievedDate, order: .reverse)])
            milestones = try modelContext.fetch(descriptor)
        } catch {
            milestones = []
        }
    }
}

// MARK: - Hero Stats Section

struct HeroStatsSection: View {
    let analytics: ReadingAnalytics?

    var body: some View {
        VStack(spacing: 16) {
            Text("\(Calendar.current.component(.year, from: Date()))")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Year in Review")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                HeroStat(
                    value: formattedHours,
                    label: "Hours Read",
                    icon: "clock.fill"
                )

                HeroStat(
                    value: "\(analytics?.booksFinishedThisYear ?? 0)",
                    label: "Books Finished",
                    icon: "book.closed.fill"
                )

                HeroStat(
                    value: "\(analytics?.currentStreak ?? 0)",
                    label: "Current Streak",
                    icon: "flame.fill"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            ThemeManager.shared.currentTheme.primaryAccent.opacity(0.3),
                            ThemeManager.shared.currentTheme.primaryAccent.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(.horizontal)
    }

    private var formattedHours: String {
        let hours = Int((analytics?.totalReadingTimeThisYear ?? 0) / 3600)
        return "\(hours)"
    }
}

struct HeroStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Monthly Trend Chart

struct MonthlyTrendChart: View {
    let data: [MonthReadingData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Over Time")
                .font(.headline)
                .padding(.horizontal)

            Chart(data) { month in
                BarMark(
                    x: .value("Month", month.monthName),
                    y: .value("Minutes", month.totalMinutes)
                )
                .foregroundStyle(
                    month.isCurrentMonth
                        ? ThemeManager.shared.currentTheme.primaryAccent.gradient
                        : Color.gray.opacity(0.6).gradient
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(formatMinutes(minutes))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(Int(minutes))m"
    }
}

// MARK: - Reading Patterns Section

struct ReadingPatternsSection: View {
    let timeOfDayData: [TimeOfDayData]
    let dayOfWeekData: [DayOfWeekData]
    let preferredHour: Int?
    let preferredDay: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Reading Patterns")
                .font(.headline)
                .padding(.horizontal)

            // Preferred time insight
            if let hour = preferredHour {
                InsightCard(
                    icon: timeOfDayIcon(for: hour),
                    title: "Favorite Reading Time",
                    value: timeOfDayString(for: hour),
                    subtitle: "You read most during the \(timeOfDayName(for: hour).lowercased())"
                )
            }

            // Preferred day insight
            if let day = preferredDay {
                InsightCard(
                    icon: "calendar",
                    title: "Most Active Day",
                    value: dayName(for: day),
                    subtitle: "You love reading on \(dayName(for: day))s"
                )
            }

            // Time of day chart
            HStack(spacing: 8) {
                ForEach(timeOfDayData, id: \.timeOfDay) { data in
                    TimeOfDayBar(data: data, maxMinutes: maxTimeOfDay)
                }
            }
            .padding(.horizontal)

            // Day of week chart
            HStack(spacing: 4) {
                ForEach(dayOfWeekData, id: \.dayOfWeek) { data in
                    DayOfWeekBar(data: data, maxMinutes: maxDayOfWeek)
                }
            }
            .padding(.horizontal)
        }
    }

    private var maxTimeOfDay: Double {
        timeOfDayData.map { $0.totalMinutes }.max() ?? 1
    }

    private var maxDayOfWeek: Double {
        dayOfWeekData.map { $0.totalMinutes }.max() ?? 1
    }

    private func timeOfDayIcon(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "sun.horizon.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private func timeOfDayString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func timeOfDayName(for hour: Int) -> String {
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private func dayName(for day: Int) -> String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[day - 1]
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal)
    }
}

struct TimeOfDayBar: View {
    let data: TimeOfDayData
    let maxMinutes: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 80)

                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.shared.currentTheme.primaryAccent)
                    .frame(height: max(4, CGFloat(data.totalMinutes / maxMinutes) * 80))
            }

            Image(systemName: data.timeOfDay.icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatMinutes(data.totalMinutes))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(Int(minutes))m"
    }
}

struct DayOfWeekBar: View {
    let data: DayOfWeekData
    let maxMinutes: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 60)

                RoundedRectangle(cornerRadius: 3)
                    .fill(ThemeManager.shared.currentTheme.primaryAccent.opacity(0.8))
                    .frame(height: max(2, CGFloat(data.totalMinutes / maxMinutes) * 60))
            }

            Text(data.shortName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Milestones Section

struct MilestonesSection: View {
    let milestones: [ReadingMilestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(milestones, id: \.id) { milestone in
                        MilestoneCard(milestone: milestone)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MilestoneCard: View {
    let milestone: ReadingMilestone

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: milestone.milestoneType.icon)
                .font(.title)
                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)

            Text(milestone.milestoneType.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: milestone.achievedDate)
    }
}

// MARK: - Engagement Section

struct EngagementSection: View {
    let analytics: ReadingAnalytics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Engagement")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                EngagementCard(
                    title: "Quotes",
                    thisYear: analytics?.quotesThisYear ?? 0,
                    allTime: analytics?.totalQuotes ?? 0,
                    icon: "quote.bubble.fill",
                    color: .orange
                )

                EngagementCard(
                    title: "Notes",
                    thisYear: analytics?.notesThisYear ?? 0,
                    allTime: analytics?.totalNotes ?? 0,
                    icon: "note.text",
                    color: .purple
                )

                EngagementCard(
                    title: "Sessions",
                    thisYear: analytics?.sessionsThisYear ?? 0,
                    allTime: analytics?.totalSessions ?? 0,
                    icon: "book.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }
}

struct EngagementCard: View {
    let title: String
    let thisYear: Int
    let allTime: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text("\(thisYear)")
                .font(.title2)
                .fontWeight(.bold)

            Text("this year")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            Text("\(allTime) total")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Supporting Types

struct MonthReadingData: Identifiable {
    let id = UUID()
    let month: Int
    let totalMinutes: TimeInterval
    let sessionCount: Int

    var monthName: String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }

    var isCurrentMonth: Bool {
        month == Calendar.current.component(.month, from: Date())
    }
}

struct TimeOfDayData {
    let timeOfDay: TimeOfDay
    let totalMinutes: TimeInterval
}

struct DayOfWeekData {
    let dayOfWeek: Int  // 1 = Sunday
    let totalMinutes: TimeInterval

    var shortName: String {
        let formatter = DateFormatter()
        return String(formatter.shortWeekdaySymbols[dayOfWeek - 1].prefix(1))
    }
}

#Preview {
    YearInReviewView()
        .preferredColorScheme(.dark)
}
