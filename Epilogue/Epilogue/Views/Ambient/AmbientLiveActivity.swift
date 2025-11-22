import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Activity Attributes
struct AmbientActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var bookTitle: String?
        var sessionDuration: TimeInterval
        var capturedCount: Int
        var isListening: Bool
        var lastTranscript: String
    }
    
    var startTime: Date
}

// MARK: - Live Activity Widget
struct AmbientLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmbientActivityAttributes.self) { context in
            // Lock Screen View
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(.orange)
                        .font(.system(size: 16))
                    Text("Epilogue Listening")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(formatDuration(context.state.sessionDuration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                // Book context
                if let book = context.state.bookTitle {
                    Text(book)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Last transcript
                if !context.state.lastTranscript.isEmpty {
                    Text(context.state.lastTranscript)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Bottom controls
                HStack {
                    Label("\(context.state.capturedCount)", 
                          systemImage: "quote.bubble")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    // Pause/Resume button
                    Button(intent: ToggleAmbientListeningIntent()) {
                        Image(systemName: context.state.isListening ? 
                              "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    
                    // End session button
                    Button(intent: EndAmbientSessionIntent()) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .activityBackgroundTint(.black.opacity(0.8))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 8) {
                        if let book = context.state.bookTitle {
                            Text(book)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        
                        if !context.state.lastTranscript.isEmpty {
                            Text(context.state.lastTranscript)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        
                        HStack(spacing: 16) {
                            Label("\(context.state.capturedCount)", 
                                  systemImage: "quote.bubble")
                                .font(.system(size: 11))
                            
                            Text(formatDuration(context.state.sessionDuration))
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 20) {
                        // Toggle listening
                        Button(intent: ToggleAmbientListeningIntent()) {
                            Image(systemName: context.state.isListening ? 
                                  "pause.circle" : "play.circle")
                                .font(.system(size: 20))
                        }
                        .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        // End session
                        Button(intent: EndAmbientSessionIntent()) {
                            Text("End Session")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.red)
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
            } compactTrailing: {
                // Show captured count or duration
                if context.state.capturedCount > 0 {
                    Text("\(context.state.capturedCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                } else {
                    Text(formatDuration(context.state.sessionDuration, abbreviated: true))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "epilogue://ambient"))
            .keylineTint(.orange)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval, abbreviated: Bool = false) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = abbreviated ? [.minute, .second] : [.hour, .minute, .second]
        formatter.unitsStyle = abbreviated ? .abbreviated : .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
}

// MARK: - App Intents for Live Activity Controls

struct ToggleAmbientListeningIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Ambient Listening"
    
    func perform() async throws -> some IntentResult {
        // Toggle listening state
        await TrueAmbientProcessor.shared.toggleListening()
        
        // Update Live Activity
        await AmbientLiveActivityManager.shared.updateActivity()
        
        return .result()
    }
}

struct EndAmbientSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "End Ambient Session"
    
    func perform() async throws -> some IntentResult {
        // End the session
        _ = await TrueAmbientProcessor.shared.endSession()
        
        // End Live Activity
        await AmbientLiveActivityManager.shared.endActivity()
        
        return .result()
    }
}

// MARK: - Live Activity Manager (Legacy - Deprecated)
// This class is deprecated. Use LiveActivityLifecycleManager instead.
// Kept for backward compatibility during migration.

@MainActor
class AmbientLiveActivityManager {
    static let shared = AmbientLiveActivityManager()

    private init() {}

    /// Use LiveActivityLifecycleManager.shared.startSession() instead
    func startActivity() async {
        await LiveActivityLifecycleManager.shared.startSession()
    }

    /// Use LiveActivityLifecycleManager.shared.updateContent() instead
    func updateActivity(
        bookTitle: String? = nil,
        capturedCount: Int? = nil,
        isListening: Bool? = nil,
        lastTranscript: String? = nil
    ) async {
        await LiveActivityLifecycleManager.shared.updateContent(
            bookTitle: bookTitle,
            capturedCount: capturedCount,
            isListening: isListening,
            lastTranscript: lastTranscript
        )
    }

    /// Use LiveActivityLifecycleManager.shared.endSession() instead
    func endActivity() async {
        await LiveActivityLifecycleManager.shared.endSession()
    }
}

// MARK: - Preview Provider
struct AmbientLiveActivity_Previews: PreviewProvider {
    static let attributes = AmbientActivityAttributes(startTime: Date())
    static let contentState = AmbientActivityAttributes.ContentState(
        bookTitle: "The Great Gatsby",
        sessionDuration: 125,
        capturedCount: 3,
        isListening: true,
        lastTranscript: "In my younger and more vulnerable years..."
    )
    
    static var previews: some View {
        Group {
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.compact))
                .previewDisplayName("Compact")
            
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
                .previewDisplayName("Expanded")
            
            attributes
                .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
                .previewDisplayName("Minimal")
            
            attributes
                .previewContext(contentState, viewKind: .content)
                .previewDisplayName("Lock Screen")
        }
    }
}