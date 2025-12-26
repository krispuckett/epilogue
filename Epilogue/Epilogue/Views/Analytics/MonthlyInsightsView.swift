import SwiftUI
import Charts
import SwiftData

struct MonthlyInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMonth: Date = Date()
    @State private var dailySummaries: [DailyReadingSummary] = []
    @State private var topBooks: [BookReadingStats] = []
    @State private var monthlyStats = MonthlyStats()

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Month Selector
            MonthSelector(selectedMonth: $selectedMonth)
                .onChange(of: selectedMonth) { _, _ in
                    loadData()
                }

            // Calendar Heat Map
            CalendarHeatMapView(
                month: selectedMonth,
                dailySummaries: dailySummaries
            )

            // Key Stats Cards
            KeyStatsRow(stats: monthlyStats)

            // Top Books This Month
            if !topBooks.isEmpty {
                TopBooksSection(books: topBooks)
            }
        }
        .padding(.vertical)
        .task {
            loadData()
        }
    }

    private func loadData() {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return
        }

        // Load daily summaries
        dailySummaries = ReadingAnalyticsService.shared.getDailySummaries(
            from: monthStart,
            to: monthEnd,
            context: modelContext
        )

        // Compute monthly stats
        monthlyStats = MonthlyStats(
            totalReadingTime: dailySummaries.reduce(0) { $0 + $1.totalReadingTime },
            totalSessions: dailySummaries.reduce(0) { $0 + $1.sessionCount },
            totalQuotes: dailySummaries.reduce(0) { $0 + $1.quotesCount },
            totalNotes: dailySummaries.reduce(0) { $0 + $1.notesCount },
            daysActive: dailySummaries.filter { $0.hasActivity }.count,
            totalDays: daysInMonth
        )

        // Load top books (from BookReadingStats)
        loadTopBooks()
    }

    private var daysInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)
        return range?.count ?? 30
    }

    private func loadTopBooks() {
        do {
            let descriptor = FetchDescriptor<BookReadingStats>(
                sortBy: [SortDescriptor(\.totalReadingTime, order: .reverse)]
            )
            let allStats = try modelContext.fetch(descriptor)

            // Filter to books read this month (using lastReadDate)
            let components = calendar.dateComponents([.year, .month], from: selectedMonth)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return
            }

            topBooks = allStats.filter { stats in
                guard let lastRead = stats.lastReadDate else { return false }
                return lastRead >= monthStart && lastRead < monthEnd
            }.prefix(3).map { $0 }
        } catch {
            topBooks = []
        }
    }
}

// MARK: - Month Selector

struct MonthSelector: View {
    @Binding var selectedMonth: Date
    private let calendar = Calendar.current

    var body: some View {
        HStack {
            Button {
                if let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                    selectedMonth = previous
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth),
                   next <= Date() {
                    selectedMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(canGoNext ? .secondary : .quaternary)
            }
            .disabled(!canGoNext)
        }
        .padding(.horizontal)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var canGoNext: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        return next <= Date()
    }
}

// MARK: - Calendar Heat Map

struct CalendarHeatMapView: View {
    let month: Date
    let dailySummaries: [DailyReadingSummary]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(daysInMonth, id: \.self) { day in
                    DayCell(
                        day: day,
                        intensity: intensityForDay(day),
                        isToday: isToday(day)
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private var daysInMonth: [Int] {
        let range = calendar.range(of: .day, in: .month, for: month)
        return Array((range?.lowerBound ?? 1)..<(range?.upperBound ?? 31))
    }

    private func intensityForDay(_ day: Int) -> Double {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard var dateComponents = calendar.date(from: components).map({ calendar.dateComponents([.year, .month], from: $0) }) else {
            return 0
        }
        dateComponents.day = day
        guard let date = calendar.date(from: dateComponents) else { return 0 }

        let dayStart = calendar.startOfDay(for: date)

        if let summary = dailySummaries.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            // Normalize to 0-1 based on reading time (0-60 minutes = 0-1)
            return min(1.0, summary.totalReadingTime / 3600)
        }
        return 0
    }

    private func isToday(_ day: Int) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: month)
        var dateComponents = components
        dateComponents.day = day
        guard let date = calendar.date(from: dateComponents) else { return false }
        return calendar.isDateInToday(date)
    }
}

struct DayCell: View {
    let day: Int
    let intensity: Double
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellColor)

            if isToday {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ThemeManager.shared.currentTheme.primaryAccent, lineWidth: 2)
            }

            Text("\(day)")
                .font(.caption2)
                .foregroundStyle(intensity > 0.5 ? .white : .primary)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var cellColor: Color {
        if intensity == 0 {
            return Color.gray.opacity(0.1)
        }
        return ThemeManager.shared.currentTheme.primaryAccent.opacity(0.2 + (intensity * 0.8))
    }
}

// MARK: - Key Stats Row

struct KeyStatsRow: View {
    let stats: MonthlyStats

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MonthlyStatCard(
                    title: "Reading Time",
                    value: stats.formattedReadingTime,
                    icon: "clock.fill",
                    color: .blue
                )

                MonthlyStatCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "book.fill",
                    color: .green
                )

                MonthlyStatCard(
                    title: "Quotes",
                    value: "\(stats.totalQuotes)",
                    icon: "quote.bubble.fill",
                    color: .orange
                )

                MonthlyStatCard(
                    title: "Notes",
                    value: "\(stats.totalNotes)",
                    icon: "note.text",
                    color: .purple
                )

                MonthlyStatCard(
                    title: "Days Active",
                    value: "\(stats.daysActive)/\(stats.totalDays)",
                    icon: "flame.fill",
                    color: .red
                )
            }
            .padding(.horizontal)
        }
    }
}

struct MonthlyStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Top Books Section

struct TopBooksSection: View {
    let books: [BookReadingStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Books This Month")
                .font(.headline)
                .padding(.horizontal)

            ForEach(books, id: \.id) { book in
                TopBookRow(book: book)
            }
        }
    }
}

struct TopBookRow: View {
    let book: BookReadingStats

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder for book cover
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.bookTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(book.bookAuthor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(book.sessionCount) sessions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var formattedTime: String {
        let hours = Int(book.totalReadingTime) / 3600
        let minutes = (Int(book.totalReadingTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Types

struct MonthlyStats {
    var totalReadingTime: TimeInterval = 0
    var totalSessions: Int = 0
    var totalQuotes: Int = 0
    var totalNotes: Int = 0
    var daysActive: Int = 0
    var totalDays: Int = 30

    var formattedReadingTime: String {
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    MonthlyInsightsView()
        .preferredColorScheme(.dark)
}
