import Foundation

// MARK: - Type-Safe Notification Names (KRI-43)
// Centralized notification names to prevent typos and enable refactoring.

extension Notification.Name {
    // MARK: - Library
    static let refreshLibrary = Notification.Name("RefreshLibrary")
    static let addBookToLibrary = Notification.Name("AddBookToLibrary")
    static let exportLibrary = Notification.Name("ExportLibrary")
    static let searchLibrary = Notification.Name("SearchLibrary")
    static let bookCoverUpdated = Notification.Name("BookCoverUpdated")
    static let bookProgressUpdated = Notification.Name("BookProgressUpdated")
    static let bookReplaced = Notification.Name("BookReplaced")
    static let readingGoalSet = Notification.Name("ReadingGoalSet")

    // MARK: - Navigation
    static let navigateToBookFromNotification = Notification.Name("NavigateToBookFromNotification")
    static let navigateToJourneyFromNotification = Notification.Name("NavigateToJourneyFromNotification")
    static let navigateToTab = Notification.Name("NavigateToTab")
    static let navigateToReadingPlan = Notification.Name("NavigateToReadingPlan")
    static let switchToLibraryTab = Notification.Name("SwitchToLibraryTab")
    static let openBook = Notification.Name("OpenBook")

    // MARK: - Book Search & Scanner
    static let showBookSearch = Notification.Name("ShowBookSearch")
    static let showBookSearchFromScanner = Notification.Name("ShowBookSearchFromScanner")
    static let showBatchBookSearch = Notification.Name("ShowBatchBookSearch")
    static let showBookScanner = Notification.Name("ShowBookScanner")
    static let showEnhancedBookScanner = Notification.Name("ShowEnhancedBookScanner")
    static let showGoodreadsImport = Notification.Name("ShowGoodreadsImport")
    static let showBookAddedToast = Notification.Name("ShowBookAddedToast")

    // MARK: - Notes & Quotes
    static let createNewNote = Notification.Name("CreateNewNote")
    static let noteCreatedWithBook = Notification.Name("NoteCreatedWithBook")
    static let noteUpdated = Notification.Name("NoteUpdated")
    static let deleteNote = Notification.Name("DeleteNote")
    static let editNote = Notification.Name("EditNote")
    static let navigateToNote = Notification.Name("navigateToNote")
    static let navigateToQuote = Notification.Name("navigateToQuote")
    static let saveQuote = Notification.Name("SaveQuote")
    static let shareQuote = Notification.Name("ShareQuote")
    static let quoteCreatedWithBook = Notification.Name("QuoteCreatedWithBook")
    static let showQuoteCapture = Notification.Name("ShowQuoteCapture")

    // MARK: - AI & Chat
    static let aiResponseComplete = Notification.Name("AIResponseComplete")
    static let aiResponseError = Notification.Name("AIResponseError")
    static let aiResponseReady = Notification.Name("AIResponseReady")
    static let aiStreamingUpdate = Notification.Name("AIStreamingUpdate")
    static let intelligenceResponseReady = Notification.Name("IntelligenceResponseReady")
    static let triggerAskAI = Notification.Name("TriggerAskAI")
    static let batchProcessQuestions = Notification.Name("BatchProcessQuestions")
    static let immediateQuestionDetected = Notification.Name("ImmediateQuestionDetected")
    static let queuedQuestionProcessed = Notification.Name("QueuedQuestionProcessed")
    static let shouldPrefetchResponses = Notification.Name("ShouldPrefetchResponses")
    static let shouldPreloadQuestion = Notification.Name("ShouldPreloadQuestion")

    // MARK: - Ambient Mode
    static let openAmbientModeFromIntent = Notification.Name("OpenAmbientModeFromIntent")
    static let ambientBookDetected = Notification.Name("AmbientBookDetected")
    static let ambientBookCleared = Notification.Name("AmbientBookCleared")
    static let ambientIntelligenceActivated = Notification.Name("AmbientIntelligenceActivated")
    static let ambientIntelligenceDeactivated = Notification.Name("AmbientIntelligenceDeactivated")
    static let captureForReview = Notification.Name("CaptureForReview")
    static let naturalReactionDetected = Notification.Name("NaturalReactionDetected")
    static let reactionBasedQuoteDetected = Notification.Name("ReactionBasedQuoteDetected")
    static let smartBufferProcessed = Notification.Name("SmartBufferProcessed")
    static let triggerQuoteSave = Notification.Name("TriggerQuoteSave")
    static let visualFeedbackRequested = Notification.Name("VisualFeedbackRequested")
    static let transcriptionEvolved = Notification.Name("TranscriptionEvolved")
    static let ambientQuickAction = Notification.Name("AmbientQuickAction")
    static let endActiveReadingSession = Notification.Name("EndActiveReadingSession")

    // MARK: - Voice
    static let voiceTranscriptUpdated = Notification.Name("voiceTranscriptUpdated")
    static let bookMentionDetected = Notification.Name("bookMentionDetected")
    static let questionDetected = Notification.Name("questionDetected")
    static let questionProcessing = Notification.Name("questionProcessing")
    static let questionProcessed = Notification.Name("questionProcessed")
    static let contentSaved = Notification.Name("contentSaved")
    static let startVoiceCommand = Notification.Name("StartVoiceCommand")
    static let startVoiceNote = Notification.Name("StartVoiceNote")
    static let voiceAddBook = Notification.Name("VoiceAddBook")
    static let wakeWordDetected = Notification.Name("WakeWordDetected")
    static let whisperTranscriptionReady = Notification.Name("WhisperTranscriptionReady")
    static let autoStopTriggered = Notification.Name("autoStopTriggered")
    static let autoStopWarning = Notification.Name("autoStopWarning")

    // MARK: - UI Actions
    static let showCommandPalette = Notification.Name("ShowCommandPalette")
    static let showCommandInput = Notification.Name("ShowCommandInput")
    static let showCompanionInvitation = Notification.Name("ShowCompanionInvitation")
    static let showOnboarding = Notification.Name("ShowOnboarding")
    static let showQuickActionCard = Notification.Name("ShowQuickActionCard")
    static let showReadingTimeline = Notification.Name("ShowReadingTimeline")
    static let showReturnCard = Notification.Name("ShowReturnCard")
    static let showSettings = Notification.Name("ShowSettings")
    static let showToastMessage = Notification.Name("ShowToastMessage")
    static let showGlassToast = Notification.Name("ShowGlassToast")
    static let forceShowDynamicIslandToast = Notification.Name("ForceShowDynamicIslandToast")
    static let forceShowInlineActivityCard = Notification.Name("ForceShowInlineActivityCard")
    static let performSearch = Notification.Name("PerformSearch")
    static let searchAll = Notification.Name("SearchAll")
    static let searchNotes = Notification.Name("SearchNotes")
    static let qualityLevelChanged = Notification.Name("QualityLevelChanged")
    static let deviceMotionUpdate = Notification.Name("deviceMotionUpdate")

    // MARK: - Notes Sync
    static let notesSyncNoteDeleted = Notification.Name("NotesSyncManager.noteDeleted")
    static let notesSyncNoteUpdated = Notification.Name("NotesSyncManager.noteUpdated")
    static let notesSyncNoteBatchDeleted = Notification.Name("NotesSyncManager.noteBatchDeleted")

    // MARK: - Navigation (uppercase variants — legacy, differs from lowercase versions)
    // navigateToBook (lowercase) is in NavigationCoordinator.swift
    static let navigateToBookNotification = Notification.Name("NavigateToBook")
    static let navigateToNoteNotification = Notification.Name("NavigateToNote")
}
