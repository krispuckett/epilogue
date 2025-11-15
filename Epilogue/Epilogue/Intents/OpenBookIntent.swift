import AppIntents
import Foundation

/// Siri Intent: "Open [book] in Epilogue" or "Show me [book]"
struct OpenBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Book"
    static var description = IntentDescription("Open a specific book in your library")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Book")
    var book: BookEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Navigate to book detail
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToBook"),
            object: book.id,
            userInfo: [
                "bookId": book.id,
                "bookTitle": book.title
            ]
        )

        // Switch to library tab
        NotificationCenter.default.post(
            name: Notification.Name("SwitchToLibraryTab"),
            object: nil
        )

        return .result()
    }
}
