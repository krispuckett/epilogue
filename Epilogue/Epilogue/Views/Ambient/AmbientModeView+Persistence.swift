import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientModeView+Persistence")

// MARK: - Data Persistence & Session Management
extension AmbientModeView {

    // MARK: - Save Quote to SwiftData

    @discardableResult
    func saveQuoteToSwiftData(_ content: AmbientProcessedContent) -> CapturedQuote? {
        // Clean the quote text - remove common prefixes
        var quoteText = content.text
        let lowercased = quoteText.lowercased()

        // Extended list of quote introduction patterns
        let prefixesToRemove = [
            "i love this quote.",
            "i love this quote",
            "i like this quote.",
            "i like this quote",
            "this is my favorite quote",
            "my favorite quote",
            "favorite quote",
            "great quote",
            "this quote",
            "here's a quote",
            "here is a quote",
            "quote...",
            "quote:",
            "quote "
        ]

        // Remove prefixes
        for prefix in prefixesToRemove {
            if lowercased.hasPrefix(prefix) {
                quoteText = String(quoteText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove common separators after the prefix
                if quoteText.starts(with: ":") || quoteText.starts(with: "-") || quoteText.starts(with: ".") {
                    quoteText = String(quoteText.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                break
            }
        }

        // Special handling for famous quotes that might be referenced
        // For example: "All we have to do is decide what to do with the time given to us"
        // This is Gandalf from LOTR - detect and add attribution if known
        let gandalfQuotes = [
            "all we have to do is decide what to do with the time given to us",
            "all we have to decide is what to do with the time that is given us"
        ]

        if gandalfQuotes.contains(lowercased.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // This is a Gandalf quote from LOTR
            // Note: We'll handle attribution later in the save process
        }

        // CRITICAL: Remove quotation marks for proper formatting
        // The quote card will add its own drop cap quotation mark
        quoteText = quoteText
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "") // Left double quotation mark
            .replacingOccurrences(of: "\u{201D}", with: "") // Right double quotation mark
            .replacingOccurrences(of: "\u{2018}", with: "") // Left single quotation mark
            .replacingOccurrences(of: "\u{2019}", with: "") // Right single quotation mark
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // CRITICAL: Validate quote has actual content after cleaning
        guard !quoteText.isEmpty else {
            #if DEBUG
            print("⚠️ Quote text is empty after cleaning - skipping save")
            #endif
            return nil
        }

        // Check for duplicates
        let fetchRequest = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.text == quoteText
            }
        )

        if let existingQuotes = try? modelContext.fetch(fetchRequest), !existingQuotes.isEmpty {
            #if DEBUG
            print("⚠️ Quote already exists: \(quoteText.prefix(30))...")
            #endif

            // Show graceful reminder to user
            savedItemsCount += 1
            savedItemType = "Quote (Already Saved)"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSaveAnimation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showSaveAnimation = false
                    savedItemType = nil
                }
            }

            // Still link to session if not already linked
            if let session = currentSession, let existingQuote = existingQuotes.first {
                if existingQuote.ambientSession == nil || !(session.capturedQuotes ?? []).contains(where: { $0.id == existingQuote.id }) {
                    existingQuote.ambientSession = session
                    // Check if quote is already in session's captured quotes before adding
                    if !(session.capturedQuotes ?? []).contains(where: { $0.id == existingQuote.id }) {
                        session.capturedQuotes = (session.capturedQuotes ?? []) + [existingQuote]
                    }
                    try? modelContext.save()
                    #if DEBUG
                    print("✅ Linked existing quote to current session")
                    #endif
                }
            }
            return existingQuotes.first
        }

        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            // Check if BookModel already exists in context
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )

            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
            }
        }

        // Parse attribution from quote text itself
        // Common patterns: "quote text by Author", "quote text - Author", "quote text, Author", "quote text from Book"
        var quoteAuthor: String? = currentBookContext?.author
        var parsedBookTitle: String? = nil
        var attributionWasParsed = false

        let attributionPatterns = [
            // "by Author" or "by Author, Book"
            try? NSRegularExpression(pattern: "\\s+by\\s+([^,]+)(?:,\\s*(.+))?\\s*$", options: .caseInsensitive),
            // "- Author" or "- Author, Book"
            try? NSRegularExpression(pattern: "\\s*[-—–]\\s*([^,]+)(?:,\\s*(.+))?\\s*$", options: []),
            // ", Author" at the end
            try? NSRegularExpression(pattern: ",\\s+([^,]+)\\s*$", options: [])
        ]

        for pattern in attributionPatterns.compactMap({ $0 }) {
            let range = NSRange(quoteText.startIndex..., in: quoteText)
            if let match = pattern.firstMatch(in: quoteText, range: range) {
                // Extract author
                if let authorRange = Range(match.range(at: 1), in: quoteText) {
                    let extractedAuthor = String(quoteText[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extractedAuthor.isEmpty && extractedAuthor.count > 2 {
                        quoteAuthor = extractedAuthor
                        attributionWasParsed = true
                    }
                }

                // Extract book title if present (capture group 2)
                if match.numberOfRanges > 2, let bookRange = Range(match.range(at: 2), in: quoteText) {
                    let extractedBook = String(quoteText[bookRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extractedBook.isEmpty && extractedBook.count > 2 {
                        parsedBookTitle = extractedBook
                    }
                }

                // Remove attribution from quote text
                if let matchRange = Range(match.range, in: quoteText) {
                    quoteText = String(quoteText[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                break  // Only use first matching pattern
            }
        }

        // If we parsed a book title, try to find or create that book
        if let bookTitle = parsedBookTitle {
            let bookFetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.title == bookTitle
                }
            )

            if let existingBook = try? modelContext.fetch(bookFetchRequest).first {
                bookModel = existingBook
            } else if bookModel == nil {
                // Create a new book with the parsed info
                let newBookModel = BookModel(
                    id: UUID().uuidString,
                    title: bookTitle,
                    author: quoteAuthor ?? "Unknown"
                )
                modelContext.insert(newBookModel)
                bookModel = newBookModel
            }
        }

        let cleanedQuote = quoteText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for Gandalf quotes from LOTR
        if gandalfQuotes.contains(cleanedQuote) && currentBookContext?.title.lowercased().contains("lord of the rings") == true {
            quoteAuthor = "Gandalf"
        }

        let capturedQuote = CapturedQuote(
            text: quoteText,
            book: bookModel,
            author: quoteAuthor,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )

        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedQuote.ambientSession = session
            // Check for duplicates before adding (defensive programming)
            if !(session.capturedQuotes ?? []).contains(where: { $0.text == capturedQuote.text }) {
                session.capturedQuotes = (session.capturedQuotes ?? []) + [capturedQuote]
            }
        }

        modelContext.insert(capturedQuote)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Quote saved to SwiftData with session: \(quoteText.prefix(50))...")
            #endif
            SensoryFeedback.success()
            return capturedQuote
        } catch {
            #if DEBUG
            print("❌ Failed to save quote: \(error)")
            #endif
            SensoryFeedback.error()
            NotificationCenter.default.post(
                name: .showToastMessage,
                object: ["message": "Failed to save quote. Please try again."]
            )
            return nil
        }
    }

    // MARK: - Save Note to SwiftData

    func saveNoteToSwiftData(_ content: AmbientProcessedContent) -> CapturedNote? {
        // Use the raw text as-is for consistency
        let noteText = content.text
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == noteText
            }
        )

        if let existingNotes = try? modelContext.fetch(fetchRequest), !existingNotes.isEmpty {
            #if DEBUG
            print("⚠️ Note already exists, skipping save: \(noteText.prefix(30))...")
            #endif
            return existingNotes.first
        }

        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )

            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
            }
        }

        let capturedNote = CapturedNote(
            content: content.text,
            book: bookModel,
            pageNumber: nil,
            timestamp: content.timestamp,
            source: .ambient
        )

        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedNote.ambientSession = session
            session.capturedNotes = (session.capturedNotes ?? []) + [capturedNote]
        }

        modelContext.insert(capturedNote)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Note saved to SwiftData with session: \(content.text.prefix(50))...")
            #endif
            SensoryFeedback.success()
            return capturedNote
        } catch {
            #if DEBUG
            print("❌ Failed to save note: \(error)")
            #endif
            SensoryFeedback.error()
            NotificationCenter.default.post(
                name: .showToastMessage,
                object: ["message": "Failed to save note. Please try again."]
            )
            return nil
        }
    }

    // MARK: - Save Question to SwiftData

    func saveQuestionToSwiftData(_ content: AmbientProcessedContent) {
        // Use the raw text as-is for consistency
        let questionText = content.text

        // Ensure a session exists (create if needed)
        if currentSession == nil {
            startAmbientSessionIfNeeded()
        }

        // CRITICAL: Check for duplicate questions in current session
        guard let session = currentSession else {
            #if DEBUG
            print("⚠️ No session available for saving question")
            #endif
            return
        }

        // Check if question already exists in this session
        let isDuplicate = (session.capturedQuestions ?? []).contains { question in
            question.content == questionText
        }

        if isDuplicate {
            #if DEBUG
            print("⚠️ DUPLICATE QUESTION DETECTED - NOT SAVING: \(questionText)")
            #endif
            return // EXIT EARLY - DO NOT SAVE DUPLICATE
        }

        let fetchRequest = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { question in
                question.content == questionText
            }
        )

        if let existingQuestions = try? modelContext.fetch(fetchRequest),
           let existingQuestion = existingQuestions.first {
            // Link to session if not already linked
            if let session = currentSession {
                if existingQuestion.ambientSession == nil {
                    existingQuestion.ambientSession = session
                    // Check if question is already in session before adding
                    if !(session.capturedQuestions ?? []).contains(where: { $0.id == existingQuestion.id }) {
                        session.capturedQuestions = (session.capturedQuestions ?? []) + [existingQuestion]
                    }
                    #if DEBUG
                    print("📎 Linked existing question to session: \(questionText.prefix(30))...")
                    #endif
                }
            }

            // Update answer if we have a response
            if let response = content.response, existingQuestion.answer == nil {
                existingQuestion.answer = response
                existingQuestion.isAnswered = true
            }

            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Updated existing question: \(questionText.prefix(30))...")
                #endif
                #if DEBUG
                print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update question: \(error)")
                #endif
            }
            return
        }

        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let fetchRequest = FetchDescriptor<BookModel>(
                predicate: #Predicate { model in
                    model.localId == book.localId.uuidString
                }
            )

            if let existingBook = try? modelContext.fetch(fetchRequest).first {
                bookModel = existingBook
            } else {
                let newBookModel = BookModel(from: book)
                bookModel = newBookModel
                modelContext.insert(newBookModel)
            }
        }

        let capturedQuestion = CapturedQuestion(
            content: questionText,
            book: bookModel,
            timestamp: content.timestamp,
            source: .ambient
        )

        // Add answer if available
        if let response = content.response {
            capturedQuestion.answer = response
            capturedQuestion.isAnswered = true
        }

        // CRITICAL: Set the session relationship immediately
        if let session = currentSession {
            capturedQuestion.ambientSession = session
            // Check for duplicates before adding (defensive programming)
            if !(session.capturedQuestions ?? []).contains(where: { $0.content == capturedQuestion.content }) {
                session.capturedQuestions = (session.capturedQuestions ?? []) + [capturedQuestion]
            }
        }

        modelContext.insert(capturedQuestion)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Question saved to SwiftData with session: \(questionText.prefix(50))...")
            #endif
            #if DEBUG
            print("   Session now has \((currentSession?.capturedQuestions ?? []).count) questions")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save question: \(error)")
            #endif
            SensoryFeedback.error()
        }
    }

    // MARK: - Process and Save Detected Content

    func processAndSaveDetectedContent(_ content: [AmbientProcessedContent]) {
        for item in content {
            // Create hash for deduplication - include response for questions to prevent duplicate AI responses
            let contentHash: String
            if item.type == .question {
                // For questions, include the response in the hash to ensure uniqueness
                contentHash = "\(item.type)_\(item.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))_\(item.response ?? "")"
            } else {
                contentHash = "\(item.type)_\(item.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
            }

            // Skip if already processed (using hash to prevent duplicates)
            if processedContentHashes.contains(contentHash) {
                #if DEBUG
                print("⚠️ Skipping duplicate: \(item.text.prefix(30))...")
                #endif
                continue
            }

            // Mark as processed
            processedContentHashes.insert(contentHash)

            // Update detection state
            withAnimation(DesignSystem.Animation.springStandard) {
                switch item.type {
                case .question:
                    detectionState = .processingQuestion
                case .quote:
                    detectionState = .detectingQuote
                case .note, .thought:
                    detectionState = .savingNote
                default:
                    detectionState = .idle
                }
            }

            // Smart filtering - automatically filter out non-book content
            if item.type == .question {
                let questionLower = item.text.lowercased()

                // Keywords that indicate non-book conversation
                let nonBookKeywords = ["chewy box", "shoe box", "bring", "brought", "aftership", "tracking", "package", "delivery"]
                let isNonBookContent = nonBookKeywords.contains { questionLower.contains($0) }

                // Keywords that indicate book-related content
                let bookRelatedKeywords = ["book", "character", "story", "plot", "chapter", "page", "author", "reading",
                                          "frodo", "gandalf", "bilbo", "ring", "hobbit", "shire", "middle-earth",
                                          "protagonist", "antagonist", "theme", "ending", "beginning"]
                let seemsBookRelated = bookRelatedKeywords.contains { questionLower.contains($0) } ||
                                       (currentBookContext.map { context in
                                        context.title.lowercased().split(separator: " ").contains {
                                            questionLower.contains($0) && $0.count > 3
                                        }
                                       } ?? false)

                // Filter out if it's clearly non-book content and not book-related
                if isNonBookContent && !seemsBookRelated {
                    logger.info("🚫 Auto-filtering non-book question: \(item.text.prefix(50))...")
                    continue
                }
            }

            // Show save animation for quotes and notes (saving is handled by processor)
            switch item.type {
            case .quote:
                // Save quote to SwiftData with session relationship and get the CapturedQuote
                if let capturedQuote = saveQuoteToSwiftData(item) {
                    savedItemsCount += 1
                    savedItemType = "Quote"

                    // Add formatted quote to messages for display using the CapturedQuote
                    let quoteMessage = UnifiedChatMessage(
                        content: capturedQuote.text ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .quote(capturedQuote)  // Use quote type with the CapturedQuote object
                    )
                    messages.append(quoteMessage)

                    // Gracefully collapse previous messages when new quote arrives
                    withAnimation(DesignSystem.Animation.easeStandard) {
                        expandedMessageIds.removeAll()
                    }

                    #if DEBUG
                    print("🎯 SAVE ANIMATION: Setting showSaveAnimation = true for Quote")
                    #endif
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSaveAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            #if DEBUG
                            print("🎯 SAVE ANIMATION: Hiding save animation for Quote")
                            #endif
                            showSaveAnimation = false
                            savedItemType = nil
                        }
                    }
                    logger.info("💾 Quote detected and saved: \(item.text.prefix(50))...")
                } else {
                    logger.warning("⚠️ Failed to save quote: \(item.text.prefix(50))...")
                }
            case .note, .thought:
                // Save note to SwiftData with session relationship
                if let capturedNote = saveNoteToSwiftData(item) {
                    savedItemsCount += 1
                    savedItemType = item.type == .note ? "Note" : "Thought"

                    // Add formatted note/thought to messages for display
                    let noteMessage = UnifiedChatMessage(
                        content: capturedNote.content ?? "",
                        isUser: true,
                        timestamp: Date(),
                        bookContext: currentBookContext,
                        messageType: .note(capturedNote)  // Use note type with the CapturedNote object
                    )
                    messages.append(noteMessage)

                    // Gracefully collapse previous messages when new note/thought arrives
                    withAnimation(DesignSystem.Animation.easeStandard) {
                        expandedMessageIds.removeAll()
                    }

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSaveAnimation = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSaveAnimation = false
                            savedItemType = nil
                        }
                    }
                    logger.info("💾 \(item.type == .note ? "Note" : "Thought") detected and saved: \(item.text.prefix(50))...")
                } else {
                    logger.warning("⚠️ Failed to save note/thought: \(item.text.prefix(50))...")
                }
            case .question:
                // Save question to SwiftData with session relationship
                saveQuestionToSwiftData(item)
                logger.info("❓ Question detected and saved: \(item.text.prefix(50))...")
            default:
                break
            }

            // ONLY show AI responses for questions in ambient mode
            // Don't show the user's question as a bubble - just the AI response
            if item.type == .question {
                if item.response != nil {
                    // More robust duplicate check - check both content and question context
                    let responseExists = messages.contains { msg in
                        !msg.isUser && (msg.content == item.response || msg.content.contains(item.text))
                    }

                    if !responseExists, let response = item.response {
                        // Format the response with the question for context
                        let formattedResponse = "**\(item.text)**\n\n\(response)"
                        let aiMessage = UnifiedChatMessage(
                            content: formattedResponse,
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        // Check if this is the first response BEFORE adding it
                        _ = messages.filter { !$0.isUser }.count == 0

                        messages.append(aiMessage)

                        // Expand the new message without collapsing others
                        // The thinking message should already be expanded
                        if !expandedMessageIds.contains(aiMessage.id) {
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                expandedMessageIds.insert(aiMessage.id)
                            }
                        }
                        #if DEBUG
                        print("✅ Added AI response for question: \(item.text.prefix(30))...")
                        #endif
                    } else {
                        #if DEBUG
                        print("⚠️ Response already exists for question: \(item.text.prefix(30))...")
                        #endif
                    }
                } else {
                    // Question detected but no response yet
                    // The thinking message is already created in the onReceive listener
                    // The processor path (processQuestionDirectly) handles the AI response via
                    // OptimizedPerplexityService streaming. DO NOT trigger a second AI call here
                    // as it causes a race condition with duplicate/inconsistent message updates.
                    pendingQuestion = item.text
                    #if DEBUG
                    print("💭 Question awaiting processor response: \(item.text.prefix(30))...")
                    #endif
                }
            }

            // Reset state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    detectionState = .idle
                }
            }
        }
    }

    // MARK: - Check for Response Updates

    func checkForResponseUpdates(in content: [AmbientProcessedContent]) {
        // Only check recent items for response updates to avoid excessive processing
        let recentItems = content.suffix(10)

        for item in recentItems {
            if item.type == .question, let response = item.response, response != "Thinking..." {
                // Check if we already have this response displayed
                let responseKey = "\(item.text)_response"
                if !processedContentHashes.contains(responseKey) {
                    processedContentHashes.insert(responseKey)

                    #if DEBUG
                    print("✅ Response update detected for: \(item.text.prefix(30))...")
                    #endif

                    // Update the saved question in SwiftData with the answer
                    if let session = currentSession {
                        if let savedQuestion = (session.capturedQuestions ?? []).first(where: { $0.content == item.text }) {
                            savedQuestion.answer = response
                            try? modelContext.save()
                            #if DEBUG
                            print("✅ Updated saved question with answer")
                            #endif
                        }
                    }

                    // Find and update the thinking message with the actual response
                    if let thinkingIndex = messages.lastIndex(where: {
                        !$0.isUser &&
                        ($0.content.contains("**\(item.text)**") ||
                         $0.content == "[Thinking]" ||
                         $0.content == "**\(item.text)**")
                    }) {
                        let updatedMessage = UnifiedChatMessage(
                            content: "**\(item.text)**\n\n\(response)",
                            isUser: false,
                            timestamp: messages[thinkingIndex].timestamp,
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        messages[thinkingIndex] = updatedMessage
                        pendingQuestion = nil

                        // Automatically expand the message to show the response
                        if !expandedMessageIds.contains(updatedMessage.id) {
                            expandedMessageIds.insert(updatedMessage.id)
                        }

                        #if DEBUG
                        print("✅ Updated thinking message with response and expanded it")
                        #endif
                        #if DEBUG
                        print("   Message content: \(updatedMessage.content.prefix(100))...")
                        #endif
                        #if DEBUG
                        print("   Total messages: \(messages.count)")
                        #endif
                    } else {
                        // No thinking message found, add response as new message
                        let aiMessage = UnifiedChatMessage(
                            content: "**\(item.text)**\n\n\(response)",
                            isUser: false,
                            timestamp: Date(),
                            bookContext: currentBookContext,
                            messageType: .text
                        )
                        messages.append(aiMessage)
                        pendingQuestion = nil

                        // Automatically expand the new message to show the response
                        expandedMessageIds.insert(aiMessage.id)

                        #if DEBUG
                        print("✅ Added new message with response and expanded it")
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - Session Lifecycle

    func startAmbientSessionIfNeeded() {
        guard currentSession == nil else { return }

        let newSession = AmbientSession()
        newSession.startTime = Date()

        // Set book context if available
        if let book = currentBookContext {
            newSession.bookModel = BookModel(from: book)
        }

        modelContext.insert(newSession)
        currentSession = newSession

        do {
            try modelContext.save()
            #if DEBUG
            if let book = currentBookContext {
                print("📚 Created ambient session for book: \(book.title)")
            } else {
                print("📚 Created generic ambient session (no book context)")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create session: \(error)")
            #endif
        }
    }

    /// Saves a question and response to the current session
    func saveQuestionToCurrentSession(_ question: String, response: String) {
        guard let session = currentSession else {
            #if DEBUG
            print("⚠️ No current session to save question to")
            #endif
            return
        }

        // Get BookModel if we have book context
        var bookModel: BookModel? = nil
        if let book = currentBookContext {
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { $0.id == book.id }
            )
            bookModel = try? modelContext.fetch(descriptor).first
        }

        let capturedQuestion = CapturedQuestion(
            content: question,
            book: bookModel,
            pageNumber: currentBookContext?.currentPage,
            timestamp: Date(),
            source: .ambient
        )
        capturedQuestion.answer = response
        capturedQuestion.isAnswered = true
        capturedQuestion.ambientSession = session

        if session.capturedQuestions == nil {
            session.capturedQuestions = []
        }
        session.capturedQuestions?.append(capturedQuestion)

        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Saved question to session: \(question.prefix(50))...")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save question: \(error)")
            #endif
        }
    }

    func createSession() -> AmbientSession {
        // Use existing session - it was created at start and items were added during saving
        guard let session = currentSession else {
            #if DEBUG
            print("❌ No current session found!")
            #endif
            return AmbientSession(book: currentBookContext)
        }

        // Just set the end time
        session.endTime = Date()

        // Validate session has content before saving
        let hasQuotes = (session.capturedQuotes ?? []).count > 0
        let hasNotes = (session.capturedNotes ?? []).count > 0
        let hasQuestions = (session.capturedQuestions ?? []).count > 0
        let hasContent = hasQuotes || hasNotes || hasQuestions

        #if DEBUG
        print("📊 Finalizing session with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
        #endif

        // Only save if there's actual content
        if hasContent {
            do {
                // Force save context to ensure all relationships are persisted
                if modelContext.hasChanges {
                    try modelContext.save()
                    #if DEBUG
                    print("✅ Session finalized in SwiftData with content")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ No changes to save in model context")
                    #endif
                    // Force a save anyway to ensure persistence
                    session.endTime = Date() // Touch the session
                    try modelContext.save()
                }
            } catch {
                #if DEBUG
                print("❌ Failed to finalize session: \(error)")
                #endif
                // Try using safe save extension
                modelContext.safeSave()
            }
        } else {
            #if DEBUG
            print("⚠️ Session is empty, removing from context")
            #endif
            modelContext.delete(session)
            try? modelContext.save()
        }

        // End processor session in background
        Task.detached { [weak processor] in
            _ = await processor?.endSession()
            await AmbientLiveActivityManager.shared.endActivity()
        }

        return session
    }

    func startNewSessionForBook(_ book: Book) {
        // Set the book context in the detector
        bookDetector.setCurrentBook(book)

        // Create a fresh session for the new book
        let newSession = AmbientSession()
        newSession.startTime = Date()
        newSession.bookModel = BookModel(from: book)
        modelContext.insert(newSession)
        currentSession = newSession

        // Clear the detected content from previous book
        processor.detectedContent.removeAll()

        // Reset counts
        savedItemsCount = 0

        do {
            try modelContext.save()
            #if DEBUG
            print("📚 Started new session for book: \(book.title)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create new session: \(error)")
            #endif
        }
    }

    func loadExistingSessionIfAvailable() {
        // Check if we're continuing from an existing session
        if let existingSession = EpilogueAmbientCoordinator.shared.existingSession {
            #if DEBUG
            print("📖 Loading existing session with \((existingSession.capturedQuestions ?? []).count) questions")
            #endif

            // Load the book context
            if let bookModel = existingSession.bookModel {
                // Convert BookModel to Book
                if let book = libraryViewModel.books.first(where: { $0.id == bookModel.id }) {
                    currentBookContext = book
                    bookDetector.setCurrentBook(book)

                    // Load color palette
                    Task {
                        await extractColorsForBook(book)
                    }
                }
            }

            // Load conversation history into messages
            for question in existingSession.capturedQuestions ?? [] {
                if let content = question.content {
                    // Add the question
                    let questionMessage = UnifiedChatMessage(
                        content: content,
                        isUser: true,
                        timestamp: question.timestamp ?? Date(),
                        bookContext: currentBookContext
                    )
                    messages.append(questionMessage)

                    // Add the answer if available
                    if let answer = question.answer {
                        let answerMessage = UnifiedChatMessage(
                            content: answer,
                            isUser: false,
                            timestamp: Date(timeInterval: 1, since: question.timestamp ?? Date()),
                            bookContext: currentBookContext
                        )
                        messages.append(answerMessage)
                    }
                }
            }

            // Continue the same session
            currentSession = existingSession
            currentSession?.startTime = Date() // Update start time for this continuation

            #if DEBUG
            print("✅ Loaded \(messages.count) messages from previous session")
            #endif
        }
    }

    func saveCurrentSessionBeforeBookSwitch() {
        guard let session = currentSession else { return }

        // Save the session with its current book
        session.endTime = Date()

        // Ensure all content is saved to the current book
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Saved session for \(currentBookContext?.title ?? "unknown book") with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save session before book switch: \(error)")
            #endif
        }
    }

    func stopAndSaveSession() {
        // Stop recording immediately
        isRecording = false
        liveTranscription = ""
        // Visibility controlled by showLiveTranscriptionBubble setting
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil

        // Stop voice manager first
        voiceManager.stopListening()

        // Clean up processor in background
        Task {
            _ = await processor.endSession()
        }

        // Finalize the session
        if let session = currentSession {
            session.endTime = Date()

            // Debug: Log the session's questions before saving
            #if DEBUG
            print("📊 DEBUG: About to save session. Questions in session:")
            #endif
            for (i, q) in (session.capturedQuestions ?? []).enumerated() {
                #if DEBUG
                print("   \(i+1). \(q.content?.prefix(50) ?? "nil") - Answer: \(q.answer != nil ? "Yes" : "No")")
                #endif
            }

            // Force save to ensure all relationships are persisted
            do {
                try modelContext.save()
                #if DEBUG
                print("✅ Session saved with \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes, \((session.capturedQuestions ?? []).count) questions")
                #endif

                // Update reading habit plan if one is active
                updateReadingPlanFromSession(session)

            } catch {
                #if DEBUG
                print("❌ Failed to save session: \(error)")
                #endif
            }

            // Debug: Log what we're saving
            #if DEBUG
            print("📊 Session Summary Debug:")
            #endif
            #if DEBUG
            print("   Questions: \((session.capturedQuestions ?? []).count)")
            #endif
            for (i, q) in (session.capturedQuestions ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((q.content ?? "").prefix(50))... Answer: \(q.isAnswered ?? false ? "Yes" : "No")")
                #endif
            }
            #if DEBUG
            print("   Quotes: \((session.capturedQuotes ?? []).count)")
            #endif
            for (i, quote) in (session.capturedQuotes ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((quote.text ?? "").prefix(50))...")
                #endif
            }
            #if DEBUG
            print("   Notes: \((session.capturedNotes ?? []).count)")
            #endif
            for (i, note) in (session.capturedNotes ?? []).enumerated() {
                #if DEBUG
                print("     \(i+1). \((note.content ?? "").prefix(50))...")
                #endif
            }

            // Show summary if there's meaningful content
            if (session.capturedQuestions ?? []).count > 0 || (session.capturedQuotes ?? []).count > 0 || (session.capturedNotes ?? []).count > 0 {
                // Present the session summary sheet
                showingSessionSummary = true
                logger.info("📊 Showing session summary with \((session.capturedQuestions ?? []).count) questions, \((session.capturedQuotes ?? []).count) quotes, \((session.capturedNotes ?? []).count) notes")
            } else {
                // No meaningful content - delete the empty session
                logger.info("📊 No meaningful content in session, deleting empty session and dismissing")
                modelContext.delete(session)
                try? modelContext.save()
                EpilogueAmbientCoordinator.shared.dismiss()
            }
        } else {
            // No session - just dismiss
            logger.info("❌ No session found, dismissing")
            EpilogueAmbientCoordinator.shared.dismiss()
        }
    }

    func updateReadingPlanFromSession(_ session: AmbientSession) {
        // Find an active reading plan
        guard let activePlan = activeReadingPlans.first else {
            #if DEBUG
            print("📚 No active reading plan to update")
            #endif
            return
        }

        // Need a start time to calculate duration
        guard let startTime = session.startTime else {
            #if DEBUG
            print("📚 Session has no start time, cannot record")
            #endif
            return
        }

        // Calculate session duration in minutes
        let sessionDuration: TimeInterval
        if let endTime = session.endTime {
            sessionDuration = endTime.timeIntervalSince(startTime)
        } else {
            sessionDuration = Date().timeIntervalSince(startTime)
        }

        let sessionMinutes = Int(sessionDuration / 60)

        // Only record if session was at least 1 minute
        guard sessionMinutes >= 1 else {
            #if DEBUG
            print("📚 Session too short to count: \(sessionMinutes) min")
            #endif
            return
        }

        #if DEBUG
        print("📚 Recording \(sessionMinutes) minutes to reading plan: \(activePlan.title)")
        #endif

        // Record the reading session to the plan
        activePlan.recordReading(minutes: sessionMinutes, fromAmbientSession: true)

        // Save the updated plan
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Reading plan progress updated - Day \(activePlan.currentDayNumber), \(activePlan.todayDay?.minutesRead ?? 0) mins today")
            #endif

            // Update the local reference if this is the same plan
            if createdReadingPlan?.id == activePlan.id {
                createdReadingPlan = activePlan
            }
        } catch {
            #if DEBUG
            print("❌ Failed to save reading plan progress: \(error)")
            #endif
        }
    }

    // MARK: - Find Saved Items

    func findQuote(matching text: String) -> CapturedQuote? {
        let fetchRequest = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { quote in
                quote.text == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }

    func findNote(matching text: String) -> CapturedNote? {
        let fetchRequest = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { note in
                note.content == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }

    func findQuestion(matching text: String) -> CapturedQuestion? {
        let fetchRequest = FetchDescriptor<CapturedQuestion>(
            predicate: #Predicate { question in
                question.content == text
            }
        )
        return try? modelContext.fetch(fetchRequest).first
    }
}
