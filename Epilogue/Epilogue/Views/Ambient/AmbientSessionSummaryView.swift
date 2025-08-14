import SwiftUI
import SwiftData

// MARK: - Award-Winning Session Summary View
struct AmbientSessionSummaryView: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    
    @State private var expandedQuestions = Set<String>()
    @State private var showFullTranscript = false
    @State private var continuationText = ""
    @State private var isProcessingFollowUp = false
    @State private var additionalMessages: [UnifiedChatMessage] = []
    @FocusState private var isInputFocused: Bool
    @State private var showShareSheet = false
    @State private var showExportOptions = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Animation states
    @State private var cardsVisible = false
    @State private var headerScale = 0.95
    
    var body: some View {
        ZStack {
            // Gradient background
            backgroundGradient
            
            // Main content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Session header
                        sessionHeaderView
                            .padding(.top, 100)
                            .scaleEffect(headerScale)
                            .onAppear {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    headerScale = 1.0
                                }
                            }
                        
                        // Quick actions
                        quickActionsRow
                            .opacity(cardsVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: cardsVisible)
                        
                        // Questions & Answers section
                        if !session.capturedQuestions.isEmpty {
                            questionsSection
                                .opacity(cardsVisible ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.2), value: cardsVisible)
                        }
                        
                        // Captured content
                        if !session.capturedQuotes.isEmpty || !session.capturedNotes.isEmpty {
                            capturedContentSection
                                .opacity(cardsVisible ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: cardsVisible)
                        }
                        
                        // Additional follow-up messages
                        ForEach(additionalMessages) { message in
                            ChatMessageView(
                                message: message,
                                currentBookContext: session.book,
                                colorPalette: colorPalette ?? defaultColorPalette
                            )
                            .id(message.id)
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: additionalMessages.count) { _, _ in
                    if let lastMessage = additionalMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        // Navigation bar
        .overlay(alignment: .top) {
            navigationBar
        }
        // Continuation input
        .safeAreaInset(edge: .bottom) {
            continuationInputBar
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                cardsVisible = true
            }
        }
        .sheet(isPresented: $showFullTranscript) {
            TranscriptView(session: session, colorPalette: colorPalette)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(session: session)
        }
    }
    
    // MARK: - Background Gradient
    @ViewBuilder
    private var backgroundGradient: some View {
        if let palette = colorPalette {
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: 0.7,
                audioLevel: 0
            )
            .ignoresSafeArea()
        } else {
            AmbientChatGradientView()
                .opacity(0.95)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .glassEffect()
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Menu {
                Button {
                    showFullTranscript = true
                } label: {
                    Label("Show Transcript", systemImage: "doc.text")
                }
                
                Button {
                    exportSession()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    shareInsights()
                } label: {
                    Label("Share Insights", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .glassEffect()
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Session Header
    private var sessionHeaderView: some View {
        VStack(spacing: 12) {
            // Title
            Text("Reading Session")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            
            // Book info (if available)
            if let book = session.book {
                HStack(spacing: 10) {
                    if let coverURL = book.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 36,
                            height: 54
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        
                        if !book.author.isEmpty {
                            Text(book.author)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Stats row
            HStack(spacing: 20) {
                statItem(icon: "clock", value: formatDuration(session.duration))
                statItem(icon: "questionmark.circle", value: "\(session.questions.count)")
                statItem(icon: "quote.bubble", value: "\(session.quotes.count)")
                if !session.notes.isEmpty {
                    statItem(icon: "note.text", value: "\(session.notes.count)")
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Quick Actions Row
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            SessionActionButton(title: "Summarize", icon: "text.badge.checkmark") {
                summarizeSession()
            }
            
            SessionActionButton(title: "Key takeaways", icon: "lightbulb") {
                extractKeyTakeaways()
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Questions Section
    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Questions & Answers")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(session.capturedQuestions) { question in
                    SessionQuestionCard(
                        question: question,
                        isExpanded: expandedQuestions.contains(question.id.uuidString),
                        onToggle: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedQuestions.contains(question.id.uuidString) {
                                    expandedQuestions.remove(question.id.uuidString)
                                } else {
                                    expandedQuestions.insert(question.id.uuidString)
                                }
                            }
                        },
                        onAskFollowUp: { followUp in
                            continuationText = followUp
                            sendFollowUp()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Captured Content Section
    private var capturedContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Captured Content")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 20)
            
            VStack(spacing: 10) {
                ForEach(session.capturedQuotes) { quote in
                    ContentCard(
                        icon: "quote.bubble",
                        text: quote.text,
                        author: quote.author,
                        type: .quote
                    )
                }
                
                ForEach(session.capturedNotes) { note in
                    ContentCard(
                        icon: "note.text",
                        text: note.content,
                        author: nil,
                        type: .note
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Continuation Input Bar
    private var continuationInputBar: some View {
        VStack(spacing: 0) {
            // Suggested actions
            if continuationText.isEmpty && !session.suggestedContinuations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["Summarize this session", "Key takeaways"], id: \.self) { suggestion in
                            Button {
                                continuationText = suggestion
                                sendFollowUp()
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassEffect()
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            
            // Input field
            HStack(spacing: 12) {
                TextField("Continue the conversation...", text: $continuationText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendFollowUp()
                    }
                
                if isProcessingFollowUp {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Button {
                        sendFollowUp()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(continuationText.isEmpty ? .white.opacity(0.3) : .white)
                    }
                    .disabled(continuationText.isEmpty)
                }
            }
            .padding(14)
            .glassEffect()
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Functions
    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassEffect()
        .clipShape(Capsule())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %02ds", minutes, seconds)
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
                    let errorMessage = UnifiedChatMessage(
                        content: "I couldn't process your question. Please try again.",
                        isUser: false,
                        timestamp: Date(),
                        bookContext: session.book
                    )
                    additionalMessages.append(errorMessage)
                    isProcessingFollowUp = false
                }
            }
        }
    }
    
    private func summarizeSession() {
        continuationText = "Summarize this reading session"
        sendFollowUp()
    }
    
    private func extractKeyTakeaways() {
        continuationText = "What are the key takeaways from this session?"
        sendFollowUp()
    }
    
    private func exportSession() {
        showExportOptions = true
    }
    
    private func shareInsights() {
        showShareSheet = true
    }
    
    private var defaultColorPalette: ColorPalette {
        ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26),
            secondary: Color(red: 0.8, green: 0.3, blue: 0.4),
            accent: Color(red: 0.6, green: 0.2, blue: 0.5),
            background: Color.black,
            textColor: Color.white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    }
}

// MARK: - Question Card (Properly Designed)
struct SessionQuestionCard: View {
    let question: CapturedQuestion
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAskFollowUp: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                        .frame(width: 24, height: 24)
                    
                    Text(question.content)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            
            // Answer (expandable)
            if isExpanded, let answer = question.answer {
                VStack(alignment: .leading, spacing: 16) {
                    Text(answer)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                    
                    // Follow-up actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ask a follow-up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FollowUpChip(text: "Tell me more") {
                                    onAskFollowUp("Tell me more about this")
                                }
                                
                                FollowUpChip(text: "Why is this important?") {
                                    onAskFollowUp("Why is this important?")
                                }
                                
                                FollowUpChip(text: "Examples?") {
                                    onAskFollowUp("Can you give me examples?")
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Content Card
struct ContentCard: View {
    let icon: String
    let text: String
    let author: String?
    let type: ContentType
    
    enum ContentType {
        case quote, note
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(type == .quote ? .green : .orange)
                .frame(width: 20, height: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let author = author {
                    Text("— \(author)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Action Button
struct SessionActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Follow-up Chip
struct FollowUpChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .glassEffect()
                .clipShape(Capsule())
        }
    }
}

// MARK: - Transcript View
struct TranscriptView: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if let palette = colorPalette {
                    BookAtmosphericGradientView(
                        colorPalette: palette,
                        intensity: 0.5,
                        audioLevel: 0
                    )
                    .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(session.transcriptSegments.enumerated()), id: \.element.id) { _, segment in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: segment.speaker == .user ? "person.circle" : "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(segment.speaker == .user ? "You" : "AI")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                    
                                    Text(segment.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .glassEffect()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: View {
    let session: AmbientSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share options coming soon")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Share Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}