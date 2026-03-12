import SwiftUI
import SwiftData
import Vision
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientModeView+Helpers")

// MARK: - Utility & Helper Methods
extension AmbientModeView {

    // MARK: - Book Detection

    func handleBookDetection(_ book: Book?) {
        guard let book = book else { return }

        // CRITICAL: Don't auto-switch to book mode when in Generic mode
        // Generic mode should stay focused on general conversations, recommendations, etc.
        let isGenericMode = EpilogueAmbientCoordinator.shared.ambientMode.isGeneric
        if isGenericMode {
            #if DEBUG
            print("📚 Ignoring book detection in Generic mode - staying generic")
            #endif
            return
        }

        // CRITICAL: Prevent duplicate detections for the same book
        if lastDetectedBookId == book.localId {
            #if DEBUG
            print("📚 Ignoring duplicate book detection: \(book.title)")
            #endif
            return
        }

        // Also check if it's the same as current book context
        if currentBookContext?.localId == book.localId {
            #if DEBUG
            print("📚 Book already set as current context: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("📚 Book detected: \(book.title)")
        #endif
        lastDetectedBookId = book.localId

        // Clear the transcription immediately to prevent double appearance
        liveTranscription = ""
        // Visibility controlled by showLiveTranscriptionBubble setting

        // Cancel any pending fade timer
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil

        // Save current session before switching books (if there was a previous book)
        if currentBookContext != nil {
            saveCurrentSessionBeforeBookSwitch()

            // Start a new session for the detected book
            withAnimation(.easeInOut(duration: 0.5)) {
                currentBookContext = book
                showBookCover = true
                startNewSessionForBook(book)
            }
        } else {
            // First book detection - just update the existing session
            withAnimation(.easeInOut(duration: 0.5)) {
                currentBookContext = book
                showBookCover = true

                // Update the current session with the detected book
                if let session = currentSession {
                    session.bookModel = BookModel(from: book)
                    do {
                        try modelContext.save()
                        #if DEBUG
                        print("📚 Updated session with first detected book: \(book.title)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("❌ Failed to update session with detected book: \(error)")
                        #endif
                    }
                }
            }
        }

        // Start timer to hide book cover after 4 seconds
        bookCoverTimer?.invalidate()
        bookCoverTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.8)) {
                showBookCover = false
            }
        }

        // Update the TrueAmbientProcessor with the new book context
        TrueAmbientProcessor.shared.updateBookContext(book)

        Task {
            await extractColorsForBook(book)
        }

        SensoryFeedback.light()
    }

    // MARK: - Color Extraction

    func extractColorsForBook(_ book: Book) async {
        let bookID = book.localId.uuidString
        #if DEBUG
        print("🎨 Extracting colors for: \(book.title)")
        #endif

        if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
            #if DEBUG
            print("✅ Found cached palette for: \(book.title)")
            #endif
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.colorPalette = cachedPalette
                }
            }
            return
        }

        guard let coverURLString = book.coverImageURL else {
            #if DEBUG
            print("❌ No cover URL for: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("🔗 Cover URL: \(coverURLString)")
        #endif

        // Use SharedBookCoverManager to load the image - this ensures proper zoom parameter
        // and consistent image quality across the app
        guard let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURLString) else {
            #if DEBUG
            print("❌ Failed to load cover image for: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("📐 Image size: \(image.size)")
        #endif

        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(from: image, imageSource: book.title)

            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.5)) {
                    self.colorPalette = palette
                    self.coverImage = image
                    #if DEBUG
                    print("✅ Color palette extracted for: \(book.title)")
                    print("  Primary: \(palette.primary)")
                    print("  Secondary: \(palette.secondary)")
                    #endif
                }
            }

            await BookColorPaletteCache.shared.cachePalette(palette, for: bookID, coverURL: book.coverImageURL)
        } catch {
            #if DEBUG
            print("❌ Failed to extract colors: \(error)")
            #endif
        }
    }

    func generatePlaceholderPalette(for book: Book) -> ColorPalette {
        ColorPalette(
            primary: DesignSystem.Colors.primaryAccent.opacity(0.8),
            secondary: Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.6),
            accent: Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.5),
            background: Color(white: 0.1),
            textColor: .white,
            luminance: 0.3,
            isMonochromatic: false,
            extractionQuality: 0.1
        )
    }

    // MARK: - Page Detection

    func detectPageMention(in text: String) {
        let lowercased = text.lowercased()

        // Regex patterns for page mentions
        let patterns = [
            "page (\\d+)",
            "on page (\\d+)",
            "i'm on page (\\d+)",
            "i am on page (\\d+)",
            "reading page (\\d+)",
            "at page (\\d+)",
            "page number (\\d+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.count))

                if let match = matches.first,
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: lowercased) {
                    let pageNumberString = String(lowercased[range])
                    if let pageNumber = Int(pageNumberString) {
                        // Update the session with the current page
                        if let session = currentSession {
                            session.currentPage = pageNumber
                            try? modelContext.save()
                            #if DEBUG
                            print("📖 Updated current page to: \(pageNumber)")
                            #endif

                            // Push page update to Live Activity
                            Task {
                                await LiveActivityLifecycleManager.shared.updateContent(pagesRead: pageNumber)
                            }

                            // Show subtle feedback
                            withAnimation(DesignSystem.Animation.easeStandard) {
                                savedItemType = "Page \(pageNumber)"
                                showSaveAnimation = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showSaveAnimation = false
                                    savedItemType = nil
                                }
                            }
                        }
                        break // Only take the first page mention
                    }
                }
            }
        }
    }

    // MARK: - Visual Intelligence

    func triggerVisualIntelligence() async {
        await MainActor.run {
            showImagePicker = true
        }
    }

    func processImageForText(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        // Show processing state
        isProcessingImage = true
        cameraJustUsed = true

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    self.isProcessingImage = false
                    // Show error feedback
                    SensoryFeedback.error()
                    self.keyboardText = "Couldn't read the text. Try better lighting."
                }
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            let extractedText = recognizedStrings.joined(separator: " ")

            DispatchQueue.main.async {
                self.isProcessingImage = false
                self.extractedText = extractedText

                // Generate smart question based on extracted text
                let smartQuestion = self.generateSmartQuestion(from: extractedText)

                // Auto-populate the input field
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.keyboardText = smartQuestion
                }

                // Haptic feedback for success
                SensoryFeedback.success()

                // Auto-submit if it's a short quote
                if self.shouldAutoSubmit(extractedText) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendTextMessage()
                    }
                }

                // Reset camera state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.cameraJustUsed = false
                    }
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            #if DEBUG
            print("Failed to perform OCR: \(error)")
            #endif
        }
    }

    func generateSmartQuestion(from text: String) -> String {
        let truncated = String(text.prefix(300))
        let wordCount = text.split(separator: " ").count

        // QUOTE DETECTION - Primary focus
        // Check if this looks like a meaningful quote worth capturing
        let isLikelyQuote = detectIfQuote(text)

        if isLikelyQuote {
            // Format as a quote capture with context
            let cleanQuote = text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Automatically save as quote if it's perfect length
            if wordCount >= 15 && wordCount <= 60 {
                // Auto-save the quote
                saveExtractedQuote(cleanQuote)
                return "💭 Quote saved: \"\(truncated)\"... - Add a note?"
            } else if wordCount < 100 {
                return "📖 Save this quote: \"\(truncated)\"... [Tap send to save]"
            }
        }

        // Detect content type and generate appropriate question
        if wordCount < 15 {
            // Very short - likely a title or heading
            return "What is the significance of '\(truncated)'?"
        } else if text.contains("\"") && wordCount < 50 {
            // Contains quotation marks - save as quote
            saveExtractedQuote(text)
            return "💭 Quote captured! Add your thoughts?"
        } else if text.contains(where: { ["thee", "thou", "thy", "hath", "doth"].contains(String($0)) }) {
            // Old English detected
            return "Translate to modern English: '\(truncated)...'"
        } else if text.contains("?") && wordCount < 100 {
            // Contains questions - philosophical passage
            return "What is the deeper meaning of: '\(truncated)...'"
        } else if text.contains(where: { ["said", "replied", "asked", "exclaimed"].contains(String($0)) }) {
            // Dialogue detected
            return "Analyze this dialogue: '\(truncated)...'"
        } else if currentBookContext?.title.contains("Hobbit") == true || currentBookContext?.title.contains("Lord") == true {
            // Context-aware for specific books
            return "How does this passage relate to the broader themes: '\(truncated)...'"
        } else {
            // Default - general explanation
            return "What does this passage mean: '\(truncated)...'"
        }
    }

    // MARK: - Quote Saving

    func saveQuoteWithAttribution(_ text: String, pageNumber: String?) {
        // Get current book if available
        let bookTitle = bookDetector.detectedBook?.title ?? "Unknown Book"
        let author = bookDetector.detectedBook?.author ?? ""

        // Create attributed quote
        var attributedText = text
        if let page = pageNumber {
            attributedText += "\n\n— \(bookTitle), p. \(page)"
        } else {
            attributedText += "\n\n— \(bookTitle)"
        }

        // Save as quote
        processSelectedQuote(attributedText)
    }

    func processSelectedQuote(_ selectedText: String) {
        // Show processing state
        isProcessingImage = true
        cameraJustUsed = true

        // Haptic feedback for quote capture
        SensoryFeedback.success()

        // Generate smart input based on selected text
        let smartInput = generateSmartQuestion(from: selectedText)

        // Update the input field
        withAnimation(.easeInOut(duration: 0.3)) {
            keyboardText = smartInput
        }

        // Reset states
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessingImage = false
        }

        // Reset camera indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                cameraJustUsed = false
            }
        }

        // If it's a perfect quote, save it immediately
        if detectIfQuote(selectedText) && selectedText.split(separator: " ").count <= 60 {
            saveExtractedQuote(selectedText)
        }
    }

    func saveQuoteFromVisualIntelligence(_ text: String, pageNumber: Int?) {
        // Create the captured quote
        let capturedQuote = CapturedQuote(
            text: text,
            book: currentBookContext.map { BookModel(from: $0) },
            author: currentBookContext?.author,
            pageNumber: pageNumber,
            timestamp: Date(),
            source: .manual
        )

        // Add to current session only (not to processor.detectedContent to avoid duplication)
        if currentSession != nil {
            if currentSession?.capturedQuotes == nil {
                currentSession?.capturedQuotes = []
            }
            currentSession?.capturedQuotes?.append(capturedQuote)
        }

        // CRITICAL FIX: Insert into SwiftData so quote persists and appears in Notes view
        modelContext.insert(capturedQuote)

        // CRITICAL FIX: Save to SwiftData database
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ Quote saved from Visual Intelligence to SwiftData: \(text.prefix(50))...")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to save quote from Visual Intelligence: \(error)")
            #endif
            // Show error notification to user instead of false success
            NotificationCenter.default.post(
                name: .showToastMessage,
                object: ["message": "Failed to save quote. Please try again."]
            )
            return  // Don't show success animation if save failed
        }

        // Add to messages
        let pageInfo = pageNumber.map { "from page \($0)" } ?? ""
        let message = UnifiedChatMessage(
            content: "**Quote captured \(pageInfo)**\n\n\(text)",
            isUser: false,
            timestamp: Date(),
            messageType: .quote(CapturedQuote(
                text: text,
                book: currentBookContext.map { BookModel(from: $0) },
                author: currentBookContext?.author,
                pageNumber: pageNumber,
                timestamp: Date(),
                source: .manual
            ))
        )
        messages.append(message)

        // Show save animation
        savedItemsCount += 1
        savedItemType = "Quote"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSaveAnimation = true
        }

        // Push capture count to Live Activity
        Task {
            await LiveActivityLifecycleManager.shared.updateContent(capturedCount: savedItemsCount)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSaveAnimation = false
                savedItemType = nil
            }
        }

        // Haptic feedback
        SensoryFeedback.success()
    }

    func saveExtractedQuote(_ text: String) {
        // Save quote to SwiftData immediately
        let quote = CapturedQuote(
            text: text,
            book: currentBookContext.map { BookModel(from: $0) },
            author: currentBookContext?.author,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual  // User captured via camera
        )

        modelContext.insert(quote)

        do {
            try modelContext.save()
            #if DEBUG
            print("💭 Quote auto-saved from camera: \(text.prefix(50))...")
            #endif

            // Haptic feedback for saved quote
            SensoryFeedback.success()

            // Show toast
            NotificationCenter.default.post(
                name: .showToastMessage,
                object: ["message": "Quote saved to \(currentBookContext?.title ?? "your collection")"]
            )
        } catch {
            #if DEBUG
            print("Failed to save quote: \(error)")
            #endif
            SensoryFeedback.error()
            NotificationCenter.default.post(
                name: .showToastMessage,
                object: ["message": "Failed to save quote. Please try again."]
            )
        }
    }

    func saveHighlightedQuote(_ quote: String, pageNumber: Int? = nil) {
        // Save as a quote through the ambient processor
        let content = AmbientProcessedContent(
            text: quote,
            type: .quote,
            timestamp: Date(),
            confidence: 1.0,
            response: nil,
            bookTitle: currentBookContext?.title,
            bookAuthor: currentBookContext?.author
        )

        processor.detectedContent.append(content)

        // Show save animation
        savedItemsCount += 1
        savedItemType = "Quote from Photo"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSaveAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showSaveAnimation = false
                savedItemType = nil
            }
        }

        // Clear the captured image
        capturedImage = nil
        showQuoteHighlighter = false
        extractedText = ""
    }

    // MARK: - Perplexity Integration

    func askPerplexityAboutText(_ text: String) async {
        // Create a question about the text
        let question = "What does this passage mean: \"\(text)\""

        // Process through AI
        await getAIResponseForAmbientQuestion(question)
    }

    // MARK: - Text Classification

    func shouldAutoSubmit(_ text: String) -> Bool {
        // Don't auto-submit quotes - let user confirm or add notes
        return false
    }

    func detectIfQuote(_ text: String) -> Bool {
        let wordCount = text.split(separator: " ").count

        // Indicators this is a quote worth capturing
        let quotableIndicators = [
            text.contains("\""),  // Has quotation marks
            text.contains("—"),    // Has em dash (often used in quotes)
            text.contains("..."),  // Has ellipsis
            wordCount >= 10 && wordCount <= 150,  // Good quote length
            text.contains(where: { ["love", "life", "death", "time", "hope", "fear", "dream", "heart", "soul", "truth", "beauty", "wisdom", "courage", "strength"].contains(String($0).lowercased()) }),  // Contains profound words
            text.first?.isUppercase == true && (text.last == "." || text.last == "!" || text.last == "?"),  // Complete sentence
        ]

        // If 2+ indicators, it's likely a quote
        return quotableIndicators.filter { $0 }.count >= 2
    }

    // MARK: - Navigation & Exit

    func exitInstantly() {
        // INSTANT UI updates
        isRecording = false
        liveTranscription = ""
        // Visibility controlled by showLiveTranscriptionBubble setting
        transcriptionFadeTimer?.invalidate()
        transcriptionFadeTimer = nil
        voiceManager.stopListening()

        // End processor session AND live activity
        Task {
            _ = await processor.endSession()
            await AmbientLiveActivityManager.shared.endActivity()
        }

        // Dismiss the view immediately using coordinator
        EpilogueAmbientCoordinator.shared.dismiss()
    }

    func openPurchaseURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)

        #if DEBUG
        print("🛒 Opening purchase URL: \(urlString)")
        #endif
    }

    // MARK: - Library Management

    func addRecommendationToLibrary(_ rec: UnifiedChatMessage.BookRecommendation) {
        Task { @MainActor in
            // Create BookModel directly with proper initialization
            let bookModel = BookModel(
                id: UUID().uuidString,
                title: rec.title,
                author: rec.author,
                publishedYear: nil,
                coverImageURL: rec.coverURL,
                isbn: rec.isbn,
                description: rec.reason,
                pageCount: nil,
                localId: UUID().uuidString
            )
            bookModel.isInLibrary = true
            bookModel.readingStatus = "want_to_read"
            bookModel.dateAdded = Date()

            modelContext.insert(bookModel)

            do {
                try modelContext.save()

                // Notify library to reload from SwiftData
                NotificationCenter.default.post(name: .refreshLibrary, object: nil)

                // Show success feedback
                SensoryFeedback.success()

                #if DEBUG
                print("📚 Added recommendation to library: \(rec.title) by \(rec.author)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to save recommendation: \(error)")
                #endif
                SensoryFeedback.error()
                NotificationCenter.default.post(
                    name: .showToastMessage,
                    object: ["message": "Failed to add book. Please try again."]
                )
            }
        }
    }
}
