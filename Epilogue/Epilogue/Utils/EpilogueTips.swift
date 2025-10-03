import SwiftUI
import TipKit

// MARK: - Ambient Mode Tips

/// Tip for discovering voice mode in Ambient
struct VoiceModeTip: Tip {
    var title: Text {
        Text("Ask Questions Aloud")
    }

    var message: Text? {
        Text("Toggle voice mode to ask questions hands-free while reading. Perfect for physical books.")
    }

    var image: Image? {
        Image(systemName: "waveform")
    }

    // Show after user has opened Ambient mode once
    var rules: [Rule] {
        #Rule(Self.$hasOpenedAmbient) {
            $0.donations.count >= 1
        }
    }

    @Parameter
    static var hasOpenedAmbient: Bool = false
}

/// Tip for Ambient Mode's intelligent features
struct AmbientIntelligenceTip: Tip {
    var title: Text {
        Text("I Remember Everything")
    }

    var message: Text? {
        Text("Ask \"What did I say about Gandalf?\" or \"Show my quotes about power\" - I have perfect memory of this session.")
    }

    var image: Image? {
        Image(systemName: "brain.fill")
    }

    // Show after user has asked 3+ questions
    var rules: [Rule] {
        #Rule(Self.$questionsAsked) {
            $0.donations.count >= 3
        }
    }

    @Parameter
    static var questionsAsked: Int = 0
}

/// Tip for page tracking
struct PageTrackingTip: Tip {
    var title: Text {
        Text("Track Your Page")
    }

    var message: Text? {
        Text("Say \"page 247\" to track where you are in the book. I'll remember your progress.")
    }

    var image: Image? {
        Image(systemName: "book.pages")
    }

    // Show after first Ambient session
    var rules: [Rule] {
        #Rule(Self.$hasUsedAmbient) {
            $0.donations.count >= 1
        }
    }

    @Parameter
    static var hasUsedAmbient: Bool = false
}

// MARK: - Library Tips

/// Tip for the Ambient Orb quick access
struct AmbientOrbTip: Tip {
    var title: Text {
        Text("Quick Access to Ambient Mode")
    }

    var message: Text? {
        Text("Tap the floating orb from any screen to instantly start a reading session.")
    }

    var image: Image? {
        Image(systemName: "circlebadge.fill")
    }

    // Show on library view after app launch
    var rules: [Rule] {
        #Rule(Self.$appLaunches) {
            $0.donations.count >= 2 // After second launch
        }
    }

    @Parameter
    static var appLaunches: Int = 0
}

/// Tip for book scanning
struct BookScanTip: Tip {
    var title: Text {
        Text("Scan Books Instantly")
    }

    var message: Text? {
        Text("Point your camera at any book cover to add it to your library with full details.")
    }

    var image: Image? {
        Image(systemName: "camera.viewfinder")
    }

    // Show if library is empty or has < 3 books
    var rules: [Rule] {
        #Rule(Self.$bookCount) {
            $0.donations.count < 3
        }
    }

    @Parameter
    static var bookCount: Int = 0
}

// MARK: - Notes & Captures Tips

/// Tip for quote capture
struct QuoteCaptureTip: Tip {
    var title: Text {
        Text("Capture Quotes Instantly")
    }

    var message: Text? {
        Text("Use the camera or voice to save meaningful passages. They're automatically linked to the book.")
    }

    var image: Image? {
        Image(systemName: "quote.opening")
    }

    // Show after adding first book
    var rules: [Rule] {
        #Rule(Self.$hasBooks) {
            $0.donations.count >= 1
        }
    }

    @Parameter
    static var hasBooks: Bool = false
}

/// Tip for session summaries
struct SessionSummaryTip: Tip {
    var title: Text {
        Text("Session Insights")
    }

    var message: Text? {
        Text("After each reading session, see a summary of themes explored, questions asked, and quotes captured.")
    }

    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }

    // Show after completing first session
    var rules: [Rule] {
        #Rule(Self.$sessionsCompleted) {
            $0.donations.count >= 1
        }
    }

    @Parameter
    static var sessionsCompleted: Int = 0
}

// MARK: - TipKit Configuration Helper

struct EpilogueTips {
    /// Configure TipKit on app launch
    static func configure() {
        #if DEBUG
        // Reset tips in debug for testing
        try? Tips.resetDatastore()
        #endif

        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    /// Donation helpers for tracking user actions
    static func donateAppLaunch() {
        AmbientOrbTip.appLaunches.donate()
    }

    static func donateAmbientOpened() {
        VoiceModeTip.hasOpenedAmbient.donate()
        PageTrackingTip.hasUsedAmbient.donate()
    }

    static func donateQuestionAsked() {
        AmbientIntelligenceTip.questionsAsked.donate()
    }

    static func donateBookAdded(totalBooks: Int) {
        BookScanTip.bookCount.donate()
        if totalBooks >= 1 {
            QuoteCaptureTip.hasBooks.donate()
        }
    }

    static func donateSessionCompleted() {
        SessionSummaryTip.sessionsCompleted.donate()
    }
}

// MARK: - Liquid Glass Tip Styling

struct LiquidGlassTipViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Color.white.opacity(0.9))
            .foregroundStyle(.white)
            .glassEffect()
            .padding(12)
    }
}

extension View {
    /// Style TipKit tooltip with liquid glass aesthetic
    func liquidGlassTip() -> some View {
        modifier(LiquidGlassTipViewModifier())
    }
}
