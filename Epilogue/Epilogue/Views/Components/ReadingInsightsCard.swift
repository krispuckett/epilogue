import SwiftUI

// MARK: - Reading Insights Card
/// Displays thematic insights from the knowledge graph on the home/ambient view.
/// Shows patterns, connections, and discoveries across the user's reading.

struct ReadingInsightsCard: View {
    @StateObject private var insightGenerator = ThematicInsightGenerator.shared
    @State private var currentInsightIndex = 0
    @State private var isExpanded = false

    var body: some View {
        Group {
            if !insightGenerator.latestInsights.isEmpty {
                insightCardContent
            }
        }
        .task {
            // Generate insights if we don't have any
            if insightGenerator.latestInsights.isEmpty {
                try? await insightGenerator.generateInsights()
            }
        }
    }

    @ViewBuilder
    private var insightCardContent: some View {
        let insights = insightGenerator.latestInsights
        let safeIndex = min(currentInsightIndex, insights.count - 1)
        let currentInsight = insights[max(0, safeIndex)]

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: currentInsight.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(currentInsight.title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.2)

                Spacer()

                // Page indicator if multiple insights
                if insights.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<insights.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentInsightIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }

            // Insight body
            Text(currentInsight.body)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Related books pills
            if !currentInsight.relatedBooks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(currentInsight.relatedBooks.prefix(3), id: \.self) { bookTitle in
                            Text(bookTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.15))
                                )
                        }
                    }
                }
            }

            // Theme tags
            if !currentInsight.relatedThemes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(currentInsight.relatedThemes.prefix(3), id: \.self) { theme in
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 9))
                            Text(theme)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.white.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            // Cycle through insights
            if insights.count > 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentInsightIndex = (currentInsightIndex + 1) % insights.count
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if insights.count > 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if value.translation.width < 0 {
                                // Swipe left - next
                                currentInsightIndex = (currentInsightIndex + 1) % insights.count
                            } else {
                                // Swipe right - previous
                                currentInsightIndex = (currentInsightIndex - 1 + insights.count) % insights.count
                            }
                        }
                    }
                }
        )
    }
}

// MARK: - Compact Insights Row
/// A more compact horizontal row of insight pills for tighter spaces

struct CompactInsightsRow: View {
    @StateObject private var insightGenerator = ThematicInsightGenerator.shared
    var onInsightTap: ((ThematicInsight) -> Void)?

    var body: some View {
        Group {
            if !insightGenerator.latestInsights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(insightGenerator.latestInsights.prefix(3)) { insight in
                            CompactInsightPill(insight: insight)
                                .onTapGesture {
                                    onInsightTap?(insight)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .task {
            if insightGenerator.latestInsights.isEmpty {
                try? await insightGenerator.generateInsights()
            }
        }
    }
}

struct CompactInsightPill: View {
    let insight: ThematicInsight

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: insight.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text(insight.body.prefix(50) + (insight.body.count > 50 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(Color.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue, .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            ReadingInsightsCard()
                .padding(.horizontal, 16)

            CompactInsightsRow()
        }
    }
}
