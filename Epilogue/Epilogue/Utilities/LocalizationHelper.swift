import Foundation

/// Helper extension for easy localization throughout the app
extension String {
    /// Returns the localized version of this string
    /// - Parameter comment: Optional comment for translators
    /// - Returns: Localized string
    func localized(comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }

    /// Returns the localized version of this string with format arguments
    /// - Parameter arguments: Format arguments to insert into the localized string
    /// - Returns: Localized and formatted string
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

/// Centralized localization keys for type-safe access
enum L10n {
    // MARK: - Navigation
    enum Tab {
        static let library = "tab.library".localized()
        static let notes = "tab.notes".localized()
        static let sessions = "tab.sessions".localized()
    }

    // MARK: - Reading Status
    enum ReadingStatus {
        static let wantToRead = "reading_status.want_to_read".localized()
        static let currentlyReading = "reading_status.currently_reading".localized()
        static let read = "reading_status.read".localized()
    }

    // MARK: - Common Actions
    enum Action {
        static let save = "action.save".localized()
        static let cancel = "action.cancel".localized()
        static let delete = "action.delete".localized()
        static let add = "action.add".localized()
        static let edit = "action.edit".localized()
        static let done = "action.done".localized()
        static let share = "action.share".localized()
        static let search = "action.search".localized()
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title".localized()

        enum Section {
            static let appearance = "settings.section.appearance".localized()
            static let library = "settings.section.library".localized()
            static let aiAssistant = "settings.section.ai_assistant".localized()
            static let ambientMode = "settings.section.ambient_mode".localized()
            static let developerOptions = "settings.section.developer_options".localized()
            static let icloudSync = "settings.section.icloud_sync".localized()
            static let data = "settings.section.data".localized()
            static let about = "settings.section.about".localized()
        }

        static let gradientTheme = "settings.gradient_theme".localized()
        static let importFromGoodreads = "settings.import_from_goodreads".localized()
        static let aiProvider = "settings.ai_provider".localized()
        static let useSonarPro = "settings.use_sonar_pro".localized()
        static let sonarProDescription = "settings.sonar_pro_description".localized()
        static let realtimeQuestions = "settings.realtime_questions".localized()
        static let audioResponses = "settings.audio_responses".localized()
        static let defaultCapture = "settings.default_capture".localized()
        static let showLiveTranscription = "settings.show_live_transcription".localized()
        static let alwaysShowInput = "settings.always_show_input".localized()
        static let exportAllData = "settings.export_all_data".localized()
        static let clearImageCaches = "settings.clear_image_caches".localized()
        static let deleteAllData = "settings.delete_all_data".localized()
        static let version = "settings.version".localized()
        static let privacyPolicy = "settings.privacy_policy".localized()
        static let termsOfService = "settings.terms_of_service".localized()
        static let credits = "settings.credits".localized()
        static let replayOnboarding = "settings.replay_onboarding".localized()
    }

    // MARK: - Library
    enum Library {
        static let title = "library.title".localized()

        enum ViewMode {
            static let grid = "library.view_mode.grid".localized()
            static let list = "library.view_mode.list".localized()
        }

        enum Filter {
            static let allBooks = "library.filter.all_books".localized()
            static let currentlyReading = "library.filter.currently_reading".localized()
            static let unread = "library.filter.unread".localized()
            static let finished = "library.filter.finished".localized()
        }

        static let reorderBooks = "library.reorder_books".localized()
        static let doneReordering = "library.done_reordering".localized()
        static let searchWeb = "library.search_web".localized()
        static let markAsRead = "library.mark_as_read".localized()
        static let markAsWantToRead = "library.mark_as_want_to_read".localized()
        static let changeCover = "library.change_cover".localized()
        static let deleteFromLibrary = "library.delete_from_library".localized()
    }

    // MARK: - General
    enum General {
        static let loading = "general.loading".localized()
        static let saving = "general.saving".localized()
        static let syncing = "general.syncing".localized()
        static let ok = "general.ok".localized()
        static let yes = "general.yes".localized()
        static let no = "general.no".localized()
    }

    // MARK: - Accessibility
    enum Accessibility {
        // Tab bar
        static let libraryTab = "accessibility.tab.library".localized()
        static let libraryTabHint = "accessibility.tab.library.hint".localized()
        static let notesTab = "accessibility.tab.notes".localized()
        static let notesTabHint = "accessibility.tab.notes.hint".localized()
        static let sessionsTab = "accessibility.tab.sessions".localized()
        static let sessionsTabHint = "accessibility.tab.sessions.hint".localized()

        // Notes view
        static let searchNotes = "accessibility.notes.search".localized()
        static let searchNotesHint = "accessibility.notes.search.hint".localized()
        static let clearSearch = "accessibility.notes.clear_search".localized()
        static let clearSearchHint = "accessibility.notes.clear_search.hint".localized()
        static let filterMenu = "accessibility.notes.filter_menu".localized()
        static let filterMenuHint = "accessibility.notes.filter_menu.hint".localized()
        static let closeSearch = "accessibility.notes.close_search".localized()
        static let openSearch = "accessibility.notes.open_search".localized()
        static let noNotesYet = "accessibility.notes.empty_state".localized()

        // Book detail
        static let endSession = "accessibility.book.end_session".localized()
        static let endSessionHint = "accessibility.book.end_session.hint".localized()
        static let startSession = "accessibility.book.start_session".localized()
        static let startSessionHint = "accessibility.book.start_session.hint".localized()
        static let readingStatus = "accessibility.book.reading_status".localized()
        static let readingStatusHint = "accessibility.book.reading_status.hint".localized()

        // Settings
        static let gradientTheme = "accessibility.settings.gradient_theme".localized()
        static let gradientThemeHint = "accessibility.settings.gradient_theme.hint".localized()
        static let goodreadsImport = "accessibility.settings.goodreads_import".localized()
        static let goodreadsImportHint = "accessibility.settings.goodreads_import.hint".localized()
        static let useSonarPro = "accessibility.settings.use_sonar_pro".localized()
        static let realtimeQuestions = "accessibility.settings.realtime_questions".localized()
        static let audioResponses = "accessibility.settings.audio_responses".localized()
        static let exportData = "accessibility.settings.export_data".localized()
        static let exportDataHint = "accessibility.settings.export_data.hint".localized()
        static let deleteAllData = "accessibility.settings.delete_all_data".localized()
        static let deleteAllDataHint = "accessibility.settings.delete_all_data.hint".localized()
        static let replayOnboarding = "accessibility.settings.replay_onboarding".localized()
        static let replayOnboardingHint = "accessibility.settings.replay_onboarding.hint".localized()
    }
}
