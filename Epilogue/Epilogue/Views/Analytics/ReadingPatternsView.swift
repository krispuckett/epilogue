import SwiftUI
import SwiftData

/// Main container view for reading pattern analytics
struct ReadingPatternsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AnalyticsTab = .week
    @State private var analytics: ReadingAnalytics?
    @State private var showingMilestoneCelebration = false
    @State private var currentMilestone: ReadingMilestone?
    @StateObject private var analyticsService = ReadingAnalyticsService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AmbientChatGradientView()
                    .opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("View", selection: $selectedTab) {
                        ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Streak Banner
                            if let analytics = analytics, analytics.currentStreak > 0 {
                                StreakBanner(
                                    currentStreak: analytics.currentStreak,
                                    longestStreak: analytics.longestStreak
                                )
                            }

                            // Tab Content
                            switch selectedTab {
                            case .week:
                                WeeklyOverviewView()
                            case .month:
                                MonthlyInsightsView()
                            case .year:
                                YearInReviewView()
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Reading Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await analyticsService.refreshAnalytics()
                            loadAnalytics()
                        }
                    } label: {
                        if analyticsService.isUpdating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(analyticsService.isUpdating)
                }
            }
            .sheet(isPresented: $showingMilestoneCelebration) {
                if let milestone = currentMilestone {
                    MilestoneCelebrationView(milestone: milestone) {
                        analyticsService.celebrateMilestone(milestone, context: modelContext)
                        showingMilestoneCelebration = false
                        checkForMoreMilestones()
                    }
                }
            }
        }
        .task {
            // Configure service if needed
            ReadingAnalyticsService.shared.configure(with: modelContext)
            loadAnalytics()
            checkForUncelebratedMilestones()
        }
    }

    private func loadAnalytics() {
        do {
            let descriptor = FetchDescriptor<ReadingAnalytics>()
            analytics = try modelContext.fetch(descriptor).first
        } catch {
            analytics = nil
        }
    }

    private func checkForUncelebratedMilestones() {
        let uncelebrated = analyticsService.getUncelebratedMilestones(context: modelContext)
        if let milestone = uncelebrated.first {
            currentMilestone = milestone
            showingMilestoneCelebration = true
        }
    }

    private func checkForMoreMilestones() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkForUncelebratedMilestones()
        }
    }
}

// MARK: - Analytics Tab

enum AnalyticsTab: CaseIterable {
    case week
    case month
    case year

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Streak Banner

struct StreakBanner: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        HStack(spacing: 16) {
            // Flame icon with animation
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("day streak!")
                        .font(.title3)
                }

                if currentStreak < longestStreak {
                    Text("Best: \(longestStreak) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if currentStreak == longestStreak && currentStreak > 1 {
                    Text("This is your best streak!")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Next milestone
            VStack(alignment: .trailing, spacing: 2) {
                Text("Next goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(nextMilestone) days")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.15),
                            Color.red.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(.horizontal)
    }

    private var nextMilestone: Int {
        let milestones = [7, 14, 21, 30, 60, 90, 100, 180, 365]
        return milestones.first { $0 > currentStreak } ?? (currentStreak + 30)
    }
}

// MARK: - Milestone Celebration View

struct MilestoneCelebrationView: View {
    let milestone: ReadingMilestone
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(ThemeManager.shared.currentTheme.primaryAccent.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                        .scaleEffect(showContent ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showContent)

                    Circle()
                        .fill(ThemeManager.shared.currentTheme.primaryAccent.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: milestone.milestoneType.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                }
                .scaleEffect(showContent ? 1 : 0.3)
                .opacity(showContent ? 1 : 0)

                // Title
                Text("Achievement Unlocked!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)

                // Milestone name
                Text(milestone.milestoneType.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)

                // Celebration message
                Text(milestone.milestoneType.celebrationMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)

                Spacer()

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue Reading")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ThemeManager.shared.currentTheme.primaryAccent)
                        )
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReadingPatternsView()
        .preferredColorScheme(.dark)
}
