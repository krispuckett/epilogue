import Foundation
import SwiftUI

// MARK: - Book Intelligence
/// Analyzes books to understand difficulty, common struggles, and optimal reading approaches.
/// This is the foundation of the Reading Companion — understanding what makes a book challenging.

@MainActor
final class BookIntelligence {
    static let shared = BookIntelligence()

    private init() {}

    // MARK: - Book Profile

    struct BookProfile {
        let book: BookModel
        let difficulty: DifficultyAssessment
        let challenges: [ReaderChallenge]
        let approachRecommendation: ApproachRecommendation
        let spoilerBoundaries: SpoilerBoundaries
        let contextNeeds: [ContextNeed]

        /// Overall intimidation score (0-1) — higher = more intimidating
        var intimidationScore: Double {
            var score = 0.0

            // Length factor (500+ pages adds intimidation)
            if let pages = book.pageCount {
                if pages > 800 { score += 0.25 }
                else if pages > 500 { score += 0.15 }
                else if pages > 300 { score += 0.05 }
            }

            // Difficulty factor
            switch difficulty.level {
            case .challenging: score += 0.3
            case .moderate: score += 0.15
            case .accessible: score += 0.0
            }

            // Era factor
            switch difficulty.era {
            case .ancient, .classical: score += 0.2
            case .earlyModern: score += 0.1
            case .modern, .contemporary: score += 0.0
            }

            // Challenge count
            score += Double(challenges.count) * 0.05

            // Known difficult work bonus
            if difficulty.isKnownDifficultWork { score += 0.2 }

            return min(score, 1.0)
        }

        var needsPreparation: Bool {
            intimidationScore > 0.4
        }

        var companionMode: CompanionMode {
            if intimidationScore > 0.7 { return .guide }
            if intimidationScore > 0.4 { return .coach }
            if intimidationScore > 0.2 { return .companion }
            return .observer
        }
    }

    enum CompanionMode {
        case guide      // Proactive, detailed help — challenging works
        case coach      // Encouraging, available help — moderate works
        case companion  // Light touch, there when needed — accessible works
        case observer   // Quiet, only responds to direct questions

        var proactivityLevel: Double {
            switch self {
            case .guide: return 1.0
            case .coach: return 0.7
            case .companion: return 0.4
            case .observer: return 0.1
            }
        }
    }

    // MARK: - Difficulty Assessment

    struct DifficultyAssessment {
        let level: DifficultyLevel
        let era: LiteraryEra
        let reasons: [String]
        let isKnownDifficultWork: Bool
        let languageComplexity: LanguageComplexity
        let structuralComplexity: StructuralComplexity
    }

    enum DifficultyLevel: String, CaseIterable {
        case accessible = "Accessible"
        case moderate = "Moderate"
        case challenging = "Challenging"
    }

    enum LiteraryEra: String, CaseIterable {
        case ancient = "Ancient"           // Homer, Virgil, etc.
        case classical = "Classical"       // Medieval through Renaissance
        case earlyModern = "Early Modern"  // 1700s-1800s
        case modern = "Modern"             // 1900-1970
        case contemporary = "Contemporary" // 1970-present
    }

    enum LanguageComplexity {
        case archaic        // Translated ancient works, Elizabethan English
        case literary       // Dense prose, complex vocabulary
        case standard       // Modern literary fiction
        case conversational // Easy reading, genre fiction
    }

    enum StructuralComplexity {
        case nonLinear      // Time jumps, multiple narratives
        case episodic       // Connected episodes (epic poetry, picaresque)
        case nested         // Stories within stories
        case conventional   // Standard narrative structure
    }

    // MARK: - Reader Challenges

    struct ReaderChallenge: Identifiable {
        let id = UUID()
        let type: ChallengeType
        let description: String
        let mitigation: String
        let severity: ChallengeSeverity
    }

    enum ChallengeType {
        case unfamiliarNames       // Foreign, ancient, or complex character names
        case largeCharacterCast    // Many characters to track
        case unfamiliarContext     // Historical/cultural knowledge needed
        case complexLanguage       // Archaic or dense prose
        case nonLinearStructure    // Confusing timeline
        case philosophicalDensity  // Heavy ideas requiring reflection
        case lengthEndurance       // Simply very long
        case translationArtifacts  // Reading in translation
        case genreConventions      // Unfamiliar genre expectations
        case ambiguousNarration    // Unreliable narrator, unclear meaning
    }

    enum ChallengeSeverity {
        case minor      // Slight friction
        case moderate   // May cause confusion
        case significant // Could cause abandonment
    }

    // MARK: - Approach Recommendation

    struct ApproachRecommendation {
        let readingStrategy: ReadingStrategy
        let paceGuidance: String
        let preparationSteps: [String]
        let duringReadingTips: [String]
        let toolsRecommended: [ReadingTool]
    }

    enum ReadingStrategy {
        case immersive      // Just read, let it wash over you
        case analytical     // Take notes, track themes
        case episodic       // Read in chunks, digest between
        case guided         // Use companion resources
        case communal       // Best with discussion/book club
    }

    enum ReadingTool {
        case characterList
        case timeline
        case mapReference
        case audioCompanion
        case annotatedEdition
        case readingGuide
        case discussionQuestions
    }

    // MARK: - Spoiler Boundaries

    struct SpoilerBoundaries {
        let safeToReveal: [SpoilerSafeContent]
        let revealAfterProgress: [ProgressGatedContent]
        let neverReveal: [String]  // Major plot points to always protect
    }

    struct SpoilerSafeContent {
        let content: String
        let category: SafeContentCategory
    }

    enum SafeContentCategory {
        case historicalContext
        case authorBackground
        case genreConventions
        case thematicSetup
        case characterIntroductions  // Who they are at the start
        case settingDetails
        case structureOverview
    }

    struct ProgressGatedContent {
        let content: String
        let revealAfterPercent: Double
        let category: String
    }

    // MARK: - Context Needs

    struct ContextNeed: Identifiable {
        let id = UUID()
        let type: ContextType
        let importance: ContextImportance
        let briefing: String       // Short context for pills
        let fullContext: String    // Detailed context for deep dive
    }

    enum ContextType {
        case historical           // When/where was this written
        case cultural             // Cultural norms/expectations
        case literary             // Literary movement, influences
        case biographical         // Author's life/perspective
        case mythological         // Required myth knowledge
        case philosophical        // Philosophical frameworks
        case linguistic           // Language/translation notes
        case structural           // How the work is organized
    }

    enum ContextImportance {
        case essential    // Really need this to understand
        case helpful      // Makes experience richer
        case enriching    // Nice to know
    }

    // MARK: - Analysis Methods

    /// Analyze a book and generate its complete intelligence profile
    func analyzeBook(_ book: BookModel) async -> BookProfile {
        // First check if we have curated intelligence for this book
        if let curated = getCuratedIntelligence(for: book) {
            return curated
        }

        // Otherwise, generate intelligence from available signals
        let difficulty = assessDifficulty(book)
        let challenges = identifyChallenges(book, difficulty: difficulty)
        let approach = recommendApproach(book, difficulty: difficulty, challenges: challenges)
        let spoilers = determineSpoilerBoundaries(book)
        let context = identifyContextNeeds(book, difficulty: difficulty)

        return BookProfile(
            book: book,
            difficulty: difficulty,
            challenges: challenges,
            approachRecommendation: approach,
            spoilerBoundaries: spoilers,
            contextNeeds: context
        )
    }

    // MARK: - Difficulty Assessment

    private func assessDifficulty(_ book: BookModel) -> DifficultyAssessment {
        let era = determineEra(book)
        let language = assessLanguageComplexity(book)
        let structure = assessStructuralComplexity(book)
        let isKnown = isKnownDifficultWork(book)

        var reasons: [String] = []
        var difficultyScore = 0.0

        // Era contribution
        switch era {
        case .ancient:
            reasons.append("Ancient text with cultural distance")
            difficultyScore += 0.3
        case .classical:
            reasons.append("Classical work with different conventions")
            difficultyScore += 0.2
        case .earlyModern:
            reasons.append("Older prose style")
            difficultyScore += 0.1
        default:
            break
        }

        // Language contribution
        switch language {
        case .archaic:
            reasons.append("Archaic or translated language")
            difficultyScore += 0.25
        case .literary:
            reasons.append("Dense literary prose")
            difficultyScore += 0.15
        default:
            break
        }

        // Structure contribution
        switch structure {
        case .nonLinear:
            reasons.append("Non-linear narrative")
            difficultyScore += 0.2
        case .episodic:
            reasons.append("Episodic structure")
            difficultyScore += 0.1
        case .nested:
            reasons.append("Complex nested narratives")
            difficultyScore += 0.15
        default:
            break
        }

        // Length contribution
        if let pages = book.pageCount, pages > 500 {
            reasons.append("Substantial length (\(pages) pages)")
            difficultyScore += 0.1
        }

        // Known difficult work
        if isKnown {
            reasons.append("Known to challenge readers")
            difficultyScore += 0.2
        }

        let level: DifficultyLevel
        if difficultyScore > 0.5 {
            level = .challenging
        } else if difficultyScore > 0.25 {
            level = .moderate
        } else {
            level = .accessible
        }

        return DifficultyAssessment(
            level: level,
            era: era,
            reasons: reasons,
            isKnownDifficultWork: isKnown,
            languageComplexity: language,
            structuralComplexity: structure
        )
    }

    private func determineEra(_ book: BookModel) -> LiteraryEra {
        // Check publication year if available
        if let yearStr = book.publishedDate,
           let year = Int(yearStr.prefix(4)) {
            if year < 500 { return .ancient }
            if year < 1700 { return .classical }
            if year < 1900 { return .earlyModern }
            if year < 1970 { return .modern }
            return .contemporary
        }

        // Infer from title/author for known works
        let title = book.title.lowercased()
        let author = book.author.lowercased()

        // Ancient works
        let ancientIndicators = ["homer", "virgil", "ovid", "iliad", "odyssey", "aeneid", "metamorphoses", "plato", "aristotle", "sophocles", "euripides"]
        if ancientIndicators.contains(where: { title.contains($0) || author.contains($0) }) {
            return .ancient
        }

        // Classical works
        let classicalIndicators = ["shakespeare", "dante", "chaucer", "milton", "cervantes", "divine comedy", "canterbury"]
        if classicalIndicators.contains(where: { title.contains($0) || author.contains($0) }) {
            return .classical
        }

        // Early modern
        let earlyModernIndicators = ["austen", "dickens", "tolstoy", "dostoevsky", "bronte", "melville", "twain"]
        if earlyModernIndicators.contains(where: { title.contains($0) || author.contains($0) }) {
            return .earlyModern
        }

        return .contemporary
    }

    private func assessLanguageComplexity(_ book: BookModel) -> LanguageComplexity {
        let title = book.title.lowercased()
        let author = book.author.lowercased()
        let desc = (book.description ?? "").lowercased()

        // Archaic indicators
        let archaicIndicators = ["translation", "translated by", "homer", "virgil", "ancient", "classical", "medieval"]
        if archaicIndicators.contains(where: { title.contains($0) || author.contains($0) || desc.contains($0) }) {
            return .archaic
        }

        // Literary fiction indicators
        let literaryIndicators = ["literary fiction", "booker prize", "pulitzer", "national book award", "experimental"]
        if literaryIndicators.contains(where: { desc.contains($0) }) {
            return .literary
        }

        // Genre fiction tends to be more accessible
        let genreIndicators = ["thriller", "mystery", "romance", "fantasy", "science fiction", "young adult"]
        if genreIndicators.contains(where: { desc.contains($0) }) {
            return .conversational
        }

        return .standard
    }

    private func assessStructuralComplexity(_ book: BookModel) -> StructuralComplexity {
        let title = book.title.lowercased()
        let desc = (book.description ?? "").lowercased()

        // Non-linear indicators
        let nonLinearIndicators = ["time", "memory", "fragmented", "non-linear", "multiple timelines"]
        if nonLinearIndicators.contains(where: { desc.contains($0) }) {
            return .nonLinear
        }

        // Episodic indicators (epic poetry, picaresque)
        let episodicIndicators = ["odyssey", "iliad", "epic", "books", "cantos", "adventures of"]
        if episodicIndicators.contains(where: { title.contains($0) || desc.contains($0) }) {
            return .episodic
        }

        // Nested narrative indicators
        let nestedIndicators = ["stories within", "frame narrative", "arabian nights", "decameron", "canterbury"]
        if nestedIndicators.contains(where: { title.contains($0) || desc.contains($0) }) {
            return .nested
        }

        return .conventional
    }

    private func isKnownDifficultWork(_ book: BookModel) -> Bool {
        let title = book.title.lowercased()
        let author = book.author.lowercased()

        // Curated list of works known to challenge readers
        let difficultWorks = [
            // Epic poetry
            "odyssey", "iliad", "aeneid", "divine comedy", "paradise lost", "faerie queene",
            // Modernist literature
            "ulysses", "finnegans wake", "the sound and the fury", "absalom, absalom",
            // Postmodern
            "infinite jest", "gravity's rainbow", "house of leaves", "pale fire",
            // Russian literature
            "war and peace", "brothers karamazov", "crime and punishment", "anna karenina",
            // Dense philosophy/fiction
            "moby dick", "middlemarch", "in search of lost time", "remembrance of things past",
            // Complex fantasy
            "silmarillion", "malazan", "second apocalypse"
        ]

        let difficultAuthors = [
            "james joyce", "william faulkner", "thomas pynchon", "david foster wallace",
            "fyodor dostoevsky", "leo tolstoy", "marcel proust", "herman melville"
        ]

        return difficultWorks.contains(where: { title.contains($0) }) ||
               difficultAuthors.contains(where: { author.contains($0) })
    }

    // MARK: - Challenge Identification

    private func identifyChallenges(_ book: BookModel, difficulty: DifficultyAssessment) -> [ReaderChallenge] {
        var challenges: [ReaderChallenge] = []

        // Era-based challenges
        if difficulty.era == .ancient || difficulty.era == .classical {
            challenges.append(ReaderChallenge(
                type: .unfamiliarContext,
                description: "The world this was written in is very different from ours",
                mitigation: "A brief historical context will help ground you",
                severity: .moderate
            ))
        }

        // Language challenges
        if difficulty.languageComplexity == .archaic {
            challenges.append(ReaderChallenge(
                type: .complexLanguage,
                description: "The language style may feel unfamiliar at first",
                mitigation: "Reading aloud can help with rhythm; it gets easier after a few pages",
                severity: .moderate
            ))

            challenges.append(ReaderChallenge(
                type: .translationArtifacts,
                description: "Translation choices affect how the text reads",
                mitigation: "Don't worry about 'getting' every line perfectly",
                severity: .minor
            ))
        }

        // Structure challenges
        if difficulty.structuralComplexity == .episodic {
            challenges.append(ReaderChallenge(
                type: .nonLinearStructure,
                description: "The story is told in episodes rather than one continuous narrative",
                mitigation: "Each section is its own adventure; treat them like connected short stories",
                severity: .minor
            ))
        }

        // Length challenges
        if let pages = book.pageCount, pages > 500 {
            challenges.append(ReaderChallenge(
                type: .lengthEndurance,
                description: "This is a substantial commitment at \(pages) pages",
                mitigation: "Break it into smaller reading goals; this isn't a race",
                severity: pages > 800 ? .moderate : .minor
            ))
        }

        // Check for character-heavy works
        let characterHeavyIndicators = ["war and peace", "game of thrones", "malazan", "wheel of time", "stormlight"]
        if characterHeavyIndicators.contains(where: { book.title.lowercased().contains($0) }) {
            challenges.append(ReaderChallenge(
                type: .largeCharacterCast,
                description: "Many characters to keep track of",
                mitigation: "Keep a character list handy; don't stress about remembering everyone immediately",
                severity: .moderate
            ))
        }

        // Check for unfamiliar name patterns
        let unfamiliarNameIndicators = ["russian", "odyssey", "iliad", "chinese", "japanese", "indian", "arabic"]
        let titleAndDesc = (book.title + " " + (book.description ?? "")).lowercased()
        if unfamiliarNameIndicators.contains(where: { titleAndDesc.contains($0) }) {
            challenges.append(ReaderChallenge(
                type: .unfamiliarNames,
                description: "Character names may be unfamiliar",
                mitigation: "A pronunciation guide can help; names become familiar quickly",
                severity: .minor
            ))
        }

        return challenges
    }

    // MARK: - Approach Recommendation

    private func recommendApproach(_ book: BookModel, difficulty: DifficultyAssessment, challenges: [ReaderChallenge]) -> ApproachRecommendation {

        var strategy: ReadingStrategy = .immersive
        var paceGuidance = "Read at your own pace and enjoy the journey."
        var preparationSteps: [String] = []
        var tips: [String] = []
        var tools: [ReadingTool] = []

        // Adjust based on difficulty
        switch difficulty.level {
        case .challenging:
            strategy = .guided
            paceGuidance = "Take your time. This rewards slow, thoughtful reading. Consider reading in focused sessions of 30-60 minutes."
            preparationSteps.append("Read a brief introduction to understand the context")
            preparationSteps.append("Know that the first 50 pages are often the hardest — it gets easier")
            tips.append("Don't worry about understanding everything on the first pass")
            tips.append("Re-reading passages is part of the experience, not a failure")
            tools.append(.readingGuide)

        case .moderate:
            strategy = .episodic
            paceGuidance = "A comfortable pace with breaks for reflection works well."
            preparationSteps.append("A quick overview of what to expect can help")
            tips.append("Trust the author; confusion early on usually resolves")

        case .accessible:
            strategy = .immersive
            paceGuidance = "Dive in and let the story carry you."
        }

        // Adjust based on specific challenges
        for challenge in challenges {
            switch challenge.type {
            case .largeCharacterCast:
                tools.append(.characterList)
                tips.append("Keep a character reference handy — or use mine")

            case .unfamiliarContext:
                preparationSteps.append("5 minutes of historical context will enrich your reading")

            case .complexLanguage:
                tips.append("Try reading aloud — it helps with rhythm and comprehension")
                tips.append("Many readers find audiobook + text together helpful")
                tools.append(.audioCompanion)

            case .nonLinearStructure:
                tools.append(.timeline)
                tips.append("A timeline can help if you feel lost")

            case .lengthEndurance:
                tips.append("Set small, achievable reading goals")
                tips.append("This is a marathon, not a sprint — celebrate progress")

            default:
                break
            }
        }

        // Era-specific adjustments
        if difficulty.era == .ancient {
            preparationSteps.insert("Understand this was originally performed orally — reading aloud honors that tradition", at: 0)
            tips.append("Epithets (\"rosy-fingered Dawn\") are features, not bugs — they're memory aids from oral tradition")
        }

        return ApproachRecommendation(
            readingStrategy: strategy,
            paceGuidance: paceGuidance,
            preparationSteps: preparationSteps,
            duringReadingTips: tips,
            toolsRecommended: tools
        )
    }

    // MARK: - Spoiler Boundaries

    private func determineSpoilerBoundaries(_ book: BookModel) -> SpoilerBoundaries {
        // Safe content that never spoils
        var safeContent: [SpoilerSafeContent] = [
            SpoilerSafeContent(content: "Historical and cultural context", category: .historicalContext),
            SpoilerSafeContent(content: "Author background and intentions", category: .authorBackground),
            SpoilerSafeContent(content: "Genre conventions and what to expect", category: .genreConventions),
            SpoilerSafeContent(content: "Opening situation and character introductions", category: .characterIntroductions),
            SpoilerSafeContent(content: "Setting and world details", category: .settingDetails),
            SpoilerSafeContent(content: "Thematic elements to watch for", category: .thematicSetup)
        ]

        // Progress-gated content
        let progressGated: [ProgressGatedContent] = [
            ProgressGatedContent(content: "Character development arcs", revealAfterPercent: 0.25, category: "Character"),
            ProgressGatedContent(content: "Major plot developments", revealAfterPercent: 0.5, category: "Plot"),
            ProgressGatedContent(content: "Thematic resolutions", revealAfterPercent: 0.75, category: "Theme")
        ]

        // Universal spoiler protections
        let neverReveal = [
            "Ending or resolution",
            "Major character deaths",
            "Plot twists",
            "Mystery solutions",
            "Character betrayals",
            "Final fates"
        ]

        return SpoilerBoundaries(
            safeToReveal: safeContent,
            revealAfterProgress: progressGated,
            neverReveal: neverReveal
        )
    }

    // MARK: - Context Needs

    private func identifyContextNeeds(_ book: BookModel, difficulty: DifficultyAssessment) -> [ContextNeed] {
        var needs: [ContextNeed] = []

        // Era-based context
        switch difficulty.era {
        case .ancient:
            needs.append(ContextNeed(
                type: .historical,
                importance: .essential,
                briefing: "Understanding the ancient world this comes from",
                fullContext: "This work comes from a world very different from ours — understanding its original context and audience enriches the experience."
            ))
            needs.append(ContextNeed(
                type: .mythological,
                importance: .helpful,
                briefing: "Greek mythology and religion",
                fullContext: "The gods aren't metaphors — they're real forces in this world. Understanding the Olympian pantheon helps."
            ))
            needs.append(ContextNeed(
                type: .linguistic,
                importance: .helpful,
                briefing: "Oral poetry conventions",
                fullContext: "This was composed for performance, not reading. Repetitive phrases, epithets, and elaborate descriptions are features of the form."
            ))

        case .classical:
            needs.append(ContextNeed(
                type: .cultural,
                importance: .helpful,
                briefing: "Medieval/Renaissance worldview",
                fullContext: "The society and values depicted may seem alien — understanding the historical context helps bridge the gap."
            ))

        case .earlyModern:
            needs.append(ContextNeed(
                type: .historical,
                importance: .helpful,
                briefing: "Social context of the era",
                fullContext: "Class, gender, and social expectations were very different — this context illuminates character motivations."
            ))

        default:
            break
        }

        // Structure-based context
        if difficulty.structuralComplexity == .episodic {
            needs.append(ContextNeed(
                type: .structural,
                importance: .helpful,
                briefing: "How the work is organized",
                fullContext: "This isn't a conventional novel structure. Understanding the episodic format helps set expectations."
            ))
        }

        // Known works get specific context
        let title = book.title.lowercased()
        if title.contains("odyssey") {
            needs.append(ContextNeed(
                type: .literary,
                importance: .essential,
                briefing: "This is a sequel to The Iliad",
                fullContext: "The Odyssey assumes you know the story of the Trojan War. A quick summary of The Iliad's key events helps."
            ))
        }

        return needs
    }

    // MARK: - Curated Intelligence

    /// Returns hand-crafted intelligence for specific well-known books
    private func getCuratedIntelligence(for book: BookModel) -> BookProfile? {
        let title = book.title.lowercased()

        // The Odyssey
        if title.contains("odyssey") && book.author.lowercased().contains("homer") {
            return createOdysseyProfile(book)
        }

        // Add more curated profiles as needed
        // War and Peace, Ulysses, Infinite Jest, etc.

        return nil
    }

    private func createOdysseyProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .challenging,
            era: .ancient,
            reasons: [
                "Ancient epic poetry with oral tradition conventions",
                "Requires mythological knowledge",
                "Cultural distance of 2,800 years",
                "Non-chronological narrative structure"
            ],
            isKnownDifficultWork: true,
            languageComplexity: .archaic,
            structuralComplexity: .episodic
        )

        let challenges = [
            ReaderChallenge(
                type: .unfamiliarContext,
                description: "The Greek world of gods, heroes, and fate is very different from ours",
                mitigation: "A 5-minute primer on Greek mythology and the Trojan War backstory helps immensely",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .complexLanguage,
                description: "Translated epic poetry has a different rhythm than modern prose",
                mitigation: "Try reading aloud — this was meant to be heard. The rhythm becomes natural after a few pages.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .nonLinearStructure,
                description: "The story doesn't start at the beginning — Odysseus's journey is told in flashbacks",
                mitigation: "Books 1-4 are about Odysseus's son; Odysseus himself appears in Book 5. The flashbacks come in Books 9-12.",
                severity: .minor
            ),
            ReaderChallenge(
                type: .unfamiliarNames,
                description: "Greek names and places may be unfamiliar",
                mitigation: "Pronunciation doesn't have to be perfect. Focus on the major characters first.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .guided,
            paceGuidance: "Read 1-2 books (chapters) per sitting. These were originally performed as entertainment — they're meant to be savored, not rushed.",
            preparationSteps: [
                "Spend 5 minutes on Trojan War backstory (The Iliad summary)",
                "Know the main Olympian gods and their domains",
                "Understand that 'books' are chapters, not volumes",
                "Consider which translation you have — Fagles and Wilson are very readable"
            ],
            duringReadingTips: [
                "Epithets like 'wine-dark sea' are features, not bugs — enjoy them",
                "The gods are characters, not metaphors — they intervene directly",
                "Reading aloud helps with the poetry's rhythm",
                "Don't worry about every detail — focus on the adventure"
            ],
            toolsRecommended: [.characterList, .audioCompanion, .readingGuide]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "The Trojan War has ended and Odysseus is trying to get home", category: .thematicSetup),
                SpoilerSafeContent(content: "Odysseus is clever and resourceful — 'polytropos' means 'man of many turns'", category: .characterIntroductions),
                SpoilerSafeContent(content: "Gods take sides and actively help or hinder mortals", category: .settingDetails),
                SpoilerSafeContent(content: "This is ultimately a homecoming story", category: .thematicSetup)
            ],
            revealAfterProgress: [
                ProgressGatedContent(content: "Odysseus's specific adventures", revealAfterPercent: 0.3, category: "Plot"),
                ProgressGatedContent(content: "The situation in Ithaca", revealAfterPercent: 0.5, category: "Plot")
            ],
            neverReveal: [
                "How Odysseus defeats the suitors",
                "The reunion with Penelope",
                "Specific character deaths"
            ]
        )

        let context = [
            ContextNeed(
                type: .mythological,
                importance: .essential,
                briefing: "Greek gods and the Trojan War",
                fullContext: "This story takes place in a world where gods are real and actively involved in human affairs. The Trojan War just ended — Odysseus was one of the Greek heroes, famous for the wooden horse trick."
            ),
            ContextNeed(
                type: .linguistic,
                importance: .helpful,
                briefing: "Oral poetry tradition",
                fullContext: "Homer (if he existed) didn't write this down — it was performed from memory. Repeated phrases, elaborate descriptions, and epithets helped bards remember and audiences follow."
            ),
            ContextNeed(
                type: .structural,
                importance: .helpful,
                briefing: "The 24-book structure",
                fullContext: "The poem is divided into 24 'books' (chapters). Books 1-4 focus on Odysseus's son Telemachus. Odysseus himself appears in Book 5. His famous adventures are told as flashbacks in Books 9-12."
            )
        ]

        return BookProfile(
            book: book,
            difficulty: difficulty,
            challenges: challenges,
            approachRecommendation: approach,
            spoilerBoundaries: spoilers,
            contextNeeds: context
        )
    }
}
