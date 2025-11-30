import SwiftUI
import SwiftData

// MARK: - Reading Plan Timeline View
/// Visual timeline display for reading habit plans with interactive milestones
/// Replaces chat-based output with actionable, connected UI

struct ReadingPlanTimelineView: View {
    @Bindable var plan: ReadingHabitPlan
    @Environment(\.modelContext) private var modelContext

    @State private var showingRitualSection = true
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with plan info
            planHeader

            ScrollView {
                VStack(spacing: 24) {
                    // Week calendar consistency view
                    weekCalendarView
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Daily timeline with checkboxes
                    dailyTimeline
                        .padding(.horizontal, 20)

                    // Ritual reminder card
                    if plan.ritualWhen != nil || plan.ritualWhere != nil {
                        ritualCard
                            .padding(.horizontal, 20)
                    }

                    // Pro tip
                    if let tip = plan.proTip {
                        proTipCard(tip)
                            .padding(.horizontal, 20)
                    }

                    // Book recommendation
                    if let bookTitle = plan.recommendedBookTitle {
                        bookRecommendationCard(title: bookTitle)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Plan Header
    private var planHeader: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 12) {
                // Show mini book cover if available, otherwise show type icon
                if let coverURLString = plan.bookCoverURL,
                   let coverURL = URL(string: coverURLString) {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 28, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        case .failure:
                            // Fallback to icon on failure
                            Image(systemName: plan.type.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        case .empty:
                            // Loading placeholder
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 28, height: 42)
                        @unknown default:
                            Image(systemName: plan.type.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        }
                    }
                } else {
                    Image(systemName: plan.type.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                }

                Text(plan.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Streak badge
                if plan.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(plan.currentStreak)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(in: .capsule)
                }
            }

            // Goal
            if !plan.goal.isEmpty {
                Text(plan.goal)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }

            // Progress bar
            progressBar
        }
        .padding(20)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.549, blue: 0.259),
                                    Color(red: 1.0, green: 0.449, blue: 0.159)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animateProgress ? geometry.size.width * plan.weekProgress : 0)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(plan.completedDays) of \(plan.totalDays) days")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Text("\(Int(plan.weekProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
            }
        }
    }

    // MARK: - Week Calendar View (Wabi-inspired)
    private var weekCalendarView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)

                Spacer()

                Text(plan.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Calendar row
            HStack(spacing: 8) {
                ForEach(plan.orderedDays) { day in
                    CalendarDayCell(
                        day: day,
                        onTap: {
                            toggleDayCompletion(day)
                        }
                    )
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Daily Timeline
    private var dailyTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DAILY PROGRESS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            VStack(spacing: 0) {
                ForEach(Array(plan.orderedDays.enumerated()), id: \.element.id) { index, day in
                    TimelineDayRow(
                        day: day,
                        isFirst: index == 0,
                        isLast: index == plan.orderedDays.count - 1,
                        targetMinutes: parseTargetMinutes(),
                        onToggle: {
                            toggleDayCompletion(day)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Ritual Card
    private var ritualCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("YOUR RITUAL")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)

                Spacer()

                Button {
                    withAnimation(DesignSystem.Animation.easeQuick) {
                        showingRitualSection.toggle()
                    }
                } label: {
                    Image(systemName: showingRitualSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if showingRitualSection {
                VStack(alignment: .leading, spacing: 12) {
                    if let when = plan.ritualWhen {
                        ritualRow(icon: "clock.fill", label: "When", value: when)
                    }

                    if let where_ = plan.ritualWhere {
                        ritualRow(icon: "location.fill", label: "Where", value: where_)
                    }

                    if let duration = plan.ritualDuration {
                        ritualRow(icon: "timer", label: "Duration", value: duration)
                    }

                    if let trigger = plan.ritualTrigger {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                                .frame(width: 24)

                            Text(trigger)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.85))
                                .italic()
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private func ritualRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Pro Tip Card
    private func proTipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 1.0, green: 0.749, blue: 0.259))

            VStack(alignment: .leading, spacing: 4) {
                Text("PRO TIP")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.2)

                Text(tip)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Book Recommendation Card
    private func bookRecommendationCard(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED FIRST READ")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            HStack(spacing: 16) {
                // Book icon placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    if let author = plan.recommendedBookAuthor {
                        Text(author)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if let reason = plan.recommendedBookReason {
                        Text(reason)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    // MARK: - Actions

    private func toggleDayCompletion(_ day: HabitDay) {
        SensoryFeedback.selection()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if day.isCompleted {
                // Uncomplete
                day.isCompleted = false
                day.completedAt = nil
                day.manualEntry = false
            } else {
                // Complete
                day.isCompleted = true
                day.completedAt = Date()
                day.manualEntry = true
            }

            plan.updatedAt = Date()
            updateStreak()

            try? modelContext.save()
        }
    }

    private func updateStreak() {
        let calendar = Calendar.current
        var streak = 0
        let today = calendar.startOfDay(for: Date())

        for day in plan.orderedDays.reversed() {
            let dayDate = calendar.startOfDay(for: day.date)

            if dayDate > today { continue }

            if day.isCompleted {
                streak += 1
            } else if dayDate < today {
                break
            }
        }

        plan.currentStreak = streak
        plan.longestStreak = max(plan.longestStreak, streak)
    }

    private func parseTargetMinutes() -> Int {
        guard let commitment = plan.commitmentLevel else { return 15 }

        if commitment.contains("15") { return 15 }
        if commitment.contains("30") { return 30 }
        if commitment.contains("1 hour") || commitment.contains("60") { return 60 }
        if commitment.contains("hours/week") { return 30 }

        return 15
    }
}

// MARK: - Calendar Day Cell (Wabi-inspired)

private struct CalendarDayCell: View {
    let day: HabitDay
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Day label
                Text(day.shortDayLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                // Checkbox circle
                ZStack {
                    Circle()
                        .fill(day.isCompleted ? Color(red: 1.0, green: 0.549, blue: 0.259) : Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)

                    if day.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else if day.isToday {
                        Circle()
                            .stroke(Color(red: 1.0, green: 0.549, blue: 0.259), lineWidth: 2)
                            .frame(width: 36, height: 36)
                    } else if day.isPast {
                        // Missed day - subtle X
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                // Date number
                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: 12, weight: day.isToday ? .semibold : .regular))
                    .foregroundStyle(day.isToday ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(CalendarCellButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Timeline Day Row

private struct TimelineDayRow: View {
    let day: HabitDay
    let isFirst: Bool
    let isLast: Bool
    let targetMinutes: Int
    let onToggle: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.549, blue: 0.259)
    private let circleSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline marker with continuous line
            VStack(spacing: 0) {
                // Top connector line (connects from previous row)
                if !isFirst {
                    Rectangle()
                        .fill(lineColor(for: day))
                        .frame(width: 2, height: 12)
                }

                // Checkbox circle
                Button(action: onToggle) {
                    ZStack {
                        // Base circle
                        Circle()
                            .fill(day.isCompleted ? accentColor : Color.clear)
                            .frame(width: circleSize, height: circleSize)

                        // Stroke for incomplete days
                        if !day.isCompleted {
                            Circle()
                                .stroke(
                                    day.isToday ? accentColor : Color.white.opacity(0.25),
                                    lineWidth: day.isToday ? 2.5 : 1.5
                                )
                                .frame(width: circleSize, height: circleSize)
                        }

                        // Checkmark for completed
                        if day.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(TimelineCheckboxStyle())

                // Bottom connector line (connects to next row)
                if !isLast {
                    Rectangle()
                        .fill(lineColor(for: day))
                        .frame(width: 2, height: 36)
                }
            }
            .frame(width: circleSize)

            // Day info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(day.dayLabel)
                        .font(.system(size: 16, weight: day.isToday ? .semibold : .medium))
                        .foregroundStyle(day.isToday ? .white : .white.opacity(0.85))

                    if day.isToday {
                        Text("•")
                            .foregroundStyle(accentColor)

                        Text("Day \(day.dayNumber)")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                    }

                    Spacer()

                    // Minutes read
                    if day.minutesRead > 0 {
                        Text("\(day.minutesRead) min")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(day.isCompleted ? accentColor : .white.opacity(0.6))
                    } else if !day.isFuture {
                        Text("\(targetMinutes) min goal")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Status text
                if day.isCompleted, let completedAt = day.completedAt {
                    Text("Completed \(completedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                } else if day.isToday && !day.isCompleted {
                    Text("Tap to mark complete")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.top, 6)
        }
    }

    private func lineColor(for day: HabitDay) -> Color {
        day.isCompleted ? accentColor : Color.white.opacity(0.15)
    }
}

private struct TimelineCheckboxStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: ReadingHabitPlan.self, HabitDay.self)

    // Create sample plan
    let plan = ReadingHabitPlan(type: .habit, title: "7-Day Reading Kickstart", goal: "Build a sustainable morning reading habit that becomes automatic")
    plan.commitmentLevel = "15 min/day"
    plan.ritualWhen = "Right after you wake up"
    plan.ritualWhere = "At your kitchen table"
    plan.ritualDuration = "10 minutes"
    plan.ritualTrigger = "After I pour my morning coffee, I will read for 10 minutes..."
    plan.proTip = "Keep your book visible! Leave it on your pillow or by your coffee maker."
    plan.recommendedBookTitle = "The House in the Cerulean Sea"
    plan.recommendedBookAuthor = "TJ Klune"
    plan.recommendedBookReason = "Cozy, heartwarming, and perfect for building momentum"
    plan.initializeWeek()

    // Mark some days as complete
    if let days = plan.days {
        days[0].isCompleted = true
        days[0].minutesRead = 22
        days[1].isCompleted = true
        days[1].minutesRead = 18
    }
    plan.currentStreak = 2

    container.mainContext.insert(plan)

    return ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        ReadingPlanTimelineView(plan: plan)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
