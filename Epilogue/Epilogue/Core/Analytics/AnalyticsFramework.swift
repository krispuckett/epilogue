import Foundation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "Analytics")

// MARK: - Analytics Protocol

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
    func setUser(id: String)
    func setUserProperty(_ key: String, value: Any)
    func timing(_ name: String, time: TimeInterval)
    func incrementCounter(_ name: String, by value: Int)
    func setValue(_ name: String, value: Double)
    func startSession()
    func endSession()
    func flush()
}

// MARK: - Analytics Event

struct AnalyticsEvent {
    let name: String
    let category: EventCategory
    let properties: [String: Any]
    let timestamp: Date

    init(name: String, category: EventCategory, properties: [String: Any] = [:]) {
        self.name = name
        self.category = category
        self.properties = properties
        self.timestamp = Date()
    }
}

// MARK: - Event Categories

enum EventCategory: String {
    case library = "library"
    case reading = "reading"
    case notes = "notes"
    case quotes = "quotes"
    case ambient = "ambient"
    case ai = "ai"
    case navigation = "navigation"
    case settings = "settings"
    case onboarding = "onboarding"
    case performance = "performance"
    case error = "error"
}

// MARK: - Predefined Events

enum Event {
    // Library Events
    case bookAdded(isbn: String?, source: BookSource)
    case bookRemoved(bookId: String)
    case bookStarted(bookId: String)
    case bookFinished(bookId: String, readingTime: TimeInterval)
    case bookRated(bookId: String, rating: Int)

    // Reading Events
    case readingSessionStarted(bookId: String)
    case readingSessionEnded(bookId: String, duration: TimeInterval, pagesRead: Int)
    case progressUpdated(bookId: String, progress: Double)

    // Notes & Quotes
    case noteCreated(bookId: String?, source: NoteSource)
    case noteEdited(noteId: String)
    case noteDeleted(noteId: String)
    case quoteCaptured(bookId: String?, method: CaptureMethod)
    case quoteShared(quoteId: String, destination: ShareDestination)

    // Ambient Mode
    case ambientSessionStarted(bookId: String?)
    case ambientSessionEnded(duration: TimeInterval, notesCount: Int, quotesCount: Int)
    case voiceNoteRecorded(duration: TimeInterval)
    case transcriptionCompleted(success: Bool, duration: TimeInterval)

    // AI Features
    case aiQuerySent(queryType: AIQueryType, model: String)
    case aiResponseReceived(responseTime: TimeInterval, tokenCount: Int)
    case aiFeatureUsed(feature: AIFeature)

    // Navigation
    case tabChanged(from: String, to: String)
    case deepLinkOpened(url: String)
    case searchPerformed(query: String, resultCount: Int)

    // Settings
    case settingChanged(key: String, value: Any)
    case dataExported(format: String, itemCount: Int)
    case dataImported(source: String, itemCount: Int)

    // Performance
    case appLaunched(launchTime: TimeInterval)
    case screenLoaded(screenName: String, loadTime: TimeInterval)
    case imageLoaded(url: String, loadTime: TimeInterval, cacheHit: Bool)

    var analyticsEvent: AnalyticsEvent {
        switch self {
        case .bookAdded(let isbn, let source):
            return AnalyticsEvent(
                name: "book_added",
                category: .library,
                properties: [
                    "isbn": isbn ?? "unknown",
                    "source": source.rawValue
                ]
            )

        case .bookRemoved(let bookId):
            return AnalyticsEvent(
                name: "book_removed",
                category: .library,
                properties: ["book_id": bookId]
            )

        case .bookStarted(let bookId):
            return AnalyticsEvent(
                name: "book_started",
                category: .reading,
                properties: ["book_id": bookId]
            )

        case .bookFinished(let bookId, let readingTime):
            return AnalyticsEvent(
                name: "book_finished",
                category: .reading,
                properties: [
                    "book_id": bookId,
                    "reading_time_hours": readingTime / 3600
                ]
            )

        case .bookRated(let bookId, let rating):
            return AnalyticsEvent(
                name: "book_rated",
                category: .library,
                properties: [
                    "book_id": bookId,
                    "rating": rating
                ]
            )

        case .readingSessionStarted(let bookId):
            return AnalyticsEvent(
                name: "reading_session_started",
                category: .reading,
                properties: ["book_id": bookId]
            )

        case .readingSessionEnded(let bookId, let duration, let pagesRead):
            return AnalyticsEvent(
                name: "reading_session_ended",
                category: .reading,
                properties: [
                    "book_id": bookId,
                    "duration_minutes": duration / 60,
                    "pages_read": pagesRead
                ]
            )

        case .progressUpdated(let bookId, let progress):
            return AnalyticsEvent(
                name: "progress_updated",
                category: .reading,
                properties: [
                    "book_id": bookId,
                    "progress_percentage": progress * 100
                ]
            )

        case .noteCreated(let bookId, let source):
            return AnalyticsEvent(
                name: "note_created",
                category: .notes,
                properties: [
                    "book_id": bookId ?? "none",
                    "source": source.rawValue
                ]
            )

        case .noteEdited(let noteId):
            return AnalyticsEvent(
                name: "note_edited",
                category: .notes,
                properties: ["note_id": noteId]
            )

        case .noteDeleted(let noteId):
            return AnalyticsEvent(
                name: "note_deleted",
                category: .notes,
                properties: ["note_id": noteId]
            )

        case .quoteCaptured(let bookId, let method):
            return AnalyticsEvent(
                name: "quote_captured",
                category: .quotes,
                properties: [
                    "book_id": bookId ?? "none",
                    "capture_method": method.rawValue
                ]
            )

        case .quoteShared(let quoteId, let destination):
            return AnalyticsEvent(
                name: "quote_shared",
                category: .quotes,
                properties: [
                    "quote_id": quoteId,
                    "destination": destination.rawValue
                ]
            )

        case .ambientSessionStarted(let bookId):
            return AnalyticsEvent(
                name: "ambient_session_started",
                category: .ambient,
                properties: ["book_id": bookId ?? "none"]
            )

        case .ambientSessionEnded(let duration, let notesCount, let quotesCount):
            return AnalyticsEvent(
                name: "ambient_session_ended",
                category: .ambient,
                properties: [
                    "duration_minutes": duration / 60,
                    "notes_count": notesCount,
                    "quotes_count": quotesCount
                ]
            )

        case .voiceNoteRecorded(let duration):
            return AnalyticsEvent(
                name: "voice_note_recorded",
                category: .ambient,
                properties: ["duration_seconds": duration]
            )

        case .transcriptionCompleted(let success, let duration):
            return AnalyticsEvent(
                name: "transcription_completed",
                category: .ambient,
                properties: [
                    "success": success,
                    "duration_seconds": duration
                ]
            )

        case .aiQuerySent(let queryType, let model):
            return AnalyticsEvent(
                name: "ai_query_sent",
                category: .ai,
                properties: [
                    "query_type": queryType.rawValue,
                    "model": model
                ]
            )

        case .aiResponseReceived(let responseTime, let tokenCount):
            return AnalyticsEvent(
                name: "ai_response_received",
                category: .ai,
                properties: [
                    "response_time_ms": responseTime * 1000,
                    "token_count": tokenCount
                ]
            )

        case .aiFeatureUsed(let feature):
            return AnalyticsEvent(
                name: "ai_feature_used",
                category: .ai,
                properties: ["feature": feature.rawValue]
            )

        case .tabChanged(let from, let to):
            return AnalyticsEvent(
                name: "tab_changed",
                category: .navigation,
                properties: [
                    "from_tab": from,
                    "to_tab": to
                ]
            )

        case .deepLinkOpened(let url):
            return AnalyticsEvent(
                name: "deep_link_opened",
                category: .navigation,
                properties: ["url": url]
            )

        case .searchPerformed(let query, let resultCount):
            return AnalyticsEvent(
                name: "search_performed",
                category: .navigation,
                properties: [
                    "query": query,
                    "result_count": resultCount
                ]
            )

        case .settingChanged(let key, let value):
            return AnalyticsEvent(
                name: "setting_changed",
                category: .settings,
                properties: [
                    "setting_key": key,
                    "setting_value": String(describing: value)
                ]
            )

        case .dataExported(let format, let itemCount):
            return AnalyticsEvent(
                name: "data_exported",
                category: .settings,
                properties: [
                    "format": format,
                    "item_count": itemCount
                ]
            )

        case .dataImported(let source, let itemCount):
            return AnalyticsEvent(
                name: "data_imported",
                category: .settings,
                properties: [
                    "source": source,
                    "item_count": itemCount
                ]
            )

        case .appLaunched(let launchTime):
            return AnalyticsEvent(
                name: "app_launched",
                category: .performance,
                properties: ["launch_time_ms": launchTime * 1000]
            )

        case .screenLoaded(let screenName, let loadTime):
            return AnalyticsEvent(
                name: "screen_loaded",
                category: .performance,
                properties: [
                    "screen_name": screenName,
                    "load_time_ms": loadTime * 1000
                ]
            )

        case .imageLoaded(let url, let loadTime, let cacheHit):
            return AnalyticsEvent(
                name: "image_loaded",
                category: .performance,
                properties: [
                    "url": url,
                    "load_time_ms": loadTime * 1000,
                    "cache_hit": cacheHit
                ]
            )
        }
    }
}

// MARK: - Supporting Enums

enum BookSource: String {
    case manual = "manual"
    case scanner = "scanner"
    case search = "search"
    case goodreads = "goodreads"
    case api = "api"
}

enum NoteSource: String {
    case manual = "manual"
    case voice = "voice"
    case ambient = "ambient"
    case imported = "imported"
}

enum CaptureMethod: String {
    case manual = "manual"
    case camera = "camera"
    case voice = "voice"
    case paste = "paste"
}

enum ShareDestination: String {
    case messages = "messages"
    case mail = "mail"
    case twitter = "twitter"
    case instagram = "instagram"
    case clipboard = "clipboard"
    case other = "other"
}

enum AIQueryType: String {
    case chat = "chat"
    case summary = "summary"
    case recommendation = "recommendation"
    case analysis = "analysis"
}

enum AIFeature: String {
    case quoteAnalysis = "quote_analysis"
    case noteEnhancement = "note_enhancement"
    case bookRecommendation = "book_recommendation"
    case sessionSummary = "session_summary"
}

// MARK: - Analytics Implementation

final class Analytics: AnalyticsService {
    static let shared = Analytics()
    private var userId: String?
    private var sessionId: String?
    private var eventQueue: [AnalyticsEvent] = []
    private let queueLock = NSLock()
    private var flushTimer: Timer?

    private init() {
        startFlushTimer()
    }

    func track(_ event: AnalyticsEvent) {
        logger.debug("Tracking event: \(event.name) in category: \(event.category.rawValue)")

        queueLock.lock()
        eventQueue.append(event)
        queueLock.unlock()

        // Flush if queue is getting large
        if eventQueue.count >= 50 {
            flush()
        }

        // Send to crash reporter for breadcrumbs
        CrashReporter.shared.addBreadcrumb(
            "Event: \(event.name)",
            category: event.category.rawValue,
            level: .info
        )
    }

    func track(_ event: Event) {
        track(event.analyticsEvent)
    }

    func setUser(id: String) {
        self.userId = id
        logger.info("User ID set: \(id)")

        // Also update crash reporter
        CrashReporter.shared.setUserContext(id: id)
    }

    func setUserProperty(_ key: String, value: Any) {
        logger.debug("User property set: \(key) = \(String(describing: value))")
        // In production, send to analytics backend
    }

    func timing(_ name: String, time: TimeInterval) {
        let event = AnalyticsEvent(
            name: "timing",
            category: .performance,
            properties: [
                "metric_name": name,
                "time_ms": time * 1000
            ]
        )
        track(event)
    }

    func incrementCounter(_ name: String, by value: Int = 1) {
        let event = AnalyticsEvent(
            name: "counter",
            category: .performance,
            properties: [
                "counter_name": name,
                "increment": value
            ]
        )
        track(event)
    }

    func setValue(_ name: String, value: Double) {
        let event = AnalyticsEvent(
            name: "metric",
            category: .performance,
            properties: [
                "metric_name": name,
                "value": value
            ]
        )
        track(event)
    }

    func startSession() {
        sessionId = UUID().uuidString
        logger.info("Analytics session started: \(sessionId ?? "")")

        let event = AnalyticsEvent(
            name: "session_start",
            category: .performance
        )
        track(event)
    }

    func endSession() {
        guard let sessionId = self.sessionId else { return }

        let event = AnalyticsEvent(
            name: "session_end",
            category: .performance,
            properties: ["session_id": sessionId]
        )
        track(event)

        self.sessionId = nil
        flush()
    }

    func flush() {
        queueLock.lock()
        let eventsToSend = eventQueue
        eventQueue.removeAll()
        queueLock.unlock()

        guard !eventsToSend.isEmpty else { return }

        logger.info("Flushing \(eventsToSend.count) analytics events")

        // In production, send to analytics backend
        Task {
            await sendEvents(eventsToSend)
        }
    }

    // MARK: - Private Helpers

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.flush()
        }
    }

    private func sendEvents(_ events: [AnalyticsEvent]) async {
        // In production, implement actual network call to analytics backend
        #if DEBUG
        for event in events {
            logger.debug("Would send event: \(event.name) with properties: \(event.properties)")
        }
        #endif
    }

    deinit {
        flushTimer?.invalidate()
        flush()
    }
}