import SwiftUI
import SwiftData

// MARK: - Reading Plan Card
/// A beautiful, interactive card that displays the user's reading habit/challenge plan
/// Designed with Epilogue's liquid glass aesthetic and deep functionality

struct ReadingPlanCard: View {
    let plan: ReadingHabitPlan
    let onTap: () -> Void
    let onMarkComplete: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    private var accentColor: Color {
        plan.currentStreak > 0 ? DesignSystem.Colors.success : DesignSystem.Colors.primaryAccent
    }

    var body: some View {
        Button {
            SensoryFeedback.light()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Header with title and streak
                headerSection

                // Week progress visualization
                weekProgressSection
                    .padding(.top, 20)

                // Today's status or next action
                todaySection
                    .padding(.top, 16)

                // Ritual reminder (compact)
                if let trigger = plan.ritualTrigger {
                    ritualReminder(trigger)
                        .padding(.top, 12)
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(PlanCardButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Plan type badge
                HStack(spacing: 6) {
                    Image(systemName: plan.type.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(plan.type.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                }
                .foregroundStyle(accentColor)

                // Title
                Text(plan.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer()

            // Streak badge
            if plan.currentStreak > 0 {
                streakBadge
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Text("\(plan.currentStreak)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.orange.opacity(0.15))
        }
        .overlay {
            Capsule()
                .strokeBorder(.orange.opacity(0.3), lineWidth: 0.5)
        }
    }

    // MARK: - Week Progress Section

    private var weekProgressSection: some View {
        HStack(spacing: 8) {
            ForEach(plan.orderedDays, id: \.id) { day in
                DayProgressPill(day: day, isToday: day.isToday)
            }
        }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.statusMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))

                if let today = plan.todayDay, !today.isCompleted {
                    Text(todayProgressText(today))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Quick complete button for today
            if let today = plan.todayDay, !today.isCompleted {
                Button {
                    SensoryFeedback.success()
                    onMarkComplete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(accentColor)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func todayProgressText(_ day: HabitDay) -> String {
        if day.minutesRead > 0 {
            return "\(day.minutesRead) min read today"
        } else {
            return "Tap to log your reading"
        }
    }

    // MARK: - Ritual Reminder

    private func ritualReminder(_ trigger: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11))
                .foregroundStyle(.yellow.opacity(0.8))

            Text(trigger)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.05))
        }
    }
}

// MARK: - Day Progress Pill
/// Individual day indicator in the week view

struct DayProgressPill: View {
    let day: HabitDay
    let isToday: Bool

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 6) {
            // Day indicator circle
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)

                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1 : 0.5)
                        .opacity(isAnimating ? 1 : 0)
                } else if isToday {
                    // Pulsing ring for today
                    Circle()
                        .strokeBorder(DesignSystem.Colors.primaryAccent, lineWidth: 2)
                        .frame(width: 36, height: 36)
                        .scaleEffect(isAnimating ? 1.1 : 1)
                        .opacity(isAnimating ? 0.5 : 1)
                }
            }

            // Day label
            Text(day.shortDayLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? .white : .white.opacity(0.5))
        }
        .onAppear {
            if day.isCompleted || isToday {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(day.dayNumber) * 0.05)) {
                    isAnimating = true
                }
            }

            // Continuous pulse for today
            if isToday && !day.isCompleted {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }

    private var backgroundColor: Color {
        switch day.status {
        case .completed:
            return DesignSystem.Colors.success
        case .today:
            return DesignSystem.Colors.primaryAccent.opacity(0.3)
        case .missed:
            return .white.opacity(0.08)
        case .upcoming:
            return .white.opacity(0.1)
        }
    }
}

// MARK: - Button Style

private struct PlanCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Expanded Plan View
/// Full detail view when card is tapped

struct ReadingPlanDetailView: View {
    let plan: ReadingHabitPlan
    @Environment(\.dismiss) private var dismiss

    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero header
                heroHeader
                    .padding(.top, 20)

                // Week progress (larger)
                weekProgressLarge
                    .padding(.horizontal, 4)

                // Goal section
                goalSection

                // Daily ritual
                if plan.ritualWhen != nil || plan.ritualWhere != nil {
                    ritualSection
                }

                // Roadmap
                roadmapSection

                // Recommended book
                if plan.recommendedBookTitle != nil {
                    recommendedBookSection
                }

                // Pro tip
                if let tip = plan.proTip {
                    proTipSection(tip)
                }

                // Actions
                actionButtons
                    .padding(.top, 8)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
        .background {
            Color.black.ignoresSafeArea()
            AmbientChatGradientView().ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                        .glassEffect(in: Circle())
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Plan", systemImage: "pencil") { }
                    Button("Pause Plan", systemImage: "pause.circle") { }
                    Divider()
                    Button("Delete Plan", systemImage: "trash", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                        .glassEffect(in: Circle())
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 16) {
            // Streak ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: plan.weekProgress)
                    .stroke(
                        LinearGradient(
                            colors: [DesignSystem.Colors.success, DesignSystem.Colors.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    if plan.currentStreak > 0 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                        Text("\(plan.currentStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(plan.completedDays)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("of \(plan.totalDays)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // Title
            Text(plan.title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Status
            Text(plan.statusMessage)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week Progress Large

    private var weekProgressLarge: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: 10) {
                ForEach(plan.orderedDays, id: \.id) { day in
                    DayProgressPillLarge(day: day)
                }
            }
        }
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("The Goal", icon: "target")

            Text(plan.goal)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }

    // MARK: - Ritual Section

    private var ritualSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Your Daily Ritual", icon: "sunrise.fill")

            VStack(alignment: .leading, spacing: 12) {
                if let when = plan.ritualWhen {
                    ritualRow(label: "When", value: when, icon: "clock")
                }
                if let where_ = plan.ritualWhere {
                    ritualRow(label: "Where", value: where_, icon: "location")
                }
                if let duration = plan.ritualDuration {
                    ritualRow(label: "How long", value: duration, icon: "timer")
                }
                if let trigger = plan.ritualTrigger {
                    ritualRow(label: "Trigger", value: trigger, icon: "bolt")
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }

    private func ritualRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Roadmap Section

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Week 1 Roadmap", icon: "map")

            VStack(alignment: .leading, spacing: 0) {
                roadmapItem(days: "Day 1-2", description: "Start with just 5 pages, no pressure", completed: plan.currentDayNumber > 2)
                roadmapItem(days: "Day 3-4", description: "Increase to your target duration", completed: plan.currentDayNumber > 4)
                roadmapItem(days: "Day 5-7", description: "Establish the full routine", completed: plan.currentDayNumber > 7, isLast: true)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }

    private func roadmapItem(days: String, description: String, completed: Bool, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(completed ? DesignSystem.Colors.success : .white.opacity(0.2))
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(completed ? DesignSystem.Colors.success.opacity(0.5) : .white.opacity(0.1))
                        .frame(width: 2, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(days)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(completed ? DesignSystem.Colors.success : .white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    // MARK: - Recommended Book Section

    private var recommendedBookSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your First Book", icon: "book")

            HStack(spacing: 14) {
                // Book placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.recommendedBookTitle ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(plan.recommendedBookAuthor ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))

                    if let reason = plan.recommendedBookReason {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
    }

    // MARK: - Pro Tip Section

    private func proTipSection(_ tip: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)

                Text("Pro Tip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(tip)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(.yellow.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(.yellow.opacity(0.2), lineWidth: 0.5)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action
            Button {
                SensoryFeedback.medium()
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Start Reading Session")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignSystem.Colors.primaryAccent)
                }
            }

            // Secondary action
            Button {
                SensoryFeedback.light()
            } label: {
                HStack {
                    Image(systemName: "bell")
                    Text("Set Reminder")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.primaryAccent)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Day Progress Pill Large

struct DayProgressPillLarge: View {
    let day: HabitDay

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            // Day circle
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)

                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else if day.isToday {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Day label
            Text(day.dayLabel)
                .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                .foregroundStyle(day.isToday ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        switch day.status {
        case .completed:
            return DesignSystem.Colors.success
        case .today:
            return DesignSystem.Colors.primaryAccent
        case .missed:
            return .white.opacity(0.08)
        case .upcoming:
            return .white.opacity(0.1)
        }
    }
}

// MARK: - Preview

#Preview("Plan Card") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView().ignoresSafeArea()

        ReadingPlanCard(
            plan: {
                let plan = ReadingHabitPlan(
                    type: .habit,
                    title: "Your 7-Day Reading Kickstart",
                    goal: "Build a sustainable morning reading habit that fits your schedule."
                )
                plan.currentStreak = 3
                plan.ritualTrigger = "After I pour my morning coffee, I will read for 10 minutes"
                plan.initializeWeek()

                // Mark some days complete
                plan.days?[0].isCompleted = true
                plan.days?[1].isCompleted = true
                plan.days?[2].isCompleted = true

                return plan
            }(),
            onTap: {},
            onMarkComplete: {}
        )
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}

#Preview("Plan Detail") {
    NavigationStack {
        ReadingPlanDetailView(
            plan: {
                let plan = ReadingHabitPlan(
                    type: .habit,
                    title: "Your 7-Day Reading Kickstart",
                    goal: "Build a sustainable morning reading habit that fits your schedule and helps you focus, starting with just 10 minutes a day."
                )
                plan.currentStreak = 3
                plan.ritualWhen = "Right after you wake up, before checking your phone"
                plan.ritualWhere = "At your kitchen table or a cozy chair near a window"
                plan.ritualDuration = "10 minutes"
                plan.ritualTrigger = "After I pour my morning coffee, I will sit down and read for 10 minutes"
                plan.recommendedBookTitle = "Meditations"
                plan.recommendedBookAuthor = "Marcus Aurelius"
                plan.recommendedBookReason = "Perfect for morning reading—short, reflective passages"
                plan.proTip = "Use the Pomodoro technique—set a timer for 10 minutes, read without distractions, then take a 2-minute break."
                plan.initializeWeek()

                plan.days?[0].isCompleted = true
                plan.days?[1].isCompleted = true
                plan.days?[2].isCompleted = true

                return plan
            }()
        )
    }
    .preferredColorScheme(.dark)
}
