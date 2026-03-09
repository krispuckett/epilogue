//
//  ReadingSessionLiveActivity.swift
//  EpilogueWidgets
//
//  Reading session Live Activity for Dynamic Island + Lock Screen.
//  This file must be added to the EpilogueWidgets target in Xcode.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (must match main app definition)
struct AmbientActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bookTitle: String?
        var sessionDuration: TimeInterval
        var capturedCount: Int
        var isListening: Bool
        var lastTranscript: String
        var pagesRead: Int = 0
        var coverAccentHex: String?
        var nudgeMessage: String?
        var nudgeIcon: String?
    }

    var startTime: Date
    var coverImagePath: String?
    var orbImagePath: String?
}

// MARK: - Reading Session Live Activity Widget
struct ReadingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbientActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            let accent = accentColor(from: context.state.coverAccentHex)

            return DynamicIsland {
                // MARK: Expanded — Leading (empty, lets center fill toward it)
                DynamicIslandExpandedRegion(.leading) {
                    Color.clear.frame(width: 0)
                }

                // MARK: Expanded — Trailing (Timer)
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.startTime, style: .timer)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)

                        if context.state.pagesRead > 0 {
                            Text("\(context.state.pagesRead)p")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Expanded — Center (Cover + Title + Stats)
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 10) {
                        bookCoverView(path: context.attributes.coverImagePath,
                                      accentHex: context.state.coverAccentHex,
                                      width: 34, height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            if let book = context.state.bookTitle {
                                Text(book)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                if context.state.isListening {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 5, height: 5)
                                        Text("Live")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.green)
                                    }
                                }

                                if context.state.capturedCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "quote.bubble.fill")
                                            .font(.system(size: 8))
                                        Text("\(context.state.capturedCount)")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(accent)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // MARK: Expanded — Bottom (Quick Actions)
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 0) {
                        // Nudge banner (above actions)
                        if let nudge = context.state.nudgeMessage,
                           let icon = context.state.nudgeIcon {
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 9))
                                Text(nudge)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(accent)
                            .padding(.bottom, 6)
                        }

                        // Action bar
                        HStack(spacing: 0) {
                            Link(destination: URL(string: "epilogue://ambient/voice-capture")!) {
                                actionPill(icon: "waveform", label: "Listen", color: accent)
                            }

                            Spacer()

                            Link(destination: URL(string: "epilogue://ambient/ocr")!) {
                                actionPill(icon: "text.quote", label: "Quote", color: accent)
                            }

                            Spacer()

                            Link(destination: URL(string: "epilogue://ambient/ai-chat")!) {
                                VStack(spacing: 3) {
                                    orbView(path: context.attributes.orbImagePath, color: accent, size: 22)
                                    Text("Ask")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(accent)
                                }
                                .frame(minWidth: 48)
                            }

                            Spacer()

                            Link(destination: URL(string: "epilogue://ambient/end-session")!) {
                                actionPill(icon: "stop.fill", label: "End", color: .red)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                if let path = context.attributes.coverImagePath,
                   let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 14, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    orbView(path: context.attributes.orbImagePath, color: accent, size: 16)
                }
            } compactTrailing: {
                if context.state.capturedCount > 0 {
                    HStack(spacing: 2) {
                        Text("\(context.state.capturedCount)")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(accent)
                } else {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52)
                        .multilineTextAlignment(.trailing)
                }
            } minimal: {
                if let path = context.attributes.coverImagePath,
                   let uiImage = UIImage(contentsOfFile: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 12, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    orbView(path: context.attributes.orbImagePath, color: accent, size: 14)
                }
            }
            .widgetURL(URL(string: "epilogue://ambient"))
            .keylineTint(accent)
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<AmbientActivityAttributes>) -> some View {
        let accent = accentColor(from: context.state.coverAccentHex)

        VStack(alignment: .leading, spacing: 10) {
            // Header: cover + title + timer
            HStack(spacing: 10) {
                bookCoverView(path: context.attributes.coverImagePath,
                              accentHex: context.state.coverAccentHex,
                              width: 36, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    if let book = context.state.bookTitle {
                        Text(book)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Text(context.attributes.startTime, style: .timer)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if context.state.isListening {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
            }

            // Stats strip
            if context.state.capturedCount > 0 || context.state.pagesRead > 0 {
                HStack(spacing: 14) {
                    if context.state.capturedCount > 0 {
                        Label("\(context.state.capturedCount) captured", systemImage: "quote.bubble.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accent)
                    }

                    if context.state.pagesRead > 0 {
                        Label("\(context.state.pagesRead) pages", systemImage: "book.pages")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.cyan)
                    }
                }
            }

            // Nudge card
            if let nudge = context.state.nudgeMessage,
               let icon = context.state.nudgeIcon {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                    Text(nudge)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // Transcript preview
            if !context.state.lastTranscript.isEmpty {
                Text(context.state.lastTranscript)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            // Quick actions
            HStack(spacing: 0) {
                Link(destination: URL(string: "epilogue://ambient/voice-capture")!) {
                    lockScreenAction(icon: "waveform", color: accent)
                }

                Spacer()

                Link(destination: URL(string: "epilogue://ambient/ocr")!) {
                    lockScreenAction(icon: "text.quote", color: accent)
                }

                Spacer()

                Link(destination: URL(string: "epilogue://ambient/ai-chat")!) {
                    orbView(path: context.attributes.orbImagePath, color: accent, size: 28)
                        .frame(width: 36, height: 36)
                }

                Spacer()

                Link(destination: URL(string: "epilogue://ambient/end-session")!) {
                    Text("End")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .activityBackgroundTint(.black.opacity(0.9))
    }

    // MARK: - Orb View (pre-rendered Metal snapshot or SwiftUI fallback)

    @ViewBuilder
    private func orbView(path: String?, color: Color, size: CGFloat) -> some View {
        if let path = path, let uiImage = UIImage(contentsOfFile: path) {
            // Pre-rendered Metal shader snapshot
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // SwiftUI fallback approximation
            staticOrbFallback(color: color, size: size)
        }
    }

    @ViewBuilder
    private func staticOrbFallback(color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.4), color.opacity(0.1), .clear],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.8), color.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.75, height: size * 0.75)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), color, color.opacity(0.5)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.45, height: size * 0.45)
        }
        .clipShape(Circle())
    }

    // MARK: - Component Helpers

    @ViewBuilder
    private func bookCoverView(path: String?, accentHex: String?, width: CGFloat, height: CGFloat) -> some View {
        if let path = path, let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor(from: accentHex).opacity(0.25))
                .frame(width: width, height: height)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: width * 0.35))
                        .foregroundStyle(accentColor(from: accentHex))
                )
        }
    }

    @ViewBuilder
    private func actionPill(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .frame(minWidth: 48)
    }

    @ViewBuilder
    private func lockScreenAction(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }

    // MARK: - Utilities

    private func accentColor(from hex: String?) -> Color {
        guard let hex = hex, hex.count >= 6 else { return .orange }
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard clean.count == 6,
              let rgb = UInt64(clean, radix: 16) else { return .orange }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// MARK: - Previews

#Preview("Compact", as: .dynamicIsland(.compact), using: AmbientActivityAttributes(startTime: Date())) {
    ReadingSessionLiveActivity()
} contentStates: {
    AmbientActivityAttributes.ContentState(
        bookTitle: "The Great Gatsby",
        sessionDuration: 3725,
        capturedCount: 3,
        isListening: true,
        lastTranscript: "",
        pagesRead: 42,
        coverAccentHex: "#4A90D9"
    )
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: AmbientActivityAttributes(startTime: Date())) {
    ReadingSessionLiveActivity()
} contentStates: {
    AmbientActivityAttributes.ContentState(
        bookTitle: "The Great Gatsby",
        sessionDuration: 3725,
        capturedCount: 3,
        isListening: true,
        lastTranscript: "In my younger years...",
        pagesRead: 42,
        coverAccentHex: "#4A90D9",
        nudgeMessage: "Anything worth capturing?",
        nudgeIcon: "text.quote"
    )
}

#Preview("Lock Screen", as: .content, using: AmbientActivityAttributes(startTime: Date())) {
    ReadingSessionLiveActivity()
} contentStates: {
    AmbientActivityAttributes.ContentState(
        bookTitle: "The Great Gatsby",
        sessionDuration: 3725,
        capturedCount: 3,
        isListening: true,
        lastTranscript: "In my younger and more vulnerable years...",
        pagesRead: 42,
        coverAccentHex: "#4A90D9",
        nudgeMessage: "25 pages today",
        nudgeIcon: "star.fill"
    )
}
