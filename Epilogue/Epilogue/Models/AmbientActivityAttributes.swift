import ActivityKit
import Foundation

// MARK: - Ambient Activity Attributes (Shared)
// This file must be added to BOTH the main app target AND the EpilogueWidgets
// widget extension target in Xcode for Live Activities to work.

struct AmbientActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bookTitle: String?
        var sessionDuration: TimeInterval
        var capturedCount: Int
        var isListening: Bool
        var lastTranscript: String
        // KRI-134: Reading Session Dashboard
        var pagesRead: Int = 0
        var coverAccentHex: String?   // Hex color from book cover for swatch
        var nudgeMessage: String?     // Proactive nudge text
        var nudgeIcon: String?        // SF Symbol for nudge
    }

    var startTime: Date
    var coverImagePath: String?  // File path to cover thumbnail in App Group container
    var orbImagePath: String?    // File path to pre-rendered orb snapshot in App Group container
}
