import SwiftUI

// MARK: - Temporal Insights Card
struct TemporalInsightsCard: View {
    let sessions: [AmbientSession]
    
    private var insights: [TemporalInsight] {
        calculateTemporalInsights()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                Text("Temporal Patterns")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            
            // Insights
            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights) { insight in
                    HStack {
                        Image(systemName: insight.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(insight.color)
                            .frame(width: 20)
                        
                        Text(insight.text)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    private func calculateTemporalInsights() -> [TemporalInsight] {
        var insights: [TemporalInsight] = []
        
        // Reading velocity
        if sessions.count > 5 {
            let avgDuration = sessions.map(\.duration).reduce(0, +) / Double(sessions.count)
            let hours = Int(avgDuration) / 3600
            let minutes = Int(avgDuration) % 3600 / 60
            
            insights.append(TemporalInsight(
                icon: "gauge",
                text: "Average session: \(minutes)m",
                color: .blue
            ))
        }
        
        // Most active time
        let hourCounts = Dictionary(grouping: sessions) { session in
            Calendar.current.component(.hour, from: session.startTime)
        }
        if let mostActiveHour = hourCounts.max(by: { $0.value.count < $1.value.count }) {
            let timeString = formatHour(mostActiveHour.key)
            insights.append(TemporalInsight(
                icon: "sun.max",
                text: "Most active: \(timeString)",
                color: .orange
            ))
        }
        
        // Reading streak
        let streakDays = calculateReadingStreak()
        if streakDays > 0 {
            insights.append(TemporalInsight(
                icon: "flame",
                text: "\(streakDays) day streak",
                color: .red
            ))
        }
        
        // Year ago comparison
        if let yearAgoSession = findYearAgoSession() {
            let bookTitle = yearAgoSession.bookModel?.title ?? "a book"
            insights.append(TemporalInsight(
                icon: "calendar",
                text: "A year ago: \(bookTitle)",
                color: .purple
            ))
        }
        
        return insights
    }
    
    private func formatHour(_ hour: Int) -> String {
        switch hour {
        case 0...5: return "Late night"
        case 6...11: return "Morning"
        case 12...17: return "Afternoon"
        case 18...23: return "Evening"
        default: return "Unknown"
        }
    }
    
    private func calculateReadingStreak() -> Int {
        let calendar = Calendar.current
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        
        var streak = 0
        var currentDate = Date()
        
        for session in sortedSessions {
            let sessionDate = calendar.startOfDay(for: session.startTime)
            let checkDate = calendar.startOfDay(for: currentDate)
            
            if sessionDate == checkDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if sessionDate < checkDate {
                break
            }
        }
        
        return streak
    }
    
    private func findYearAgoSession() -> AmbientSession? {
        let calendar = Calendar.current
        let yearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let yearAgoStart = calendar.startOfDay(for: yearAgo)
        let yearAgoEnd = calendar.date(byAdding: .day, value: 1, to: yearAgoStart) ?? yearAgo
        
        return sessions.first { session in
            session.startTime >= yearAgoStart && session.startTime < yearAgoEnd
        }
    }
}

// MARK: - Character Companions Card
struct CharacterCompanionsCard: View {
    let companions: [CharacterCompanion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 16))
                Text("Reading Companions")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            
            // Character list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(companions.prefix(5)) { companion in
                    HStack {
                        // Character initial circle
                        Text(String(companion.name.prefix(1)))
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle()
                                    .fill(colorForCharacter(companion.name))
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(companion.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            
                            Text("Discussed in \(companion.sessions.count) sessions")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    private func colorForCharacter(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        let index = abs(name.hashValue) % colors.count
        return colors[index].opacity(0.7)
    }
}

// MARK: - Theme Connections Card
struct ThemeConnectionsCard: View {
    let sessions: [AmbientSession]
    
    private var themes: [(theme: String, count: Int)] {
        extractThemes()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 16))
                Text("Recurring Themes")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            
            // Theme tags
            FlowLayout(spacing: 8) {
                ForEach(themes.prefix(8), id: \.theme) { item in
                    ThemeTag(theme: item.theme, count: item.count)
                }
            }
        }
        .padding(20)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    private func extractThemes() -> [(theme: String, count: Int)] {
        var themeCounts: [String: Int] = [:]
        
        // Common literary themes to detect
        let themeKeywords = [
            "love": ["love", "romance", "heart", "passion"],
            "death": ["death", "mortality", "dying", "loss"],
            "power": ["power", "control", "authority", "dominance"],
            "identity": ["identity", "self", "who am I", "purpose"],
            "freedom": ["freedom", "liberty", "independence", "choice"],
            "time": ["time", "memory", "past", "future"],
            "nature": ["nature", "environment", "earth", "wilderness"],
            "family": ["family", "mother", "father", "children"]
        ]
        
        for session in sessions {
            let allContent = session.capturedQuestions.map(\.content).joined(separator: " ") +
                           session.capturedNotes.map(\.content).joined(separator: " ")
            
            let lowercased = allContent.lowercased()
            
            for (theme, keywords) in themeKeywords {
                if keywords.contains(where: { lowercased.contains($0) }) {
                    themeCounts[theme, default: 0] += 1
                }
            }
        }
        
        return themeCounts
            .map { (theme: $0.key.capitalized, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Theme Tag
struct ThemeTag: View {
    let theme: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text(theme)
                .font(.system(size: 12, weight: .medium))
            Text("×\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.white.opacity(0.1))
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(for: subviews, in: proposal.width ?? 0, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(for: subviews, in: bounds.width, spacing: spacing)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var height: CGFloat = 0
        
        init(for subviews: Subviews, in width: CGFloat, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > width && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            height = currentY + lineHeight
        }
    }
}

// MARK: - Supporting Types
struct TemporalInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
}