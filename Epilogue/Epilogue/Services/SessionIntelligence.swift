import Foundation
import SwiftUI
import Combine
import NaturalLanguage
import CoreML
import Vision

// MARK: - Session Intelligence Service
@MainActor
class SessionIntelligence: ObservableObject {
    static let shared = SessionIntelligence()
    
    @Published var isProcessing = false
    @Published var detectedPatterns: [SessionPattern] = []
    @Published var characterInsights: [CharacterInsight] = []
    @Published var thematicConnections: [ThematicConnection] = []
    @Published var readingEvolution: ReadingEvolution?
    
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])
    private let tokenizer = NLTokenizer(unit: .word)
    
    private init() {}
    
    // MARK: - Pattern Detection
    func detectPatterns(across sessions: [AmbientSession]) async -> [SessionPattern] {
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        var patterns: [SessionPattern] = []
        
        // Analyze question evolution
        let questionPatterns = analyzeQuestionEvolution(sessions)
        patterns.append(contentsOf: questionPatterns)
        
        // Detect recurring themes
        let themePatterns = detectRecurringThemes(sessions)
        patterns.append(contentsOf: themePatterns)
        
        // Find insight clusters
        let insightClusters = findInsightClusters(sessions)
        patterns.append(contentsOf: insightClusters)
        
        // Analyze emotional journey
        let emotionalPatterns = analyzeEmotionalJourney(sessions)
        patterns.append(contentsOf: emotionalPatterns)
        
        await MainActor.run {
            self.detectedPatterns = patterns.sorted { $0.confidence > $1.confidence }
        }
        
        return patterns
    }
    
    // MARK: - Character Analysis
    func analyzeCharacterEvolution(across sessions: [AmbientSession]) async -> [CharacterInsight] {
        var characterMentions: [String: [CharacterMention]] = [:]
        
        for session in sessions {
            // Extract character mentions from questions and notes
            let content = (session.capturedQuestions ?? []).compactMap { $0.content } + 
                         (session.capturedNotes ?? []).compactMap { $0.content }
            
            for text in content {
                let characters = extractCharacterNames(from: text)
                for character in characters {
                    let sentiment = analyzeSentiment(for: text)
                    let mention = CharacterMention(
                        sessionId: session.id ?? UUID(),
                        timestamp: session.startTime ?? Date(),
                        context: text,
                        sentiment: sentiment,
                        bookTitle: session.bookModel?.title
                    )
                    characterMentions[character, default: []].append(mention)
                }
            }
        }
        
        // Build character insights
        let insights = characterMentions.compactMap { name, mentions -> CharacterInsight? in
            guard mentions.count > 2 else { return nil }
            
            let sentimentEvolution = mentions.map(\.sentiment)
            let averageSentiment = sentimentEvolution.reduce(0, +) / Float(sentimentEvolution.count)
            
            return CharacterInsight(
                characterName: name,
                mentions: mentions,
                sentimentEvolution: sentimentEvolution,
                averageSentiment: averageSentiment,
                firstMention: mentions.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(),
                lastMention: mentions.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(),
                crossBookAppearances: Set(mentions.compactMap(\.bookTitle)).count
            )
        }
        
        await MainActor.run {
            self.characterInsights = insights.sorted { $0.mentions.count > $1.mentions.count }
        }
        
        return insights
    }
    
    // MARK: - Thematic Analysis
    func findThematicConnections(between sessions: [AmbientSession]) async -> [ThematicConnection] {
        var connections: [ThematicConnection] = []
        
        // Use embedding-based similarity (simplified version)
        for i in 0..<sessions.count {
            for j in (i+1)..<sessions.count {
                let session1 = sessions[i]
                let session2 = sessions[j]
                
                let similarity = calculateSemanticSimilarity(session1, session2)
                
                if similarity > 0.7 {
                    let sharedThemes = extractSharedThemes(session1, session2)
                    
                    connections.append(ThematicConnection(
                        sourceSession: session1,
                        targetSession: session2,
                        themes: sharedThemes,
                        strength: similarity,
                        connectionType: determineConnectionType(sharedThemes)
                    ))
                }
            }
        }
        
        await MainActor.run {
            self.thematicConnections = connections.sorted { $0.strength > $1.strength }
        }
        
        return connections
    }
    
    // MARK: - Reading Evolution
    func measureReadingEvolution(sessions: [AmbientSession]) async -> ReadingEvolution {
        let sortedSessions = sessions.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        // Measure question complexity over time
        let complexityScores = sortedSessions.map { session in
            measureQuestionComplexity(session.capturedQuestions ?? [])
        }
        
        // Measure engagement depth
        let engagementScores = sortedSessions.map { session in
            measureEngagementDepth(session)
        }
        
        // Measure thematic diversity
        let thematicDiversity = measureThematicDiversity(sortedSessions)
        
        // Calculate growth rate
        let growthRate = calculateGrowthRate(complexityScores)
        
        let evolution = ReadingEvolution(
            complexityProgression: complexityScores,
            engagementProgression: engagementScores,
            thematicDiversity: thematicDiversity,
            growthRate: growthRate,
            milestones: identifyMilestones(sortedSessions),
            currentPhase: determineCurrentPhase(complexityScores)
        )
        
        await MainActor.run {
            self.readingEvolution = evolution
        }
        
        return evolution
    }
    
    // MARK: - Predictive Features
    func predictNextSession(basedOn history: [AmbientSession]) -> SessionPrediction {
        // Analyze patterns to predict next session
        let recentThemes = extractRecentThemes(from: history.suffix(5))
        let timePattern = analyzeTimePattern(history)
        let bookProgression = analyzeBookProgression(history)
        
        return SessionPrediction(
            suggestedBook: bookProgression.nextBook,
            suggestedTime: timePattern.optimalTime,
            suggestedQuestions: generatePredictiveQuestions(recentThemes),
            expectedThemes: recentThemes,
            confidence: calculatePredictionConfidence(history)
        )
    }
    
    // MARK: - Helper Functions
    private func analyzeQuestionEvolution(_ sessions: [AmbientSession]) -> [SessionPattern] {
        var patterns: [SessionPattern] = []
        
        let allQuestions = sessions.flatMap { $0.capturedQuestions ?? [] }
        
        // Group questions by similarity
        let questionClusters = clusterQuestions(allQuestions)
        
        for cluster in questionClusters {
            if cluster.count > 2 {
                patterns.append(SessionPattern(
                    id: UUID(),
                    type: .questionEvolution,
                    description: "Recurring interest in: \((cluster.first?.content ?? "").prefix(50))",
                    occurrences: cluster.count,
                    confidence: Float(cluster.count) / Float(allQuestions.count),
                    sessions: sessions.filter { session in
                        (session.capturedQuestions ?? []).contains { q in
                            cluster.contains { $0.id == q.id }
                        }
                    }
                ))
            }
        }
        
        return patterns
    }
    
    private func detectRecurringThemes(_ sessions: [AmbientSession]) -> [SessionPattern] {
        var themeCounts: [String: Int] = [:]
        var themesSessions: [String: [AmbientSession]] = [:]
        
        for session in sessions {
            let themes = extractThemes(from: session)
            for theme in themes {
                themeCounts[theme, default: 0] += 1
                themesSessions[theme, default: []].append(session)
            }
        }
        
        return themeCounts.compactMap { theme, count -> SessionPattern? in
            guard count > 2 else { return nil }
            
            return SessionPattern(
                id: UUID(),
                type: .recurringTheme,
                description: "Recurring theme: \(theme)",
                occurrences: count,
                confidence: Float(count) / Float(sessions.count),
                sessions: themesSessions[theme] ?? []
            )
        }
    }
    
    private func findInsightClusters(_ sessions: [AmbientSession]) -> [SessionPattern] {
        // Group sessions with similar insights
        var patterns: [SessionPattern] = []
        
        // Simplified clustering based on content similarity
        for i in 0..<sessions.count {
            var cluster = [sessions[i]]
            
            for j in (i+1)..<sessions.count {
                if areSessionsSimilar(sessions[i], sessions[j]) {
                    cluster.append(sessions[j])
                }
            }
            
            if cluster.count > 2 {
                patterns.append(SessionPattern(
                    id: UUID(),
                    type: .insightCluster,
                    description: "Connected insights across \(cluster.count) sessions",
                    occurrences: cluster.count,
                    confidence: Float(cluster.count) / Float(sessions.count),
                    sessions: cluster
                ))
            }
        }
        
        return patterns
    }
    
    private func analyzeEmotionalJourney(_ sessions: [AmbientSession]) -> [SessionPattern] {
        var patterns: [SessionPattern] = []
        
        let sortedSessions = sessions.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        var emotionalScores: [Float] = []
        
        for session in sortedSessions {
            let content = (session.capturedQuestions ?? []).compactMap { $0.content }.joined(separator: " ") +
                         (session.capturedNotes ?? []).compactMap { $0.content }.joined(separator: " ")
            let sentiment = analyzeSentiment(for: content)
            emotionalScores.append(sentiment)
        }
        
        // Detect emotional peaks and valleys
        if let maxScore = emotionalScores.max(),
           let maxIndex = emotionalScores.firstIndex(of: maxScore) {
            patterns.append(SessionPattern(
                id: UUID(),
                type: .emotionalPeak,
                description: "Emotional peak in reading journey",
                occurrences: 1,
                confidence: maxScore,
                sessions: [sortedSessions[maxIndex]]
            ))
        }
        
        return patterns
    }
    
    private func extractCharacterNames(from text: String) -> [String] {
        // Use NLTagger for named entity recognition
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var names: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tag == .personalName {
                names.append(String(text[tokenRange]))
            }
            return true
        }
        
        return names
    }
    
    private func analyzeSentiment(for text: String) -> Float {
        sentimentAnalyzer.string = text
        
        var totalScore: Float = 0
        var wordCount = 0
        
        sentimentAnalyzer.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag {
                totalScore += Float(tag.rawValue) ?? 0
                wordCount += 1
            }
            return true
        }
        
        return wordCount > 0 ? totalScore / Float(wordCount) : 0
    }
    
    private func calculateSemanticSimilarity(_ session1: AmbientSession, _ session2: AmbientSession) -> Float {
        // Simplified similarity calculation
        let content1 = ((session1.capturedQuestions ?? []).compactMap { $0.content } + 
                       (session1.capturedNotes ?? []).compactMap { $0.content }).joined(separator: " ")
        let content2 = ((session2.capturedQuestions ?? []).compactMap { $0.content } + 
                       (session2.capturedNotes ?? []).compactMap { $0.content }).joined(separator: " ")
        
        let words1 = Set(content1.lowercased().split(separator: " "))
        let words2 = Set(content2.lowercased().split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0 : Float(intersection.count) / Float(union.count)
    }
    
    private func extractSharedThemes(_ session1: AmbientSession, _ session2: AmbientSession) -> [String] {
        let themes1 = extractThemes(from: session1)
        let themes2 = extractThemes(from: session2)
        return Array(Set(themes1).intersection(Set(themes2)))
    }
    
    private func extractThemes(from session: AmbientSession) -> [String] {
        // Simple theme extraction
        let content = ((session.capturedQuestions ?? []).compactMap { $0.content } + 
                      (session.capturedNotes ?? []).compactMap { $0.content }).joined(separator: " ").lowercased()
        
        var themes: [String] = []
        let themeKeywords = ["identity", "love", "death", "power", "freedom", "time", "nature", "family", "truth", "beauty"]
        
        for keyword in themeKeywords {
            if content.contains(keyword) {
                themes.append(keyword.capitalized)
            }
        }
        
        return themes
    }
    
    private func determineConnectionType(_ themes: [String]) -> ThematicConnection.ConnectionType {
        if themes.contains("Character") { return .character }
        if themes.contains("Time") { return .temporal }
        if themes.contains(where: { ["Love", "Death", "Power"].contains($0) }) { return .philosophical }
        return .thematic
    }
    
    private func measureQuestionComplexity(_ questions: [CapturedQuestion]) -> Float {
        guard !questions.isEmpty else { return 0 }
        
        var totalComplexity: Float = 0
        
        for question in questions {
            let content = question.content ?? ""
            let wordCount = content.split(separator: " ").count
            let hasWhy = content.lowercased().contains("why")
            let hasHow = content.lowercased().contains("how")
            let hasCompare = content.lowercased().contains("compare") || content.lowercased().contains("contrast")
            
            var complexity: Float = Float(wordCount) / 10
            if hasWhy { complexity += 0.3 }
            if hasHow { complexity += 0.3 }
            if hasCompare { complexity += 0.4 }
            
            totalComplexity += min(complexity, 1.0)
        }
        
        return totalComplexity / Float(questions.count)
    }
    
    private func measureEngagementDepth(_ session: AmbientSession) -> Float {
        let questionScore = Float(session.capturedQuestions?.count ?? 0) * 0.3
        let quoteScore = Float(session.capturedQuotes?.count ?? 0) * 0.2
        let noteScore = Float(session.capturedNotes?.count ?? 0) * 0.2
        let durationScore = min(Float(session.duration / 3600), 1.0) * 0.3
        
        return min(questionScore + quoteScore + noteScore + durationScore, 1.0)
    }
    
    private func measureThematicDiversity(_ sessions: [AmbientSession]) -> Float {
        let allThemes = sessions.flatMap { extractThemes(from: $0) }
        let uniqueThemes = Set(allThemes)
        return Float(uniqueThemes.count) / Float(max(allThemes.count, 1))
    }
    
    private func calculateGrowthRate(_ scores: [Float]) -> Float {
        guard scores.count > 1 else { return 0 }
        
        let firstHalf = scores.prefix(scores.count / 2)
        let secondHalf = scores.suffix(scores.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Float(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Float(secondHalf.count)
        
        return (secondAvg - firstAvg) / max(firstAvg, 0.01)
    }
    
    private func identifyMilestones(_ sessions: [AmbientSession]) -> [ReadingMilestone] {
        var milestones: [ReadingMilestone] = []
        
        // First deep question
        if let firstDeepQuestion = sessions.first(where: { !($0.capturedQuestions?.isEmpty ?? true) }) {
            milestones.append(ReadingMilestone(
                date: firstDeepQuestion.startTime ?? Date(),
                description: "First thoughtful question",
                sessionId: firstDeepQuestion.id ?? UUID()
            ))
        }
        
        // Most quotes captured
        if let mostQuotes = sessions.max(by: { ($0.capturedQuotes?.count ?? 0) < ($1.capturedQuotes?.count ?? 0) }),
           (mostQuotes.capturedQuotes?.count ?? 0) > 3 {
            milestones.append(ReadingMilestone(
                date: mostQuotes.startTime ?? Date(),
                description: "Deep engagement with text",
                sessionId: mostQuotes.id ?? UUID()
            ))
        }
        
        return milestones
    }
    
    private func determineCurrentPhase(_ scores: [Float]) -> ReadingPhase {
        guard let latest = scores.last else { return .exploring }
        
        if latest < 0.3 { return .exploring }
        if latest < 0.6 { return .developing }
        if latest < 0.8 { return .deepening }
        return .mastering
    }
    
    private func clusterQuestions(_ questions: [CapturedQuestion]) -> [[CapturedQuestion]] {
        // Simple clustering based on content similarity
        var clusters: [[CapturedQuestion]] = []
        var processed = Set<UUID>()
        
        for question in questions {
            guard let questionId = question.id else { continue }
            if processed.contains(questionId) { continue }
            
            var cluster = [question]
            processed.insert(questionId)
            
            for other in questions {
                if let otherId = other.id, !processed.contains(otherId) && areQuestionsSimilar(question, other) {
                    cluster.append(other)
                    processed.insert(otherId)
                }
            }
            
            if cluster.count > 1 {
                clusters.append(cluster)
            }
        }
        
        return clusters
    }
    
    private func areQuestionsSimilar(_ q1: CapturedQuestion, _ q2: CapturedQuestion) -> Bool {
        let words1 = Set((q1.content ?? "").lowercased().split(separator: " "))
        let words2 = Set((q2.content ?? "").lowercased().split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let smaller = min(words1.count, words2.count)
        
        return smaller > 0 ? Float(intersection.count) / Float(smaller) > 0.5 : false
    }
    
    private func areSessionsSimilar(_ s1: AmbientSession, _ s2: AmbientSession) -> Bool {
        calculateSemanticSimilarity(s1, s2) > 0.6
    }
    
    private func extractRecentThemes(from sessions: ArraySlice<AmbientSession>) -> [String] {
        Array(sessions).flatMap { extractThemes(from: $0) }
    }
    
    private func analyzeTimePattern(_ sessions: [AmbientSession]) -> (optimalTime: String, pattern: String) {
        let hourCounts = Dictionary(grouping: sessions) { session in
            Calendar.current.component(.hour, from: session.startTime ?? Date())
        }
        
        if let mostFrequent = hourCounts.max(by: { $0.value.count < $1.value.count }) {
            let hour = mostFrequent.key
            let timeString = hour < 12 ? "Morning" : hour < 18 ? "Afternoon" : "Evening"
            return (timeString, "Most active during \(timeString.lowercased())")
        }
        
        return ("Anytime", "No clear pattern")
    }
    
    private func analyzeBookProgression(_ sessions: [AmbientSession]) -> (nextBook: String?, pattern: String) {
        // Analyze book reading patterns
        let bookTitles = sessions.compactMap { $0.bookModel?.title }
        let uniqueBooks = Array(Set(bookTitles))
        
        // Simple recommendation (would use ML in production)
        if uniqueBooks.contains(where: { $0.contains("Lord of the Rings") }) {
            return ("The Hobbit", "Fantasy series progression")
        }
        
        return (nil, "Diverse reading pattern")
    }
    
    private func generatePredictiveQuestions(_ themes: [String]) -> [String] {
        themes.prefix(3).map { theme in
            "How does \(theme.lowercased()) evolve in the next chapter?"
        }
    }
    
    private func calculatePredictionConfidence(_ history: [AmbientSession]) -> Float {
        // More history = higher confidence
        min(Float(history.count) / 20.0, 1.0)
    }
}

// MARK: - Supporting Types
struct SessionPattern: Identifiable {
    let id: UUID
    let type: PatternType
    let description: String
    let occurrences: Int
    let confidence: Float
    let sessions: [AmbientSession]
    
    enum PatternType {
        case questionEvolution
        case recurringTheme
        case insightCluster
        case emotionalPeak
    }
}

struct CharacterInsight: Identifiable {
    let id = UUID()
    let characterName: String
    let mentions: [CharacterMention]
    let sentimentEvolution: [Float]
    let averageSentiment: Float
    let firstMention: Date
    let lastMention: Date
    let crossBookAppearances: Int
}

struct CharacterMention {
    let sessionId: UUID
    let timestamp: Date
    let context: String
    let sentiment: Float
    let bookTitle: String?
}

struct ThematicConnection: Identifiable {
    let id = UUID()
    let sourceSession: AmbientSession
    let targetSession: AmbientSession
    let themes: [String]
    let strength: Float
    let connectionType: ConnectionType
    
    enum ConnectionType {
        case thematic
        case character
        case temporal
        case philosophical
    }
}

struct ReadingEvolution {
    let complexityProgression: [Float]
    let engagementProgression: [Float]
    let thematicDiversity: Float
    let growthRate: Float
    let milestones: [ReadingMilestone]
    let currentPhase: ReadingPhase
}

struct ReadingMilestone: Identifiable {
    let id = UUID()
    let date: Date
    let description: String
    let sessionId: UUID
}

enum ReadingPhase {
    case exploring
    case developing
    case deepening
    case mastering
    
    var description: String {
        switch self {
        case .exploring: return "Exploring new territories"
        case .developing: return "Developing deeper insights"
        case .deepening: return "Deepening understanding"
        case .mastering: return "Mastering complex themes"
        }
    }
}

struct SessionPrediction {
    let suggestedBook: String?
    let suggestedTime: String
    let suggestedQuestions: [String]
    let expectedThemes: [String]
    let confidence: Float
}