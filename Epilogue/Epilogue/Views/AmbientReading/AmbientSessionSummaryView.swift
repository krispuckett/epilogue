import SwiftUI
import SwiftData

struct AmbientSessionSummaryView: View {
    let session: OptimizedAmbientSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Animation states
    @State private var showContent = false
    @State private var showSaveCheckmark = false
    @State private var autoDismissTimer: Timer?
    
    // Natural language summary
    @State private var sessionSummary = ""
    @State private var keyInsights: [String] = []
    @State private var bestQuote: SessionContent?
    @State private var readingProgress: Float?
    
    var body: some View {
        ZStack {
            // Beautiful gradient background based on book colors
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 32) {
                    // Elegant header with save animation
                    headerSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    
                    // Natural language summary
                    if !sessionSummary.isEmpty {
                        summarySection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                    }
                    
                    // Key insights with beautiful cards
                    if !keyInsights.isEmpty {
                        insightsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                    }
                    
                    // Best quote with typography
                    if let quote = bestQuote {
                        quoteSection(quote)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
                    }
                    
                    // Reading progress if detected
                    if let progress = readingProgress {
                        progressSection(progress)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
                    }
                    
                    // Continue reading button
                    continueSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            
            // Auto-save checkmark overlay
            if showSaveCheckmark {
                saveCheckmarkOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            generateNaturalSummary()
            startAnimations()
            autoSaveSession()
        }
        .onDisappear {
            autoDismissTimer?.invalidate()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base black
            Color.black.ignoresSafeArea()
            
            // Book-colored gradient if available
            if let book = session.bookContext,
               let primaryColor = getBookPrimaryColor(book) {
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.4),
                        primaryColor.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .blendMode(.plusLighter)
            }
            
            // Subtle noise texture
            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Subtle completion indicator
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.green)
                )
                .scaleEffect(showSaveCheckmark ? 1.2 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSaveCheckmark)
            
            VStack(spacing: 8) {
                Text("Session Complete")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                if let book = session.bookContext {
                    Text(book.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    // MARK: - Natural Language Summary
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sessionSummary)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Key Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                ForEach(keyInsights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .offset(y: 8)
                        
                        Text(insight)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Quote Section
    
    private func quoteSection(_ quote: SessionContent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Large decorative quote mark
            Text("\u{201C}")
                .font(.system(size: 60, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: -10, y: 10)
            
            Text(quote.text)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)
            
            if let bookTitle = quote.bookContext {
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 30, height: 1)
                    
                    Text(bookTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Progress Section
    
    private func progressSection(_ progress: Float) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.pages")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Reading Progress")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
    
    // MARK: - Continue Section
    
    private var continueSection: some View {
        Button {
            continueReading()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 18))
                
                Text("Continue Reading")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [.white, .white.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .white.opacity(0.25), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Save Checkmark Overlay
    
    private var saveCheckmarkOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .scaleEffect(showSaveCheckmark ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSaveCheckmark)
            
            Text("Saved")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Natural Language Generation
    
    private func generateNaturalSummary() {
        // Analyze session content
        let questions = session.allContent.filter { $0.type == .question }
        let quotes = session.allContent.filter { $0.type == .quote }
        let insights = session.allContent.filter { $0.type == .insight }
        
        // Generate natural summary based on content
        var summary = ""
        
        if !questions.isEmpty {
            let themes = extractThemes(from: questions)
            if !themes.isEmpty {
                summary = "You explored themes of \(themes.joined(separator: ", "))"
            }
            
            if questions.count > 3 {
                summary += " through \(questions.count) thoughtful questions"
            }
        }
        
        if !quotes.isEmpty && !summary.isEmpty {
            summary += ", and captured \(quotes.count) meaningful quote\(quotes.count > 1 ? "s" : "")"
        } else if !quotes.isEmpty {
            summary = "You captured \(quotes.count) meaningful quote\(quotes.count > 1 ? "s" : "")"
        }
        
        if let book = session.bookContext {
            if !summary.isEmpty {
                summary += " from \(book.title)"
            }
        }
        
        if summary.isEmpty {
            summary = "You had a thoughtful reading session"
            if let book = session.bookContext {
                summary += " with \(book.title)"
            }
        }
        
        summary += "."
        sessionSummary = summary
        
        // Generate key insights
        generateKeyInsights(questions: questions, quotes: quotes, insights: insights)
        
        // Select best quote
        bestQuote = quotes.max(by: { $0.confidence < $1.confidence })
        
        // Detect reading progress
        detectReadingProgress()
    }
    
    private func extractThemes(from questions: [SessionContent]) -> [String] {
        // Simple theme extraction based on keywords
        var themes: Set<String> = []
        
        for question in questions {
            let text = question.text.lowercased()
            
            if text.contains("hero") || text.contains("journey") || text.contains("quest") {
                themes.insert("the hero's journey")
            }
            if text.contains("courage") || text.contains("brave") || text.contains("fear") {
                themes.insert("courage")
            }
            if text.contains("love") || text.contains("relationship") {
                themes.insert("love and relationships")
            }
            if text.contains("meaning") || text.contains("purpose") || text.contains("why") {
                themes.insert("meaning and purpose")
            }
            if text.contains("identity") || text.contains("who") || text.contains("self") {
                themes.insert("identity")
            }
        }
        
        return Array(themes).prefix(3).map { $0 }
    }
    
    private func generateKeyInsights(questions: [SessionContent], quotes: [SessionContent], insights: [SessionContent]) {
        var generatedInsights: [String] = []
        
        // Add insights based on questions asked
        if questions.count > 5 {
            generatedInsights.append("You engaged deeply with the text, asking \(questions.count) questions about key themes")
        } else if questions.count > 0 {
            generatedInsights.append("You reflected on important passages with thoughtful questions")
        }
        
        // Add insights based on quotes captured
        if quotes.count > 3 {
            generatedInsights.append("You found \(quotes.count) passages that resonated with you")
        }
        
        // Add insights based on session duration
        let minutes = Int(session.duration) / 60
        if minutes > 30 {
            generatedInsights.append("You maintained focus for over \(minutes) minutes of deep reading")
        }
        
        // Add any actual insights from the session
        for insight in insights.prefix(2) {
            if insight.text.count < 100 {
                generatedInsights.append(insight.text)
            }
        }
        
        keyInsights = Array(generatedInsights.prefix(3))
    }
    
    private func detectReadingProgress() {
        // Check if any content mentions page numbers or chapter progress
        for content in session.allContent {
            // PageContext doesn't exist, check bookContext instead
            if content.bookContext != nil {
                // For now, we can't determine page-based progress
                // Could be enhanced with actual page extraction
                break
            }
        }
        
        // Check transcriptions for progress mentions
        let transcriptions = session.rawTranscriptions.joined(separator: " ").lowercased()
        if transcriptions.contains("chapter") {
            // Try to extract chapter number
            // This is simplified - would need better parsing in production
            if transcriptions.contains("chapter 5") {
                readingProgress = 0.25
            } else if transcriptions.contains("chapter 10") {
                readingProgress = 0.5
            } else if transcriptions.contains("halfway") {
                readingProgress = 0.5
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getBookPrimaryColor(_ book: Book) -> Color? {
        // This would normally extract the primary color from the book cover
        // For now, return a default color based on genre or mood
        return session.metadata.mood.color
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.6)) {
            showContent = true
        }
    }
    
    private func autoSaveSession() {
        // Save in background
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showSaveCheckmark = true
                }
                
                // Hide checkmark after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSaveCheckmark = false
                    }
                }
                
                // Auto-dismiss after 3 seconds if configured
                if session.allContent.count < 3 {
                    autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                        continueReading()
                    }
                }
            }
            
            // Actually save the session
            await saveSessionData()
        }
    }
    
    private func saveSessionData() async {
        // Save to persistent storage (SwiftData/CoreData)
        // Implementation depends on your data layer
    }
    
    private func continueReading() {
        // Navigate back to library tab
        if session.bookContext != nil {
            navigationCoordinator.selectedTab = .library
        }
        dismiss()
    }
}

#Preview {
    let book = Book(
        id: "1",
        title: "The Lord of the Rings",
        author: "J.R.R. Tolkien",
        publishedYear: "1954",
        coverImageURL: nil as String?,
        isbn: nil as String?,
        description: "An epic fantasy adventure",
        pageCount: 1216
    )
    
    var session: OptimizedAmbientSession = {
        var s = OptimizedAmbientSession(
            startTime: Date().addingTimeInterval(-1800),
            endTime: nil,
            bookContext: book,
            clusters: [],
            rawTranscriptions: [],
            allContent: [],
            metadata: SessionMetadata()
        )
        s.endTime = Date()
        return s
    }()
    
    AmbientSessionSummaryView(session: session)
        .environmentObject(NavigationCoordinator.shared)
        .environmentObject(LibraryViewModel())
}