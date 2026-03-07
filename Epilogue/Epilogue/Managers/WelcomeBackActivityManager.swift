import ActivityKit
import SwiftUI
import SwiftData

// MARK: - Activity Attributes (must match widget definition)
struct WelcomeBackActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bookTitle: String
        var authorName: String
        var progressPercent: Int // 0-100
        var greeting: String // "Good morning", "Welcome back", etc.
    }

    // Fixed properties
    var bookCoverURL: String?
}

/// Manages the Welcome Back Live Activity that shows in Dynamic Island
@MainActor
final class WelcomeBackActivityManager {
    static let shared = WelcomeBackActivityManager()

    private var currentActivity: Activity<WelcomeBackActivityAttributes>?

    private init() {}

    // MARK: - Start Activity

    /// Starts the Welcome Back Live Activity in the Dynamic Island
    /// - Parameters:
    ///   - bookTitle: The title of the current book
    ///   - authorName: The author's name
    ///   - progressPercent: Reading progress (0-100)
    ///   - coverURL: Optional cover image URL
    func startActivity(
        bookTitle: String,
        authorName: String,
        progressPercent: Int,
        coverURL: String? = nil
    ) {
        // Don't start if already active
        guard currentActivity == nil else {
            #if DEBUG
            print("🎴 WelcomeBackActivity: Already active, updating instead")
            #endif
            updateActivity(progressPercent: progressPercent)
            return
        }

        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("🎴 WelcomeBackActivity: Live Activities not enabled")
            #endif
            return
        }

        let greeting = Self.timeBasedGreeting()

        let attributes = WelcomeBackActivityAttributes(bookCoverURL: coverURL)
        let initialState = WelcomeBackActivityAttributes.ContentState(
            bookTitle: bookTitle,
            authorName: authorName,
            progressPercent: progressPercent,
            greeting: greeting
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity

            #if DEBUG
            print("🎴 WelcomeBackActivity: Started - \(bookTitle) (\(progressPercent)%)")
            #endif

            // Auto-end after 30 seconds (user should have seen it by then)
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await endActivity()
            }

        } catch {
            #if DEBUG
            print("🎴 WelcomeBackActivity: Failed to start - \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Update Activity

    func updateActivity(progressPercent: Int) {
        guard let activity = currentActivity else { return }

        let greeting = Self.timeBasedGreeting()

        Task {
            let updatedState = WelcomeBackActivityAttributes.ContentState(
                bookTitle: activity.content.state.bookTitle,
                authorName: activity.content.state.authorName,
                progressPercent: progressPercent,
                greeting: greeting
            )

            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )

            #if DEBUG
            print("🎴 WelcomeBackActivity: Updated progress to \(progressPercent)%")
            #endif
        }
    }

    // MARK: - End Activity

    func endActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = activity.content.state
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        currentActivity = nil

        #if DEBUG
        print("🎴 WelcomeBackActivity: Ended")
        #endif
    }

    /// End activity when user taps to open app
    func endActivityOnAppOpen() {
        Task {
            await endActivity()
        }
    }

    // MARK: - Helpers

    private static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Welcome back"
        }
    }

    /// Check if a welcome back activity is currently running
    var isActive: Bool {
        currentActivity != nil
    }
}

// MARK: - Convenience extension for starting from BookModel
extension WelcomeBackActivityManager {

    /// Start activity from a BookModel
    func startActivity(for book: BookModel) {
        let progressPercent: Int
        if let pageCount = book.pageCount, pageCount > 0 {
            progressPercent = Int((Double(book.currentPage) / Double(pageCount)) * 100)
        } else {
            progressPercent = 0
        }

        startActivity(
            bookTitle: book.title,
            authorName: book.author,
            progressPercent: progressPercent,
            coverURL: book.coverImageURL
        )
    }
}
