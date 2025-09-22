import SwiftUI
import SwiftData

// MARK: - Jony Ive-Inspired Minimalist Session Summary
struct AmbientSessionSummaryView: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    var onDismiss: (() -> Void)? = nil  // Custom dismiss callback
    
    @State private var expandedQuestions = Set<String>()
    @State private var hasInitializedExpanded = false
    @State private var continuationText = ""
    @State private var isProcessingFollowUp = false
    @State private var additionalMessages: [UnifiedChatMessage] = []
    @FocusState private var isInputFocused: Bool
    @State private var isRecording = false
    @State private var contentOffset: CGFloat = 0
    @State private var isKeyInsightExpanded = false
    @State private var editingPage = false
    @State private var pageText = ""
    @FocusState private var isPageFocused: Bool
    @State private var generatedInsight: String? = nil
    @State private var isGeneratingInsight = false
    @State private var showingChat = false
    @State private var showingAmbientMode = false
    @State private var textFieldHeight: CGFloat = 44
    @State private var showQuickActions = false
    @StateObject private var quotaManager = PerplexityQuotaManager.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle, almost invisible gradient
                minimalGradientBackground
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Clean header section
                        headerSection
                            .padding(.top, 0)  // Remove top padding - navigation handles it
                            .padding(.bottom, 24)
                        
                        // Session metrics in monospace
                        metricsSection
                            .padding(.bottom, 32)
                        
                        // Primary content card - show most recent or most relevant question
                        if let mostRelevantQuestion = findMostRelevantQuestion() {
                            primaryInsightCard(question: mostRelevantQuestion)
                                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                .padding(.bottom, 24)
                        }
                        
                        // Clean conversation threads
                        if !(session.capturedQuestions ?? []).isEmpty {
                            conversationSection
                                .padding(.bottom, 32)
                        }
                        
                        // Captured content grid
                        if !(session.capturedQuotes ?? []).isEmpty || !(session.capturedNotes ?? []).isEmpty {
                            capturedContentGrid
                                .padding(.bottom, 32)
                        }
                        
                        // Follow-up messages in ambient style
                        if !additionalMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("FOLLOW-UP")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .tracking(1.2)
                                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                
                                VStack(spacing: 1) {
                                    // Start numbering after existing questions
                                    // Only show AI messages (which contain both Q&A)
                                    let aiMessages = additionalMessages.filter { !$0.isUser }
                                    let startIndex = (session.capturedQuestions ?? []).count
                                    ForEach(Array(aiMessages.enumerated()), id: \.element.id) { index, message in
                                        MinimalMessageView(
                                            message: message,
                                            index: startIndex + index
                                        )
                                        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                    }
                                }
                            }
                            .padding(.bottom, 32)
                        }
                        
                        Spacer(minLength: 120)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Reading Session")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if let onDismiss = onDismiss {
                            // Use custom dismiss callback if provided
                            onDismiss()
                        } else {
                            // Otherwise use standard dismiss
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                minimalInputBar
            }
            .onAppear {
                // Auto-expand all questions on first load
                if !hasInitializedExpanded {
                    for question in session.capturedQuestions ?? [] {
                        expandedQuestions.insert((question.id ?? UUID()).uuidString)
                    }
                    hasInitializedExpanded = true
                }

                // Generate AI insight for the session
                generateAIInsight()
            }
            .fullScreenCover(isPresented: $showingChat) {
                NavigationStack {
                    UnifiedChatView(
                        preSelectedBook: convertBookModelToBook(session.bookModel),
                        startInVoiceMode: false,
                        isAmbientMode: false
                    )
                    .environmentObject(libraryViewModel)
                }
            }
            .sheet(isPresented: $quotaManager.showQuotaExceededSheet) {
                QuotaExceededView()
            }
            .fullScreenCover(isPresented: $showingAmbientMode) {
                NavigationStack {
                    AmbientModeView()
                        .environmentObject(libraryViewModel)
                }
            }
        }
    }
    
    // MARK: - Book Gradient Background - EXACTLY LIKE LIBRARY VIEW
    private var minimalGradientBackground: some View {
        ZStack {
            // Permanent ambient gradient background - EXACTLY LIKE LIBRARY VIEW
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Subtle darkening overlay for better readability - EXACTLY LIKE LIBRARY VIEW
            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Custom Navigation Bar (Removed - using native toolbar)
    // Keeping for reference if needed later
    /*
    private var customNavigationBar: some View {
        HStack {
            // Left - Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Center - Title
            Text("Reading Session")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Right - Menu button
            Menu {
                Button {
                    exportSession()
                } label: {
                    Label("Export Session", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    shareInsights()
                } label: {
                    Label("Share Insights", systemImage: "message")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 8)
        .frame(height: 56)
    }
    */
    
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
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
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
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Metrics Section (Monospaced)
    private var metricsSection: some View {
        HStack(spacing: 24) {
            metricItem(value: formatDuration(session.duration), label: "DURATION")
            
            // Page tracking - tappable to edit
            if editingPage {
                VStack(spacing: 4) {
                    TextField("Page", text: $pageText)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .focused($isPageFocused)
                        .keyboardType(.numberPad)
                        .onSubmit {
                            savePageNumber()
                        }
                    
                    Text("PAGE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.5)
                }
            } else {
                Button {
                    pageText = session.currentPage != nil ? "\(session.currentPage!)" : ""
                    editingPage = true
                    isPageFocused = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Text(session.currentPage != nil ? "\(session.currentPage!)" : "—")
                                .font(.system(size: 24, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.95))
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        }
                        
                        Text("PAGE")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if (session.capturedQuestions ?? []).count > 0 {
                metricItem(value: "\((session.capturedQuestions ?? []).count)", label: "QUESTIONS")
            }
            if (session.capturedQuotes ?? []).count > 0 {
                metricItem(value: "\((session.capturedQuotes ?? []).count)", label: "QUOTES")
            }
            if (session.capturedNotes ?? []).count > 0 {
                metricItem(value: "\((session.capturedNotes ?? []).count)", label: "NOTES")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .onTapGesture {
            if editingPage {
                savePageNumber()
            }
        }
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
                if isGeneratingInsight {
                    // If analyzing, open chat view
                    showingChat = true
                } else {
                    // Otherwise toggle expansion
                    withAnimation(DesignSystem.Animation.springStandard) {
                        isKeyInsightExpanded.toggle()
                    }
                }
                SensoryFeedback.light()
            }) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("KEY INSIGHT")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .tracking(1.2)
                        
                        Spacer()
                        
                        Image(systemName: isKeyInsightExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    // Show AI-generated insight or loading state
                    if isGeneratingInsight {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                .scaleEffect(0.8)
                            Text("Analyzing session...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else if let insight = generatedInsight {
                        Text(insight)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    } else if let answer = question.answer {
                        // Fallback to extracted insight
                        let insight = extractKeyInsight(from: answer, question: question.content ?? "")
                        Text(insight)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    } else {
                        // Fallback to question if no answer
                        Text(question.content ?? "")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(DesignSystem.Spacing.cardPadding)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isKeyInsightExpanded, let answer = question.answer {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5)
                    
                    Text(try! AttributedString(markdown: answer))
                        .font(.custom("Georgia", size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                        .padding(.bottom, 24)
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .clipped()
    }
    
    // MARK: - Conversation Section
    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CONVERSATION")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            
            VStack(spacing: 1) {
                ForEach(Array((session.capturedQuestions ?? []).enumerated()), id: \.element.id) { index, question in
                    MinimalThreadView(
                        question: question,
                        index: index,
                        isExpanded: expandedQuestions.contains((question.id ?? UUID()).uuidString),
                        onToggle: {
                            withAnimation(DesignSystem.Animation.easeQuick) {
                                if expandedQuestions.contains((question.id ?? UUID()).uuidString) {
                                    expandedQuestions.remove((question.id ?? UUID()).uuidString)
                                } else {
                                    expandedQuestions.insert((question.id ?? UUID()).uuidString)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }
    
    // MARK: - Captured Content (Threaded like Conversation)
    private var capturedContentGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CAPTURED")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            
            VStack(spacing: 12) {
                ForEach(session.capturedQuotes ?? []) { quote in
                    MinimalThreadedCard(
                        type: "QUOTE",
                        content: quote.text ?? "",
                        author: quote.author
                    )
                }
                
                ForEach(session.capturedNotes ?? []) { note in
                    MinimalThreadedCard(
                        type: "NOTE",
                        content: note.content ?? "",
                        author: nil
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        }
    }
    
    // MARK: - Input Bar (Universal Input Bar WITHOUT .background())
    private var minimalInputBar: some View {
        VStack(spacing: 0) {
            // Processing indicator with scrolling text pill
            if isProcessingFollowUp {
                HStack {
                    Spacer()
                    
                    // Scrolling text pill - like in ambient mode
                    HStack(spacing: 12) {
                        ScrollingBookMessages()
                            .frame(maxWidth: 200)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    
                    Spacer()
                }
                .padding(.bottom, 16)
            }
            
            // Input bar with proper layout
            HStack(spacing: 12) {
                // Glass input container that expands
                VStack(spacing: 0) {
                    // Main input row
                    HStack(spacing: 12) {
                        // Plus button that expands to show quick actions
                        Button {
                            if !showQuickActions {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showQuickActions = true
                                }
                                isInputFocused = true
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    showQuickActions = false
                                }
                            }
                            SensoryFeedback.light()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .rotationEffect(.degrees(showQuickActions ? 45 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showQuickActions)
                        }

                        // Text input field
                        VStack(spacing: 0) {
                            HStack {
                                if showQuickActions {
                                    // Active text field when expanded
                                    TextField("Continue the conversation...", text: $continuationText, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 17))
                                        .foregroundStyle(.white)
                                        .tint(Color(red: 1.0, green: 0.549, blue: 0.259))
                                        .lineLimit(1...5)
                                        .focused($isInputFocused)
                                        .onSubmit {
                                            if !continuationText.isEmpty {
                                                sendFollowUp()
                                            }
                                        }
                                } else {
                                    // Clean input field
                                    TextField("Continue the conversation...", text: $continuationText, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 17))
                                        .foregroundStyle(.white)
                                        .tint(Color(red: 1.0, green: 0.549, blue: 0.259))
                                        .lineLimit(1...3)
                                        .focused($isInputFocused)
                                        .onSubmit {
                                            if !continuationText.isEmpty {
                                                sendFollowUp()
                                            }
                                        }
                                }

                                Spacer()
                            }
                        }

                        // Right side buttons
                        HStack(spacing: 14) {
                            // Submit button when there's text
                            if !continuationText.isEmpty {
                                Button {
                                    sendFollowUp()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15))
                                            .frame(width: 36, height: 36)
                                            .glassEffect(in: Circle())
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(
                                                        Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.3),
                                                        lineWidth: 0.5
                                                    )
                                            }

                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Ambient orb
                            Button {
                                reopenAmbientMode()
                            } label: {
                                AmbientOrbButton(size: 36) {
                                    // Action handled by parent
                                }
                                .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    // Quick actions (only when expanded)
                    if showQuickActions {
                        VStack(spacing: 0) {
                            Divider()
                                .background(Color.white.opacity(0.1))

                            VStack(spacing: 0) {
                                // Ask About Books
                                QuickActionRow(
                                    icon: "bubble.left.and.bubble.right",
                                    title: "Ask About Books",
                                    subtitle: "Get insights from your library",
                                    warmAmber: Color(red: 1.0, green: 0.549, blue: 0.259),
                                    action: {
                                        continuationText = "What themes connect across my reading?"
                                        showQuickActions = false
                                        sendFollowUp()
                                    }
                                )

                                // Reading Insights
                                QuickActionRow(
                                    icon: "lightbulb",
                                    title: "Reading Insights",
                                    subtitle: "Discover patterns in your notes",
                                    warmAmber: Color(red: 1.0, green: 0.549, blue: 0.259),
                                    action: {
                                        continuationText = "What patterns do you see in my notes and highlights?"
                                        showQuickActions = false
                                        sendFollowUp()
                                    }
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.001))
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.25),
                                    Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: Color(red: 1.0, green: 0.549, blue: 0.259).opacity(0.15), radius: 16, y: 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showQuickActions)
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
    
    private func savePageNumber() {
        editingPage = false
        isPageFocused = false
        
        if let pageNumber = Int(pageText), pageNumber > 0 {
            session.currentPage = pageNumber
            try? modelContext.save()
            print("📖 Updated session page to: \(pageNumber)")
        } else if pageText.isEmpty {
            // Clear page if empty
            session.currentPage = nil
            try? modelContext.save()
        }
    }
    
    private func sendFollowUp() {
        guard !continuationText.isEmpty else { return }
        
        let questionText = continuationText
        continuationText = ""
        
        // Add thinking message (just like ambient mode - ONE message that shows question and gets updated)
        let thinkingMessage = UnifiedChatMessage(
            content: "**\(questionText)**",  // Format like ambient mode
            isUser: false,
            timestamp: Date(),
            bookContext: session.book
        )
        additionalMessages.append(thinkingMessage)
        
        isProcessingFollowUp = true
        
        Task {
            let aiService = AICompanionService.shared
            do {
                let response = try await aiService.processMessage(
                    questionText,
                    bookContext: session.book,
                    conversationHistory: additionalMessages.dropLast() // Exclude thinking message
                )
                
                await MainActor.run {
                    // Update thinking message with the answer (exactly like ambient mode)
                    if let lastIndex = additionalMessages.indices.last {
                        additionalMessages[lastIndex] = UnifiedChatMessage(
                            content: "**\(questionText)**\n\n\(response)",  // Format like ambient mode
                            isUser: false,
                            timestamp: Date(),
                            bookContext: session.book
                        )
                    }
                    
                    // CRITICAL: Save follow-up question to the session
                    let capturedQuestion = CapturedQuestion(
                        content: questionText,
                        book: session.bookModel,
                        pageNumber: session.currentPage,
                        timestamp: Date(),
                        source: .ambient
                    )
                    capturedQuestion.answer = response
                    capturedQuestion.isAnswered = true
                    capturedQuestion.ambientSession = session
                    
                    // Add to session and save
                    if var questions = session.capturedQuestions {
                        questions.append(capturedQuestion)
                        session.capturedQuestions = questions
                    } else {
                        session.capturedQuestions = [capturedQuestion]
                    }
                    modelContext.insert(capturedQuestion)
                    
                    do {
                        try modelContext.save()
                        print("✅ Follow-up question saved to session: \(questionText.prefix(50))...")
                        print("   Session now has \((session.capturedQuestions ?? []).count) questions")
                    } catch {
                        print("❌ Failed to save follow-up question: \(error)")
                    }
                    
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
        SensoryFeedback.light()
    }
    
    private func exportSession() {
        // Export implementation
    }
    
    private func shareInsights() {
        // Share implementation
    }
    
    // MARK: - Helper Functions
    
    private func findMostRelevantQuestion() -> CapturedQuestion? {
        guard !(session.capturedQuestions ?? []).isEmpty else { return nil }
        
        // Strategy: Find the first question with a high-quality answer to maintain chronological order
        // while still showing meaningful content
        let questionsWithAnswers = (session.capturedQuestions ?? []).filter { $0.answer != nil }

        if questionsWithAnswers.isEmpty {
            return (session.capturedQuestions ?? []).first // Return first question if no answers
        }

        // Find the first question that meets quality threshold
        for question in questionsWithAnswers {
            let answer = question.answer ?? ""
            let score = calculateAnswerQuality(answer)

            // Return first question with high quality answer
            if score > 300 {
                return question
            }
        }

        // If no high-quality answers, just return the first question with an answer
        return questionsWithAnswers.first ?? (session.capturedQuestions ?? []).first
    }
    
    private func calculateAnswerQuality(_ answer: String) -> Int {
        var score = answer.count
        
        // Bonus for containing character names (indicates specific content)
        let characterNames = ["Aragorn", "Frodo", "Gandalf", "Bilbo", "Sauron", "Gimli", "Legolas", "Boromir", "Sam", "Merry", "Pippin"]
        for name in characterNames {
            if answer.contains(name) {
                score += 100
            }
        }
        
        // Bonus for containing important items/places
        let importantTerms = ["Andúril", "Narsil", "Sting", "Ring", "Gondor", "Rohan", "Mordor", "Shire", "sword", "throne"]
        for term in importantTerms {
            if answer.lowercased().contains(term.lowercased()) {
                score += 50
            }
        }
        
        // Prefer answers that explain something (not just list facts)
        if answer.contains("symbolizes") || answer.contains("represents") || answer.contains("meaning") {
            score += 200
        }
        
        return score
    }
    
    // MARK: - AI-Powered Insight Generation
    
    private func generateAIInsight() {
        guard generatedInsight == nil && !isGeneratingInsight else { return }
        
        isGeneratingInsight = true
        
        Task {
            do {
                // Prepare session context
                var context = "Reading session analysis:\n"
                
                // Add book context
                if let book = session.book {
                    context += "Book: \(book.title) by \(book.author)\n"
                }
                
                // Add session metrics
                let duration = Int((session.endTime ?? Date()).timeIntervalSince(session.startTime ?? Date())) / 60
                context += "Duration: \(duration) minutes\n"
                context += "Questions asked: \((session.capturedQuestions ?? []).count)\n"
                
                // Add questions and answers
                if !(session.capturedQuestions ?? []).isEmpty {
                    context += "\nKey questions discussed:\n"
                    for (index, question) in (session.capturedQuestions ?? []).prefix(3).enumerated() {
                        context += "\(index + 1). \(question.content)\n"
                        if let answer = question.answer {
                            // Include first sentence of answer for context
                            let firstSentence = answer.components(separatedBy: ". ").first ?? answer
                            context += "   → \(firstSentence.prefix(100))...\n"
                        }
                    }
                }
                
                // Add quotes if available
                if !(session.capturedQuotes ?? []).isEmpty {
                    context += "\nQuotes captured: \((session.capturedQuotes ?? []).count)\n"
                    if let firstQuote = (session.capturedQuotes ?? []).first {
                        context += "Sample: \"\((firstQuote.text ?? "").prefix(50))...\"\n"
                    }
                }
                
                // Add notes if available
                if !(session.capturedNotes ?? []).isEmpty {
                    context += "Notes taken: \((session.capturedNotes ?? []).count)\n"
                }
                
                // Generate insight prompt
                let prompt = """
                Based on this reading session, provide ONE profound, concise insight (maximum 20 words) that captures the essence of what was explored or learned.
                
                The insight should:
                - Be thought-provoking and meaningful
                - Reflect the themes or ideas discussed
                - Not just repeat a question or fact
                - Feel like a valuable takeaway
                
                Context:
                \(context)
                
                Respond with ONLY the insight, no introduction or explanation.
                """
                
                // Try Foundation Models first (free and fast)
                if AICompanionService.shared.currentProvider == .appleIntelligence {
                    let response = try await AICompanionService.shared.processMessage(
                        prompt,
                        bookContext: session.book,
                        conversationHistory: []
                    )
                    
                    await MainActor.run {
                        self.generatedInsight = response.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.isGeneratingInsight = false
                    }
                } else {
                    // Use Perplexity if available
                    let response = try await OptimizedPerplexityService.shared.chat(
                        message: prompt,
                        bookContext: session.book
                    )
                    
                    await MainActor.run {
                        self.generatedInsight = response.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.isGeneratingInsight = false
                    }
                }
            } catch {
                // Fallback to extracted insight
                await MainActor.run {
                    self.isGeneratingInsight = false
                    // Will use the fallback extractKeyInsight method
                }
                print("Failed to generate AI insight: \(error)")
            }
        }
    }
    
    private func extractKeyInsight(from answer: String, question: String) -> String {
        // Remove markdown formatting
        let cleanAnswer = answer
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
        
        // Split into sentences
        let sentences = cleanAnswer.components(separatedBy: ". ")
            .filter { !$0.isEmpty }
        
        // Look for the most insightful sentence
        for sentence in sentences {
            // Skip sentences that are just restating the question
            if sentence.lowercased().contains(question.lowercased()) {
                continue
            }
            
            // Prefer sentences with key information
            let keyPhrases = ["is a", "is the", "was a", "was the", "represents", "lives in", "resides", "known for", "famous for"]
            for phrase in keyPhrases {
                if sentence.lowercased().contains(phrase) {
                    // Clean up and return this sentence
                    let cleaned = sentence
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                    
                    // Add period if missing
                    if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                        return cleaned + "."
                    }
                    return cleaned
                }
            }
        }
        
        // Fallback: return first non-question sentence or a summary
        if let firstGoodSentence = sentences.first(where: { !$0.lowercased().contains(question.lowercased()) }) {
            let cleaned = firstGoodSentence
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            
            if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                return cleaned + "."
            }
            return cleaned
        }
        
        // Ultimate fallback - create a summary from question
        if question.lowercased().starts(with: "who is") {
            let subject = question.replacingOccurrences(of: "Who is ", with: "")
                .replacingOccurrences(of: "?", with: "")
            return "\(subject) is a key character in the story."
        }
        
        return "An important insight from your reading session."
    }

    private func convertBookModelToBook(_ bookModel: BookModel?) -> Book? {
        guard let bookModel = bookModel else { return nil }
        return libraryViewModel.books.first { $0.id == bookModel.id }
    }

    private func reopenAmbientMode() {
        showingAmbientMode = true
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
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                
                Text(question.content ?? "")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
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
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                    
                    Text(try! AttributedString(markdown: answer))
                        .font(.custom("Georgia", size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 40)
                        .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
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
        HStack(alignment: .top, spacing: 16) {
            Text(type)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)
                .frame(width: 60, alignment: .leading)
                .padding(.top, 2)  // Small adjustment to align with text cap height
            
            VStack(alignment: .leading, spacing: 6) {
                Text(content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let author = author {
                    Text("— \(author)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Minimal Message View (Ambient Style)
struct MinimalMessageView: View {
    let message: UnifiedChatMessage
    let index: Int
    @State private var messageOpacity: Double = 0
    @State private var messageBlur: Double = 12
    @State private var messageScale: CGFloat = 0.96
    @State private var isExpanded = false  // Start collapsed like in ambient
    @State private var answerOpacity: Double = 0
    @State private var answerBlur: Double = 8
    @State private var hasShownAnswer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question row - exactly like ambient mode
            HStack(alignment: .center, spacing: 16) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                
                Text(extractQuestion(from: message.content))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textQuaternary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(messageOpacity)
            .blur(radius: messageBlur)
            .scaleEffect(messageScale)
            .onTapGesture {
                withAnimation(DesignSystem.Animation.easeQuick) {
                    isExpanded.toggle()
                }
            }
            .onAppear {
                // Sophisticated blur revelation animation
                withAnimation(
                    .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.6)
                ) {
                    messageOpacity = 1.0
                    messageBlur = 0
                    messageScale = 1.0
                }
            }
            
            // Answer (expandable) - exactly like ambient mode
            if isExpanded && !extractAnswer(from: message.content).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                    
                    Text(formatResponseText(extractAnswer(from: message.content)))
                        .font(.custom("Georgia", size: 17))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 40)  // Indent under the number
                        .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                }
                .opacity(answerOpacity)
                .blur(radius: answerBlur)
                .onAppear {
                    if !hasShownAnswer {
                        hasShownAnswer = true
                        withAnimation(
                            .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.8)
                            .delay(0.3)
                        ) {
                            answerOpacity = 1.0
                            answerBlur = 0
                        }
                    } else {
                        answerOpacity = 1.0
                        answerBlur = 0
                    }
                }
                .onChange(of: isExpanded) { _, newValue in
                    if hasShownAnswer {
                        answerOpacity = newValue ? 1.0 : 0
                        answerBlur = newValue ? 0 : 8
                    }
                }
            }
        }
    }
    
    private func extractQuestion(from content: String) -> String {
        // Extract question from formatted content "**question**\n\nanswer"
        if content.contains("**") && content.contains("\n\n") {
            let parts = content.components(separatedBy: "\n\n")
            if parts.count >= 1 {
                let question = parts[0].replacingOccurrences(of: "**", with: "")
                return question
            }
        }
        // For user messages, return as-is
        return content
    }
    
    private func extractAnswer(from content: String) -> String {
        // Extract answer from formatted content "**question**\n\nanswer"
        if content.contains("**") && content.contains("\n\n") {
            let parts = content.components(separatedBy: "\n\n")
            if parts.count >= 2 {
                let answer = parts.dropFirst().joined(separator: "\n\n")
                return answer
            }
        }
        // If no answer yet (still thinking), return empty
        return ""
    }
    
    private func formatResponseText(_ text: String) -> AttributedString {
        // Split text into sentences and group into paragraphs
        let sentences = text.components(separatedBy: ". ")
        var paragraphs: [String] = []
        var currentParagraph = ""
        
        for (index, sentence) in sentences.enumerated() {
            let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanSentence.isEmpty {
                currentParagraph += cleanSentence
                if !cleanSentence.hasSuffix(".") {
                    currentParagraph += "."
                }
                
                // Create paragraph break every 2-3 sentences or at natural breaks
                if (index + 1) % 3 == 0 || 
                   cleanSentence.contains("However") || 
                   cleanSentence.contains("Additionally") ||
                   cleanSentence.contains("Furthermore") ||
                   cleanSentence.contains("In conclusion") ||
                   cleanSentence.contains("First") ||
                   cleanSentence.contains("Second") ||
                   cleanSentence.contains("Finally") {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                } else if index < sentences.count - 1 {
                    currentParagraph += " "
                }
            }
        }
        
        // Add any remaining text as final paragraph
        if !currentParagraph.trimmingCharacters(in: .whitespaces).isEmpty {
            paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
        }
        
        // Join paragraphs with double newlines for spacing
        let formattedText = paragraphs.joined(separator: "\n\n")
        
        // Convert to AttributedString with markdown support
        do {
            return try AttributedString(markdown: formattedText)
        } catch {
            return AttributedString(formattedText)
        }
    }
}

// MARK: - Session Quick Actions Menu (Direct actions, no input field)
struct SessionQuickActionsMenu: View {
    @Binding var isPresented: Bool
    let onTextSubmit: (String) -> Void
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack {
            Spacer()

            // Position menu above the input field (with proper spacing)
            VStack(spacing: 0) {
                // Quick actions
                VStack(spacing: 0) {
                    // Ask About Books
                    Button {
                        onTextSubmit("What themes connect across my reading?")
                        isPresented = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ask About Books")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("Get insights from your library")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // Reading Insights
                    Button {
                        onTextSubmit("What patterns do you see in my notes and highlights?")
                        isPresented = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 22))
                                .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reading Insights")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("Discover patterns in your notes")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.001))
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .frame(maxWidth: 340)
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Position above the input field
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}
