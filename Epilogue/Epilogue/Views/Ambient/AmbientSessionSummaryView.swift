import SwiftUI
import SwiftData

// MARK: - Jony Ive-Inspired Minimalist Session Summary
struct AmbientSessionSummaryView: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    
    @State private var expandedQuestions = Set<String>()
    @State private var continuationText = ""
    @State private var isProcessingFollowUp = false
    @State private var additionalMessages: [UnifiedChatMessage] = []
    @FocusState private var isInputFocused: Bool
    @State private var showingCommandPalette = false
    @State private var isRecording = false
    @State private var contentOffset: CGFloat = 0
    @State private var isKeyInsightExpanded = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Subtle, almost invisible gradient
                minimalGradientBackground
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Clean header section
                        headerSection
                            .padding(.top, 20)
                            .padding(.bottom, 32)
                        
                        // Session metrics in monospace
                        metricsSection
                            .padding(.bottom, 32)
                        
                        // Primary content card
                        if let firstQuestion = session.capturedQuestions.first {
                            primaryInsightCard(question: firstQuestion)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                        }
                        
                        // Clean conversation threads
                        if !session.capturedQuestions.isEmpty {
                            conversationSection
                                .padding(.bottom, 32)
                        }
                        
                        // Captured content grid
                        if !session.capturedQuotes.isEmpty || !session.capturedNotes.isEmpty {
                            capturedContentGrid
                                .padding(.bottom, 32)
                        }
                        
                        // Follow-up messages
                        ForEach(additionalMessages) { message in
                            MinimalMessageView(message: message)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                        }
                        
                        Spacer(minLength: 120)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                customNavigationBar
            }
            .safeAreaInset(edge: .bottom) {
                minimalInputBar
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            if showingCommandPalette {
                commandPaletteOverlay
            }
        }
    }
    
    // MARK: - Book Gradient Background
    private var minimalGradientBackground: some View {
        ZStack {
            // Book-based gradient from colorPalette
            if let palette = colorPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 0.4, // Subtle but present
                    audioLevel: 0
                )
                .ignoresSafeArea()
            } else {
                // Fallback gradient
                AmbientChatGradientView()
                    .opacity(0.6)
                    .ignoresSafeArea()
            }
            
            // Subtle darkening overlay for readability
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Custom Navigation Bar
    private var customNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("Reading Session")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.95))
            
            Spacer()
            
            Menu {
                Button("Export Session") { exportSession() }
                Button("Share Insights") { shareInsights() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
    }
    
    // MARK: - Header Section with Book Cover
    private var headerSection: some View {
        VStack(spacing: 20) {
            if let book = session.book {
                // Book cover
                if let coverURL = book.coverImageURL {
                    SharedBookCoverView(
                        coverURL: coverURL,
                        width: 80,
                        height: 120
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
                
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text(book.author)
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Metrics Section (Monospaced)
    private var metricsSection: some View {
        HStack(spacing: 32) {
            metricItem(value: formatDuration(session.duration), label: "DURATION")
            if session.questions.count > 0 {
                metricItem(value: "\(session.questions.count)", label: "QUESTIONS")
            }
            if session.quotes.count > 0 {
                metricItem(value: "\(session.quotes.count)", label: "QUOTES")
            }
            if session.notes.count > 0 {
                metricItem(value: "\(session.notes.count)", label: "NOTES")
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func metricItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.95))
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
        }
    }
    
    // MARK: - Primary Insight Card
    private func primaryInsightCard(question: CapturedQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isKeyInsightExpanded.toggle()
                }
                HapticManager.shared.lightTap()
            }) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("KEY INSIGHT")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(1.2)
                        
                        Spacer()
                        
                        Image(systemName: isKeyInsightExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    Text(question.content)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.leading)
                }
                .padding(24)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isKeyInsightExpanded, let answer = question.answer {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5)
                    
                    Text(answer)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    // MARK: - Conversation Section
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CONVERSATION")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)
                .padding(.horizontal, 20)
            
            VStack(spacing: 1) {
                ForEach(Array(session.capturedQuestions.enumerated()), id: \.element.id) { index, question in
                    MinimalThreadView(
                        question: question,
                        index: index,
                        isExpanded: expandedQuestions.contains(question.id.uuidString),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedQuestions.contains(question.id.uuidString) {
                                    expandedQuestions.remove(question.id.uuidString)
                                } else {
                                    expandedQuestions.insert(question.id.uuidString)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Captured Content (Threaded like Conversation)
    private var capturedContentGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CAPTURED")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(session.capturedQuotes) { quote in
                    MinimalThreadedCard(
                        type: "QUOTE",
                        content: quote.text,
                        author: quote.author
                    )
                }
                
                ForEach(session.capturedNotes) { note in
                    MinimalThreadedCard(
                        type: "NOTE",
                        content: note.content,
                        author: nil
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Input Bar (Universal Input Bar WITHOUT .background())
    private var minimalInputBar: some View {
        VStack(spacing: 0) {
            // Processing indicator
            if isProcessingFollowUp {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Thinking...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 12)
            }
            
            // Universal Input Bar - matching UnifiedChatView
            UniversalInputBar(
                messageText: $continuationText,
                showingCommandPalette: $showingCommandPalette,
                isInputFocused: $isInputFocused,
                context: .chat(book: session.book),
                onSend: sendFollowUp,
                onMicrophoneTap: handleMicrophoneTap,
                isRecording: $isRecording,
                colorPalette: colorPalette,
                isAmbientMode: true
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Command Palette Overlay
    private var commandPaletteOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    showingCommandPalette = false
                }
            
            ChatCommandPalette(
                isPresented: $showingCommandPalette,
                selectedBook: .constant(session.book),
                commandText: $continuationText
            )
            .environmentObject(libraryViewModel)
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Helper Functions
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "00:%02d", seconds)
        }
    }
    
    private func sendFollowUp() {
        guard !continuationText.isEmpty else { return }
        
        let userMessage = UnifiedChatMessage(
            content: continuationText,
            isUser: true,
            timestamp: Date(),
            bookContext: session.book
        )
        additionalMessages.append(userMessage)
        
        let questionText = continuationText
        continuationText = ""
        isProcessingFollowUp = true
        
        Task {
            let aiService = AICompanionService.shared
            do {
                let response = try await aiService.processMessage(
                    questionText,
                    bookContext: session.book,
                    conversationHistory: additionalMessages
                )
                
                await MainActor.run {
                    let aiMessage = UnifiedChatMessage(
                        content: response,
                        isUser: false,
                        timestamp: Date(),
                        bookContext: session.book
                    )
                    additionalMessages.append(aiMessage)
                    isProcessingFollowUp = false
                }
            } catch {
                await MainActor.run {
                    isProcessingFollowUp = false
                }
            }
        }
    }
    
    private func handleMicrophoneTap() {
        isRecording.toggle()
        HapticManager.shared.lightTap()
    }
    
    private func exportSession() {
        // Export implementation
    }
    
    private func shareInsights() {
        // Share implementation
    }
}

// MARK: - Minimal Thread View
struct MinimalThreadView: View {
    let question: CapturedQuestion
    let index: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question row
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24)
                
                Text(question.content)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }
            
            // Answer (expandable)
            if isExpanded, let answer = question.answer {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                    
                    Text(answer)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 40)
                        .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
            }
        }
    }
}

// MARK: - Minimal Threaded Card (like conversation)
struct MinimalThreadedCard: View {
    let type: String
    let content: String
    let author: String?
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(type)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)
                .frame(width: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let author = author {
                    Text("— \(author)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Minimal Message View
struct MinimalMessageView: View {
    let message: UnifiedChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            Text(message.content)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(message.isUser ? .white.opacity(0.95) : .white.opacity(0.8))
                .padding(16)
                .glassEffect()
                .clipShape(Rectangle())
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}