import SwiftUI
import SwiftData

// MARK: - Reading Plans Hub View
/// Central hub for all reading plans and challenges with a beautiful calendar view

struct ReadingPlansHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ReadingHabitPlan.createdAt, order: .reverse)
    private var allPlans: [ReadingHabitPlan]

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingCreatePlan = false
    @State private var selectedPlan: ReadingHabitPlan?

    private var activePlans: [ReadingHabitPlan] {
        allPlans.filter { $0.isActive && !$0.isPaused }
    }

    private var completedPlans: [ReadingHabitPlan] {
        allPlans.filter { !$0.isActive || $0.completedAt != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AmbientChatGradientView()
                    .opacity(0.5)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Calendar section
                        calendarSection
                            .padding(.top, 8)

                        // Plan count summary
                        if !allPlans.isEmpty {
                            Text("Plans: \(allPlans.count) total, \(activePlans.count) active")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        // Active plans
                        if !activePlans.isEmpty {
                            activePlansSection
                        }

                        // Completed plans
                        if !completedPlans.isEmpty {
                            completedPlansSection
                        }

                        // Empty state
                        if allPlans.isEmpty {
                            emptyState
                                .padding(.top, 40)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Reading Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreatePlanFromHubSheet { plan in
                    // Set selected plan after a brief delay to allow sheet to dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedPlan = plan
                    }
                }
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailSheet(plan: plan, onDismiss: {
                    selectedPlan = nil
                })
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(monthYearString(currentMonth))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 8)

            // Calendar grid
            CalendarGridView(
                currentMonth: currentMonth,
                selectedDate: $selectedDate,
                completedDates: completedDatesSet,
                plannedDates: plannedDatesSet,
                todayDate: Date()
            )
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var completedDatesSet: Set<Date> {
        var dates = Set<Date>()
        let calendar = Calendar.current

        for plan in allPlans {
            for day in plan.orderedDays where day.isCompleted {
                let normalized = calendar.startOfDay(for: day.date)
                dates.insert(normalized)
            }
        }
        return dates
    }

    private var plannedDatesSet: Set<Date> {
        var dates = Set<Date>()
        let calendar = Calendar.current

        for plan in activePlans {
            for day in plan.orderedDays where !day.isCompleted {
                let normalized = calendar.startOfDay(for: day.date)
                dates.insert(normalized)
            }
        }
        return dates
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Active Plans Section

    private var activePlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Plans")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            ForEach(activePlans) { plan in
                PlanHubCard(plan: plan) {
                    selectedPlan = plan
                }
            }
        }
    }

    // MARK: - Completed Plans Section

    private var completedPlansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 4)

            ForEach(completedPlans) { plan in
                PlanHubCard(plan: plan, isCompleted: true) {
                    selectedPlan = plan
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No Reading Plans Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Create a habit or challenge to track your reading goals")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button {
                showingCreatePlan = true
            } label: {
                Text("Create Your First Plan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .glassEffect(in: .capsule)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }

}

// MARK: - Calendar Grid View

private struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let completedDates: Set<Date>
    let plannedDates: Set<Date>
    let todayDate: Date

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            // Days grid
            let days = daysInMonth()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    CalendarDayCell(
                        date: day,
                        isCurrentMonth: isCurrentMonth(day),
                        isToday: isToday(day),
                        isSelected: isSelected(day),
                        isCompleted: isCompleted(day),
                        isPlanned: isPlanned(day)
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedDate = day
                        }
                    }
                }
            }
        }
    }

    private func daysInMonth() -> [Date] {
        var days: [Date] = []

        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthStart = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return days
        }

        // Get first day of month and its weekday
        let firstWeekday = calendar.component(.weekday, from: monthStart)

        // Add days from previous month to fill first week
        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 1, to: 0, by: -1) {
                if let day = calendar.date(byAdding: .day, value: -i, to: monthStart) {
                    days.append(day)
                }
            }
        }

        // Add days of current month
        var currentDate = monthStart
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Add days from next month to complete last week
        while days.count % 7 != 0 {
            if let day = calendar.date(byAdding: .day, value: 1, to: days.last ?? currentDate) {
                days.append(day)
            }
        }

        return days
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isCompleted(_ date: Date) -> Bool {
        let normalized = calendar.startOfDay(for: date)
        return completedDates.contains(normalized)
    }

    private func isPlanned(_ date: Date) -> Bool {
        let normalized = calendar.startOfDay(for: date)
        return plannedDates.contains(normalized)
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isCompleted: Bool
    let isPlanned: Bool
    let action: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.549, blue: 0.259)

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                if isCompleted {
                    Circle()
                        .fill(accentColor)
                } else if isToday {
                    Circle()
                        .stroke(accentColor, lineWidth: 2)
                } else if isPlanned {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                } else if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                }

                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday || isCompleted ? .semibold : .regular))
                    .foregroundStyle(dayTextColor)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dayTextColor: Color {
        if isCompleted {
            return .white
        } else if !isCurrentMonth {
            return .white.opacity(0.2)
        } else if isToday {
            return accentColor
        } else {
            return .white.opacity(0.8)
        }
    }
}

// MARK: - Plan Hub Card

private struct PlanHubCard: View {
    let plan: ReadingHabitPlan
    var isCompleted: Bool = false
    let action: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.549, blue: 0.259)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Book cover or progress circle
                if let coverURL = plan.bookCoverURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            progressCircle
                        @unknown default:
                            progressCircle
                        }
                    }
                    .frame(width: 44, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    progressCircle
                }

                // Plan info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    if let bookTitle = plan.bookTitle {
                        Text(bookTitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Text(plan.statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                // Streak badge (for active plans)
                if !isCompleted && plan.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("\(plan.currentStreak)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(accentColor)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
        .buttonStyle(PlanHubCardButtonStyle())
    }

    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)

            Circle()
                .trim(from: 0, to: plan.weekProgress)
                .stroke(
                    isCompleted ? Color.green : accentColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(plan.completedDays)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct PlanHubCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Create Plan From Hub Sheet

private struct CreatePlanFromHubSheet: View {
    let onPlanCreated: (ReadingHabitPlan) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BookModel.dateAdded, order: .reverse)
    private var allBooks: [BookModel]

    @State private var selectedFlowType: ReadingPlanQuestionFlow.FlowType?
    @State private var isReady = false

    private var availableBooks: [Book] {
        // Deduplicate by book ID (keep first occurrence, usually most recently added)
        var seenIds = Set<String>()
        return allBooks
            .filter { $0.isInLibrary } // Only books actually in library
            .filter { $0.readingStatus == ReadingStatus.currentlyReading.rawValue || $0.readingStatus == ReadingStatus.wantToRead.rawValue }
            .filter { book in
                if seenIds.contains(book.id) {
                    return false
                }
                seenIds.insert(book.id)
                return true
            }
            .map { $0.toBook() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AmbientChatGradientView()
                    .ignoresSafeArea()

                if isReady {
                    if let flowType = selectedFlowType {
                        ReadingPlanQuestionFlow(
                            flowType: flowType,
                            availableBooks: availableBooks,
                            onComplete: { context in
                                createPlan(context: context)
                            },
                            onDismiss: {
                                dismiss()
                            }
                        )
                    } else {
                        planTypeSelection
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if selectedFlowType != nil {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFlowType = nil
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: selectedFlowType != nil ? "chevron.left" : "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .onAppear {
                // Small delay to ensure view is fully presented before showing content
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isReady = true
                    }
                }
            }
        }
    }

    // MARK: - Plan Type Selection

    private var planTypeSelection: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What would you like to create?")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PlanTypeCard(
                    icon: "calendar.badge.clock",
                    title: "Reading Habit",
                    subtitle: "Build a daily reading routine"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFlowType = .habit
                    }
                }

                PlanTypeCard(
                    icon: "flag.fill",
                    title: "Reading Challenge",
                    subtitle: "Set an ambitious goal"
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFlowType = .challenge
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
    }

    private func createPlan(context: ReadingPlanContext) {
        let days = context.durationDays
        let planType: PlanType = context.flowType == .habit ? .habit : .challenge

        // Use book title if selected, otherwise generic title
        let title: String
        if let book = context.selectedBook {
            title = book.title
        } else {
            title = context.flowType == .habit ? "\(days)-Day Reading Kickstart" : "Reading Challenge"
        }

        let goal = context.flowType == .habit
            ? "Build a sustainable reading habit"
            : "Push your reading limits"

        #if DEBUG
        print("📋 [Hub] Creating reading plan: '\(title)' (type: \(planType))")
        #endif

        let plan = ReadingHabitPlan(type: planType, title: title, goal: goal)
        plan.preferredTime = context.timePreference
        plan.commitmentLevel = context.commitmentLevel
        plan.planDuration = context.planDuration

        // Associate book if selected
        if let book = context.selectedBook {
            plan.bookId = book.id
            plan.bookTitle = book.title
            plan.bookAuthor = book.author
            plan.bookCoverURL = book.coverImageURL
        }

        // Set notification preferences from onboarding
        plan.notificationsEnabled = context.notificationsEnabled
        if context.notificationsEnabled {
            plan.notificationTime = context.notificationTime
        }

        plan.initializeDays(count: days)

        #if DEBUG
        print("📋 [Hub] Plan configured - isActive: \(plan.isActive), days: \(plan.days?.count ?? 0)")
        #endif

        modelContext.insert(plan)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ [Hub] Reading plan saved successfully: \(plan.title) (id: \(plan.id))")
            #endif
            SensoryFeedback.success()
            onPlanCreated(plan)
            dismiss()
        } catch {
            #if DEBUG
            print("❌ [Hub] Failed to save reading plan: \(error)")
            print("❌ [Hub] Error details: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Plan Type Card

private struct PlanTypeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.549, blue: 0.259)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PlanTypeCardButtonStyle())
    }
}

private struct PlanTypeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Plan Detail Sheet

private struct PlanDetailSheet: View {
    @Bindable var plan: ReadingHabitPlan
    var onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AmbientChatGradientView()
                    .ignoresSafeArea()

                ReadingPlanTimelineView(plan: plan)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    planOptionsMenu
                }
            }
        }
    }

    private var planOptionsMenu: some View {
        Menu {
            if plan.isPaused {
                Button("Resume Plan", systemImage: "play.circle") {
                    plan.resume()
                    try? modelContext.save()
                }
            } else {
                Button("Pause Plan", systemImage: "pause.circle") {
                    plan.pause()
                    try? modelContext.save()
                }
            }

            Divider()

            Button("Delete Plan", systemImage: "trash", role: .destructive) {
                Task {
                    // Cancel notifications before deleting the plan
                    await ReadingPlanNotificationService.shared.cancelReminders(for: plan)
                    modelContext.delete(plan)
                    try? modelContext.save()
                    onDismiss()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Preview

#Preview("With Plans") {
    let container = try! ModelContainer(for: ReadingHabitPlan.self, HabitDay.self)

    let plan1 = ReadingHabitPlan(type: .habit, title: "7-Day Reading Kickstart", goal: "Build a habit")
    plan1.initializeDays(count: 7)
    plan1.days?[0].isCompleted = true
    plan1.days?[1].isCompleted = true
    plan1.days?[2].isCompleted = true
    plan1.currentStreak = 3

    let plan2 = ReadingHabitPlan(type: .habit, title: "14-Day Challenge", goal: "Read more")
    plan2.initializeDays(count: 14)
    plan2.isActive = false
    plan2.completedAt = Date()

    container.mainContext.insert(plan1)
    container.mainContext.insert(plan2)

    return ReadingPlansHubView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}

#Preview("Empty State") {
    ReadingPlansHubView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [ReadingHabitPlan.self, HabitDay.self])
}
