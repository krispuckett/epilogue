import SwiftUI
import SwiftData

// MARK: - Book Reading Plan Section
/// Compact reading plan display for BookDetailView
/// Shows active plans or prompts to create one

struct BookReadingPlanSection: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<ReadingHabitPlan> { $0.isActive == true }, sort: \ReadingHabitPlan.createdAt, order: .reverse)
    private var activeReadingPlans: [ReadingHabitPlan]

    @State private var showCreatePlanSheet = false
    @State private var showPlanDetailSheet = false
    @State private var createdPlan: ReadingHabitPlan? = nil

    private var activePlan: ReadingHabitPlan? {
        createdPlan ?? activeReadingPlans.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                    .frame(width: 28, height: 28)

                Text("Reading Plan")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if activePlan != nil {
                    Button {
                        showPlanDetailSheet = true
                    } label: {
                        Text("View")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                    }
                }
            }

            // Content
            if let plan = activePlan {
                activePlanCard(plan)
            } else {
                emptyPlanPrompt
            }
        }
        .sheet(isPresented: $showPlanDetailSheet) {
            if let plan = activePlan {
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
                                showPlanDetailSheet = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Pause Plan", systemImage: "pause.circle") {
                                    plan.pause()
                                    try? modelContext.save()
                                }
                                Divider()
                                Button("Delete Plan", systemImage: "trash", role: .destructive) {
                                    // Cancel notifications before deleting the plan
                                    Task {
                                        await ReadingPlanNotificationService.shared.cancelReminders(for: plan)
                                    }
                                    modelContext.delete(plan)
                                    try? modelContext.save()
                                    createdPlan = nil
                                    showPlanDetailSheet = false
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreatePlanSheet, onDismiss: {
            // Show timeline if a plan was just created
            if createdPlan != nil {
                showPlanDetailSheet = true
            }
        }) {
            CreateReadingPlanSheet(book: book) { plan in
                createdPlan = plan
            }
        }
    }

    // MARK: - Active Plan Card

    private func activePlanCard(_ plan: ReadingHabitPlan) -> some View {
        Button {
            showPlanDetailSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Title and streak
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)

                        Text(plan.statusMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    // Streak badge
                    if plan.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text("\(plan.currentStreak)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(in: .capsule)
                    }
                }

                // Week progress pills
                HStack(spacing: 6) {
                    ForEach(plan.orderedDays, id: \.id) { day in
                        CompactDayPill(day: day)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))

                        Capsule()
                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259))
                            .frame(width: geometry.size.width * plan.weekProgress)
                    }
                }
                .frame(height: 4)
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PlanSectionButtonStyle())
    }

    // MARK: - Empty State Prompt

    private var emptyPlanPrompt: some View {
        Button {
            showCreatePlanSheet = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a Reading Plan")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("Build a habit or set a challenge")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PlanSectionButtonStyle())
    }
}

// MARK: - Compact Day Pill

private struct CompactDayPill: View {
    let day: HabitDay

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 28, height: 28)

            if day.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else if day.isToday {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.549, blue: 0.259), lineWidth: 2)
                    .frame(width: 28, height: 28)
            } else if day.isPast {
                // Missed - subtle indication
            }
        }
    }

    private var backgroundColor: Color {
        switch day.status {
        case .completed:
            return Color(red: 1.0, green: 0.549, blue: 0.259)
        case .today:
            return Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.2)
        case .missed:
            return .white.opacity(0.08)
        case .upcoming:
            return .white.opacity(0.1)
        }
    }
}

// MARK: - Button Style

private struct PlanSectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Create Reading Plan Sheet

struct CreateReadingPlanSheet: View {
    let book: Book
    let onPlanCreated: (ReadingHabitPlan) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                AmbientChatGradientView()
                    .ignoresSafeArea()

                // Go directly to habit flow with preselected book
                ReadingPlanQuestionFlow(
                    flowType: .habit,
                    preselectedBook: book,
                    onComplete: { context in
                        createPlan(context: context)
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
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
            }
        }
    }

    // MARK: - Create Plan

    private func createPlan(context: ReadingPlanContext) {
        let days = context.durationDays
        let planBook = context.selectedBook ?? book

        // Use book title as the plan title
        let title = planBook.title
        let goal = "Build a sustainable reading habit that fits your schedule"

        let plan = ReadingHabitPlan(type: .habit, title: title, goal: goal)
        plan.preferredTime = context.timePreference
        plan.commitmentLevel = context.commitmentLevel
        plan.planDuration = context.planDuration

        // Associate the book
        plan.bookId = planBook.id
        plan.bookTitle = planBook.title
        plan.bookAuthor = planBook.author
        plan.bookCoverURL = planBook.coverImageURL

        // Set notification preferences from onboarding
        plan.notificationsEnabled = context.notificationsEnabled
        if context.notificationsEnabled {
            plan.notificationTime = context.notificationTime
        }

        plan.initializeDays(count: days)

        modelContext.insert(plan)

        do {
            try modelContext.save()
            SensoryFeedback.success()
            onPlanCreated(plan)
            dismiss()
        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan: \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview("With Active Plan") {
    let container = try! ModelContainer(for: ReadingHabitPlan.self, HabitDay.self)

    let plan = ReadingHabitPlan(type: .habit, title: "7-Day Reading Kickstart", goal: "Build a habit")
    plan.initializeWeek()
    plan.days?[0].isCompleted = true
    plan.days?[1].isCompleted = true
    plan.currentStreak = 2

    container.mainContext.insert(plan)

    let book = Book(
        id: "test123",
        title: "Test Book",
        author: "Test Author",
        isbn: "123"
    )

    return ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        BookReadingPlanSection(book: book)
            .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}

#Preview("Empty State") {
    let book = Book(
        id: "test456",
        title: "Test Book",
        author: "Test Author",
        isbn: "123"
    )

    return ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        BookReadingPlanSection(book: book)
            .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [ReadingHabitPlan.self, HabitDay.self])
}
