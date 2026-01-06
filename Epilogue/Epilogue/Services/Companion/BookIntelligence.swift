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
        if let yearStr = book.publishedYear,
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
        let desc = (book.desc ?? "").lowercased()

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
        let desc = (book.desc ?? "").lowercased()

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
        let titleAndDesc = (book.title + " " + (book.desc ?? "")).lowercased()
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
        let author = book.author.lowercased()

        // The Odyssey
        if title.contains("odyssey") && author.contains("homer") {
            return createOdysseyProfile(book)
        }

        // War and Peace
        if title.contains("war and peace") && author.contains("tolstoy") {
            return createWarAndPeaceProfile(book)
        }

        // The Brothers Karamazov
        if title.contains("karamazov") && author.contains("dostoevsky") {
            return createBrothersKaramazovProfile(book)
        }

        // Lord of the Rings
        if title.contains("lord of the rings") || title.contains("fellowship") ||
           title.contains("two towers") || title.contains("return of the king") {
            if author.contains("tolkien") {
                return createLordOfTheRingsProfile(book)
            }
        }

        // Infinite Jest
        if title.contains("infinite jest") && author.contains("wallace") {
            return createInfiniteJestProfile(book)
        }

        // Moby Dick
        if title.contains("moby") && author.contains("melville") {
            return createMobyDickProfile(book)
        }

        // 1984
        if (title.contains("1984") || title.contains("nineteen eighty")) && author.contains("orwell") {
            return create1984Profile(book)
        }

        // Project Hail Mary
        if title.contains("hail mary") && author.contains("weir") {
            return createProjectHailMaryProfile(book)
        }

        // The Count of Monte Cristo
        if title.contains("monte cristo") && author.contains("dumas") {
            return createMontesCristoProfile(book)
        }

        // Dune
        if title == "dune" && author.contains("herbert") {
            return createDuneProfile(book)
        }

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

    // MARK: - War and Peace

    private func createWarAndPeaceProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .challenging,
            era: .earlyModern,
            reasons: [
                "Epic length (over 1,200 pages)",
                "Large cast of characters with Russian naming conventions",
                "Historical backdrop requires context",
                "Philosophical digressions"
            ],
            isKnownDifficultWork: true,
            languageComplexity: .literary,
            structuralComplexity: .episodic
        )

        let challenges = [
            ReaderChallenge(
                type: .unfamiliarNames,
                description: "Russian names use first name + patronymic (father's name) + surname, plus nicknames",
                mitigation: "Prince Andrei Nikolayevich Bolkonsky might be called Andrei, Andryusha, or Prince Bolkonsky. Keep a character list handy for the first 100 pages.",
                severity: .significant
            ),
            ReaderChallenge(
                type: .largeCharacterCast,
                description: "Dozens of characters across three main families",
                mitigation: "Focus on the Rostovs, Bolkonskys, and Bezukhovs first. Everyone else is secondary.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .lengthEndurance,
                description: "This is a marathon, not a sprint",
                mitigation: "Set a sustainable pace — 20-30 pages per day works well. The book rewards patience.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .philosophicalDensity,
                description: "Tolstoy includes essays on history and philosophy",
                mitigation: "You can skim these sections on first read without losing the story. Come back to them later.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .episodic,
            paceGuidance: "20-30 pages per day is sustainable. Don't try to finish quickly — let it unfold.",
            preparationSteps: [
                "Understand Russian naming: First name, Patronymic (father's name + ovich/ovna), Surname",
                "Know the three main families: Rostovs, Bolkonskys, Bezukhovs",
                "Brief context: Napoleonic Wars, 1805-1812 Russia",
                "Keep a simple character list for the first few hundred pages"
            ],
            duringReadingTips: [
                "When confused by names, look for context clues — 'the countess' helps identify which woman",
                "The war scenes and peace scenes alternate — both are essential",
                "Tolstoy's philosophy sections can be skimmed if they slow you down",
                "Pay attention to the main characters' growth — that's the heart of the book"
            ],
            toolsRecommended: [.characterList, .timeline, .annotatedEdition]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Three aristocratic Russian families during the Napoleonic Wars", category: .thematicSetup),
                SpoilerSafeContent(content: "Pierre Bezukhov: illegitimate son seeking meaning", category: .characterIntroductions),
                SpoilerSafeContent(content: "Prince Andrei Bolkonsky: disillusioned aristocrat", category: .characterIntroductions),
                SpoilerSafeContent(content: "Natasha Rostova: spirited young countess", category: .characterIntroductions)
            ],
            revealAfterProgress: [
                ProgressGatedContent(content: "Pierre's marriage complications", revealAfterPercent: 15, category: "Plot"),
                ProgressGatedContent(content: "Andrei's war experiences", revealAfterPercent: 20, category: "Plot"),
                ProgressGatedContent(content: "Natasha's coming of age", revealAfterPercent: 40, category: "Plot")
            ],
            neverReveal: [
                "Major character deaths",
                "Final romantic pairings",
                "The fate of Moscow",
                "The epilogue revelations"
            ]
        )

        let context = [
            ContextNeed(
                type: .historical,
                importance: .essential,
                briefing: "Napoleonic Wars and Russian society",
                fullContext: "Russia in 1805-1812, during Napoleon's campaigns. The aristocracy spoke French, owned serfs, and faced an existential threat when Napoleon invaded."
            ),
            ContextNeed(
                type: .cultural,
                importance: .helpful,
                briefing: "Russian aristocratic life",
                fullContext: "The Russian nobility lived in a complex social world with strict codes of honor, arranged marriages, and vast estates worked by serfs."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - The Brothers Karamazov

    private func createBrothersKaramazovProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .challenging,
            era: .earlyModern,
            reasons: [
                "Dense philosophical and theological discussions",
                "Complex family dynamics",
                "Russian naming conventions",
                "Heavy themes requiring reflection"
            ],
            isKnownDifficultWork: true,
            languageComplexity: .literary,
            structuralComplexity: .conventional
        )

        let challenges = [
            ReaderChallenge(
                type: .philosophicalDensity,
                description: "Famous chapters like 'The Grand Inquisitor' are dense philosophical arguments",
                mitigation: "These sections reward slow, careful reading. Take breaks to reflect.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .unfamiliarNames,
                description: "Multiple names per character plus Russian patronymics",
                mitigation: "Dmitri/Mitya, Ivan/Vanya, Alexei/Alyosha are the same people. Keep a simple reference.",
                severity: .moderate
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .analytical,
            paceGuidance: "Take your time with the philosophical sections. This book repays slow reading.",
            preparationSteps: [
                "Know the three brothers: Dmitri (passionate), Ivan (intellectual), Alyosha (spiritual)",
                "Understand this is about faith, doubt, morality, and family",
                "Russian naming: First name + patronymic + surname, plus diminutives"
            ],
            duringReadingTips: [
                "The 'Grand Inquisitor' chapter is famous — read it slowly",
                "Each brother represents a different response to existence",
                "Don't rush the trial sections",
                "Father Zosima's teachings are thematically central"
            ],
            toolsRecommended: [.characterList, .readingGuide, .discussionQuestions]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "A dysfunctional family of a father and three sons", category: .thematicSetup),
                SpoilerSafeContent(content: "Themes of faith, doubt, and moral responsibility", category: .thematicSetup)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "Who killed Fyodor Pavlovich",
                "The trial verdict",
                "Character deaths and fates"
            ]
        )

        let context = [
            ContextNeed(
                type: .philosophical,
                importance: .helpful,
                briefing: "19th century Russian religious and philosophical debates",
                fullContext: "Dostoevsky was wrestling with atheism, Christianity, and the problem of evil. The brothers represent different philosophical positions."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - Lord of the Rings

    private func createLordOfTheRingsProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .moderate,
            era: .modern,
            reasons: [
                "Dense world-building with invented languages",
                "Large cast of characters with unusual names",
                "Epic length across three volumes",
                "Archaic prose style"
            ],
            isKnownDifficultWork: false,
            languageComplexity: .literary,
            structuralComplexity: .conventional
        )

        let challenges = [
            ReaderChallenge(
                type: .unfamiliarNames,
                description: "Elvish names, place names, and archaic English",
                mitigation: "Don't worry about pronunciation. Focus on the fellowship members first.",
                severity: .minor
            ),
            ReaderChallenge(
                type: .lengthEndurance,
                description: "Three long books with detailed descriptions",
                mitigation: "Take your time. The pacing is deliberate — let yourself settle into Middle-earth.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .immersive,
            paceGuidance: "Let yourself be immersed. The slow pacing is intentional — Tolkien wants you to live in this world.",
            preparationSteps: [
                "Know that The Hobbit comes first (but isn't required)",
                "The Ring is evil and must be destroyed in Mordor",
                "Hobbits are small, love peace, and live in the Shire"
            ],
            duringReadingTips: [
                "The songs and poems add atmosphere — you can skim them if needed",
                "Tom Bombadil is meant to be mysterious",
                "The appendices are optional but rewarding",
                "Trust Tolkien's pacing — the adventure builds"
            ],
            toolsRecommended: [.mapReference, .characterList]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Frodo inherits a ring that must be destroyed", category: .thematicSetup),
                SpoilerSafeContent(content: "A fellowship of nine sets out to help him", category: .thematicSetup),
                SpoilerSafeContent(content: "The ring was made by Sauron, the Dark Lord", category: .settingDetails)
            ],
            revealAfterProgress: [
                ProgressGatedContent(content: "The fellowship's composition", revealAfterPercent: 20, category: "Plot"),
                ProgressGatedContent(content: "Events in Moria", revealAfterPercent: 40, category: "Plot")
            ],
            neverReveal: [
                "Gandalf's fate and return",
                "Gollum's role in the ending",
                "The destruction of the Ring",
                "Who survives the war"
            ]
        )

        let context = [
            ContextNeed(
                type: .literary,
                importance: .enriching,
                briefing: "Tolkien's influences: Norse mythology, WWI, Catholicism",
                fullContext: "Tolkien was a WWI veteran, a medieval scholar, and a devout Catholic. The themes of sacrifice, corruption, and hope reflect his experiences."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - Infinite Jest

    private func createInfiniteJestProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .challenging,
            era: .contemporary,
            reasons: [
                "1,000+ pages with essential endnotes",
                "Non-linear, fragmented narrative",
                "Dense, complex prose",
                "No clear plot structure initially"
            ],
            isKnownDifficultWork: true,
            languageComplexity: .literary,
            structuralComplexity: .nonLinear
        )

        let challenges = [
            ReaderChallenge(
                type: .nonLinearStructure,
                description: "The timeline is scrambled and won't make sense until late in the book",
                mitigation: "Trust the process. Themes and characters will connect as you go.",
                severity: .significant
            ),
            ReaderChallenge(
                type: .lengthEndurance,
                description: "1,000+ pages with 400 pages of endnotes",
                mitigation: "Use two bookmarks. Read the endnotes — many are essential. Don't rush.",
                severity: .significant
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .guided,
            paceGuidance: "20-30 pages per day. Use two bookmarks (one for text, one for endnotes). This is a commitment.",
            preparationSteps: [
                "Accept that confusion is intentional and temporary",
                "Get two bookmarks ready for endnote navigation",
                "Know that endnotes are often essential, not supplementary",
                "Set a sustainable pace — this isn't a book to rush"
            ],
            duringReadingTips: [
                "Endnotes are essential — read them when referenced",
                "Don't try to 'figure it out' — let it unfold",
                "Pay attention to recurring themes: entertainment, addiction, communication",
                "The tennis academy and halfway house stories will connect"
            ],
            toolsRecommended: [.characterList, .readingGuide, .timeline]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Set in near-future North America with absurdist elements", category: .settingDetails),
                SpoilerSafeContent(content: "Two main settings: a tennis academy and a halfway house", category: .settingDetails),
                SpoilerSafeContent(content: "Themes of entertainment addiction and genuine communication", category: .thematicSetup)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "What the 'entertainment' cartridge does",
                "The fate of major characters",
                "How the storylines connect",
                "The ending (or lack thereof)"
            ]
        )

        let context = [
            ContextNeed(
                type: .literary,
                importance: .helpful,
                briefing: "Postmodern literature and David Foster Wallace's project",
                fullContext: "Wallace wanted to write a sincere novel in an ironic age. The difficulty is intentional — it mirrors the challenge of genuine connection in a world of entertainment."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - Moby Dick

    private func createMobyDickProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .challenging,
            era: .earlyModern,
            reasons: [
                "19th century prose style",
                "Extended digressions on whaling",
                "Philosophical density",
                "Unconventional narrative structure"
            ],
            isKnownDifficultWork: true,
            languageComplexity: .literary,
            structuralComplexity: .episodic
        )

        let challenges = [
            ReaderChallenge(
                type: .philosophicalDensity,
                description: "Melville digresses into philosophy, cetology, and metaphysics",
                mitigation: "These chapters enrich the theme of obsession. Skim if needed, but they're rewarding.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .complexLanguage,
                description: "19th century prose with Shakespearean influences",
                mitigation: "The language is deliberate — Melville is performing. Let it wash over you.",
                severity: .moderate
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .episodic,
            paceGuidance: "Read the adventure and skim the cetology on first pass. You can always return to the whale chapters.",
            preparationSteps: [
                "Know this is about obsession, not just whaling",
                "The narrator is Ishmael, but Ahab is the focus",
                "Chapters on whale anatomy are thematic, not filler",
                "This was a commercial failure in Melville's time — now it's a masterpiece"
            ],
            duringReadingTips: [
                "Chapter 1 sets the tone perfectly",
                "Ahab doesn't appear until well into the book — that's intentional",
                "The whale chapters explore obsession metaphorically",
                "The ending is famous but still powerful"
            ],
            toolsRecommended: [.annotatedEdition, .readingGuide]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Captain Ahab hunts a white whale that took his leg", category: .thematicSetup),
                SpoilerSafeContent(content: "Ishmael narrates from the whaling ship Pequod", category: .characterIntroductions),
                SpoilerSafeContent(content: "This is about obsession and the unknowable", category: .thematicSetup)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "The fate of the Pequod",
                "What happens to Ahab",
                "Who survives",
                "The final confrontation with Moby Dick"
            ]
        )

        let context = [
            ContextNeed(
                type: .historical,
                importance: .helpful,
                briefing: "19th century whaling industry",
                fullContext: "Whaling was a major industry. Whalers spent years at sea. The danger and isolation shaped the men who did this work."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - 1984

    private func create1984Profile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .accessible,
            era: .modern,
            reasons: [
                "Straightforward prose",
                "Clear narrative",
                "Themes require thought but story is accessible"
            ],
            isKnownDifficultWork: false,
            languageComplexity: .standard,
            structuralComplexity: .conventional
        )

        let challenges = [
            ReaderChallenge(
                type: .philosophicalDensity,
                description: "The 'Goldstein book' section is intentionally dense political theory",
                mitigation: "This section is meant to feel like propaganda. Don't feel you need to absorb every word.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .immersive,
            paceGuidance: "This is a page-turner. Let yourself be drawn in by the atmosphere.",
            preparationSteps: [
                "Written in 1948 about totalitarianism",
                "Newspeak, doublethink, and Big Brother are now in our vocabulary",
                "This is a warning, not a prophecy"
            ],
            duringReadingTips: [
                "Pay attention to the language — 'Newspeak' is thematically central",
                "Part 2 (the book-within-a-book) is meant to feel like propaganda",
                "The appendix on Newspeak is worth reading",
                "Notice how hope and despair alternate"
            ],
            toolsRecommended: [.discussionQuestions]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Winston Smith lives in a totalitarian society", category: .thematicSetup),
                SpoilerSafeContent(content: "Big Brother is always watching", category: .settingDetails),
                SpoilerSafeContent(content: "Thoughtcrime is the ultimate offense", category: .settingDetails)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "Winston's fate",
                "The nature of Room 101",
                "What happens to Julia",
                "The ending"
            ]
        )

        let context = [
            ContextNeed(
                type: .historical,
                importance: .helpful,
                briefing: "Post-WWII fears of totalitarianism",
                fullContext: "Orwell wrote this in 1948 after witnessing the rise of Stalinism and fascism. It's a warning about how totalitarianism controls reality."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - Project Hail Mary

    private func createProjectHailMaryProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .accessible,
            era: .contemporary,
            reasons: [
                "Fast-paced, engaging prose",
                "Science is explained clearly",
                "Strong narrative drive"
            ],
            isKnownDifficultWork: false,
            languageComplexity: .conversational,
            structuralComplexity: .nonLinear
        )

        let challenges = [
            ReaderChallenge(
                type: .nonLinearStructure,
                description: "The story alternates between present and flashbacks",
                mitigation: "The flashbacks fill in context as needed. Trust the structure.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .immersive,
            paceGuidance: "This is a page-turner. Let yourself be swept along by the problem-solving.",
            preparationSteps: [
                "You don't need a science background — Weir explains everything",
                "The structure uses flashbacks effectively",
                "This is about ingenuity and friendship"
            ],
            duringReadingTips: [
                "The science is real (mostly) — enjoy the problem-solving",
                "The flashbacks become important",
                "Pay attention to Grace's personality",
                "The friendship that develops is the heart of the book"
            ],
            toolsRecommended: [.audioCompanion]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "An astronaut wakes up alone with no memory of his mission", category: .thematicSetup),
                SpoilerSafeContent(content: "Earth is in danger and he has to figure out why and how to help", category: .thematicSetup)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "Who/what Rocky is",
                "The nature of the astrophage",
                "The ending choices",
                "Grace's backstory revelations"
            ]
        )

        let context = [
            ContextNeed(
                type: .literary,
                importance: .enriching,
                briefing: "From the author of The Martian",
                fullContext: "Andy Weir writes scientifically accurate adventure stories. Like The Martian, this features a protagonist who thinks their way out of impossible situations."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - The Count of Monte Cristo

    private func createMontesCristoProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .moderate,
            era: .earlyModern,
            reasons: [
                "Epic length (unabridged)",
                "19th century French novel conventions",
                "Large cast of characters",
                "Complex revenge plot"
            ],
            isKnownDifficultWork: false,
            languageComplexity: .standard,
            structuralComplexity: .conventional
        )

        let challenges = [
            ReaderChallenge(
                type: .lengthEndurance,
                description: "Unabridged version is 1,200+ pages",
                mitigation: "The length allows for satisfying payoffs. Each subplot connects to the revenge.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .largeCharacterCast,
                description: "Many characters with French names across decades",
                mitigation: "Keep a simple family tree. Characters return years later — pay attention to names.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .immersive,
            paceGuidance: "This is a page-turner despite its length. Let the revenge unfold at its own pace.",
            preparationSteps: [
                "Choose unabridged if possible — the subplots pay off",
                "Set in early 19th century France",
                "This is the ultimate revenge story",
                "Keep track of names — people return decades later"
            ],
            duringReadingTips: [
                "Every subplot connects to the main revenge",
                "Patience pays off — Dantes' revenge is methodical",
                "The 'boring' Paris society chapters set up satisfying payoffs",
                "Trust Dumas — he's a master of suspense"
            ],
            toolsRecommended: [.characterList, .timeline]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "A young sailor is wrongly imprisoned and escapes to seek revenge", category: .thematicSetup),
                SpoilerSafeContent(content: "The ultimate revenge fantasy", category: .thematicSetup)
            ],
            revealAfterProgress: [
                ProgressGatedContent(content: "How Dantes escapes", revealAfterPercent: 15, category: "Plot"),
                ProgressGatedContent(content: "The treasure", revealAfterPercent: 20, category: "Plot")
            ],
            neverReveal: [
                "Specific revenge tactics",
                "Which villains get what fate",
                "The ending and moral resolution",
                "Dantes' romantic fate"
            ]
        )

        let context = [
            ContextNeed(
                type: .historical,
                importance: .helpful,
                briefing: "Post-Napoleonic France",
                fullContext: "Set during Napoleon's exile and return (the Hundred Days). Political allegiances could get you imprisoned or killed."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }

    // MARK: - Dune

    private func createDuneProfile(_ book: BookModel) -> BookProfile {
        let difficulty = DifficultyAssessment(
            level: .moderate,
            era: .modern,
            reasons: [
                "Dense world-building with invented terminology",
                "Political and ecological complexity",
                "Philosophical and religious themes"
            ],
            isKnownDifficultWork: false,
            languageComplexity: .standard,
            structuralComplexity: .conventional
        )

        let challenges = [
            ReaderChallenge(
                type: .unfamiliarNames,
                description: "Invented terminology: Bene Gesserit, Kwisatz Haderach, melange, etc.",
                mitigation: "There's a glossary at the back. Don't worry about pronouncing everything perfectly.",
                severity: .moderate
            ),
            ReaderChallenge(
                type: .genreConventions,
                description: "Political intrigue and ecology are central, not action",
                mitigation: "This is political science fiction. The action serves the ideas.",
                severity: .minor
            )
        ]

        let approach = ApproachRecommendation(
            readingStrategy: .analytical,
            paceGuidance: "Read carefully — Herbert rewards attention to detail. Use the glossary.",
            preparationSteps: [
                "Know this is about ecology, politics, and religion as much as adventure",
                "There's a glossary in the back — use it",
                "The Bene Gesserit are a powerful sisterhood",
                "Melange (spice) is the most valuable substance in the universe"
            ],
            duringReadingTips: [
                "The appendices add depth — read them after",
                "Paul's visions are meant to be ambiguous",
                "Pay attention to the ecology — it's central",
                "This is about the dangers of heroes, not their glory"
            ],
            toolsRecommended: [.characterList, .readingGuide]
        )

        let spoilers = SpoilerBoundaries(
            safeToReveal: [
                SpoilerSafeContent(content: "Paul Atreides's family moves to the desert planet Arrakis", category: .thematicSetup),
                SpoilerSafeContent(content: "Arrakis is the only source of the spice melange", category: .settingDetails),
                SpoilerSafeContent(content: "Political intrigue between noble houses", category: .thematicSetup)
            ],
            revealAfterProgress: [],
            neverReveal: [
                "The Harkonnen attack",
                "Paul's transformation",
                "The Fremen prophecies",
                "The climactic confrontation"
            ]
        )

        let context = [
            ContextNeed(
                type: .literary,
                importance: .enriching,
                briefing: "Herbert's influences: ecology, Middle Eastern culture, religion",
                fullContext: "Dune explores colonialism, ecology, and the danger of charismatic leaders. Herbert drew on Middle Eastern cultures and ecological science."
            )
        ]

        return BookProfile(book: book, difficulty: difficulty, challenges: challenges, approachRecommendation: approach, spoilerBoundaries: spoilers, contextNeeds: context)
    }
}
