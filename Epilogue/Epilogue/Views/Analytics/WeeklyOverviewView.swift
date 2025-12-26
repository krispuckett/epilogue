import SwiftUI
import Charts
import SwiftData

struct WeeklyOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var weeklyData: [DayReadingData] = []
    @State private var lastWeekTotal: TimeInterval = 0
    @State private var thisWeekTotal: TimeInterval = 0
    @State private var selectedDay: DayReadingData?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(formattedThisWeekTotal)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                }

                Spacer()

                // Comparison with last week
                if lastWeekTotal > 0 {
                    ComparisonPill(
                        thisWeek: thisWeekTotal,
                        lastWeek: lastWeekTotal
                    )
                }
            }
            .padding(.horizontal)

            // Bar Chart
            if weeklyData.isEmpty {
                EmptyWeekView()
            } else {
                Chart(weeklyData) { day in
                    BarMark(
                        x: .value("Day", day.shortDayName),
                        y: .value("Minutes", day.totalMinutes)
                    )
                    .foregroundStyle(
                        day.isToday
                            ? ThemeManager.shared.currentTheme.primaryAccent.gradient
                            : Color.gray.opacity(0.6).gradient
                    )
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        if day.totalMinutes > 0 {
                            Text(day.formattedTime)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel()
                            .font(.caption)
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
                .chartYScale(domain: 0...(maxReadingTime + 10))
                .frame(height: 180)
                .padding(.horizontal)
            }

            // Quick Stats Row
            HStack(spacing: 16) {
                QuickStatCard(
                    title: "Avg/Day",
                    value: formattedAveragePerDay,
                    icon: "chart.bar.fill"
                )

                QuickStatCard(
                    title: "Sessions",
                    value: "\(totalSessions)",
                    icon: "book.fill"
                )

                QuickStatCard(
                    title: "Best Day",
                    value: bestDayName,
                    icon: "star.fill"
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .task {
            loadData()
        }
    }

    // MARK: - Computed Properties

    private var maxReadingTime: Double {
        weeklyData.map { $0.totalMinutes }.max() ?? 60
    }

    private var formattedThisWeekTotal: String {
        formatDuration(thisWeekTotal * 60)  // Convert minutes to seconds
    }

    private var formattedAveragePerDay: String {
        guard !weeklyData.isEmpty else { return "0m" }
        let avg = thisWeekTotal / Double(weeklyData.count)
        return formatMinutes(avg)
    }

    private var totalSessions: Int {
        weeklyData.reduce(0) { $0 + $1.sessionCount }
    }

    private var bestDayName: String {
        guard let best = weeklyData.max(by: { $0.totalMinutes < $1.totalMinutes }),
              best.totalMinutes > 0 else {
            return "-"
        }
        return best.dayName
    }

    // MARK: - Data Loading

    private func loadData() {
        weeklyData = ReadingAnalyticsService.shared.getWeeklyReadingData(context: modelContext)
        thisWeekTotal = weeklyData.reduce(0) { $0 + $1.totalMinutes }

        // Calculate last week's total
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: today),
              let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: lastWeekEnd) else {
            return
        }

        lastWeekTotal = ReadingAnalyticsService.shared.getReadingTime(
            from: lastWeekStart,
            to: lastWeekEnd,
            context: modelContext
        ) / 60  // Convert to minutes
    }

    // MARK: - Formatting Helpers

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Views

struct ComparisonPill: View {
    let thisWeek: TimeInterval
    let lastWeek: TimeInterval

    private var percentageChange: Double {
        guard lastWeek > 0 else { return 0 }
        return ((thisWeek - lastWeek) / lastWeek) * 100
    }

    private var isPositive: Bool {
        percentageChange >= 0
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)

            Text("\(abs(Int(percentageChange)))%")
                .font(.caption)
                .fontWeight(.medium)

            Text("vs last week")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPositive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
        )
        .foregroundStyle(isPositive ? .green : .orange)
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

struct EmptyWeekView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No reading activity this week")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Start a reading session to see your progress")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WeeklyOverviewView()
        .preferredColorScheme(.dark)
}
