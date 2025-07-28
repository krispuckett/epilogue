import SwiftUI
import SwiftData
import Combine

// MARK: - Chat Message Model (for legacy compatibility)
struct ChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    let bookContext: Book?
    var isNew: Bool = true
}

// MARK: - Chat View
struct ChatView: View {
    var body: some View {
        UnifiedChatView()
    }
}

// MARK: - Chat View Wrapper (hides tab bar)
struct ChatViewWrapper: View {
    var body: some View {
        ChatView()
            .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Preview
#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}