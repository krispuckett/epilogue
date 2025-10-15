import SwiftUI

// MARK: - Conversation Counter (Visual Component)
struct ConversationCounter: View {
    @StateObject private var storeKit = SimplifiedStoreKitManager.shared
    @AppStorage("devShowConversationCounter") private var devShowCounter = false

    var body: some View {
        // Show if: free user with remaining count OR developer mode enabled
        if ((!storeKit.isPlus && storeKit.conversationsRemaining() != nil) || devShowCounter) {
            counterView
        }
    }

    private var counterView: some View {
        HStack(spacing: 4) {
            // Dot indicators
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(index < remainingCount ? DesignSystem.Colors.primaryAccent : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }

            Text("\(remainingCount) left this month")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .kerning(0.5)
                .foregroundColor(.white.opacity(0.7))

            // Developer mode indicator
            if devShowCounter && storeKit.isPlus {
                Text("(DEV)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var remainingCount: Int {
        if devShowCounter && storeKit.isPlus {
            // Show mock data in dev mode if user is Plus
            return 3
        }
        return storeKit.conversationsRemaining() ?? 8
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Conversation Counter Preview")
                .foregroundColor(.white)

            ConversationCounter()

            Text("Enable 'Show Counter' in Settings > Developer to see mock data")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
