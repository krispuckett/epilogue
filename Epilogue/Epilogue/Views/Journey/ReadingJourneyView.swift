import SwiftUI
import SwiftData

// MARK: - Reading Journey View
/// A beautiful timeline view for the user's reading journey
/// Matches the What's New sheet design pattern with expandable sections
struct ReadingJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var manager = ReadingJourneyManager.shared
    @State private var hasAppeared = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Minimal gradient background (matching What's New)
                minimalGradientBackground

                if let journey = manager.currentJourney {
                    journeyContent(journey)
                } else {
                    CreateJourneyView()
                }
            }
            .navigationTitle("Your Reading Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if manager.currentJourney != nil {
                        Button(action: { showingDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }
            .alert("Delete Journey?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let journey = manager.currentJourney {
                        manager.deleteJourney(journey)
                    }
                }
            } message: {
                Text("This will delete your entire reading journey. You can always create a new one.")
            }
            .onAppear {
                if !hasAppeared {
                    manager.initialize(modelContext: modelContext)
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Background
    private var minimalGradientBackground: some View {
        ZStack {
            // Permanent ambient gradient background
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Subtle darkening overlay for better readability
            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Journey Content
    private func journeyContent(_ journey: ReadingJourney) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // Header with progress
                journeyHeader(journey)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Current book highlight
                if let currentBook = journey.currentBook {
                    currentBookCard(currentBook)
                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                        .padding(.bottom, 32)
                }

                // Timeline
                timelineSection(journey)
                    .padding(.bottom, 32)

                Spacer(minLength: 60)
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Journey Header
    private func journeyHeader(_ journey: ReadingJourney) -> some View {
        VStack(spacing: 12) {
            if let intent = journey.userIntent {
                Text(intent)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            }

            // Progress indicator
            ProgressIndicatorView(
                completed: journey.completedBooks.count,
                total: journey.orderedBooks.count,
                progress: journey.progress
            )
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }

    // MARK: - Current Book Card
    private func currentBookCard(_ journeyBook: JourneyBook) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("CURRENT")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()

                if let progress = journeyBook.bookModel?.currentPage,
                   let total = journeyBook.bookModel?.pageCount,
                   total > 0 {
                    Text("\(Int((Double(progress) / Double(total)) * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                }
            }

            if let book = journeyBook.bookModel {
                HStack(spacing: 16) {
                    // Book cover
                    AsyncImage(url: URL(string: book.coverImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(2)

                        Text(book.author)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))

                        if let reasoning = journeyBook.reasoning {
                            Text(reasoning)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.small))
    }

    // MARK: - Timeline Section
    private func timelineSection(_ journey: ReadingJourney) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("TIMELINE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

            VStack(spacing: 0) {
                ForEach(Array(journey.orderedBooks.enumerated()), id: \.element.id) { index, journeyBook in
                    TimelineBookRow(
                        journeyBook: journeyBook,
                        isFirst: index == 0,
                        isLast: index == journey.orderedBooks.count - 1
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }

}

// MARK: - Timeline Book Row
struct TimelineBookRow: View {
    let journeyBook: JourneyBook
    let isFirst: Bool
    let isLast: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 16) {
                // Timeline marker - extends through full content height
                ZStack(alignment: .top) {
                    // Continuous vertical line
                    VStack(spacing: 0) {
                        // Line above (if not first)
                        if !isFirst {
                            Rectangle()
                                .fill(journeyBook.isCompleted ? Color(red: 1.0, green: 0.549, blue: 0.259) : Color.white.opacity(0.2))
                                .frame(width: 2, height: 24)
                        } else {
                            Spacer()
                                .frame(height: 24)
                        }

                        // Line below extends to bottom
                        if !isLast {
                            Rectangle()
                                .fill(journeyBook.isCompleted ? Color(red: 1.0, green: 0.549, blue: 0.259) : Color.white.opacity(0.2))
                                .frame(width: 2)
                        }
                    }

                    // Marker circle positioned at top
                    VStack(spacing: 0) {
                        if !isFirst {
                            Spacer()
                                .frame(height: 12) // Half of line above to center marker
                        }

                        ZStack {
                            Circle()
                                .fill(journeyBook.isCompleted ? Color(red: 1.0, green: 0.549, blue: 0.259) : Color.white.opacity(0.1))
                                .frame(width: 24, height: 24)

                            if journeyBook.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if journeyBook.isCurrentlyReading {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 8, height: 8)
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    .frame(width: 12, height: 12)
                            }
                        }

                        Spacer()
                    }
                }
                .frame(width: 24)

                // Book info
                VStack(alignment: .leading, spacing: 8) {
                    if let book = journeyBook.bookModel {
                        HStack {
                            Text(book.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(journeyBook.isCompleted ? 0.6 : 0.9))

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        }

                        Text(book.author)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))

                        if journeyBook.isCompleted, let completedAt = journeyBook.completedAt {
                            Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.8))
                                .padding(.top, 4)
                        } else if let reasoning = journeyBook.reasoning {
                            Text(reasoning)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(isExpanded ? nil : 2)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(DesignSystem.Animation.easeQuick) {
                    isExpanded.toggle()
                }
            }
            .padding(.vertical, 16)

            // Expanded content - milestones
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)

                    if let milestones = journeyBook.milestones, !milestones.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Milestones")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1.2)
                                .padding(.leading, 40)

                            ForEach(journeyBook.orderedMilestones) { milestone in
                                MilestoneRow(milestone: milestone)
                                    .padding(.leading, 40)
                            }
                        }
                        .padding(.vertical, 12)
                    } else {
                        Text("No milestones yet")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.leading, 40)
                            .padding(.vertical, 12)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Milestone Row
struct MilestoneRow: View {
    let milestone: BookMilestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(milestone.isCompleted ? Color(red: 1.0, green: 0.549, blue: 0.259) : .white.opacity(0.4))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(milestone.isCompleted ? 0.6 : 0.85))

                if let description = milestone.milestoneDescription {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }

            Spacer()

            if milestone.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Progress Indicator
struct ProgressIndicatorView: View {
    let completed: Int
    let total: Int
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 1.0, green: 0.549, blue: 0.259))
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            // Text
            HStack {
                Text("\(completed) of \(total) books completed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ReadingJourneyView()
        .modelContainer(for: [ReadingJourney.self, JourneyBook.self])
}
