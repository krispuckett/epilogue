import SwiftUI

// MARK: - Reading Plan Question Flow

/// Interactive question flow for building personalized reading habits/challenges
/// Uses liquid glass pills matching Epilogue's design language
struct ReadingPlanQuestionFlow: View {
    let flowType: FlowType
    let preselectedBook: Book?
    let availableBooks: [Book]
    let onComplete: (ReadingPlanContext) -> Void
    let onDismiss: () -> Void

    enum FlowType {
        case habit      // "Help me build a reading habit"
        case challenge  // "Create a reading challenge"
    }

    init(flowType: FlowType, preselectedBook: Book? = nil, availableBooks: [Book] = [], onComplete: @escaping (ReadingPlanContext) -> Void, onDismiss: @escaping () -> Void) {
        self.flowType = flowType
        self.preselectedBook = preselectedBook
        self.availableBooks = availableBooks
        self.onComplete = onComplete
        self.onDismiss = onDismiss
    }

    @State private var currentQuestionIndex = 0
    @State private var answers: [String] = []
    @State private var selectedBook: Book?
    @State private var isVisible = false
    @State private var questionVisible = false
    @State private var showingBookPicker = false
    @State private var showingCustomDuration = false
    @State private var customDurationDays: Int = 60

    // Base questions (before notification)
    private var baseQuestions: [QuestionData] {
        switch flowType {
        case .habit:
            return [
                QuestionData(
                    question: "How long should your plan last?",
                    options: ["7 days", "14 days", "21 days", "30+ days"]
                ),
                QuestionData(
                    question: "How much time can you dedicate?",
                    options: ["15 min/day", "30 min/day", "1 hour/day", "Flexible"]
                ),
                QuestionData(
                    question: "When do you usually have time?",
                    options: ["Morning", "Lunch break", "Evening", "Weekends"]
                ),
                QuestionData(
                    question: "How often should I remind you?",
                    options: ["Daily", "Every few days", "Weekly", "No reminders"]
                )
            ]
        case .challenge:
            // If book is already selected, skip the "what kind of challenge" question
            // since we know they want to finish that specific book
            if preselectedBook != nil || selectedBook != nil {
                return [
                    QuestionData(
                        question: "How ambitious are you feeling?",
                        options: ["Gentle start", "Moderate push", "Ambitious goal", "All in"]
                    ),
                    QuestionData(
                        question: "What's your timeframe?",
                        options: ["This month", "This quarter", "This year", "No deadline"]
                    ),
                    QuestionData(
                        question: "How often should I remind you?",
                        options: ["Daily", "Every few days", "Weekly", "No reminders"]
                    )
                ]
            } else {
                return [
                    QuestionData(
                        question: "What kind of challenge excites you?",
                        options: ["Read more books", "Explore new genres", "Finish my TBR", "Read the classics"]
                    ),
                    QuestionData(
                        question: "How ambitious are you feeling?",
                        options: ["Gentle start", "Moderate push", "Ambitious goal", "All in"]
                    ),
                    QuestionData(
                        question: "What's your timeframe?",
                        options: ["This month", "This quarter", "This year", "No deadline"]
                    ),
                    QuestionData(
                        question: "How often should I remind you?",
                        options: ["Daily", "Every few days", "Weekly", "No reminders"]
                    )
                ]
            }
        }
    }

    // Notification time question (shown if user wants reminders)
    private var notificationTimeQuestion: QuestionData {
        QuestionData(
            question: "What time works best?",
            options: ["Morning (8am)", "Midday (12pm)", "Afternoon (5pm)", "Evening (8pm)"]
        )
    }

    // Dynamic questions list that includes notification time if needed
    private var questions: [QuestionData] {
        var qs = baseQuestions
        // If user selected reminders (answers[3] exists and is not "No reminders"), add time question
        if answers.count > 3 && answers[3] != "No reminders" {
            qs.append(notificationTimeQuestion)
        }
        return qs
    }

    // Check if we're on the notification frequency question
    private var isOnNotificationFrequencyQuestion: Bool {
        currentQuestionIndex == 3
    }

    // Total steps: book selection (if no preselected) + questions
    private var totalSteps: Int {
        let bookStep = (preselectedBook == nil && !availableBooks.isEmpty) ? 1 : 0
        return bookStep + questions.count
    }

    private var currentStep: Int {
        let bookStep = (preselectedBook == nil && !availableBooks.isEmpty) ? 1 : 0
        return bookStep + currentQuestionIndex
    }

    private var isOnBookSelection: Bool {
        preselectedBook == nil && !availableBooks.isEmpty && selectedBook == nil && currentQuestionIndex == 0
    }

    var body: some View {
        Group {
            if isOnBookSelection {
                // Book selection - full screen layout
                VStack(spacing: 0) {
                    bookSelectionView
                        .opacity(questionVisible ? 1 : 0)
                        .offset(y: questionVisible ? 0 : 15)

                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            Circle()
                                .fill(index < currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .scaleEffect(index == currentStep ? 1.3 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                        }
                    }
                    .padding(.bottom, 8)

                    // Skip button
                    Button {
                        skipToResult()
                    } label: {
                        Text("Skip to plan")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.bottom, 100) // Clear input bar
                }
            } else if showingCustomDuration {
                // Custom duration picker
                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 24) {
                        Text("How many days?")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .opacity(questionVisible ? 1 : 0)
                            .offset(y: questionVisible ? 0 : -10)

                        // Duration stepper
                        HStack(spacing: 20) {
                            Button {
                                if customDurationDays > 30 {
                                    customDurationDays -= 7
                                    SensoryFeedback.light()
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .glassEffect(.regular, in: .circle)
                            }

                            Text("\(customDurationDays)")
                                .font(.system(size: 48, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 100)

                            Button {
                                if customDurationDays < 365 {
                                    customDurationDays += 7
                                    SensoryFeedback.light()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .glassEffect(.regular, in: .circle)
                            }
                        }
                        .opacity(questionVisible ? 1 : 0)
                        .offset(y: questionVisible ? 0 : 15)

                        Text("days")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        // Confirm button
                        Button {
                            selectCustomDuration()
                        } label: {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 150, height: 48)
                                .glassEffect(.regular, in: .capsule)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 100) // Clear input bar
                    }
                }
                .padding(.horizontal, 24)
            } else if currentQuestionIndex < questions.count {
                // Question step - centered layout
                VStack(spacing: 24) {
                    Spacer()

                    let question = questions[currentQuestionIndex]

                    VStack(spacing: 24) {
                        // Question
                        Text(question.question)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .opacity(questionVisible ? 1 : 0)
                            .offset(y: questionVisible ? 0 : -10)

                        // Options as 2x2 centered grid
                        let rows = question.options.chunked(into: 2)
                        VStack(spacing: 10) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                                HStack(spacing: 10) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, option in
                                        let overallIndex = rowIndex * 2 + colIndex
                                        PlanOptionPill(
                                            text: option,
                                            delay: Double(overallIndex) * 0.06
                                        ) {
                                            selectOption(option)
                                        }
                                    }
                                }
                            }
                        }
                        .opacity(questionVisible ? 1 : 0)
                        .offset(y: questionVisible ? 0 : 15)
                    }
                    .id(currentQuestionIndex)

                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { index in
                            Circle()
                                .fill(index < currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .scaleEffect(index == currentStep ? 1.3 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                        }
                    }
                    .padding(.top, 20)

                    // Skip button
                    Button {
                        skipToResult()
                    } label: {
                        Text("Skip to plan")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Clear input bar
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // If preselected book, use it
            if let book = preselectedBook {
                selectedBook = book
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                questionVisible = true
            }
        }
    }

    // MARK: - Book Selection View

    private var bookSelectionView: some View {
        VStack(spacing: 0) {
            Text("Which book will you read?")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)

            // Scrollable book list
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    ForEach(availableBooks, id: \.id) { book in
                        PlanBookSelectionRow(book: book) {
                            selectBook(book)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            // "Any book" option at bottom - positioned above input bar
            Button {
                selectBook(nil)
            } label: {
                Text("I'll decide later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 16)
            .padding(.bottom, 80) // Space for input bar
        }
    }

    private func selectBook(_ book: Book?) {
        SensoryFeedback.selection()
        selectedBook = book

        // Animate transition to questions
        withAnimation(.easeOut(duration: 0.15)) {
            questionVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                questionVisible = true
            }
        }
    }

    private func selectOption(_ option: String) {
        SensoryFeedback.selection()

        // Handle custom duration selection
        if option == "30+ days" {
            withAnimation(.easeOut(duration: 0.15)) {
                questionVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingCustomDuration = true
                    questionVisible = true
                }
            }
            return
        }

        answers.append(option)

        // Animate out current question
        withAnimation(.easeOut(duration: 0.15)) {
            questionVisible = false
        }

        // Move to next question or complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    questionVisible = true
                }
            } else {
                completeFlow()
            }
        }
    }

    private func selectCustomDuration() {
        SensoryFeedback.selection()
        answers.append("\(customDurationDays) days")
        showingCustomDuration = false

        // Animate out and move to next question
        withAnimation(.easeOut(duration: 0.15)) {
            questionVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentQuestionIndex < questions.count - 1 {
                currentQuestionIndex += 1
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    questionVisible = true
                }
            } else {
                completeFlow()
            }
        }
    }

    private func skipToResult() {
        SensoryFeedback.light()
        completeFlow()
    }

    private func completeFlow() {
        // Notification time is at index 4 only if user chose reminders
        let notificationTime: String? = answers.indices.contains(4) ? answers[4] : nil

        let context = ReadingPlanContext(
            flowType: flowType,
            planDuration: answers.indices.contains(0) ? answers[0] : nil,
            commitmentLevel: answers.indices.contains(1) ? answers[1] : nil,
            timePreference: answers.indices.contains(2) ? answers[2] : nil,
            notificationFrequency: answers.indices.contains(3) ? answers[3] : nil,
            notificationTimePreference: notificationTime,
            selectedBook: selectedBook ?? preselectedBook
        )
        onComplete(context)
    }
}

// MARK: - Plan Book Selection Row

private struct PlanBookSelectionRow: View {
    let book: Book
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            guard !isPressed else { return }
            isPressed = true
            action()
        } label: {
            HStack(spacing: 14) {
                // Book cover
                if let coverURL = book.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 75)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        case .failure, .empty:
                            bookPlaceholder
                        @unknown default:
                            bookPlaceholder
                        }
                    }
                } else {
                    bookPlaceholder
                }

                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)

                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Selection indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
        .buttonStyle(PlanBookRowButtonStyle(isPressed: isPressed))
    }

    private var bookPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.white.opacity(0.1))
            .frame(width: 50, height: 75)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }
}

private struct PlanBookRowButtonStyle: ButtonStyle {
    let isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Question Data

private struct QuestionData {
    let question: String
    let options: [String]
}

// MARK: - Reading Plan Context

struct ReadingPlanContext {
    let flowType: ReadingPlanQuestionFlow.FlowType
    let planDuration: String?            // "7 days", "14 days", etc.
    let commitmentLevel: String?         // "15 min/day", "30 min/day", etc.
    let timePreference: String?          // "Morning", "Evening", etc.
    let notificationFrequency: String?   // "Daily", "Every few days", "Weekly", "No reminders"
    let notificationTimePreference: String? // "Morning (8am)", "Midday (12pm)", etc.
    let selectedBook: Book?              // The book to read with this plan

    // Legacy alias for challenge flow
    var challengeOrBlocker: String? { timePreference }

    /// Whether notifications should be enabled based on user preference
    var notificationsEnabled: Bool {
        guard let freq = notificationFrequency else { return false }
        return freq != "No reminders"
    }

    /// Notification interval in days (nil if no reminders)
    var notificationIntervalDays: Int? {
        guard let freq = notificationFrequency else { return nil }
        switch freq {
        case "Daily": return 1
        case "Every few days": return 3
        case "Weekly": return 7
        default: return nil
        }
    }

    /// Notification time as a Date (hour component only)
    var notificationTime: Date? {
        guard notificationsEnabled else { return nil }
        guard let timePref = notificationTimePreference else {
            // Default to 9 AM if no preference specified
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
        }

        let hour: Int
        switch timePref {
        case "Morning (8am)": hour = 8
        case "Midday (12pm)": hour = 12
        case "Afternoon (5pm)": hour = 17
        case "Evening (8pm)": hour = 20
        default: hour = 9
        }

        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
    }

    var isEmpty: Bool {
        planDuration == nil && commitmentLevel == nil && timePreference == nil
    }

    var durationDays: Int {
        guard let duration = planDuration else { return 7 }
        // Extract number from string like "60 days" or "14 days"
        let digits = duration.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let days = Int(digits), days > 0 {
            return days
        }
        return 7
    }

    /// Builds a descriptive string for the AI prompt
    func buildPromptContext() -> String {
        switch flowType {
        case .habit:
            return buildHabitPrompt()
        case .challenge:
            return buildChallengePrompt()
        }
    }

    private func buildHabitPrompt() -> String {
        var parts: [String] = ["Help me build a sustainable reading habit."]

        if let duration = planDuration {
            parts.append("I want a \(duration.lowercased()) plan.")
        }

        if let commitment = commitmentLevel {
            parts.append("I can commit to \(commitment.lowercased()).")
        }

        if let time = timePreference {
            parts.append("I usually have time to read in the \(time.lowercased()).")
        }

        parts.append("Give me a specific, actionable plan with concrete steps I can start today.")

        return parts.joined(separator: " ")
    }

    private func buildChallengePrompt() -> String {
        var parts: [String] = ["Create a personalized reading challenge for me."]

        if let challenge = timePreference { // First question for challenge is "type"
            switch challenge {
            case "Read more books": parts.append("I want to increase the number of books I read.")
            case "Explore new genres": parts.append("I want to branch out and try new genres.")
            case "Finish my TBR": parts.append("I want to finally tackle my to-be-read pile.")
            case "Read the classics": parts.append("I want to read more classic literature.")
            default: break
            }
        }

        if let ambition = commitmentLevel {
            switch ambition {
            case "Gentle start": parts.append("Start me with an achievable goal.")
            case "Moderate push": parts.append("Challenge me but keep it realistic.")
            case "Ambitious goal": parts.append("I want something that pushes me.")
            case "All in": parts.append("Give me the biggest challenge you've got.")
            default: break
            }
        }

        if let timeframe = challengeOrBlocker {
            switch timeframe {
            case "This month": parts.append("Timeframe: this month.")
            case "This quarter": parts.append("Timeframe: the next 3 months.")
            case "This year": parts.append("Timeframe: this year.")
            case "No deadline": parts.append("Open-ended, no specific deadline.")
            default: break
            }
        }

        parts.append("Give me specific book count goals, milestones, and accountability tips.")

        return parts.joined(separator: " ")
    }
}

// MARK: - Plan Option Pill

private struct PlanOptionPill: View {
    let text: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false
    @State private var isPressed = false

    var body: some View {
        Button {
            guard !isPressed else { return }
            isPressed = true
            SensoryFeedback.selection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        } label: {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 150, height: 48)
                .contentShape(Capsule())
                .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(PlanPillButtonStyle(isPressed: isPressed))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// Custom button style for reliable press feedback
private struct PlanPillButtonStyle: ButtonStyle {
    let isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Habit Flow") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        ReadingPlanQuestionFlow(
            flowType: .habit,
            onComplete: { context in
                print("Context: \(context.buildPromptContext())")
            },
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Challenge Flow") {
    ZStack {
        Color.black.ignoresSafeArea()
        AmbientChatGradientView()
            .ignoresSafeArea()

        ReadingPlanQuestionFlow(
            flowType: .challenge,
            onComplete: { context in
                print("Context: \(context.buildPromptContext())")
            },
            onDismiss: {}
        )
    }
    .preferredColorScheme(.dark)
}

// MARK: - Array Extension for Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
