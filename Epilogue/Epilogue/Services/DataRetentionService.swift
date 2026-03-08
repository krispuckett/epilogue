import Foundation
import SwiftData

// MARK: - Data Retention Service
/// Manages automatic cleanup of privacy-sensitive data based on user preferences.
/// Handles ambient transcripts, AI conversation history, and provides data summary stats.

@MainActor
final class DataRetentionService {
    static let shared = DataRetentionService()

    // MARK: - Retention Period

    enum RetentionPeriod: String, CaseIterable, Identifiable {
        case sevenDays = "7_days"
        case thirtyDays = "30_days"
        case ninetyDays = "90_days"
        case oneYear = "1_year"
        case never = "never"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .sevenDays: return "7 Days"
            case .thirtyDays: return "30 Days"
            case .ninetyDays: return "90 Days"
            case .oneYear: return "1 Year"
            case .never: return "Never"
            }
        }

        /// Returns the cutoff date for this retention period, or nil for "never"
        var cutoffDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .sevenDays:
                return calendar.date(byAdding: .day, value: -7, to: Date())
            case .thirtyDays:
                return calendar.date(byAdding: .day, value: -30, to: Date())
            case .ninetyDays:
                return calendar.date(byAdding: .day, value: -90, to: Date())
            case .oneYear:
                return calendar.date(byAdding: .year, value: -1, to: Date())
            case .never:
                return nil
            }
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let autoDeleteTranscripts = "privacy_autoDeleteTranscripts"
        static let transcriptRetention = "privacy_transcriptRetention"
        static let autoDeleteAIHistory = "privacy_autoDeleteAIHistory"
        static let aiHistoryRetention = "privacy_aiHistoryRetention"
        static let lastCleanupDate = "privacy_lastCleanupDate"
        static let lastMicrophoneAccess = "privacy_lastMicrophoneAccess"
    }

    // MARK: - Preferences

    var autoDeleteTranscripts: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoDeleteTranscripts) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoDeleteTranscripts) }
    }

    var transcriptRetentionPeriod: RetentionPeriod {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.transcriptRetention) ?? RetentionPeriod.ninetyDays.rawValue
            return RetentionPeriod(rawValue: raw) ?? .ninetyDays
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.transcriptRetention) }
    }

    var autoDeleteAIHistory: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.autoDeleteAIHistory) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoDeleteAIHistory) }
    }

    var aiHistoryRetentionPeriod: RetentionPeriod {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.aiHistoryRetention) ?? RetentionPeriod.ninetyDays.rawValue
            return RetentionPeriod(rawValue: raw) ?? .ninetyDays
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.aiHistoryRetention) }
    }

    var lastMicrophoneAccessDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastMicrophoneAccess) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastMicrophoneAccess) }
    }

    // MARK: - Data Summary

    struct DataSummary {
        let ambientSessionCount: Int
        let notesAndQuotesCount: Int
        let aiConversationCount: Int
        let lastMicrophoneAccess: Date?
    }

    func getDataSummary(modelContext: ModelContext) -> DataSummary {
        let sessionDescriptor = FetchDescriptor<AmbientSession>()
        let sessionCount = (try? modelContext.fetchCount(sessionDescriptor)) ?? 0

        let noteDescriptor = FetchDescriptor<CapturedNote>()
        let notesCount = (try? modelContext.fetchCount(noteDescriptor)) ?? 0

        let quoteDescriptor = FetchDescriptor<CapturedQuote>()
        let quotesCount = (try? modelContext.fetchCount(quoteDescriptor)) ?? 0

        let aiDescriptor = FetchDescriptor<ConversationMemoryEntry>()
        let aiCount = (try? modelContext.fetchCount(aiDescriptor)) ?? 0

        return DataSummary(
            ambientSessionCount: sessionCount,
            notesAndQuotesCount: notesCount + quotesCount,
            aiConversationCount: aiCount,
            lastMicrophoneAccess: lastMicrophoneAccessDate
        )
    }

    // MARK: - Cleanup

    /// Performs retention-based cleanup if needed. Call on app launch.
    func performCleanupIfNeeded(container: ModelContainer) {
        // Only run cleanup once per day
        let lastCleanup = UserDefaults.standard.object(forKey: Keys.lastCleanupDate) as? Date
        if let lastCleanup, Calendar.current.isDateInToday(lastCleanup) {
            return
        }

        let context = ModelContext(container)

        var deletedTranscripts = 0
        var deletedAIEntries = 0

        // Clean up ambient sessions
        if autoDeleteTranscripts, let cutoff = transcriptRetentionPeriod.cutoffDate {
            deletedTranscripts = deleteAmbientSessions(before: cutoff, context: context)
        }

        // Clean up AI conversation history
        if autoDeleteAIHistory, let cutoff = aiHistoryRetentionPeriod.cutoffDate {
            deletedAIEntries = deleteAIHistory(before: cutoff, context: context)
        }

        // Save and record
        if deletedTranscripts > 0 || deletedAIEntries > 0 {
            try? context.save()
            #if DEBUG
            print("🧹 [DataRetention] Cleaned up \(deletedTranscripts) ambient sessions, \(deletedAIEntries) AI entries")
            #endif
        }

        UserDefaults.standard.set(Date(), forKey: Keys.lastCleanupDate)
    }

    // MARK: - Bulk Clear

    /// Deletes all ambient sessions and their captured content.
    func clearAllVoiceTranscripts(modelContext: ModelContext) -> Int {
        var count = 0
        do {
            let descriptor = FetchDescriptor<AmbientSession>()
            let sessions = try modelContext.fetch(descriptor)
            count = sessions.count
            for session in sessions {
                modelContext.delete(session)
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ [DataRetention] Failed to clear voice transcripts: \(error)")
            #endif
        }
        return count
    }

    /// Deletes all AI conversation memory entries and threads.
    func clearAllAIHistory(modelContext: ModelContext) -> Int {
        var count = 0
        do {
            // Delete threads first (cascade should handle entries, but be explicit)
            let threadDescriptor = FetchDescriptor<MemoryThread>()
            let threads = try modelContext.fetch(threadDescriptor)
            for thread in threads {
                modelContext.delete(thread)
            }

            let entryDescriptor = FetchDescriptor<ConversationMemoryEntry>()
            let entries = try modelContext.fetch(entryDescriptor)
            count = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("❌ [DataRetention] Failed to clear AI history: \(error)")
            #endif
        }
        return count
    }

    // MARK: - Private Helpers

    private func deleteAmbientSessions(before cutoffDate: Date, context: ModelContext) -> Int {
        var count = 0
        do {
            let descriptor = FetchDescriptor<AmbientSession>(
                predicate: #Predicate<AmbientSession> { session in
                    session.startTime != nil && session.startTime! < cutoffDate
                }
            )
            let sessions = try context.fetch(descriptor)
            count = sessions.count
            for session in sessions {
                context.delete(session)
            }
        } catch {
            #if DEBUG
            print("❌ [DataRetention] Failed to delete old ambient sessions: \(error)")
            #endif
        }
        return count
    }

    private func deleteAIHistory(before cutoffDate: Date, context: ModelContext) -> Int {
        var count = 0
        do {
            let descriptor = FetchDescriptor<ConversationMemoryEntry>(
                predicate: #Predicate<ConversationMemoryEntry> { entry in
                    entry.timestamp < cutoffDate
                }
            )
            let entries = try context.fetch(descriptor)
            count = entries.count
            for entry in entries {
                context.delete(entry)
            }
        } catch {
            #if DEBUG
            print("❌ [DataRetention] Failed to delete old AI history: \(error)")
            #endif
        }
        return count
    }

    /// Records that the microphone was accessed. Safe to call from any thread.
    nonisolated func recordMicrophoneAccess() {
        UserDefaults.standard.set(Date(), forKey: "privacy_lastMicrophoneAccess")
    }
}
