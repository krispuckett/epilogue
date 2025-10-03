import SwiftUI

/// Liquid glass status pill showing offline/online state and queue depth
struct OfflineStatusPill: View {
    @ObservedObject var queueManager = OfflineQueueManager.shared
    @State private var pulseAnimation = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon with animation
            ZStack {
                // Pulse ring when processing
                if queueManager.isProcessing {
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                }

                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.bounce, value: queueManager.isOnline)
            }
            .frame(width: 20, height: 20)

            // Status text
            Text(statusText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))

            // Queue depth badge
            if queueManager.queueDepth > 0 {
                Text("\(queueManager.queueDepth)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.9))
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: queueManager.isOnline)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: queueManager.queueDepth)
        .onAppear {
            // Start pulse animation for processing state
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }

    private var statusIcon: String {
        if queueManager.isProcessing {
            return "arrow.triangle.2.circlepath"
        } else if !queueManager.isOnline {
            return "wifi.slash"
        } else if queueManager.queueDepth > 0 {
            return "checkmark.circle.fill"
        } else {
            return "wifi"
        }
    }

    private var statusText: String {
        if queueManager.isProcessing {
            return "Processing..."
        } else if !queueManager.isOnline {
            return "Offline"
        } else if queueManager.queueDepth > 0 {
            return "Queue"
        } else {
            return "Online"
        }
    }

    private var statusColor: Color {
        if queueManager.isProcessing {
            return .blue
        } else if !queueManager.isOnline {
            return .orange
        } else if queueManager.queueDepth > 0 {
            return .green
        } else {
            return .green
        }
    }
}

/// Enhanced mode toggle button with icons
struct AmbientModeToggleButton: View {
    let isVoiceMode: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isVoiceMode ? "waveform" : "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolEffect(.bounce, value: isVoiceMode)

                Text(isVoiceMode ? "Voice" : "Text")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .sensoryFeedback(.selection, trigger: isVoiceMode)
    }
}