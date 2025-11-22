import SwiftUI
import SwiftData

/// PROTOTYPE: Simple UI to test discovery conversation flow
/// This demonstrates the core concept without modifying UnifiedChatView
struct DiscoveryPrototypeView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var service = DiscoveryConversationService.shared

    @State private var messages: [DisplayMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            messageView(message)
                                .id(message.id)
                        }

                        if isProcessing {
                            processingView
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input
            inputBar
        }
        .onAppear {
            showGreeting()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Book Discovery")
                .font(.headline)

            Text("PROTOTYPE - Testing conversation flow")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(white: 0.1))
    }

    // MARK: - Messages

    private func messageView(_ message: DisplayMessage) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Text content
            Text(message.content)
                .padding(12)
                .background(
                    message.isUser
                        ? Color.blue.opacity(0.2)
                        : Color.white.opacity(0.1)
                )
                .cornerRadius(12)
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            // Recommendations (if any)
            if !message.recommendations.isEmpty {
                ForEach(message.recommendations) { rec in
                    recommendationCard(rec)
                }
            }
        }
    }

    private func recommendationCard(_ rec: BookRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title & Author
            VStack(alignment: .leading, spacing: 4) {
                Text(rec.title)
                    .font(.headline)
                Text(rec.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            if !rec.description.isEmpty {
                Text(rec.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Reasoning
            HStack(alignment: .top, spacing: 8) {
                Text("💡")
                Text(rec.reasoning)
                    .font(.callout)
                    .foregroundStyle(.blue)
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    addToLibrary(rec)
                }) {
                    Label("Add to Library", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    askForMoreInfo(rec)
                }) {
                    Label("Tell Me More", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Thinking...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("What are you looking for?", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .disabled(isProcessing)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(inputText.isEmpty || isProcessing)
        }
        .padding()
        .background(Color(white: 0.1))
    }

    // MARK: - Actions

    private func showGreeting() {
        let greeting: String
        if libraryViewModel.books.isEmpty {
            greeting = """
            👋 Hi! I'm here to help you discover your next great read.

            I can recommend books based on:
            • What you're in the mood for
            • Authors or books you've loved
            • Themes or topics you're curious about

            What kind of book are you looking for?
            """
        } else {
            let topGenre = "fiction"  // Would analyze library
            greeting = """
            📚 Ready to find your next book?

            I've noticed you enjoy \(topGenre). I can suggest something similar, or help you explore something completely different.

            What sounds good right now?
            """
        }

        messages.append(DisplayMessage(
            content: greeting,
            isUser: false,
            recommendations: []
        ))
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        // Add user message
        let userMessage = inputText
        messages.append(DisplayMessage(
            content: userMessage,
            isUser: true,
            recommendations: []
        ))

        inputText = ""
        isProcessing = true

        Task {
            do {
                // Convert library books
                let library = libraryViewModel.books.map { book in
                    BookModel(
                        id: book.id.uuidString,
                        localId: book.id.uuidString,
                        title: book.title,
                        author: book.author,
                        publishedYear: nil,
                        coverImageURL: nil,
                        isbn: book.isbn,
                        desc: book.bookDescription ?? "",
                        pageCount: book.totalPages,
                        isInLibrary: true,
                        readingStatus: "unread",
                        currentPage: book.currentPage ?? 0,
                        dateAdded: book.dateAdded
                    )
                }

                // Build conversation history
                let conversationHistory = messages.map { msg in
                    ConversationMessage(
                        role: msg.isUser ? "user" : "assistant",
                        content: msg.content
                    )
                }

                // Get AI response
                let response = try await service.handleMessage(
                    userMessage,
                    library: library,
                    conversationHistory: conversationHistory
                )

                // Add assistant message
                await MainActor.run {
                    messages.append(DisplayMessage(
                        content: response.text,
                        isUser: false,
                        recommendations: response.recommendations
                    ))
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.append(DisplayMessage(
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        isUser: false,
                        recommendations: []
                    ))
                    isProcessing = false
                }
            }
        }
    }

    private func addToLibrary(_ rec: BookRecommendation) {
        // Would add book to library
        messages.append(DisplayMessage(
            content: "Great choice! I've added \(rec.title) to your library. Want more recommendations?",
            isUser: false,
            recommendations: []
        ))
    }

    private func askForMoreInfo(_ rec: BookRecommendation) {
        // Would show detailed view
        inputText = "Tell me more about \(rec.title)"
        sendMessage()
    }
}

// MARK: - Display Message Model

struct DisplayMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let recommendations: [BookRecommendation]
}

// MARK: - Preview

#Preview {
    DiscoveryPrototypeView()
        .environmentObject(LibraryViewModel())
        .preferredColorScheme(.dark)
}
