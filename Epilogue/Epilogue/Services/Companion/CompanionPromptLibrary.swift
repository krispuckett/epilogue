import Foundation

// MARK: - Companion Prompt Library
/// A curated library of prompts for the Reading Companion.
/// These prompts are designed to generate helpful, spoiler-free guidance.

@MainActor
final class CompanionPromptLibrary {
    static let shared = CompanionPromptLibrary()

    private init() {}

    // MARK: - Preparation Prompts

    /// Generate a spoiler-free introduction prompt
    func preparationPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        var prompt = """
        I'm about to start reading "\(book.title)" by \(book.author).

        Give me a spoiler-free introduction that helps me understand:
        1. What kind of book this is and what to expect
        2. Any historical or cultural context I should know
        3. What makes this book special or enduring
        4. One thing that will help me enjoy it more

        Keep it conversational and encouraging — I'm excited to start but maybe a little intimidated.
        Don't summarize the plot. Just help me feel prepared to begin.
        """

        // Add specific context needs
        let essentialContext = profile.contextNeeds.filter { $0.importance == .essential }
        if !essentialContext.isEmpty {
            prompt += "\n\nSpecifically, I might need context about:"
            for need in essentialContext {
                prompt += "\n- \(need.briefing)"
            }
        }

        return prompt
    }

    // MARK: - Approach Prompts

    /// Generate a "how to read this" prompt
    func approachPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book
        let approach = profile.approachRecommendation

        var prompt = """
        I'm starting "\(book.title)" and want to know: how should I approach reading this?

        I'm looking for practical advice like:
        - What reading pace works best?
        - Should I take notes or just read?
        - Any tips for getting through challenging parts?
        - What should I pay attention to?

        Be specific to this book, not generic advice. Help me read this the way it deserves to be read.
        """

        // Add challenge-specific requests
        for challenge in profile.challenges.prefix(2) {
            prompt += "\n\nI've heard readers sometimes struggle with: \(challenge.description)"
        }

        return prompt
    }

    // MARK: - Context Prompts

    /// Generate a context-providing prompt
    func contextPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        var prompt = """
        Before I read "\(book.title)", give me essential context that will enrich my understanding.

        I want to know:
        1. When and where was this written, and why does that matter?
        2. What was the author's world like?
        3. Any cultural knowledge that helps?
        4. How was this originally received?

        Make it interesting — I want context, not a history lecture.
        Don't tell me what happens in the story.
        """

        // Add era-specific context requests
        switch profile.difficulty.era {
        case .ancient:
            prompt += "\n\nThis is an ancient text, so I especially want to understand the world it came from."
        case .classical:
            prompt += "\n\nI'd like to understand the medieval/Renaissance context."
        case .earlyModern:
            prompt += "\n\nHelp me understand the social world of this era."
        default:
            break
        }

        return prompt
    }

    // MARK: - Character Guide Prompts

    /// Generate a character introduction prompt
    func characterGuidePrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        I'm starting "\(book.title)" and I've heard there are many characters to track.

        Give me a spoiler-free guide to the main characters I'll meet early on:
        - Who are the key people I should pay attention to?
        - How do I keep track of them?
        - Are there any naming patterns that help (like Russian patronymics)?
        - Any pronunciation tips for names?

        Only describe who they are at the beginning — don't tell me what happens to them!
        Focus on the 5-8 most important characters to start.
        """
    }

    // MARK: - Structure Guide Prompts

    /// Generate a structure explanation prompt
    func structureGuidePrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        Help me understand how "\(book.title)" is structured.

        I want to know:
        - How is the book organized (books, parts, chapters)?
        - Is the story told chronologically?
        - Are there multiple narrators or perspectives?
        - Anything about the structure that might confuse me at first?

        Just explain the form, not the content. I want to know what to expect structurally.
        """
    }

    // MARK: - Check-In Prompts

    /// Generate an early reading check-in prompt
    func earlyCheckInPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        I'm in the early pages of "\(book.title)".

        How are you finding it so far?

        If you're feeling:
        - Confused → That's normal! The beginning is often the hardest. What's unclear?
        - Slow → The pace often picks up. Hang in there.
        - Curious → What's catching your attention?
        - Overwhelmed → Let's break it down. What would help right now?

        I'm here to help you get into the rhythm of this book.
        """
    }

    // MARK: - Theme Discussion Prompts

    /// Generate a theme exploration prompt
    func themeDiscussionPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        You're well into "\(book.title)" now.

        What themes or ideas are you noticing? I'd love to discuss:
        - Patterns you're seeing
        - Characters or situations that resonate with you
        - Questions the book is raising
        - Connections to other books or your own experience

        This is your reading — I'm curious what's standing out to you.
        """
    }

    // MARK: - Near-End Prompts

    /// Generate a reflection prompt for readers nearing the end
    func nearEndReflectionPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        You're approaching the end of "\(book.title)".

        How is this landing for you?

        Some readers like to:
        - Slow down and savor the final pages
        - Rush to the ending and then sit with it
        - Take a break before the finale to build anticipation

        Whatever feels right is right. What's resonating with you as you near the end?
        """
    }

    // MARK: - Clarification Prompts

    /// Generate a prompt when user seems confused
    func clarificationOfferPrompt(for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        Reading "\(book.title)" and feeling a bit lost?

        That's completely normal — this book asks a lot of readers.

        I can help clarify:
        - Who's who (character confusion)
        - What's happening (plot confusion)
        - Why something matters (context confusion)
        - How to read this (approach confusion)

        What would be most helpful right now?
        """
    }

    // MARK: - Encouragement Prompts

    /// Generate encouraging messages for readers who might need motivation
    func encouragementPrompt(for profile: BookIntelligence.BookProfile, progress: Double) -> String {
        let book = profile.book

        if progress < 0.15 {
            return """
            The beginning of "\(book.title)" is notoriously challenging.

            You're not supposed to understand everything yet. Keep going — the pieces will start falling into place.

            Many readers who now love this book struggled through these early pages. You're not alone.
            """
        } else if progress < 0.3 {
            return """
            You're building momentum with "\(book.title)".

            The hardest part — getting oriented in this world — is behind you.

            You're starting to understand the rhythm. Trust the author; they know where they're taking you.
            """
        } else if progress < 0.7 {
            return """
            You're in the heart of "\(book.title)" now.

            This is where the investment pays off. The world, the characters, the themes — they're all clicking into place.

            Enjoy this part. You've earned it.
            """
        } else {
            return """
            The home stretch of "\(book.title)".

            Everything is building toward resolution. Whatever you're feeling — tension, anticipation, reluctance to end — that's the book working on you.

            You're almost there.
            """
        }
    }

    // MARK: - Dynamic Prompts

    /// Generate a context-aware follow-up question
    func followUpPrompt(after previousTopic: String, for profile: BookIntelligence.BookProfile) -> String {
        let book = profile.book

        return """
        We were just discussing \(previousTopic) in "\(book.title)".

        Would you like to explore this further, or is there something else on your mind about the book?

        I can:
        - Go deeper on what we were discussing
        - Explain how this connects to other elements
        - Move on to a different topic
        - Just let you get back to reading

        What would be helpful?
        """
    }

    // MARK: - Book-Specific Prompts

    /// Get curated prompts for well-known books
    func curatedPrompts(for bookTitle: String) -> [String: String]? {
        let title = bookTitle.lowercased()

        // The Odyssey
        if title.contains("odyssey") {
            return [
                "preparation": """
                I'm about to read The Odyssey for the first time.

                Give me a 2-minute primer on what I need to know:
                - What happened in The Iliad (the prequel)
                - The main Greek gods I'll encounter
                - How epic poetry works (epithets, structure)
                - One thing that will help me enjoy this more

                Keep it conversational. I'm excited but a bit intimidated.
                """,

                "approach": """
                How should I read The Odyssey?

                I've heard it's structured unusually and has lots of epithets and repetition.

                Give me practical reading advice:
                - How fast should I read?
                - Should I read it aloud?
                - How do I handle the epithets?
                - What's the structure I should expect?
                """,

                "context": """
                Help me understand the world of The Odyssey.

                What was ancient Greece like when this was written (performed)?
                Why were the gods so involved in human affairs?
                What was hospitality (xenia) and why does it matter?
                What did the ancient Greeks value?

                Make it interesting, not academic.
                """,

                "characters": """
                Give me a spoiler-free guide to the characters in The Odyssey.

                Who are the main mortals and gods I need to track?
                Just describe who they are at the start — not what happens to them.
                Focus on the most important 8-10 characters.
                Include pronunciation tips if names are tricky.
                """
            ]
        }

        // War and Peace
        if title.contains("war and peace") {
            return [
                "preparation": """
                I'm starting War and Peace.

                Give me what I need to know to begin:
                - The historical setting (Russia, Napoleon)
                - How Russian names work (those patronymics!)
                - The main families I'll follow
                - Why this book is worth the commitment

                I'm intimidated by the length but excited. Help me feel prepared.
                """,

                "characters": """
                I need a character guide for War and Peace.

                Explain the Russian naming system (first name, patronymic, last name, nicknames).
                Introduce the main families without spoilers.
                Who should I really pay attention to?
                Any tips for keeping track of everyone?
                """
            ]
        }

        // Infinite Jest
        if title.contains("infinite jest") {
            return [
                "approach": """
                How should I approach reading Infinite Jest?

                I've heard it's notoriously difficult with:
                - Endnotes that are essential
                - Non-linear structure
                - Many characters
                - Dense prose

                Give me practical strategies for actually getting through this.
                Should I use two bookmarks? Read on an e-reader? Take notes?
                """
            ]
        }

        return nil
    }

    // MARK: - Pill Text Generation

    /// Generate short, tappable pill suggestions based on context
    func pillSuggestions(for profile: BookIntelligence.BookProfile, progress: Double) -> [String] {
        var pills: [String] = []

        // New to book
        if progress < 0.05 {
            if profile.needsPreparation {
                pills.append("What should I know first?")
                pills.append("How do I approach this?")
            }
            pills.append("Tell me about the author")
        }

        // Early reading
        else if progress < 0.2 {
            pills.append("I'm confused about something")
            if profile.challenges.contains(where: { $0.type == .largeCharacterCast }) {
                pills.append("Who's who again?")
            }
            pills.append("Is this supposed to be hard?")
        }

        // Mid reading
        else if progress < 0.7 {
            pills.append("What themes am I seeing?")
            pills.append("Help me with this section")
            pills.append("What should I watch for?")
        }

        // Near end
        else {
            pills.append("How should I finish this?")
            pills.append("What did I miss?")
            pills.append("What should I read next?")
        }

        return pills
    }
}
