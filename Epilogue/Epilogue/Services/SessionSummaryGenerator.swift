import Foundation
import SwiftUI
import SwiftData
import NaturalLanguage
import Combine

// MARK: - Session Summary Generator
@MainActor
class SessionSummaryGenerator: ObservableObject {
    static let shared = SessionSummaryGenerator()
    
    @Published var currentSummary: SessionSummary?
    @Published var isGenerating = false
    
    // MARK: - Types
    
    struct SessionSummary {
        let id = UUID()
        let generatedAt: Date
        let session: OptimizedAmbientSession
        let clusters: [ContentCluster]
        let insights: [SessionInsight]
        let suggestions: [ActionableSuggestion]
        let keyTakeaways: [String]
        let readingStats: ReadingStatistics
        let emotionalArc: [EmotionalMoment]
    }
    
    struct ContentCluster: Identifiable {
        let id = UUID()
        let theme: String
        let themeEmoji: String
        let quotes: [CapturedQuote]
        let notes: [CapturedNote]
        let questions: [SessionContent]
        let dominantEmotion: String
        let significance: Float // 0-1 importance score
        
        var itemCount: Int {
            quotes.count + notes.count + questions.count
        }
    }
    
    struct SessionInsight: Identifiable {
        let id = UUID()
        let type: InsightType
        let title: String
        let description: String
        let icon: String
        let color: Color
        let relatedContent: [Any] // Can be quotes, notes, or questions
        
        enum InsightType {
            case interest      // "You were particularly interested in..."
            case pattern      // "You tend to highlight passages about..."
            case emotion      // "This passage moved you..."
            case discovery    // "You discovered connections between..."
            case growth       // "Your understanding evolved..."
        }
    }
    
    struct ActionableSuggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let title: String
        let description: String
        let actionText: String
        let icon: String
        let color: Color
        let metadata: [String: Any]
        
        enum SuggestionType {
            case exploreMore     // Dive deeper into topic
            case relatedBooks    // Book recommendations
            case discussion      // Book club questions
            case reflection      // Journal prompts
            case research        // External resources
            case nextChapter     // What to look for next
        }
    }
    
    struct ReadingStatistics {
        let duration: TimeInterval
        let quotesCount: Int
        let notesCount: Int
        let questionsCount: Int
        let wordsPerMinute: Int
        let engagementScore: Float // 0-1
        let focusScore: Float // 0-1 based on consistency
    }
    
    struct EmotionalMoment {
        let timestamp: Date
        let emotion: String
        let intensity: Float
        let trigger: String? // What caused this emotion
    }
    
    // MARK: - Generation
    
    func generateSummary(for session: OptimizedAmbientSession) async -> SessionSummary {
        isGenerating = true
        defer { isGenerating = false }
        
        // Extract all content
        let quotes = extractQuotes(from: session)
        let notes = extractNotes(from: session)
        let questions = extractQuestions(from: session)
        
        // Cluster content by themes
        let clusters = await clusterContent(quotes: quotes, notes: notes, questions: questions)
        
        // Generate insights
        let insights = generateInsights(from: clusters, session: session)
        
        // Create suggestions
        let suggestions = generateSuggestions(from: clusters, insights: insights, session: session)
        
        // Extract key takeaways
        let takeaways = extractKeyTakeaways(from: clusters, insights: insights)
        
        // Calculate statistics
        let stats = calculateStatistics(for: session)
        
        // Analyze emotional journey
        let emotionalArc = analyzeEmotionalArc(session: session)
        
        let summary = SessionSummary(
            generatedAt: Date(),
            session: session,
            clusters: clusters,
            insights: insights,
            suggestions: suggestions,
            keyTakeaways: takeaways,
            readingStats: stats,
            emotionalArc: emotionalArc
        )
        
        currentSummary = summary
        return summary
    }
    
    // MARK: - Content Clustering
    
    private func clusterContent(quotes: [CapturedQuote], notes: [CapturedNote], questions: [SessionContent]) async -> [ContentCluster] {
        // Use NLP to find themes
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        var themeMap: [String: (quotes: [CapturedQuote], notes: [CapturedNote], questions: [SessionContent])] = [:]
        
        // Process quotes
        for quote in quotes {
            let themes = extractThemes(from: quote.text, using: tagger)
            for theme in themes {
                if themeMap[theme] == nil {
                    themeMap[theme] = ([], [], [])
                }
                themeMap[theme]?.quotes.append(quote)
            }
        }
        
        // Process notes
        for note in notes {
            let themes = extractThemes(from: note.content, using: tagger)
            for theme in themes {
                if themeMap[theme] == nil {
                    themeMap[theme] = ([], [], [])
                }
                themeMap[theme]?.notes.append(note)
            }
        }
        
        // Process questions
        for question in questions where question.type == .question {
            let themes = extractThemes(from: question.text, using: tagger)
            for theme in themes {
                if themeMap[theme] == nil {
                    themeMap[theme] = ([], [], [])
                }
                themeMap[theme]?.questions.append(question)
            }
        }
        
        // Convert to clusters with significance scoring
        var clusters: [ContentCluster] = []
        for (theme, content) in themeMap {
            let significance = calculateSignificance(
                quotesCount: content.quotes.count,
                notesCount: content.notes.count,
                questionsCount: content.questions.count
            )
            
            let cluster = ContentCluster(
                theme: theme.capitalized,
                themeEmoji: getEmojiForTheme(theme),
                quotes: content.quotes,
                notes: content.notes,
                questions: content.questions,
                dominantEmotion: detectDominantEmotion(from: content),
                significance: significance
            )
            
            clusters.append(cluster)
        }
        
        // Sort by significance
        return clusters.sorted { $0.significance > $1.significance }
    }
    
    private func extractThemes(from text: String, using tagger: NLTagger) -> [String] {
        tagger.string = text
        var themes: [String] = []
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, tag == .noun || tag == .verb {
                let word = String(text[range]).lowercased()
                // Filter out common words
                if !isCommonWord(word) && word.count > 3 {
                    themes.append(word)
                }
            }
            return true
        }
        
        // Group related themes
        return consolidateThemes(themes).prefix(3).map { $0 }
    }
    
    private func consolidateThemes(_ themes: [String]) -> [String] {
        // Group similar themes together
        var consolidated: [String] = []
        var processed = Set<String>()
        
        for theme in themes {
            if !processed.contains(theme) {
                consolidated.append(theme)
                processed.insert(theme)
            }
        }
        
        return consolidated
    }
    
    private func isCommonWord(_ word: String) -> Bool {
        let commonWords = ["have", "that", "this", "with", "from", "been", "were", "what", "when", "where", "will", "would", "could", "should", "about", "which", "their", "there", "these", "those"]
        return commonWords.contains(word)
    }
    
    private func getEmojiForTheme(_ theme: String) -> String {
        let themeEmojis: [String: String] = [
            "love": "❤️",
            "time": "⏰",
            "life": "🌱",
            "death": "🕊️",
            "nature": "🌿",
            "war": "⚔️",
            "peace": "☮️",
            "family": "👨‍👩‍👧‍👦",
            "friendship": "🤝",
            "journey": "🗺️",
            "discovery": "🔍",
            "wisdom": "🦉",
            "knowledge": "📚",
            "emotion": "💭",
            "memory": "💫",
            "dream": "💤",
            "hope": "🌟",
            "fear": "😰",
            "courage": "🦁",
            "change": "🔄"
        ]
        
        let lowercased = theme.lowercased()
        return themeEmojis[lowercased] ?? "📝"
    }
    
    // MARK: - Insight Generation
    
    private func generateInsights(from clusters: [ContentCluster], session: OptimizedAmbientSession) -> [SessionInsight] {
        var insights: [SessionInsight] = []
        
        // Interest insight - what captured attention most
        if let topCluster = clusters.first {
            insights.append(SessionInsight(
                type: .interest,
                title: "You were particularly interested in \(topCluster.theme)",
                description: "You captured \(topCluster.itemCount) thoughts about this theme, showing deep engagement with these ideas.",
                icon: "star.fill",
                color: .yellow,
                relatedContent: Array(topCluster.quotes.prefix(3))
            ))
        }
        
        // Pattern insight - recurring themes
        let recurringThemes = clusters.filter { $0.itemCount >= 3 }
        if recurringThemes.count >= 2 {
            let themeList = recurringThemes.prefix(3).map { $0.theme }.joined(separator: ", ")
            insights.append(SessionInsight(
                type: .pattern,
                title: "Recurring themes: \(themeList)",
                description: "These concepts appeared multiple times throughout your reading, suggesting they resonate deeply with you.",
                icon: "arrow.triangle.2.circlepath",
                color: .blue,
                relatedContent: recurringThemes
            ))
        }
        
        // Emotion insight - most emotional moments
        if let emotionalCluster = clusters.first(where: { $0.dominantEmotion != "neutral" }) {
            insights.append(SessionInsight(
                type: .emotion,
                title: "This passage moved you",
                description: "You had a strong \(emotionalCluster.dominantEmotion) response to content about \(emotionalCluster.theme).",
                icon: "heart.fill",
                color: .pink,
                relatedContent: emotionalCluster.quotes
            ))
        }
        
        // Discovery insight - connections made
        let questionsWithAnswers = session.allContent.filter { $0.type == .question && $0.aiResponse != nil }
        if questionsWithAnswers.count >= 2 {
            insights.append(SessionInsight(
                type: .discovery,
                title: "You explored \(questionsWithAnswers.count) questions",
                description: "Your curiosity led to deeper understanding through thoughtful questions and AI discussions.",
                icon: "lightbulb.fill",
                color: .orange,
                relatedContent: questionsWithAnswers
            ))
        }
        
        // Growth insight - evolution of understanding
        if session.duration > 1800 { // More than 30 minutes
            insights.append(SessionInsight(
                type: .growth,
                title: "Deep reading session",
                description: "You spent \(Int(session.duration / 60)) minutes in focused reading, allowing for deep comprehension and reflection.",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                relatedContent: []
            ))
        }
        
        return insights
    }
    
    // MARK: - Suggestion Generation
    
    private func generateSuggestions(from clusters: [ContentCluster], insights: [SessionInsight], session: OptimizedAmbientSession) -> [ActionableSuggestion] {
        var suggestions: [ActionableSuggestion] = []
        
        // Explore more suggestion
        if let topCluster = clusters.first {
            suggestions.append(ActionableSuggestion(
                type: .exploreMore,
                title: "Dive deeper into \(topCluster.theme)",
                description: "You showed strong interest in this topic. Consider exploring related passages or chapters.",
                actionText: "Find Related Content",
                icon: "magnifyingglass",
                color: .blue,
                metadata: ["theme": topCluster.theme]
            ))
        }
        
        // Related books suggestion
        if clusters.count >= 2 {
            let themes = clusters.prefix(3).map { $0.theme }
            suggestions.append(ActionableSuggestion(
                type: .relatedBooks,
                title: "Books you might enjoy",
                description: "Based on your interest in \(themes.joined(separator: " and "))",
                actionText: "View Recommendations",
                icon: "books.vertical.fill",
                color: .purple,
                metadata: ["themes": themes]
            ))
        }
        
        // Discussion questions
        if !clusters.isEmpty {
            suggestions.append(ActionableSuggestion(
                type: .discussion,
                title: "Discussion questions",
                description: "Perfect for your next book club meeting or personal reflection",
                actionText: "Generate Questions",
                icon: "bubble.left.and.bubble.right.fill",
                color: .green,
                metadata: ["clusters": clusters.map { $0.theme }]
            ))
        }
        
        // Reflection prompts
        if let emotionalInsight = insights.first(where: { $0.type == .emotion }) {
            suggestions.append(ActionableSuggestion(
                type: .reflection,
                title: "Journal about this session",
                description: "Capture your thoughts while they're fresh",
                actionText: "Open Journal",
                icon: "pencil.and.outline",
                color: .orange,
                metadata: ["prompt": "What made this reading session meaningful?"]
            ))
        }
        
        // Next chapter preview
        if session.bookContext != nil {
            suggestions.append(ActionableSuggestion(
                type: .nextChapter,
                title: "What to look for next",
                description: "Key themes to watch for in your next reading session",
                actionText: "View Themes",
                icon: "arrow.right.circle.fill",
                color: .mint,
                metadata: ["themes": clusters.prefix(2).map { $0.theme }]
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Key Takeaways
    
    private func extractKeyTakeaways(from clusters: [ContentCluster], insights: [SessionInsight]) -> [String] {
        var takeaways: [String] = []
        
        // Add top themes
        for cluster in clusters.prefix(3) {
            if cluster.significance > 0.5 {
                takeaways.append("\(cluster.themeEmoji) Key theme: \(cluster.theme)")
            }
        }
        
        // Add top insights
        for insight in insights.prefix(2) {
            takeaways.append("💡 \(insight.title)")
        }
        
        // Add summary statistic
        let totalItems = clusters.reduce(0) { $0 + $1.itemCount }
        if totalItems > 5 {
            takeaways.append("📊 Captured \(totalItems) meaningful moments")
        }
        
        return takeaways
    }
    
    // MARK: - Statistics
    
    private func calculateStatistics(for session: OptimizedAmbientSession) -> ReadingStatistics {
        let quotes = session.allContent.filter { $0.type == .quote }.count
        let notes = session.allContent.filter { $0.type == .reflection || $0.type == .insight }.count
        let questions = session.allContent.filter { $0.type == .question }.count
        
        // Estimate reading speed (rough calculation)
        let estimatedWords = Int(session.duration * 3) // Rough estimate
        let wpm = estimatedWords / max(1, Int(session.duration / 60))
        
        // Calculate engagement score
        let totalContent = quotes + notes + questions
        let engagementScore = min(1.0, Float(totalContent) / 20.0) // 20 items = full engagement
        
        // Calculate focus score based on content consistency
        let focusScore = calculateFocusScore(session: session)
        
        return ReadingStatistics(
            duration: session.duration,
            quotesCount: quotes,
            notesCount: notes,
            questionsCount: questions,
            wordsPerMinute: wpm,
            engagementScore: engagementScore,
            focusScore: focusScore
        )
    }
    
    private func calculateFocusScore(session: OptimizedAmbientSession) -> Float {
        // Analyze time gaps between content
        let timestamps = session.allContent.map { $0.timestamp }.sorted()
        guard timestamps.count > 1 else { return 1.0 }
        
        var gaps: [TimeInterval] = []
        for i in 1..<timestamps.count {
            gaps.append(timestamps[i].timeIntervalSince(timestamps[i-1]))
        }
        
        // Calculate consistency
        let avgGap = gaps.reduce(0, +) / Double(gaps.count)
        let variance = gaps.map { pow($0 - avgGap, 2) }.reduce(0, +) / Double(gaps.count)
        
        // Lower variance = higher focus
        let focusScore = max(0, min(1, 1.0 - Float(variance / 3600))) // Normalize to 0-1
        return focusScore
    }
    
    // MARK: - Emotional Analysis
    
    private func analyzeEmotionalArc(session: OptimizedAmbientSession) -> [EmotionalMoment] {
        var moments: [EmotionalMoment] = []
        
        for content in session.allContent {
            let emotion = detectEmotion(from: content.text)
            if emotion != "neutral" {
                moments.append(EmotionalMoment(
                    timestamp: content.timestamp,
                    emotion: emotion,
                    intensity: content.confidence,
                    trigger: content.type == .quote ? "Quote" : content.type == .question ? "Question" : "Reflection"
                ))
            }
        }
        
        return moments
    }
    
    private func detectEmotion(from text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("love") || lowercased.contains("beautiful") || lowercased.contains("wonderful") {
            return "joy"
        } else if lowercased.contains("sad") || lowercased.contains("tragic") || lowercased.contains("loss") {
            return "sadness"
        } else if lowercased.contains("angry") || lowercased.contains("frustrat") || lowercased.contains("rage") {
            return "anger"
        } else if lowercased.contains("fear") || lowercased.contains("afraid") || lowercased.contains("terrif") {
            return "fear"
        } else if lowercased.contains("surprise") || lowercased.contains("shock") || lowercased.contains("unexpected") {
            return "surprise"
        } else {
            return "neutral"
        }
    }
    
    private func detectDominantEmotion(from content: (quotes: [CapturedQuote], notes: [CapturedNote], questions: [SessionContent])) -> String {
        var emotions: [String] = []
        
        for quote in content.quotes {
            emotions.append(detectEmotion(from: quote.text))
        }
        for note in content.notes {
            emotions.append(detectEmotion(from: note.content))
        }
        for question in content.questions {
            emotions.append(detectEmotion(from: question.text))
        }
        
        // Find most common emotion
        let emotionCounts = emotions.reduce(into: [:]) { counts, emotion in
            counts[emotion, default: 0] += 1
        }
        
        return emotionCounts.max(by: { $0.value < $1.value })?.key ?? "neutral"
    }
    
    private func calculateSignificance(quotesCount: Int, notesCount: Int, questionsCount: Int) -> Float {
        // Weight different content types
        let quoteWeight: Float = 0.3
        let noteWeight: Float = 0.4
        let questionWeight: Float = 0.3
        
        let weightedSum = Float(quotesCount) * quoteWeight +
                         Float(notesCount) * noteWeight +
                         Float(questionsCount) * questionWeight
        
        // Normalize to 0-1 range (assuming 10 items is highly significant)
        return min(1.0, weightedSum / 10.0)
    }
    
    // MARK: - Helper Methods
    
    private func extractQuotes(from session: OptimizedAmbientSession) -> [CapturedQuote] {
        // In a real implementation, would fetch from SwiftData
        // For now, create from session content
        return session.allContent
            .filter { $0.type == .quote }
            .map { content in
                CapturedQuote(
                    text: content.text,
                    book: nil,
                    author: nil,
                    pageNumber: nil,
                    timestamp: content.timestamp,
                    source: .ambient
                )
            }
    }
    
    private func extractNotes(from session: OptimizedAmbientSession) -> [CapturedNote] {
        return session.allContent
            .filter { $0.type == .reflection || $0.type == .insight }
            .map { content in
                CapturedNote(
                    content: content.text,
                    book: nil,
                    pageNumber: nil,
                    timestamp: content.timestamp,
                    source: .ambient
                )
            }
    }
    
    private func extractQuestions(from session: OptimizedAmbientSession) -> [SessionContent] {
        return session.allContent.filter { $0.type == .question }
    }
}

// MARK: - SwiftUI Views

struct GeneratedSessionSummaryView: View {
    let summary: SessionSummaryGenerator.SessionSummary
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Stats
                    SessionStatsCard(stats: summary.readingStats)
                        .padding(.horizontal)
                    
                    // Tab Selection
                    SessionTabSelector(selectedTab: $selectedTab)
                        .padding(.horizontal)
                    
                    // Content based on tab
                    Group {
                        switch selectedTab {
                        case 0:
                            ThemeClustersView(clusters: summary.clusters)
                        case 1:
                            InsightsView(insights: summary.insights)
                        case 2:
                            SuggestionsView(suggestions: summary.suggestions)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Key Takeaways
                    if !summary.keyTakeaways.isEmpty {
                        KeyTakeawaysCard(takeaways: summary.keyTakeaways)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

struct SessionStatsCard: View {
    let stats: SessionSummaryGenerator.ReadingStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatItem(
                    value: "\(Int(stats.duration / 60))",
                    label: "minutes",
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatItem(
                    value: "\(stats.quotesCount)",
                    label: "quotes",
                    icon: "quote.bubble.fill",
                    color: .green
                )
                
                StatItem(
                    value: "\(stats.notesCount)",
                    label: "notes",
                    icon: "note.text",
                    color: .orange
                )
                
                StatItem(
                    value: "\(stats.questionsCount)",
                    label: "questions",
                    icon: "questionmark.circle.fill",
                    color: .purple
                )
            }
            
            // Engagement meters
            HStack(spacing: 16) {
                EngagementMeter(
                    label: "Engagement",
                    value: stats.engagementScore,
                    color: .mint
                )
                
                EngagementMeter(
                    label: "Focus",
                    value: stats.focusScore,
                    color: .indigo
                )
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

struct EngagementMeter: View {
    let label: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 6)
        }
    }
}

struct SessionTabSelector: View {
    @Binding var selectedTab: Int
    let tabs = ["Themes", "Insights", "Suggestions"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(DesignSystem.Animation.springStandard) {
                        selectedTab = index
                    }
                }) {
                    Text(tabs[index])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == index ? .black : .white.opacity(0.6))
                        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == index ? Color.white : Color.white.opacity(0.1))
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ThemeClustersView: View {
    let clusters: [SessionSummaryGenerator.ContentCluster]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(clusters.prefix(5)) { cluster in
                ThemeClusterCard(cluster: cluster)
            }
        }
    }
}

struct ThemeClusterCard: View {
    let cluster: SessionSummaryGenerator.ContentCluster
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(cluster.themeEmoji)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.theme)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("\(cluster.itemCount) items • \(cluster.dominantEmotion)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Significance indicator
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.textQuaternary,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(Int(cluster.significance * 100))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !cluster.quotes.isEmpty {
                        Label("\(cluster.quotes.count) quotes", systemImage: "quote.bubble")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    
                    if !cluster.notes.isEmpty {
                        Label("\(cluster.notes.count) notes", systemImage: "note.text")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                    
                    if !cluster.questions.isEmpty {
                        Label("\(cluster.questions.count) questions", systemImage: "questionmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.purple)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(DesignSystem.Animation.springStandard) {
                isExpanded.toggle()
            }
        }
    }
}

struct InsightsView: View {
    let insights: [SessionSummaryGenerator.SessionInsight]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}

struct InsightCard: View {
    let insight: SessionSummaryGenerator.SessionInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: insight.icon)
                .font(.system(size: 24))
                .foregroundStyle(insight.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(insight.color.opacity(0.2))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(insight.description)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SuggestionsView: View {
    let suggestions: [SessionSummaryGenerator.ActionableSuggestion]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(suggestions) { suggestion in
                GeneratedSuggestionCard(suggestion: suggestion)
            }
        }
    }
}

struct GeneratedSuggestionCard: View {
    let suggestion: SessionSummaryGenerator.ActionableSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(suggestion.color)
                
                Text(suggestion.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            Text(suggestion.description)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(2)
            
            Button(action: {
                // Handle action
                SensoryFeedback.light()
            }) {
                Text(suggestion.actionText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(suggestion.color)
                    )
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct KeyTakeawaysCard: View {
    let takeaways: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Takeaways")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(takeaways, id: \.self) { takeaway in
                    Text(takeaway)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(DesignSystem.Spacing.inlinePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}