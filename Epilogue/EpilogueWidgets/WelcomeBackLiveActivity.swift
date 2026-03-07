//
//  WelcomeBackLiveActivity.swift
//  EpilogueWidgets
//
//  Welcome Back Live Activity - Shows in Dynamic Island on app return
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
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

// MARK: - Welcome Back Live Activity Widget
struct WelcomeBackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WelcomeBackActivityAttributes.self) { context in
            // Lock Screen / Banner View
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View - Shows when user long-presses
                DynamicIslandExpandedRegion(.leading) {
                    // Book icon
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Progress
                    Text("\(context.state.progressPercent)%")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.greeting)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(context.state.bookTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Tap to continue reading")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))

                        Spacer()

                        // Progress bar
                        ProgressView(value: Double(context.state.progressPercent), total: 100)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                // Compact: Book icon
                Image(systemName: "book.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
            } compactTrailing: {
                // Compact: Progress or greeting
                Text("\(context.state.progressPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            } minimal: {
                // Minimal: Just book icon
                Image(systemName: "book.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
            }
            .widgetURL(URL(string: "epilogue://welcomeback"))
            .keylineTint(.orange)
        }
    }

    // MARK: - Lock Screen View
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WelcomeBackActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            // Book icon (since we can't load images in widgets easily)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.2))
                    .frame(width: 50, height: 70)

                Image(systemName: "book.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.greeting)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(context.state.bookTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)

                Text(context.state.authorName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                // Progress bar
                HStack(spacing: 8) {
                    ProgressView(value: Double(context.state.progressPercent), total: 100)
                        .progressViewStyle(.linear)
                        .tint(.orange)

                    Text("\(context.state.progressPercent)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.9))
        .activitySystemActionForegroundColor(.orange)
    }
}

// MARK: - Preview
#Preview("Compact", as: .dynamicIsland(.compact), using: WelcomeBackActivityAttributes(bookCoverURL: nil)) {
    WelcomeBackLiveActivity()
} contentStates: {
    WelcomeBackActivityAttributes.ContentState(
        bookTitle: "The Lord of the Rings",
        authorName: "J.R.R. Tolkien",
        progressPercent: 35,
        greeting: "Welcome back"
    )
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: WelcomeBackActivityAttributes(bookCoverURL: nil)) {
    WelcomeBackLiveActivity()
} contentStates: {
    WelcomeBackActivityAttributes.ContentState(
        bookTitle: "The Lord of the Rings",
        authorName: "J.R.R. Tolkien",
        progressPercent: 35,
        greeting: "Good morning"
    )
}

#Preview("Lock Screen", as: .content, using: WelcomeBackActivityAttributes(bookCoverURL: nil)) {
    WelcomeBackLiveActivity()
} contentStates: {
    WelcomeBackActivityAttributes.ContentState(
        bookTitle: "The Lord of the Rings",
        authorName: "J.R.R. Tolkien",
        progressPercent: 35,
        greeting: "Welcome back"
    )
}
