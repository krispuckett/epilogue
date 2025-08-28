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
        PerplexityStyleSessionsView()
    }
}

// MARK: - Chat View Wrapper
struct ChatViewWrapper: View {
    var body: some View {
        ChatView()
    }
}

// MARK: - Preview
#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}